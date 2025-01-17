const std = @import("std");
const Z80 = @import("Z80.zig");

// increment pair helper
pub fn inx(reg1: u8, reg2: u8) struct { u8, u8 } {
    var combined = Z80.toUint16(reg1, reg2);
    combined += 1;

    return .{ @as(u8, @intCast(combined >> 8)), @as(u8, @intCast(combined & 0xFF)) };
}

// INX B: Increment register pair B.
pub fn inx_B(self: *Z80) !void {
    std.log.debug("[03]\tINC \tBC", .{});
    self.register.b, self.register.c = inx(self.register.b, self.register.c);
}

// INX D: Increment register pair D.
pub fn inx_D(self: *Z80) !void {
    std.log.debug("[13]\tINC \tDE", .{});
    self.register.d, self.register.e = inx(self.register.d, self.register.e);
}

// INX H: Increment register pair H.
pub fn inx_H(self: *Z80) !void {
    std.log.debug("[23]\tINC \tHL", .{});
    self.register.h, self.register.l = inx(self.register.h, self.register.l);
}

// INX SP: Increment stack pointer.
pub fn inx_SP(self: *Z80) !void {
    std.log.debug("[33]\tINC \tSP", .{});
    self.sp += 1;
}
