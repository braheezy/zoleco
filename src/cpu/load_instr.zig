const std = @import("std");
const Z80 = @import("Z80.zig");

const getHighByte = @import("opcode.zig").getHighByte;
const getLowByte = @import("opcode.zig").getLowByte;

const OpcodeTable = @import("opcode.zig").OpcodeTable;

pub fn pushIy(self: *Z80) !void {
    self.sp = if (self.sp == 0) 0xFFFF else self.sp - 1;
    self.memory[self.sp] = getHighByte(self.iy);

    self.sp = if (self.sp == 0) 0xFFFF else self.sp - 1;
    self.memory[self.sp] = getLowByte(self.iy);

    std.log.debug("[FD E5]\tPUSH Iy", .{});

    self.cycle_count += 15;
}

// Swap BC with BC'
pub fn exx(self: *Z80) !void {
    const tempB = self.register.b;
    self.register.b = self.shadow_register.b;
    self.shadow_register.b = tempB;

    const tempC = self.register.c;
    self.register.c = self.shadow_register.c;
    self.shadow_register.c = tempC;

    // Swap DE
    const tempD = self.register.d;
    self.register.d = self.shadow_register.d;
    self.shadow_register.d = tempD;

    const tempE = self.register.e;
    self.register.e = self.shadow_register.e;
    self.shadow_register.e = tempE;

    // Swap HL
    const tempH = self.register.h;
    self.register.h = self.shadow_register.h;
    self.shadow_register.h = tempH;

    const tempL = self.register.l;
    self.register.l = self.shadow_register.l;
    self.shadow_register.l = tempL;

    std.log.debug("[D9]\tEXX", .{});

    // Add the T-cycle cost
    self.cycle_count += 4;
}

pub fn push(self: *Z80, lower: u8, upper: u8) !void {
    // Store value in stack; stack grows downward
    self.memory[self.sp - 1] = upper;
    self.memory[self.sp - 2] = lower;
    self.sp -= 2;
}

pub fn push_DE(self: *Z80) !void {
    std.log.debug("[D5]\tPUSH\tDE", .{});
    try push(self, self.register.e, self.register.d);
    self.cycle_count += 11;
}

pub fn push_HL(self: *Z80) !void {
    std.log.debug("[E5]\tPUSH\tHL", .{});
    try push(self, self.register.l, self.register.h);
    self.cycle_count += 11;
}

pub fn push_BC(self: *Z80) !void {
    std.log.debug("[C5]\tPUSH\tBC", .{});
    try push(self, self.register.c, self.register.b);
    self.cycle_count += 11;
}

pub fn push_AF(self: *Z80) !void {
    std.log.debug("[F5]\tPUSH\tAF", .{});
    try push(self, self.flag.toByte(), self.register.a);
    self.cycle_count += 11;
}

test "pushIy" {
    const allocator = std.testing.allocator;

    var z80 = try Z80.init(std.testing.allocator, &[_]u8{0x1});
    defer z80.free(allocator);

    // Set initial state
    z80.sp = 0xFFFE; // Example stack pointer position
    z80.iy = 0x1234; // Example IY register value
    const original_sp = z80.sp;
    const original_cycle_count = z80.cycle_count;

    // Perform the operation
    pushIy(&z80);

    // Verify SP was decremented correctly
    try std.testing.expect(z80.sp == original_sp - 2);

    // Verify memory contains the pushed IY value
    try std.testing.expect(z80.memory[original_sp - 1] == 0x12); // High byte
    try std.testing.expect(z80.memory[original_sp - 2] == 0x34); // Low byte

    // Verify cycle count
    try std.testing.expect(z80.cycle_count == original_cycle_count + 15);
}

test "exx" {
    // Initialize CPU
    var z80 = Z80{
        .register = Z80.Register{
            .b = 0x44,
            .c = 0x5A,
            .d = 0x3D,
            .e = 0xA2,
            .h = 0x88,
            .l = 0x59,
        },
        .shadow_register = Z80.ShadowRegister{
            .b = 0x09,
            .c = 0x88,
            .d = 0x93,
            .e = 0x00,
            .h = 0x00,
            .l = 0xE7,
        },
        .cycle_count = 1,
    };

    const original_cycles = z80.cycle_count;

    // Perform EXX
    exx(&z80);

    // Verify BC and BC'
    try std.testing.expectEqual(0x09, z80.register.b);
    try std.testing.expectEqual(0x88, z80.register.c);
    try std.testing.expectEqual(0x44, z80.shadow_register.b);
    try std.testing.expectEqual(0x5A, z80.shadow_register.c);

    // Verify DE and DE'
    try std.testing.expectEqual(0x93, z80.register.d);
    try std.testing.expectEqual(0x00, z80.register.e);
    try std.testing.expectEqual(0x3D, z80.shadow_register.d);
    try std.testing.expectEqual(0xA2, z80.shadow_register.e);

    // Verify HL and HL'
    try std.testing.expectEqual(0x00, z80.register.h);
    try std.testing.expectEqual(0xE7, z80.register.l);
    try std.testing.expectEqual(0x88, z80.shadow_register.h);
    try std.testing.expectEqual(0x59, z80.shadow_register.l);

    // Verify T-cycle count
    try std.testing.expectEqual(original_cycles + 4, z80.cycle_count);
}
