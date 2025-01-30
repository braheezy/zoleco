const std = @import("std");
const Z80 = @import("Z80.zig");

// RLC: Rotate accumulator left. The Carry bit is set equal to the high-order
// bit of the accumulator. The contents of the accumulator are rotated one bit
// position to the left, with the high-order bit being transferred to the
// low-order bit position of the accumulator
pub fn rlca(self: *Z80) !void {
    self.flag.carry = (self.register.a & 0x80) == 0x80;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.cycle_count += 4;
    self.register.a = std.math.rotl(u8, self.register.a, 1);
    self.flag.setUndocumentedFlags(self.register.a);
    self.q = self.flag.toByte();
}

pub fn rlc(self: *Z80, data: u8) u8 {
    self.flag.carry = (data & 0x80) == 0x80;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    const result = std.math.rotl(u8, data, 1);
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.parity_overflow = Z80.parity(u8, result);
    self.flag.setUndocumentedFlags(result);
    self.cycle_count += 8;
    self.q = self.flag.toByte();
    return result;
}

pub fn rlc_B(self: *Z80) !void {
    self.register.b = rlc(self, self.register.b);
}

pub fn rlc_C(self: *Z80) !void {
    self.register.c = rlc(self, self.register.c);
}

pub fn rlc_D(self: *Z80) !void {
    self.register.d = rlc(self, self.register.d);
}

pub fn rlc_E(self: *Z80) !void {
    self.register.e = rlc(self, self.register.e);
}

pub fn rlc_H(self: *Z80) !void {
    self.register.h = rlc(self, self.register.h);
}

pub fn rlc_L(self: *Z80) !void {
    self.register.l = rlc(self, self.register.l);
}

pub fn rlc_M(self: *Z80) !void {
    const address = self.getHL();
    self.memory[address] = rlc(self, self.memory[address]);
}

pub fn rlc_A(self: *Z80) !void {
    self.register.a = rlc(self, self.register.a);
}

// RRC: Rotate accumulator right.
// The carry bit is set equal to the low-order
// bit of the accumulator. The contents of the accumulator are
// rotated one bit position to the right, with the low-order bit
// being transferred to the high-order bit position of the
// accumulator.
pub fn rrca(self: *Z80) !void {
    self.flag.carry = self.register.a & 0x01 == 1;

    self.register.a = std.math.rotr(u8, self.register.a, 1);

    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    self.cycle_count += 4;
    self.flag.setUndocumentedFlags(self.register.a);
    self.q = self.flag.toByte();
}

fn rrc(self: *Z80, data: u8) u8 {
    self.flag.carry = data & 0x01 == 1;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    const result = std.math.rotr(u8, data, 1);
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.parity_overflow = Z80.parity(u8, result);
    self.flag.setUndocumentedFlags(result);
    self.q = self.flag.toByte();

    self.cycle_count += 8;

    return result;
}

pub fn rrc_B(self: *Z80) !void {
    self.register.b = rrc(self, self.register.b);
}

pub fn rrc_C(self: *Z80) !void {
    self.register.c = rrc(self, self.register.c);
}

pub fn rrc_D(self: *Z80) !void {
    self.register.d = rrc(self, self.register.d);
}

pub fn rrc_E(self: *Z80) !void {
    self.register.e = rrc(self, self.register.e);
}

pub fn rrc_H(self: *Z80) !void {
    self.register.h = rrc(self, self.register.h);
}

pub fn rrc_L(self: *Z80) !void {
    self.register.l = rrc(self, self.register.l);
}

pub fn rrc_M(self: *Z80) !void {
    const address = self.getHL();
    self.memory[address] = rrc(self, self.memory[address]);
}

pub fn rrc_A(self: *Z80) !void {
    self.register.a = rrc(self, self.register.a);
}

// RAL: Rotate accumulator left through carry.
// The contents of the accumulator are rotated one bit position to the left.
// The high-order bit of the accumulator replaces the Carry bit, while the
// Carry bit replaces the high-order bit of the accumulator.
pub fn rla(self: *Z80) !void {
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
    self.flag.setUndocumentedFlags(self.register.a);
    self.q = self.flag.toByte();
}

pub fn rl(self: *Z80, data: u8) u8 {
    const carry: u8 = if (self.flag.carry)
        1
    else
        0;

    // Isolate most significant bit to check for Carry
    self.flag.carry = (data & 0x80) == 0x80;
    // Rotate accumulator left through carry
    const result = (data << 1) | carry;

    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.cycle_count += 8;
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.parity_overflow = Z80.parity(u8, result);
    self.flag.setUndocumentedFlags(result);
    self.q = self.flag.toByte();
    return result;
}

pub fn rl_B(self: *Z80) !void {
    self.register.b = rl(self, self.register.b);
}

pub fn rl_C(self: *Z80) !void {
    self.register.c = rl(self, self.register.c);
}

pub fn rl_D(self: *Z80) !void {
    self.register.d = rl(self, self.register.d);
}

pub fn rl_E(self: *Z80) !void {
    self.register.e = rl(self, self.register.e);
}

pub fn rl_H(self: *Z80) !void {
    self.register.h = rl(self, self.register.h);
}

pub fn rl_L(self: *Z80) !void {
    self.register.l = rl(self, self.register.l);
}

pub fn rl_M(self: *Z80) !void {
    const address = self.getHL();
    self.memory[address] = rl(self, self.memory[address]);
}

pub fn rl_A(self: *Z80) !void {
    self.register.a = rl(self, self.register.a);
}

// RAR: Rotate accumulator right through carry.
// The contents of the accumulator are rotated one bit position to the right.
// The low order bit of the accumulator replaces the carry bit, while the carry bit replaces
// the high order bit of the accumulator.
pub fn rra(self: *Z80) !void {
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
    self.flag.setUndocumentedFlags(self.register.a);
    self.q = self.flag.toByte();
}

fn rr(self: *Z80, data: u8) u8 {
    const carry_rotate: u8 = if (self.flag.carry)
        1
    else
        0;

    // Isolate least significant bit to check for Carry
    self.flag.carry = data & 0x01 != 0;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    // Rotate accumulator right through carry
    const result = (data >> 1) | (carry_rotate << (8 - 1));
    self.cycle_count += 8;
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.parity_overflow = Z80.parity(u8, result);
    self.flag.setUndocumentedFlags(result);
    self.q = self.flag.toByte();

    return result;
}

pub fn rr_B(self: *Z80) !void {
    self.register.b = rr(self, self.register.b);
}

pub fn rr_C(self: *Z80) !void {
    self.register.c = rr(self, self.register.c);
}

pub fn rr_D(self: *Z80) !void {
    self.register.d = rr(self, self.register.d);
}

pub fn rr_E(self: *Z80) !void {
    self.register.e = rr(self, self.register.e);
}

pub fn rr_H(self: *Z80) !void {
    self.register.h = rr(self, self.register.h);
}

pub fn rr_L(self: *Z80) !void {
    self.register.l = rr(self, self.register.l);
}

pub fn rr_M(self: *Z80) !void {
    const address = self.getHL();
    self.memory[address] = rr(self, self.memory[address]);
}

pub fn rr_A(self: *Z80) !void {
    self.register.a = rr(self, self.register.a);
}
