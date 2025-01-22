const std = @import("std");
const Z80 = @import("Z80.zig");

pub fn addix(self: *Z80, high: u8, low: u8) void {
    const ix_val: u16 = self.ix;
    const bc_val: u16 = (@as(u16, high) << 8) | @as(u16, low);

    const sum: u32 = @as(u32, ix_val) + @as(u32, bc_val);
    const result: u16 = @intCast(sum & 0xFFFF);

    self.ix = result; // Store the new IX

    // Set carry if the 16-bit addition overflowed
    self.flag.carry = (sum > 0xFFFF);

    // Half-carry if carry from bit 11
    self.flag.half_carry = ((ix_val & 0x0FFF) + (bc_val & 0x0FFF)) > 0x0FFF;

    // N is reset
    self.flag.add_subtract = false;

    self.cycle_count += 7;
}

pub fn add_BC(self: *Z80) !void {
    std.log.debug("[DD 09]\tINC IX BC", .{});
    addix(self, self.register.b, self.register.c);
}

pub fn add_DE(self: *Z80) !void {
    std.log.debug("[DD 19]\tINC IX DE", .{});
    addix(self, self.register.d, self.register.e);
}
