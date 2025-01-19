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
    self.register.a = (self.register.a << 1) | (self.register.a >> (8 - 1));
}
