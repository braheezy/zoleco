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
    self.register.b, self.register.c = inx(self.register.b, self.register.c);
    self.cycle_count += 6;
}

// INX D: Increment register pair D.
pub fn inx_D(self: *Z80) !void {
    self.register.d, self.register.e = inx(self.register.d, self.register.e);
    self.cycle_count += 6;
}

// INX H: Increment register pair H.
pub fn inx_H(self: *Z80) !void {
    self.register.h, self.register.l = inx(self.register.h, self.register.l);
    self.cycle_count += 6;
}

// INX SP: Increment stack pointer.
pub fn inx_SP(self: *Z80) !void {
    self.sp += 1;
    self.cycle_count += 6;
}

fn dad(self: *Z80, reg1: u8, reg2: u8) void {
    const reg_pair = @as(u32, Z80.toUint16(reg1, reg2));
    const hl = @as(u32, self.getHL());

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
    dad(self, self.register.b, self.register.c);
}

// DAD D: Add register pair D to register pair H.
pub fn dad_D(self: *Z80) !void {
    dad(self, self.register.d, self.register.e);
}

// DAD H: Add register pair H to register pair H.
pub fn dad_H(self: *Z80) !void {
    dad(self, self.register.h, self.register.l);
}

// DAD SP: Add stack pointer to register pair H.
pub fn dad_SP(self: *Z80) !void {
    const hl = @as(u32, self.getHL());

    const result = hl + @as(u32, self.sp);

    self.flag.carry = result > 0xFFFF;
    self.flag.half_carry = (hl & 0xFFF) + (self.sp & 0xFFF) > 0xFFF;
    self.flag.add_subtract = false;

    self.register.h = @as(u8, @truncate(result >> 8));
    self.register.l = @as(u8, @truncate(result));

    self.cycle_count += 11;
}

pub fn push(self: *Z80, lower: u8, upper: u8) void {
    // Store value in stack, note: stack grows downwards
    self.memory[self.sp - 1] = upper;
    self.memory[self.sp - 2] = lower;
    self.sp -= 2;
    self.cycle_count += 11;
}

// PUSH D: Push register pair D onto stack.
pub fn push_DE(self: *Z80) !void {
    push(self, self.register.e, self.register.d);
}

// PUSH H: Push register pair H onto stack.
pub fn push_HL(self: *Z80) !void {
    push(self, self.register.l, self.register.h);
}

// PUSH B: Push register pair B onto stack.
pub fn push_BC(self: *Z80) !void {
    push(self, self.register.c, self.register.b);
}

// PUSH AF: Push accumulator and flags onto stack.
pub fn push_AF(self: *Z80) !void {
    push(self, self.flag.toByte(), self.register.a);
}

// pop returns two bytes from the stack.
pub fn pop(self: *Z80) struct { u8, u8 } {
    const lower = self.memory[self.sp];
    const upper = self.memory[self.sp + 1];
    self.sp += 2;
    self.cycle_count += 10;

    return .{ lower, upper };
}

// POP H: Pop register pair H from stack.
pub fn pop_HL(self: *Z80) !void {
    self.register.l, self.register.h = pop(self);
}

// POP B: Pop register pair B from stack.
pub fn pop_BC(self: *Z80) !void {
    self.register.c, self.register.b = pop(self);
}

// POP D: Pop register pair D from stack.
pub fn pop_DE(self: *Z80) !void {
    self.register.e, self.register.d = pop(self);
}

// POP AF: Pop accumulator and flags from stack.
pub fn pop_AF(self: *Z80) !void {
    const fl, self.register.a = pop(self);
    self.flag = Z80.Flag.fromByte(fl);
}
