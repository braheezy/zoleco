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
    std.log.debug("[0F] RRC \tA", .{});

    self.flag.carry = self.register.a & 0x01 == 1;

    self.register.a = std.math.rotr(u8, self.register.a, 1);

    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    self.cycle_count += 4;
}

fn parity(x: u8) bool {
    var count: u8 = 0;
    var val = x;
    while (val != 0) {
        count += val & 1;
        val >>= 1;
    }
    // Even parity if count of ones is even
    return (count & 1) == 0;
}
