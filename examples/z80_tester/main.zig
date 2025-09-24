const std = @import("std");
const Allocator = std.mem.Allocator;
const Z80 = @import("z80").Z80;

const TestIO = @import("devices.zig").TestIO;

const assert = std.testing.expect;

const TestCase = struct {
    name: []const u8,
    initial: State,
    final: State,
    cycles: std.json.Value,
    ports: ?std.json.Value = null,
    in_test_data: ?u8 = null,
};

const State = struct {
    pc: u16,
    sp: u16,
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8,
    h: u8,
    l: u8,
    i: u8,
    r: u8,
    ei: u8,
    wz: u16,
    ix: u16,
    iy: u16,
    af_: u16,
    bc_: u16,
    de_: u16,
    hl_: u16,
    im: u8,
    p: u8,
    q: u8,
    iff1: u8,
    iff2: u8,
    ram: [][]u16,
};

const CycleEntry = union(enum) {
    address: u16,
    data: ?u8,
    bus_state: []const u8,
};

const Result = struct {
    total: usize,
    successes: usize,
};

var has_failure = false;
pub fn main() !void {
    // Memory allocation setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };

    // args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cwd = std.fs.cwd();

    for (args[1..]) |arg| {
        const single_test_file = if (std.mem.indexOf(u8, arg, " ") == null)
            try std.fmt.allocPrint(allocator, "{s}.json", .{arg})
        else
            try std.fmt.allocPrint(allocator, "{s}.json", .{arg});
        defer allocator.free(single_test_file);
        std.debug.print("running single file: {s}\n", .{single_test_file});
        try processFile(single_test_file, allocator);
        std.process.exit(0);
    } else {
        // Otherwise, iterate over all files in "tests" directory, relative to this file
        var tests_dir = try cwd.openDir("tests", .{ .iterate = true });
        defer tests_dir.close();

        var it = tests_dir.iterate();
        while (try it.next()) |entry| {
            const file_name = entry.name;
            try processFile(file_name, allocator);
        }
    }

    if (has_failure) {
        std.debug.print("❌ There was a failure!\n", .{});
    } else {
        std.debug.print("✅ All tests passed!\n", .{});
    }
}

fn processFile(name: []const u8, allocator: std.mem.Allocator) !void {
    const cwd = std.fs.cwd();
    const full_path = try std.fmt.allocPrint(allocator, "tests/{s}", .{name});
    defer allocator.free(full_path);

    var file = try cwd.openFile(full_path, .{});
    defer file.close();

    // Split the filename (without .json) into parts
    const base_name = name[0 .. name.len - 5]; // Remove .json
    var parts = std.mem.splitScalar(u8, base_name, ' ');
    var opcodes = std.array_list.Managed([]const u8).init(allocator);
    defer opcodes.deinit();

    while (parts.next()) |part| {
        // Skip underscores as they represent displacement bytes
        if (!std.mem.eql(u8, part, "__")) {
            try opcodes.append(part);
        }
    }

    // Print opcode info based on number of parts
    switch (opcodes.items.len) {
        1 => { // Single opcode like "00"
            const arrow = if (opcodes.items[0].len == 3) "======>" else "=======>";
            std.debug.print("0x{s} {s} ", .{ opcodes.items[0], arrow });
        },
        2 => { // Prefix + opcode like "dd 00"
            const arrow = if (opcodes.items[1].len == 3) "===>" else "====>";
            std.debug.print("0x{s} {s} {s} ", .{ opcodes.items[0], opcodes.items[1], arrow });
        },
        3 => { // Double prefix like "dd cb 00" or "dd cb __ 00"
            std.debug.print("0x{s} {s} {s} => ", .{ opcodes.items[0], opcodes.items[1], opcodes.items[2] });
        },
        else => {
            std.debug.print("Invalid opcode format in filename: {s}\n", .{name});
            return;
        },
    }

    const json_content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(json_content);

    var parsed = try std.json.parseFromSlice([]TestCase, allocator, json_content, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const test_cases = parsed.value;
    var result = Result{ .successes = 0, .total = test_cases.len };
    var failures = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (failures.items) |msg| allocator.free(msg);
        failures.deinit();
    }

    var test_io = try TestIO.init(allocator);
    defer allocator.destroy(test_io);

    var z80 = try Z80.init(allocator);
    defer allocator.destroy(z80);
    z80.io = &test_io.io;
    z80.input_last_cycle = true;

    for (test_cases) |*tc| {
        if (tc.ports) |ports| {
            const arr = ports.array.items[0].array;
            const data: u8 = @intCast(arr.items[1].integer);
            // port
            _ = arr.items[2];
            tc.*.in_test_data = data;
        }
        if (runTest(
            allocator,
            tc.*,
            &failures,
            z80,
            test_io,
        ) catch false) {
            result.successes += 1;
        }
    }

    printResult(result.successes, result.total);
    if (result.successes != result.total) {
        has_failure = true;
        for (failures.items[0..@min(10, failures.items.len)]) |msg| {
            std.debug.print("  {s}\n", .{msg});
        }
    }
}

fn printResult(successes: usize, total: usize) void {
    if (successes == total) {
        std.debug.print("({d}/{d})...OK\n", .{ successes, total });
    } else {
        std.debug.print("({d}/{d})...FAIL\n", .{ successes, total });
    }
}

fn runTest(
    al: std.mem.Allocator,
    t: TestCase,
    failures: *std.array_list.Managed([]const u8),
    z80: *Z80,
    test_io: *TestIO,
) !bool {
    loadState(z80, t.initial);
    test_io.value = t.in_test_data orelse 0;
    _ = try z80.step();
    try validateState(z80.*, t.final, al, failures);
    z80.input_last_cycle = true;
    return failures.items.len == 0;
}

fn loadState(z80: *Z80, state: State) void {
    z80.pc = state.pc;
    z80.sp = state.sp;
    z80.ix = state.ix;
    z80.iy = state.iy;
    z80.r = state.r;

    z80.register.a = state.a;
    z80.register.b = state.b;
    z80.register.c = state.c;
    z80.register.d = state.d;
    z80.register.e = state.e;
    z80.register.h = state.h;
    z80.register.l = state.l;

    z80.wz = state.wz;

    z80.shadow_register.a = @intCast((state.af_ >> 8) & 0xFF);
    z80.shadow_register.b = @intCast((state.bc_ >> 8) & 0xFF);
    z80.shadow_register.c = @intCast(state.bc_ & 0xFF);
    z80.shadow_register.d = @intCast((state.de_ >> 8) & 0xFF);
    z80.shadow_register.e = @intCast(state.de_ & 0xFF);
    z80.shadow_register.h = @intCast((state.hl_ >> 8) & 0xFF);
    z80.shadow_register.l = @intCast(state.hl_ & 0xFF);

    z80.flag.sign = (state.f & 0x80) != 0;
    z80.flag.zero = (state.f & 0x40) != 0;
    z80.flag.y = (state.f & 0x20) != 0;
    z80.flag.half_carry = (state.f & 0x10) != 0;
    z80.flag.x = (state.f & 0x08) != 0;
    z80.flag.parity_overflow = (state.f & 0x04) != 0;
    z80.flag.add_subtract = (state.f & 0x02) != 0;
    z80.flag.carry = (state.f & 0x01) != 0;

    const shadow_flag: u8 = @intCast(state.af_ & 0xFF);

    z80.shadow_flag.sign = (shadow_flag & 0x80) != 0;
    z80.shadow_flag.zero = (shadow_flag & 0x40) != 0;
    z80.shadow_flag.y = (shadow_flag & 0x20) != 0;
    z80.shadow_flag.half_carry = (shadow_flag & 0x10) != 0;
    z80.shadow_flag.x = (shadow_flag & 0x08) != 0;
    z80.shadow_flag.parity_overflow = (shadow_flag & 0x04) != 0;
    z80.shadow_flag.add_subtract = (shadow_flag & 0x02) != 0;
    z80.shadow_flag.carry = (shadow_flag & 0x01) != 0;

    z80.q = state.q;

    z80.iff1 = state.iff1 != 0;
    z80.iff2 = state.iff2 != 0;
    z80.i = state.i;
    z80.interrupt_mode = switch (state.im) {
        0 => .{ .zero = {} },
        1 => .{ .one = {} },
        2 => .{ .two = {} },
        else => unreachable,
    };

    for (state.ram) |entry| {
        z80.io.writeMemory(z80.io.ctx, entry[0], @intCast(entry[1]));
    }
}

fn checkEquals(comptime T: type, allocator: std.mem.Allocator, failures: *std.array_list.Managed([]const u8), label: []const u8, actual: T, expected: T) !void {
    if (@TypeOf(actual) == Z80.InterruptMode) {
        const actual_mode = @intFromEnum(actual);
        const expected_mode = @intFromEnum(expected);
        if (actual_mode != expected_mode) {
            const msg = try std.fmt.allocPrint(allocator, "{s}: expected {d}, got {d}", .{ label, expected_mode, actual_mode });
            try failures.append(msg);
        }
        return;
    }
    if (actual != expected) {
        const msg = try std.fmt.allocPrint(allocator, "{s}: expected {any}, got {any}", .{ label, expected, actual });
        try failures.append(msg);
    }
}

fn validateState(z80: Z80, state: State, al: std.mem.Allocator, failures: *std.array_list.Managed([]const u8)) !void {
    try checkEquals(u16, al, failures, "pc", z80.pc, state.pc);
    try checkEquals(u16, al, failures, "sp", z80.sp, state.sp);
    try checkEquals(u16, al, failures, "ix", z80.ix, state.ix);
    try checkEquals(u16, al, failures, "iy", z80.iy, state.iy);
    try checkEquals(u8, al, failures, "r", z80.r, state.r);

    try checkEquals(u8, al, failures, "a", z80.register.a, state.a);
    try checkEquals(u8, al, failures, "b", z80.register.b, state.b);
    try checkEquals(u8, al, failures, "c", z80.register.c, state.c);
    try checkEquals(u8, al, failures, "d", z80.register.d, state.d);
    try checkEquals(u8, al, failures, "e", z80.register.e, state.e);
    try checkEquals(u8, al, failures, "h", z80.register.h, state.h);
    try checkEquals(u8, al, failures, "l", z80.register.l, state.l);

    try checkEquals(u8, al, failures, "shadow a", z80.shadow_register.a, @as(u8, @intCast((state.af_ >> 8) & 0xFF)));
    try checkEquals(u8, al, failures, "shadow b", z80.shadow_register.b, @as(u8, @intCast((state.bc_ >> 8) & 0xFF)));
    try checkEquals(u8, al, failures, "shadow c", z80.shadow_register.c, @as(u8, @intCast(state.bc_ & 0xFF)));
    try checkEquals(u8, al, failures, "shadow d", z80.shadow_register.d, @as(u8, @intCast((state.de_ >> 8) & 0xFF)));
    try checkEquals(u8, al, failures, "shadow e", z80.shadow_register.e, @as(u8, @intCast(state.de_ & 0xFF)));
    try checkEquals(u8, al, failures, "shadow h", z80.shadow_register.h, @as(u8, @intCast((state.hl_ >> 8) & 0xFF)));
    try checkEquals(u8, al, failures, "shadow l", z80.shadow_register.l, @as(u8, @intCast(state.hl_ & 0xFF)));

    const exp_flags = Z80.Flag{
        .sign = (state.f & 0x80) != 0,
        .zero = (state.f & 0x40) != 0,
        .y = (state.f & 0x20) != 0,
        .half_carry = (state.f & 0x10) != 0,
        .x = (state.f & 0x08) != 0,
        .parity_overflow = (state.f & 0x04) != 0,
        .add_subtract = (state.f & 0x02) != 0,
        .carry = (state.f & 0x01) != 0,
    };
    try checkEquals(bool, al, failures, "flag.sign", z80.flag.sign, exp_flags.sign);
    try checkEquals(bool, al, failures, "flag.zero", z80.flag.zero, exp_flags.zero);
    try checkEquals(bool, al, failures, "flag.y", z80.flag.y, exp_flags.y);
    try checkEquals(bool, al, failures, "flag.half_carry", z80.flag.half_carry, exp_flags.half_carry);
    try checkEquals(bool, al, failures, "flag.parity_overflow", z80.flag.parity_overflow, exp_flags.parity_overflow);
    try checkEquals(bool, al, failures, "flag.x", z80.flag.x, exp_flags.x);
    try checkEquals(bool, al, failures, "flag.carry", z80.flag.carry, exp_flags.carry);
    try checkEquals(bool, al, failures, "flag.add_subtract", z80.flag.add_subtract, exp_flags.add_subtract);

    try checkEquals(u8, al, failures, "q", z80.q, state.q);

    try checkEquals(bool, al, failures, "interrupts_enabled 1", z80.iff1, (state.iff1 != 0));
    try checkEquals(bool, al, failures, "interrupts_enabled 2", z80.iff2, (state.iff2 != 0));
    try checkEquals(u8, al, failures, "i", z80.i, state.i);
    const expected_interrupt_mode: Z80.InterruptMode = switch (state.im) {
        0 => Z80.InterruptMode{ .zero = {} },
        1 => Z80.InterruptMode{ .one = {} },
        2 => Z80.InterruptMode{ .two = {} },
        else => unreachable,
    };
    try checkEquals(@TypeOf(z80.interrupt_mode), al, failures, "interrupt_mode", z80.interrupt_mode, expected_interrupt_mode);

    try checkEquals(u16, al, failures, "wz", z80.wz, state.wz);

    for (state.ram) |entry| {
        const addr = entry[0];
        const value = entry[1];
        const str = try std.fmt.allocPrint(al, "memory[{d}]", .{addr});
        defer al.free(str);
        try checkEquals(u8, al, failures, str, z80.io.readMemory(z80.io.ctx, addr), @truncate(value));
    }
}
