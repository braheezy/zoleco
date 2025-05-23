const std = @import("std");
const Z80 = @import("../Z80.zig");

fn setShiftFlags(self: *Z80, val: u8, carry_out: bool) void {
    self.flag.carry = carry_out;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.setZ(@intCast(val));
    self.flag.setS(@intCast(val));
    self.flag.parity_overflow = Z80.parity(u8, val);
    self.flag.setUndocumentedFlags(val);
    self.q = self.flag.toByte();
}

/// SLA (Shift Left Arithmetic): bit 7 -> CF, bit 0 = 0
fn shiftLeftArithmetic(self: *Z80, val: u8) u8 {
    var value = val;

    // Handle indexed addressing if we're in an indexed context
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        // Set WZ for indexed operations
        self.wz = addr;
        // Get value from memory
        value = self.io.readMemory(self.io.ctx, addr);
    }

    const carry_out = (value & 0x80) != 0;
    const result = @as(u8, (value << 1) & 0xFE);
    setShiftFlags(self, result, carry_out);

    // Write result back to memory if indexed
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        self.io.writeMemory(self.io.ctx, addr, result);
    }

    self.q = self.flag.toByte();
    return result;
}
/// SLL (Shift Left, set LSB = 1): bit 7 -> CF, bit 0 = 1
fn shiftLeft(self: *Z80, val: u8) u8 {
    var value = val;

    // Handle indexed addressing if we're in an indexed context
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        // Set WZ for indexed operations
        self.wz = addr;
        // Get value from memory
        value = self.io.readMemory(self.io.ctx, addr);
    }

    const carry_out = (value & 0x80) != 0;
    const result = @as(u8, (value << 1) | 0x01);
    setShiftFlags(self, result, carry_out);

    // Write result back to memory if indexed
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        self.io.writeMemory(self.io.ctx, addr, result);
    }

    self.q = self.flag.toByte();
    return result;
}

/// SRL (Shift Right Logical): bit 0 -> CF, bit 7 = 0
fn shiftRight(self: *Z80, val: u8) u8 {
    var value = val;

    // Handle indexed addressing if we're in an indexed context
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        // Set WZ for indexed operations
        self.wz = addr;
        // Get value from memory
        value = self.io.readMemory(self.io.ctx, addr);
    }

    const carry_out = (value & 0x01) != 0;
    const result = @as(u8, value >> 1);
    setShiftFlags(self, result, carry_out);

    // Write result back to memory if indexed
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        self.io.writeMemory(self.io.ctx, addr, result);
    }

    self.q = self.flag.toByte();
    return result;
}

/// SRA (Shift Right Arithmetic): bit 0 -> CF, bit 7 preserved
fn shiftRightArithmetic(self: *Z80, val: u8) u8 {
    var value = val;

    // Handle indexed addressing if we're in an indexed context
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        // Set WZ for indexed operations
        self.wz = addr;
        // Get value from memory
        value = self.io.readMemory(self.io.ctx, addr);
    }

    const carry_out = (value & 0x01) != 0;
    // Preserve bit 7
    const result = @as(u8, (value & 0x80) | (value >> 1));
    setShiftFlags(self, result, carry_out);

    // Write result back to memory if indexed
    if (self.curr_index_reg != null) {
        const addr = self.getDisplacedAddress(self.displacement);
        self.io.writeMemory(self.io.ctx, addr, result);
    }

    self.q = self.flag.toByte();
    return result;
}

pub fn sla_B(self: *Z80) !void {
    self.register.b = shiftLeftArithmetic(self, self.register.b);
}

pub fn sla_C(self: *Z80) !void {
    self.register.c = shiftLeftArithmetic(self, self.register.c);
}

pub fn sla_D(self: *Z80) !void {
    self.register.d = shiftLeftArithmetic(self, self.register.d);
}

pub fn sla_E(self: *Z80) !void {
    self.register.e = shiftLeftArithmetic(self, self.register.e);
}

pub fn sla_H(self: *Z80) !void {
    self.register.h = shiftLeftArithmetic(self, self.register.h);
}

pub fn sla_L(self: *Z80) !void {
    self.register.l = shiftLeftArithmetic(self, self.register.l);
}

pub fn sla_M(self: *Z80) !void {
    const addr = Z80.getHL(self);
    const val = self.io.readMemory(self.io.ctx, addr);
    self.io.writeMemory(self.io.ctx, addr, shiftLeftArithmetic(self, val));
}

pub fn sla_A(self: *Z80) !void {
    self.register.a = shiftLeftArithmetic(self, self.register.a);
}

pub fn sra_B(self: *Z80) !void {
    self.register.b = shiftRightArithmetic(self, self.register.b);
}

pub fn sra_C(self: *Z80) !void {
    self.register.c = shiftRightArithmetic(self, self.register.c);
}

pub fn sra_D(self: *Z80) !void {
    self.register.d = shiftRightArithmetic(self, self.register.d);
}

pub fn sra_E(self: *Z80) !void {
    self.register.e = shiftRightArithmetic(self, self.register.e);
}

pub fn sra_H(self: *Z80) !void {
    self.register.h = shiftRightArithmetic(self, self.register.h);
}

pub fn sra_L(self: *Z80) !void {
    self.register.l = shiftRightArithmetic(self, self.register.l);
}

pub fn sra_M(self: *Z80) !void {
    const addr = Z80.getHL(self);
    const val = self.io.readMemory(self.io.ctx, addr);
    self.io.writeMemory(self.io.ctx, addr, shiftRightArithmetic(self, val));
}

pub fn sra_A(self: *Z80) !void {
    self.register.a = shiftRightArithmetic(self, self.register.a);
}

pub fn sll_B(self: *Z80) !void {
    self.register.b = shiftLeft(self, self.register.b);
}

pub fn sll_C(self: *Z80) !void {
    self.register.c = shiftLeft(self, self.register.c);
}

pub fn sll_D(self: *Z80) !void {
    self.register.d = shiftLeft(self, self.register.d);
}

pub fn sll_E(self: *Z80) !void {
    self.register.e = shiftLeft(self, self.register.e);
}

pub fn sll_H(self: *Z80) !void {
    self.register.h = shiftLeft(self, self.register.h);
}

pub fn sll_L(self: *Z80) !void {
    self.register.l = shiftLeft(self, self.register.l);
}

pub fn sll_M(self: *Z80) !void {
    const address = if (self.curr_index_reg != null)
        self.getDisplacedAddress(self.displacement)
    else
        self.getHL();
    const val = self.io.readMemory(self.io.ctx, address);
    self.io.writeMemory(self.io.ctx, address, shiftLeft(self, val));
}

pub fn sll_A(self: *Z80) !void {
    self.register.a = shiftLeft(self, self.register.a);
}

pub fn srl_B(self: *Z80) !void {
    self.register.b = shiftRight(self, self.register.b);
}

pub fn srl_C(self: *Z80) !void {
    self.register.c = shiftRight(self, self.register.c);
}

pub fn srl_D(self: *Z80) !void {
    self.register.d = shiftRight(self, self.register.d);
}

pub fn srl_E(self: *Z80) !void {
    self.register.e = shiftRight(self, self.register.e);
}

pub fn srl_H(self: *Z80) !void {
    self.register.h = shiftRight(self, self.register.h);
}

pub fn srl_L(self: *Z80) !void {
    self.register.l = shiftRight(self, self.register.l);
}

pub fn srl_M(self: *Z80) !void {
    const addr = Z80.getHL(self);
    const val = self.io.readMemory(self.io.ctx, addr);
    self.io.writeMemory(self.io.ctx, addr, shiftRight(self, val));
}

pub fn srl_A(self: *Z80) !void {
    self.register.a = shiftRight(self, self.register.a);
}
