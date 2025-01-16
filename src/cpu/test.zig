const std = @import("std");
const Allocator = std.mem.Allocator;
const Z80 = @import("Z80.zig");
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

// const RamEntry = struct {
//     address: u16,
//     value: u8,
// };

// const CycleEnum = enum {
//     address,
//     data,
//     bus_state,
// };

const CycleEntry = union(enum) {
    address: u16,
    data: u8,
    bus_state: []const u8,
};

const Cycle = struct {
    address: ?u16,
    data: ?u8,
    bus_state: ?[]const u8,
};

pub fn main() !void {
    // Memory allocation setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <test_file.json>\n", .{args[0]});
        return;
    }

    const json_file_path = args[1];
    var file = try std.fs.cwd().openFile(json_file_path, .{});
    defer file.close();

    const json_content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(json_content);

    std.debug.print("json_content {s}\n", .{json_content});
    var parsed = try std.json.parseFromSlice([]TestCase, allocator, json_content, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    _ = parsed.value;

    // for (test_case) |t| {
    // try runTest(allocator, test_case);
    // }
}

fn runTest(al: std.mem.Allocator, t: TestCase) !void {
    std.debug.print("Running test: {s}\n", .{t.name});

    const memory = try al.alloc(u8, 0x10000);

    var z80 = Z80{ .memory = memory };
    loadState(&z80, t.initial);

    // for (t.cycles) |_| {
    // Execute one step
    try z80.step();
    // }

    // try validateState(&z80, t.final);
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
        z80.memory[entry[0]] = entry[1];
    }
}

fn validateState(z80: *Z80, state: State) !void {
    try assert(z80.pc == state.pc);
    try assert(z80.sp == state.sp);
    try assert(z80.ix == state.ix);
    try assert(z80.iy == state.iy);
    try assert(z80.r == state.r);

    try assert(z80.register.a == state.a);
    try assert(z80.register.b == state.b);
    try assert(z80.register.c == state.c);
    try assert(z80.register.d == state.d);
    try assert(z80.register.e == state.e);
    try assert(z80.register.h == state.h);
    try assert(z80.register.l == state.l);

    try assert(z80.shadow_register.a == @as(u8, @intCast((state.af_ >> 8) & 0xFF)));
    try assert(z80.shadow_register.b == @as(u8, @intCast((state.bc_ >> 8) & 0xFF)));
    try assert(z80.shadow_register.c == @as(u8, @intCast(state.bc_ & 0xFF)));
    try assert(z80.shadow_register.d == @as(u8, @intCast((state.de_ >> 8) & 0xFF)));
    try assert(z80.shadow_register.e == @as(u8, @intCast(state.de_ & 0xFF)));
    try assert(z80.shadow_register.h == @as(u8, @intCast((state.hl_ >> 8) & 0xFF)));
    try assert(z80.shadow_register.l == @as(u8, @intCast(state.hl_ & 0xFF)));

    const expected_flags = Z80.Flag{
        .sign = (state.f & 0x80) != 0,
        .zero = (state.f & 0x40) != 0,
        .half_carry = (state.f & 0x10) != 0,
        .parity_overflow = (state.f & 0x04) != 0,
        .carry = (state.f & 0x01) != 0,
    };
    try assert(z80.flag.sign == expected_flags.sign);
    try assert(z80.flag.zero == expected_flags.zero);
    try assert(z80.flag.half_carry == expected_flags.half_carry);
    try assert(z80.flag.parity_overflow == expected_flags.parity_overflow);
    try assert(z80.flag.carry == expected_flags.carry);

    try assert(z80.interrupts_enabled == (state.iff1 != 0));
    const expected_interrupt_mode: Z80.InterruptMode = switch (state.im) {
        0 => Z80.InterruptMode{ .zero = {} },
        1 => Z80.InterruptMode{ .one = {} },
        2 => Z80.InterruptMode{ .two = {} },
        else => unreachable,
    };
    try assert(@intFromEnum(z80.interrupt_mode) == @intFromEnum(expected_interrupt_mode));

    for (state.ram) |entry| {
        try assert(z80.memory[entry[0]] == entry[1]);
    }
}
