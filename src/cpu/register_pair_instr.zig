const std = @import("std");
const Z80 = @import("Z80.zig");

const getHighByte = @import("opcode.zig").getHighByte;
const getLowByte = @import("opcode.zig").getLowByte;

// increment pair helper
pub fn inx(self: *Z80, reg1: u8, reg2: u8) struct { u8, u8 } {
    var combined = Z80.toUint16(reg1, reg2);
    combined += 1;

    self.q = 0;

    return .{ @as(u8, @intCast(combined >> 8)), @as(u8, @intCast(combined & 0xFF)) };
}

// INX B: Increment register pair B.
pub fn inx_B(self: *Z80) !void {
    self.register.b, self.register.c = inx(self, self.register.b, self.register.c);
    self.cycle_count += 6;
}

// INX D: Increment register pair D.
pub fn inx_D(self: *Z80) !void {
    self.register.d, self.register.e = inx(self, self.register.d, self.register.e);
    self.cycle_count += 6;
}

// INX H: Increment register pair H.
pub fn inx_H(self: *Z80) !void {
    self.register.h, self.register.l = inx(self, self.register.h, self.register.l);
    self.cycle_count += 6;
}

// INX SP: Increment stack pointer.
pub fn inx_SP(self: *Z80) !void {
    self.sp += 1;
    self.cycle_count += 6;
    self.q = 0;
}

fn dad(self: *Z80, reg1: u8, reg2: u8) void {
    const reg_pair = @as(u32, Z80.toUint16(reg1, reg2));
    const hl = @as(u32, self.getHL());

    // Set WZ to HL+1 before the addition
    self.wz = @as(u16, @truncate(hl +% 1));

    const result = hl + reg_pair;

    self.flag.carry = result > 0xFFFF;
    self.flag.half_carry = (hl & 0xFFF) + (reg_pair & 0xFFF) > 0xFFF;
    self.flag.add_subtract = false;

    // Set new HL value
    self.register.h = @as(u8, @truncate(result >> 8));
    self.register.l = @as(u8, @truncate(result));

    // X and Y flags come from bits 3 and 5 of high byte of result
    self.flag.x = (self.register.h & 0x08) != 0;
    self.flag.y = (self.register.h & 0x20) != 0;

    // Update Q with new flags
    self.q = self.flag.toByte();

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
    // Split SP into high and low bytes
    const sp_high: u8 = @truncate(self.sp >> 8);
    const sp_low: u8 = @truncate(self.sp);

    // Use the common dad helper
    dad(self, sp_high, sp_low);
}

pub fn push(self: *Z80, lower: u8, upper: u8) void {
    // Store value in stack, note: stack grows downwards
    self.memory[self.sp - 1] = upper;
    self.memory[self.sp - 2] = lower;
    self.sp -= 2;
    self.cycle_count += 11;
    self.q = 0;
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
    self.q = 0;

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

// The memory location pointed to by SP is stored into IXL and SP is incremented. The memory location pointed to by SP is stored into IXH and SP is incremented again.
pub fn pop_IX(self: *Z80) !void {
    const ixl, const ixh = pop(self);
    self.curr_index_reg.?.* = Z80.toUint16(ixh, ixl);
    self.cycle_count += 10;
    self.q = 0;
}
// Exchanges (SP) with IXL, and (SP+1) with IXH.
pub fn ex_SP_IX(self: *Z80) !void {
    const curr_index_reg = self.curr_index_reg.?.*;
    // Read from memory using wrapping addition for SP+1
    const sp_low = self.memory[self.sp];
    const sp_high = self.memory[self.sp +% 1];

    // Get current IX values
    const ix_high = getHighByte(curr_index_reg);
    const ix_low = getLowByte(curr_index_reg);

    // Exchange values
    self.memory[self.sp] = ix_low;
    self.memory[self.sp +% 1] = ix_high;
    self.curr_index_reg.?.* = Z80.toUint16(sp_high, sp_low);

    self.wz = self.curr_index_reg.?.*;

    self.cycle_count += 23;
    self.q = 0;
}

// SP is decremented and IXH is stored into the memory location pointed to by SP. SP is decremented again and IXL is stored into the memory location pointed to by SP.
pub fn push_IX(self: *Z80) !void {
    const ixh = getHighByte(self.curr_index_reg.?.*);
    const ixl = getLowByte(self.curr_index_reg.?.*);
    self.memory[self.sp - 1] = ixh;
    self.memory[self.sp - 2] = ixl;
    self.sp -= 2;
    self.cycle_count += 15;
    self.q = 0;
}

// Loads the value of IX into SP.
pub fn load_IX_SP(self: *Z80) !void {
    self.sp = self.curr_index_reg.?.*;
    self.cycle_count += 10;
    self.q = 0;
}

// Subtracts BC and the carry flag from HL.
pub fn sbc_HL_BC(self: *Z80) !void {
    const hl = self.getHL();
    const bc = Z80.toUint16(self.register.b, self.register.c);
    const carry: u16 = if (self.flag.carry) 1 else 0;
    const result = hl -% bc -% carry;

    // Set flags
    sbc_hl_flags(self, hl, bc, result);

    // Store result
    self.register.h = @truncate((result & 0xFF00) >> 8);
    self.register.l = @truncate(result & 0x00FF);

    // Set WZ
    self.wz = hl +% 1;

    self.cycle_count += 15;
}
fn sbc_hl_flags(self: *Z80, hl: u16, bc: u16, result: u16) void {
    // Sign flag: set if result is negative (bit 15 is 1)
    self.flag.sign = (result & 0x8000) != 0;

    // Zero flag: set if result is zero
    self.flag.zero = result == 0;

    // Half carry: set if borrow from bit 12
    self.flag.half_carry = ((@as(i32, hl) & 0xFFF) - (@as(i32, bc) & 0xFFF) - @as(i32, if (self.flag.carry) 1 else 0)) < 0;

    // Overflow: set if sign of result differs from sign of original when subtracting from same sign
    const sign_hl = (hl & 0x8000) != 0;
    const sign_bc = (bc & 0x8000) != 0;
    const sign_result = (result & 0x8000) != 0;
    self.flag.parity_overflow = (sign_hl != sign_bc) and (sign_hl != sign_result);

    // Carry: set if result is negative in unsigned arithmetic
    self.flag.carry = (@as(i32, hl) - @as(i32, bc) - @as(i32, if (self.flag.carry) 1 else 0)) < 0;

    // Add/subtract: always set for subtraction
    self.flag.add_subtract = true;

    // X flag: copy of bit 11 of result
    self.flag.x = (result & 0x0800) != 0;

    // Y flag: copy of bit 13 of result
    self.flag.y = (result & 0x2000) != 0;

    self.q = self.flag.toByte();
}

// Adds BC and the carry flag to HL.
pub fn adc_HL_BC(self: *Z80) !void {
    const hl = self.getHL();
    const bc = Z80.toUint16(self.register.b, self.register.c);
    const carry: u16 = if (self.flag.carry) 1 else 0;
    const result = hl +% bc +% carry;

    // Set flags
    adc_hl_flags(self, hl, bc, result);

    // Store result
    self.register.h = @truncate((result & 0xFF00) >> 8);
    self.register.l = @truncate(result & 0x00FF);

    // Set WZ
    self.wz = hl +% 1;

    self.cycle_count += 15;
}
fn adc_hl_flags(self: *Z80, hl: u16, bc: u16, result: u16) void {
    // Sign flag: set if result is negative (bit 15 is 1)
    self.flag.sign = (result & 0x8000) != 0;

    // Zero flag: set if result is zero
    self.flag.zero = result == 0;

    // Half carry: set if borrow from bit 12
    self.flag.half_carry = ((@as(i32, hl) & 0xFFF) + (@as(i32, bc) & 0xFFF) + @as(i32, if (self.flag.carry) 1 else 0)) > 0x0FFF;

    // Overflow: set if sign of result differs from sign of operands when adding numbers with same sign
    const sign_hl = (hl & 0x8000) != 0;
    const sign_bc = (bc & 0x8000) != 0;
    const sign_result = (result & 0x8000) != 0;
    self.flag.parity_overflow = (sign_hl == sign_bc) and (sign_hl != sign_result);

    // Carry: set if result is negative in unsigned arithmetic
    self.flag.carry = (@as(i32, hl) + @as(i32, bc) + @as(i32, if (self.flag.carry) 1 else 0)) > 0xFFFF;

    // Add/subtract: always set for subtraction
    self.flag.add_subtract = false;

    // X flag: copy of bit 11 of result
    self.flag.x = (result & 0x0800) != 0;

    // Y flag: copy of bit 13 of result
    self.flag.y = (result & 0x2000) != 0;

    self.q = self.flag.toByte();
}
