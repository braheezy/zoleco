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
    self.cycle_count += 6;
}

// INX D: Increment register pair D.
pub fn inx_D(self: *Z80) !void {
    std.log.debug("[13]\tINC \tDE", .{});
    self.register.d, self.register.e = inx(self.register.d, self.register.e);
    self.cycle_count += 6;
}

// INX H: Increment register pair H.
pub fn inx_H(self: *Z80) !void {
    std.log.debug("[23]\tINC \tHL", .{});
    self.register.h, self.register.l = inx(self.register.h, self.register.l);
    self.cycle_count += 6;
}

// INX SP: Increment stack pointer.
pub fn inx_SP(self: *Z80) !void {
    std.log.debug("[33]\tINC \tSP", .{});
    self.sp += 1;
    self.cycle_count += 6;
}

fn dad(self: *Z80, reg1: u8, reg2: u8) void {
    const reg_pair = @as(u32, Z80.toUint16(reg1, reg2));
    const hl = @as(u32, Z80.toUint16(self.register.h, self.register.l));

    const result = hl + reg_pair;

    self.flag.carry = result > 0xFFFF;
    self.flag.half_carry = (hl & 0xFFF) + (reg_pair & 0xFFF) > 0xFFF;
    self.flag.add_subtract = false;

    self.register.h = @as(u8, @truncate(result >> 8));
    self.register.l = @as(u8, @truncate(result));

    self.cycle_count += 11;
}

// DAD B: Add register pair B to register pair H.
pub fn dad_B(self: *Z80) !void {
    std.log.debug("[09]\tADD \tHL,BC", .{});
    dad(self, self.register.b, self.register.c);
}

// DAD D: Add register pair D to register pair H.
pub fn dad_D(self: *Z80) !void {
    std.log.debug("[19]\tADD \tHL,DE", .{});
    dad(self, self.register.d, self.register.e);
}

// DAD H: Add register pair H to register pair H.
pub fn dad_H(self: *Z80) !void {
    std.log.debug("[29]\tADD \tHL,HL", .{});
    dad(self, self.register.h, self.register.l);
}

// DAD SP: Add stack pointer to register pair H.
pub fn dad_SP(self: *Z80) !void {
    std.log.debug("[39]\tADD \tHL,SP", .{});
    const hl = @as(u32, Z80.toUint16(self.register.h, self.register.l));

    const result = hl + @as(u32, self.sp);

    self.flag.carry = result > 0xFFFF;
    self.flag.half_carry = (hl & 0xFFF) + (self.sp & 0xFFF) > 0xFFF;
    self.flag.add_subtract = false;

    self.register.h = @as(u8, @truncate(result >> 8));
    self.register.l = @as(u8, @truncate(result));

    self.cycle_count += 11;
}
