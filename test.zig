const std = @import("std");
const Allocator = std.mem.Allocator;
const Z80 = @import("z80");
const assets = @import("assets");

const assert = std.testing.expect;

const TestCase = struct {
    name: []const u8,
    initial: State,
    final: State,
    cycles: std.json.Value,
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

pub fn main() !void {
    // Memory allocation setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };

    var total_failures = std.ArrayList([]const u8).init(allocator);
    defer total_failures.deinit();

    for (assets.files) |json_file_path| {
        const full_json_file_path = try std.fmt.allocPrint(allocator, "tests/{s}", .{json_file_path});
        defer allocator.free(full_json_file_path);
        var file = try std.fs.cwd().openFile(full_json_file_path, .{});
        defer file.close();

        const json_content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(json_content);

        var parsed = try std.json.parseFromSlice([]TestCase, allocator, json_content, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const test_case = parsed.value;

        std.debug.print("Running test: {s}...\n", .{test_case[0].name[0..2]});

        for (test_case) |t| {
            try runTest(allocator, t, &total_failures);
        }
    }

    if (total_failures.items.len != 0) {
        std.debug.print("Failures:\n", .{});
        for (total_failures.items) |msg| {
            std.debug.print("{s}\n", .{msg});
            allocator.free(msg);
        }
    } else {
        std.debug.print("All tests passed.\n", .{});
    }
}

fn runTest(al: std.mem.Allocator, t: TestCase, total_failures: *std.ArrayList([]const u8)) !void {
    const memory = try al.alloc(u8, 0x10000);
    defer al.free(memory);

    var z80 = Z80{ .memory = memory };
    loadState(&z80, t.initial);

    try z80.step();

    var failures = std.ArrayList([]const u8).init(al);
    defer {
        // for (failures.items) |msg| {
        //     al.free(msg);
        // }
        failures.deinit();
    }

    try validateState(z80, t.final, al, &failures);
    if (failures.items.len != 0) {
        try total_failures.appendSlice(failures.items);
    }
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

    z80.shadow_register.a = @intCast((state.af_ >> 8) & 0xFF);
    z80.shadow_register.b = @intCast((state.bc_ >> 8) & 0xFF);
    z80.shadow_register.c = @intCast(state.bc_ & 0xFF);
    z80.shadow_register.d = @intCast((state.de_ >> 8) & 0xFF);
    z80.shadow_register.e = @intCast(state.de_ & 0xFF);
    z80.shadow_register.h = @intCast((state.hl_ >> 8) & 0xFF);
    z80.shadow_register.l = @intCast(state.hl_ & 0xFF);

    z80.flag.sign = (state.f & 0x80) != 0;
    z80.flag.zero = (state.f & 0x40) != 0;
    z80.flag.half_carry = (state.f & 0x10) != 0;
    z80.flag.parity_overflow = (state.f & 0x04) != 0;
    z80.flag.carry = (state.f & 0x01) != 0;

    z80.interrupts_enabled = state.iff1 != 0;
    z80.interrupt_mode = switch (state.im) {
        0 => .{ .zero = {} },
        1 => .{ .one = {} },
        2 => .{ .two = {} },
        else => unreachable,
    };

    for (state.ram) |entry| {
        z80.memory[entry[0]] = @intCast(entry[1]);
    }
}

fn checkEquals(comptime T: type, allocator: std.mem.Allocator, failures: *std.ArrayList([]const u8), label: []const u8, actual: T, expected: T) !void {
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

fn validateState(z80: Z80, state: State, allocator: std.mem.Allocator, failures: *std.ArrayList([]const u8)) !void {
    try checkEquals(u16, allocator, failures, "pc", z80.pc, state.pc);
    try checkEquals(u16, allocator, failures, "sp", z80.sp, state.sp);
    try checkEquals(u16, allocator, failures, "ix", z80.ix, state.ix);
    try checkEquals(u16, allocator, failures, "iy", z80.iy, state.iy);
    try checkEquals(u8, allocator, failures, "r", z80.r, state.r);

    try checkEquals(u8, allocator, failures, "a", z80.register.a, state.a);
    try checkEquals(u8, allocator, failures, "b", z80.register.b, state.b);
    try checkEquals(u8, allocator, failures, "c", z80.register.c, state.c);
    try checkEquals(u8, allocator, failures, "d", z80.register.d, state.d);
    try checkEquals(u8, allocator, failures, "e", z80.register.e, state.e);
    try checkEquals(u8, allocator, failures, "h", z80.register.h, state.h);
    try checkEquals(u8, allocator, failures, "l", z80.register.l, state.l);

    try checkEquals(u8, allocator, failures, "shadow a", z80.shadow_register.a, @as(u8, @intCast((state.af_ >> 8) & 0xFF)));
    try checkEquals(u8, allocator, failures, "shadow b", z80.shadow_register.b, @as(u8, @intCast((state.bc_ >> 8) & 0xFF)));
    try checkEquals(u8, allocator, failures, "shadow c", z80.shadow_register.c, @as(u8, @intCast(state.bc_ & 0xFF)));
    try checkEquals(u8, allocator, failures, "shadow d", z80.shadow_register.d, @as(u8, @intCast((state.de_ >> 8) & 0xFF)));
    try checkEquals(u8, allocator, failures, "shadow e", z80.shadow_register.e, @as(u8, @intCast(state.de_ & 0xFF)));
    try checkEquals(u8, allocator, failures, "shadow h", z80.shadow_register.h, @as(u8, @intCast((state.hl_ >> 8) & 0xFF)));
    try checkEquals(u8, allocator, failures, "shadow l", z80.shadow_register.l, @as(u8, @intCast(state.hl_ & 0xFF)));

    const expected_flags = Z80.Flag{
        .sign = (state.f & 0x80) != 0,
        .zero = (state.f & 0x40) != 0,
        .half_carry = (state.f & 0x10) != 0,
        .parity_overflow = (state.f & 0x04) != 0,
        .carry = (state.f & 0x01) != 0,
    };
    try checkEquals(bool, allocator, failures, "flag.sign", z80.flag.sign, expected_flags.sign);
    try checkEquals(bool, allocator, failures, "flag.zero", z80.flag.zero, expected_flags.zero);
    try checkEquals(bool, allocator, failures, "flag.half_carry", z80.flag.half_carry, expected_flags.half_carry);
    try checkEquals(bool, allocator, failures, "flag.parity_overflow", z80.flag.parity_overflow, expected_flags.parity_overflow);
    try checkEquals(bool, allocator, failures, "flag.carry", z80.flag.carry, expected_flags.carry);

    try checkEquals(bool, allocator, failures, "interrupts_enabled", z80.interrupts_enabled, (state.iff1 != 0));
    const expected_interrupt_mode: Z80.InterruptMode = switch (state.im) {
        0 => Z80.InterruptMode{ .zero = {} },
        1 => Z80.InterruptMode{ .one = {} },
        2 => Z80.InterruptMode{ .two = {} },
        else => unreachable,
    };
    try checkEquals(@TypeOf(z80.interrupt_mode), allocator, failures, "interrupt_mode", z80.interrupt_mode, expected_interrupt_mode);

    for (state.ram) |entry| {
        const addr = entry[0];
        const value = entry[1];
        try checkEquals(u8, allocator, failures, "memory[{d}]", z80.memory[addr], @truncate(value));
    }
}
