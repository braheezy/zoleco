const std = @import("std");
const Z80 = @import("Z80.zig");

fn setShiftFlags(self: *Z80, val: u8, carry_out: bool) void {
    self.flag.carry = carry_out;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.setZ(@intCast(val));
    self.flag.setS(@intCast(val));
    self.flag.parity_overflow = Z80.parity(u8, val);
}

/// SLA (Shift Left Arithmetic): bit 7 -> CF, bit 0 = 0
fn shiftLeftArithmetic(self: *Z80, val: u8) u8 {
    const carry_out = (val & 0x80) != 0;
    const result = @as(u8, (val << 1) & 0xFE);
    setShiftFlags(self, result, carry_out);
    self.cycle_count += 8;
    return result;
}

/// SLL (Shift Left, set LSB = 1): bit 7 -> CF, bit 0 = 1
fn shiftLeft(self: *Z80, val: u8) u8 {
    const carry_out = (val & 0x80) != 0;
    const result = @as(u8, (val << 1) | 0x01);
    setShiftFlags(self, result, carry_out);
    self.cycle_count += 8;
    return result;
}

/// SRL (Shift Right Logical): bit 0 -> CF, bit 7 = 0
fn shiftRight(self: *Z80, val: u8) u8 {
    const carry_out = (val & 0x01) != 0;
    const result = @as(u8, val >> 1);
    setShiftFlags(self, result, carry_out);
    self.cycle_count += 8;
    return result;
}

/// SRA (Shift Right Arithmetic): bit 0 -> CF, bit 7 preserved
fn shiftRightArithmetic(self: *Z80, val: u8) u8 {
    const carry_out = (val & 0x01) != 0;
    // Preserve bit 7
    const result = @as(u8, (val & 0x80) | (val >> 1));
    setShiftFlags(self, result, carry_out);
    self.cycle_count += 8;
    return result;
}

pub fn sla_B(self: *Z80) !void {
    std.log.debug("[CB 20]\tSLA\tB", .{});
    self.register.b = shiftLeftArithmetic(self, self.register.b);
}

pub fn sla_C(self: *Z80) !void {
    std.log.debug("[CB 21]\tSLA\tC", .{});
    self.register.c = shiftLeftArithmetic(self, self.register.c);
}

pub fn sla_D(self: *Z80) !void {
    std.log.debug("[CB 22]\tSLA\tD", .{});
    self.register.d = shiftLeftArithmetic(self, self.register.d);
}

pub fn sla_E(self: *Z80) !void {
    std.log.debug("[CB 23]\tSLA\tE", .{});
    self.register.e = shiftLeftArithmetic(self, self.register.e);
}

pub fn sla_H(self: *Z80) !void {
    std.log.debug("[CB 24]\tSLA\tH", .{});
    self.register.h = shiftLeftArithmetic(self, self.register.h);
}

pub fn sla_L(self: *Z80) !void {
    std.log.debug("[CB 25]\tSLA\tL", .{});
    self.register.l = shiftLeftArithmetic(self, self.register.l);
}

pub fn sla_M(self: *Z80) !void {
    std.log.debug("[CB 26]\tSLA\tM", .{});
    const addr = Z80.getHL(self);
    const val = self.memory[addr];
    self.memory[addr] = shiftLeftArithmetic(self, val);
    self.cycle_count += 7;
}

pub fn sla_A(self: *Z80) !void {
    std.log.debug("[CB 27]\tSLA\tA", .{});
    self.register.a = shiftLeftArithmetic(self, self.register.a);
}

pub fn sra_B(self: *Z80) !void {
    std.log.debug("[CB 28]\tSRA\tA", .{});
    self.register.b = shiftRightArithmetic(self, self.register.b);
}

pub fn sra_C(self: *Z80) !void {
    std.log.debug("[CB 29]\tSRA\tC", .{});
    self.register.c = shiftRightArithmetic(self, self.register.c);
}

pub fn sra_D(self: *Z80) !void {
    std.log.debug("[CB 2A]\tSRA\tD", .{});
    self.register.d = shiftRightArithmetic(self, self.register.d);
}

pub fn sra_E(self: *Z80) !void {
    std.log.debug("[CB 2B]\tSRA\tE", .{});
    self.register.e = shiftRightArithmetic(self, self.register.e);
}

pub fn sra_H(self: *Z80) !void {
    std.log.debug("[CB 2C]\tSRA\tH", .{});
    self.register.h = shiftRightArithmetic(self, self.register.h);
}

pub fn sra_L(self: *Z80) !void {
    std.log.debug("[CB 2D]\tSRA\tL", .{});
    self.register.l = shiftRightArithmetic(self, self.register.l);
}

pub fn sra_M(self: *Z80) !void {
    std.log.debug("[CB 2E]\tSRA\tM", .{});
    const addr = Z80.getHL(self);
    const val = self.memory[addr];
    self.memory[addr] = shiftRightArithmetic(self, val);
    self.cycle_count += 7;
}

pub fn sra_A(self: *Z80) !void {
    std.log.debug("[CB 2F]\tSRA\tA", .{});
    self.register.a = shiftRightArithmetic(self, self.register.a);
}

pub fn sll_B(self: *Z80) !void {
    std.log.debug("[CB 30]\tSLL\tB", .{});
    self.register.b = shiftLeft(self, self.register.b);
}

pub fn sll_C(self: *Z80) !void {
    std.log.debug("[CB 31]\tSLL\tC", .{});
    self.register.c = shiftLeft(self, self.register.c);
}

pub fn sll_D(self: *Z80) !void {
    std.log.debug("[CB 32]\tSLL\tD", .{});
    self.register.d = shiftLeft(self, self.register.d);
}

pub fn sll_E(self: *Z80) !void {
    std.log.debug("[CB 33]\tSLL\tE", .{});
    self.register.e = shiftLeft(self, self.register.e);
}

pub fn sll_H(self: *Z80) !void {
    std.log.debug("[CB 34]\tSLL\tH", .{});
    self.register.h = shiftLeft(self, self.register.h);
}

pub fn sll_L(self: *Z80) !void {
    std.log.debug("[CB 35]\tSLL\tL", .{});
    self.register.l = shiftLeft(self, self.register.l);
}

pub fn sll_M(self: *Z80) !void {
    std.log.debug("[CB 36]\tSLL\tM", .{});
    const addr = Z80.getHL(self);
    const val = self.memory[addr];
    self.memory[addr] = shiftLeft(self, val);
    self.cycle_count += 7;
}

pub fn sll_A(self: *Z80) !void {
    std.log.debug("[CB 37]\tSLL\tA", .{});
    self.register.a = shiftLeft(self, self.register.a);
}

pub fn srl_B(self: *Z80) !void {
    std.log.debug("[CB 38]\tSRL\tB", .{});
    self.register.b = shiftRight(self, self.register.b);
}

pub fn srl_C(self: *Z80) !void {
    std.log.debug("[CB 39]\tSRL\tC", .{});
    self.register.c = shiftRight(self, self.register.c);
}

pub fn srl_D(self: *Z80) !void {
    std.log.debug("[CB 3A]\tSRL\tD", .{});
    self.register.d = shiftRight(self, self.register.d);
}

pub fn srl_E(self: *Z80) !void {
    std.log.debug("[CB 3B]\tSRL\tE", .{});
    self.register.e = shiftRight(self, self.register.e);
}

pub fn srl_H(self: *Z80) !void {
    std.log.debug("[CB 3C]\tSRL\tH", .{});
    self.register.h = shiftRight(self, self.register.h);
}

pub fn srl_L(self: *Z80) !void {
    std.log.debug("[CB 3D]\tSRL\tL", .{});
    self.register.l = shiftRight(self, self.register.l);
}

pub fn srl_M(self: *Z80) !void {
    std.log.debug("[CB 3E]\tSRL\tM", .{});
    const addr = Z80.getHL(self);
    const val = self.memory[addr];
    self.memory[addr] = shiftRight(self, val);
    self.cycle_count += 7;
}

pub fn srl_A(self: *Z80) !void {
    std.log.debug("[CB 3F]\tSRL\tA", .{});
    self.register.a = shiftRight(self, self.register.a);
}
