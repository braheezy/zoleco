const std = @import("std");
const Z80 = @import("Z80.zig");

// RLC: Rotate accumulator left. The Carry bit is set equal to the high-order
// bit of the accumulator. The contents of the accumulator are rotated one bit
// position to the left, with the high-order bit being transferred to the
// low-order bit position of the accumulator
pub fn rlc(self: *Z80) !void {
    std.log.debug("[07]\tRLC \tA", .{});
    self.flag.carry = (self.register.a & 0x80) == 0x80;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.register.a = std.math.rotl(u8, self.register.a, 1);
    self.cycle_count += 4;
}

// RRC: Rotate accumulator right.
// The carry bit is set equal to the low-order
// bit of the accumulator. The contents of the accumulator are
// rotated one bit position to the right, with the low-order bit
// being transferred to the high-order bit position of the
// accumulator.
pub fn rrc(self: *Z80) !void {
    std.log.debug("[0F]\tRRC \tA", .{});

    self.flag.carry = self.register.a & 0x01 == 1;

    self.register.a = std.math.rotr(u8, self.register.a, 1);

    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    self.cycle_count += 4;
}

// RAL: Rotate accumulator left through carry.
// The contents of the accumulator are rotated one bit position to the left.
// The high-order bit of the accumulator replaces the Carry bit, while the
// Carry bit replaces the high-order bit of the accumulator.
pub fn ral(self: *Z80) !void {
    std.log.debug("[17]\tRAL \tA", .{});
    const carry: u8 = if (self.flag.carry)
        1
    else
        0;

    // Isolate most significant bit to check for Carry
    self.flag.carry = (self.register.a & 0x80) == 0x80;
    // Rotate accumulator left through carry
    self.register.a = (self.register.a << 1) | carry;

    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.cycle_count += 4;
}

// RAR: Rotate accumulator right through carry.
// The contents of the accumulator are rotated one bit position to the right.
// The low order bit of the accumulator replaces the carry bit, while the carry bit replaces
// the high order bit of the accumulator.
pub fn rra(self: *Z80) !void {
    std.log.debug("[1F]\tRAR \tA", .{});
    const carry_rotate: u8 = if (self.flag.carry)
        1
    else
        0;

    // Isolate least significant bit to check for Carry
    self.flag.carry = self.register.a & 0x01 != 0;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    // Rotate accumulator right through carry
    self.register.a = (self.register.a >> 1) | (carry_rotate << (8 - 1));
    self.cycle_count += 4;
}
