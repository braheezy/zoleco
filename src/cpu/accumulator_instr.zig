const std = @import("std");
const Z80 = @import("Z80.zig");

fn detectOverflow(a: u8, b: u8, result: u8) bool {
    // Overflow occurs if a and b have the same sign but the result has a different sign
    const sign_a = (a & 0x80) != 0;
    const sign_b = (b & 0x80) != 0;
    const sign_result = (result & 0x80) != 0;

    return (sign_a == sign_b) and (sign_a != sign_result);
}

// add helper
pub fn add(self: *Z80, data: u8) u8 {
    const result = self.register.a +% data;

    // Handle condition bits
    self.flag.setZ(@as(u16, result));
    self.flag.setS(@as(u16, result));
    self.flag.carry = Z80.carryAdd(self.register.a, data);
    self.flag.half_carry = Z80.auxCarryAdd(self.register.a, data);
    self.flag.parity_overflow = detectOverflow(self.register.a, data, result);
    self.flag.add_subtract = false;

    self.cycle_count += 4;

    return result;
}

// ADD B: ADD accumulator with register B.
pub fn add_B(self: *Z80) !void {
    self.register.a = add(self, self.register.b);
}

// ADD C: ADD accumulator with register C.
pub fn add_C(self: *Z80) !void {
    self.register.a = add(self, self.register.c);
}

// ADD D: ADD accumulator with register D.
pub fn add_D(self: *Z80) !void {
    self.register.a = add(self, self.register.d);
}

// ADD E: ADD accumulator with register E.
pub fn add_E(self: *Z80) !void {
    self.register.a = add(self, self.register.e);
}

// ADD H: ADD accumulator with register H.
pub fn add_H(self: *Z80) !void {
    self.register.a = add(self, self.register.h);
}

// ADD L: ADD accumulator with register L.
pub fn add_L(self: *Z80) !void {
    self.register.a = add(self, self.register.l);
}

// ADD M: ADD accumulator with memory address pointed to by register pair HL
pub fn add_M(self: *Z80) !void {
    self.register.a = add(self, self.memory[self.getHL()]);
}

// ADD A: ADD accumulator with register A.
pub fn add_A(self: *Z80) !void {
    self.register.a = add(self, self.register.a);
}

// ADD N: ADD accumulator with immediate value.
pub fn add_N(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.a = add(self, data[0]);
}

fn parity_add(a: u8, b: u8, carry: u8) bool {
    const result: u8 = a +% b +% carry;

    // Overflow occurs when the sign of the result differs from the sign of both inputs.
    const sign_a = (a & 0x80) != 0;
    const sign_b = (b & 0x80) != 0;
    const sign_result = (result & 0x80) != 0;

    return (sign_a == sign_b) and (sign_a != sign_result);
}

fn carryAdd(value: u8, addend: u8, carry: u8) bool {
    return @as(u16, value) + @as(u16, addend) + @as(u16, carry) > 0xFF;
}

// add with carry helper
pub fn adc(self: *Z80, data: u8) u8 {
    const carry: u8 = if (self.flag.carry) 1 else 0;
    const result = self.register.a +% data +% carry;

    // Handle condition bits
    self.flag.setZ(@as(u16, result));
    self.flag.setS(@as(u16, result));
    self.flag.carry = carryAdd(self.register.a, data, carry);
    self.flag.half_carry = ((self.register.a & 0xF) +% (data & 0xF) +% @as(u8, carry)) > 0xF;
    self.flag.parity_overflow = parity_add(self.register.a, data, carry);
    self.flag.add_subtract = false;

    self.cycle_count += 4;

    return @intCast(result);
}

// ADC B: Add accumulator with register B and carry.
pub fn adc_B(self: *Z80) !void {
    self.register.a = adc(self, self.register.b);
}

// ADC C: Add accumulator with register C and carry.
pub fn adc_C(self: *Z80) !void {
    self.register.a = adc(self, self.register.c);
}

// ADC D: Add accumulator with register D and carry.
pub fn adc_D(self: *Z80) !void {
    self.register.a = adc(self, self.register.d);
}

// ADC E: Add accumulator with register E and carry.
pub fn adc_E(self: *Z80) !void {
    self.register.a = adc(self, self.register.e);
}

// ADC H: Add accumulator with register H and carry.
pub fn adc_H(self: *Z80) !void {
    self.register.a = adc(self, self.register.h);
}

// ADC L: Add accumulator with register L and carry.
pub fn adc_L(self: *Z80) !void {
    self.register.a = adc(self, self.register.l);
}

// ADC M: Subtract memory address pointed to by register pair HL from accumulator.
pub fn adc_M(self: *Z80) !void {
    self.register.a = adc(self, self.memory[self.getHL()]);
}

// ADC A: Add accumulator with register A and carry.
pub fn adc_A(self: *Z80) !void {
    self.register.a = adc(self, self.register.a);
}

// ADC A: Add accumulator with immediate value and carry.
pub fn adc_N(self: *Z80) !void {
    const data = try self.fetchData(1);
    const n = data[0];

    const carry_in: u8 = if (self.flag.carry) 1 else 0;
    const sum: u16 = @as(u16, self.register.a) + @as(u16, n) + @as(u16, carry_in);
    const result: u8 = @intCast(sum & 0xFF);

    self.flag.carry = (sum > 0xFF);
    self.flag.half_carry = ((self.register.a & 0xF) + (n & 0xF) + carry_in) > 0xF;
    self.flag.parity_overflow = (((self.register.a ^ result) & (n ^ result)) & 0x80) != 0;
    self.flag.setS(@intCast(result));
    self.flag.setZ(@intCast(result));
    self.flag.add_subtract = false;

    self.register.a = result;
    self.cycle_count += 7;
}

fn detectOverflowSub(a: u8, b: u8, result: u8) bool {
    // Overflow occurs if a and b have opposite signs and result sign differs from a
    const sign_a = (a & 0x80) != 0;
    const sign_b = (b & 0x80) != 0;
    const sign_result = (result & 0x80) != 0;

    return (sign_a != sign_b) and (sign_a != sign_result);
}

// subtract helper
pub fn sub(self: *Z80, data: u8) u8 {
    const result = @as(u16, self.register.a) -% @as(u16, data);

    // Handle condition bits
    self.flag.setZ(@as(u16, result));
    self.flag.setS(@as(u16, result));
    self.flag.carry = Z80.carrySub(self.register.a, data);
    self.flag.half_carry = Z80.auxCarrySub(self.register.a, data);
    self.flag.parity_overflow = detectOverflowSub(self.register.a, data, @truncate(result));
    self.flag.add_subtract = true;

    self.cycle_count += 4;

    return @truncate(result);
}

// SUB B: Subtract register B from accumulator.
pub fn sub_B(self: *Z80) !void {
    self.register.a = sub(self, self.register.b);
}

// SUB C: Subtract register C from accumulator.
pub fn sub_C(self: *Z80) !void {
    self.register.a = sub(self, self.register.c);
}

// SUB D: Subtract register D from accumulator.
pub fn sub_D(self: *Z80) !void {
    self.register.a = sub(self, self.register.d);
}

// SUB E: Subtract register E from accumulator.
pub fn sub_E(self: *Z80) !void {
    self.register.a = sub(self, self.register.e);
}

// SUB H: Subtract register H from accumulator.
pub fn sub_H(self: *Z80) !void {
    self.register.a = sub(self, self.register.h);
}

// SUB L: Subtract register L from accumulator.
pub fn sub_L(self: *Z80) !void {
    self.register.a = sub(self, self.register.l);
}

// SUB M: Subtract memory address pointed to by register pair HL from accumulator.
pub fn sub_M(self: *Z80) !void {
    self.register.a = sub(self, self.memory[self.getHL()]);
}

// SUB A: Subtract accumulator from accumulator.
pub fn sub_A(self: *Z80) !void {
    self.register.a = sub(self, self.register.a);
}

// SUB N: Subtract immediate value from accumulator.
pub fn sub_N(self: *Z80) !void {
    const data = try self.fetchData(1);
    const n = data[0];

    self.register.a = sub(self, n);
}

fn sbc_overflow(a: u8, s: u8, cy: bool) bool {
    const carry: u8 = if (cy) 1 else 0;
    const diff = (@as(i16, a) - @as(i16, s) - @as(i16, carry)) & 0xFF;
    const res: u8 = @intCast(diff);
    return ((a ^ s) & (a ^ res) & 0x80) != 0;
}

// subtract with borrow helper
/// SBB A, data
/// A <- A - data - CY
/// SBB A, data => A ← A - data - CY
pub fn sbb(self: *Z80, data: u8) u8 {
    const carry_in: u8 = if (self.flag.carry) 1 else 0;

    // Store original A, data, and carry_in for overflow computation
    const origA = self.register.a;
    const origData = data;
    const origCY = self.flag.carry;

    const sum_16 = @as(u16, @intCast(data)) + @as(u16, @intCast(carry_in));
    const full_sub = @as(i16, self.register.a) - @as(i16, @intCast(sum_16));
    self.flag.carry = (full_sub < 0);
    const result = @as(u8, @intCast(full_sub & 0xFF));

    const a_low: i16 = (origA & 0x0F);
    const b_low: i16 = (origData & 0x0F) + carry_in;
    self.flag.half_carry = (a_low - b_low) < 0;

    self.flag.parity_overflow = sbc_overflow(origA, origData, origCY);
    self.flag.setS(@as(u16, result));
    self.flag.setZ(@as(u16, result));
    self.flag.add_subtract = true;

    self.cycle_count += 4;
    self.register.a = result;
    return result;
}

// SBB B: Subtract register B from accumulator with borrow.
pub fn sbb_B(self: *Z80) !void {
    self.register.a = sbb(self, self.register.b);
}

// SBB C: Subtract register C from accumulator with borrow.
pub fn sbb_C(self: *Z80) !void {
    self.register.a = sbb(self, self.register.c);
}

// SBB D: Subtract register D from accumulator with borrow.
pub fn sbb_D(self: *Z80) !void {
    self.register.a = sbb(self, self.register.d);
}

// SBB E: Subtract register E from accumulator with borrow.
pub fn sbb_E(self: *Z80) !void {
    self.register.a = sbb(self, self.register.e);
}

// SBB H: Subtract register H from accumulator with borrow.
pub fn sbb_H(self: *Z80) !void {
    self.register.a = sbb(self, self.register.h);
}

// SBB L: Subtract register L from accumulator with borrow.
pub fn sbb_L(self: *Z80) !void {
    self.register.a = sbb(self, self.register.l);
}

// SBB M: Subtract memory address pointed to by register pair HL from accumulator with borrow.
pub fn sbb_M(self: *Z80) !void {
    self.register.a = sbb(self, self.memory[self.getHL()]);
}

// SBB A: Subtract register A from accumulator with borrow.
pub fn sbb_A(self: *Z80) !void {
    self.register.a = sbb(self, self.register.a);
}

// SBB N: Subtract immediate value from accumulator with borrow.
pub fn sbb_N(self: *Z80) !void {
    const data = try self.fetchData(1);
    const n = data[0];

    self.register.a = sbb(self, n);
    self.cycle_count += 3;
}
// ana performs AND with data and accumulator, storing in accumulator.
pub fn ana(self: *Z80, data: u8) void {
    const result = @as(u16, self.register.a) & @as(u16, data);

    // Handle condition bits
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.carry = false;
    self.flag.add_subtract = false;
    self.flag.half_carry = true;
    self.flag.parity_overflow = Z80.parity(u16, result);

    self.register.a = @intCast(result);
}

// ANA B: AND register B with accumulator.
pub fn ana_B(self: *Z80) !void {
    ana(self, self.register.b);
}

// ANA C: AND register C with accumulator.
pub fn ana_C(self: *Z80) !void {
    ana(self, self.register.c);
}

// ANA D: AND register D with accumulator.
pub fn ana_D(self: *Z80) !void {
    ana(self, self.register.d);
}

// ANA E: AND register E with accumulator.
pub fn ana_E(self: *Z80) !void {
    ana(self, self.register.e);
}

// ANA H: AND register H with accumulator.
pub fn ana_H(self: *Z80) !void {
    ana(self, self.register.h);
}

// ANA L: AND register L with accumulator.
pub fn ana_L(self: *Z80) !void {
    ana(self, self.register.l);
}

// ANA M: AND memory address pointed to by register pair HL with accumulator.
pub fn ana_M(self: *Z80) !void {
    ana(self, self.memory[self.getHL()]);
}

// ANA A: AND accumulator with accumulator.
pub fn ana_A(self: *Z80) !void {
    ana(self, self.register.a);
}

// xra performs Exclusive OR register with accumulator
pub fn xra(self: *Z80, data: u8) void {
    const result = @as(u16, self.register.a) ^ @as(u16, data);

    // Handle condition bits
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.carry = false;
    self.flag.parity_overflow = Z80.parity(u16, result);
    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    self.register.a = @intCast(result);
}

// XRA B: Exclusive-OR register B with accumulator.
pub fn xra_B(self: *Z80) !void {
    xra(self, self.register.b);
}

// XRA C: Exclusive-OR register C with accumulator.
pub fn xra_C(self: *Z80) !void {
    xra(self, self.register.c);
}

// XRA D: Exclusive-OR register D with accumulator.
pub fn xra_D(self: *Z80) !void {
    xra(self, self.register.d);
}

// XRA E: Exclusive-OR register E with accumulator.
pub fn xra_E(self: *Z80) !void {
    xra(self, self.register.e);
}

// XRA H: Exclusive-OR register H with accumulator.
pub fn xra_H(self: *Z80) !void {
    xra(self, self.register.h);
}

// XRA L: Exclusive-OR register L with accumulator.
pub fn xra_L(self: *Z80) !void {
    xra(self, self.register.l);
}

// XRA M: Exclusive-OR memory address pointed to by register pair HL with accumulator.
pub fn xra_M(self: *Z80) !void {
    xra(self, self.memory[self.getHL()]);
}

// XRA A: Exclusive-OR accumulator with accumulator.
pub fn xra_A(self: *Z80) !void {
    xra(self, self.register.a);
}

// ora performs OR with accumulator
pub fn ora(self: *Z80, reg: u8) void {
    const result = @as(u16, self.register.a) | @as(u16, reg);

    // Handle condition bits
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.carry = false;
    self.flag.parity_overflow = Z80.parity(u16, result);
    self.flag.add_subtract = false;
    self.flag.half_carry = false;

    self.register.a = @intCast(result);
}

// ORA B: OR A with register B
pub fn ora_B(self: *Z80) !void {
    ora(self, self.register.b);
}

// ORA C: OR A with register C
pub fn ora_C(self: *Z80) !void {
    ora(self, self.register.c);
}

// ORA D: OR A with register D
pub fn ora_D(self: *Z80) !void {
    ora(self, self.register.d);
}

// ORA E: OR A with register E
pub fn ora_E(self: *Z80) !void {
    ora(self, self.register.e);
}

// ORA H: OR A with register H
pub fn ora_H(self: *Z80) !void {
    ora(self, self.register.h);
}

// ORA L: OR A with register L
pub fn ora_L(self: *Z80) !void {
    ora(self, self.register.l);
}

// ORA M: OR A with memory location pointed to by register pair HL
pub fn ora_M(self: *Z80) !void {
    const address = self.getHL();
    ora(self, self.memory[address]);
}

// ORA A: OR A with register A
pub fn ora_A(self: *Z80) !void {
    ora(self, self.register.a);
}

// compare helper
pub fn compare(self: *Z80, data: u8) void {
    const result = @as(u16, self.register.a) -% @as(u16, data);

    // Handle condition bits
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.carry = Z80.carrySub(self.register.a, data);
    self.flag.half_carry = Z80.auxCarrySub(self.register.a, data);
    self.flag.add_subtract = true;

    const diff = (@as(i16, self.register.a) - @as(i16, data)) & 0xFF;
    const res: u8 = @intCast(diff);
    self.flag.parity_overflow = ((self.register.a ^ data) & (self.register.a ^ res) & 0x80) != 0;
}

// CMP B: Compare A with register B
pub fn cmp_B(self: *Z80) !void {
    compare(self, self.register.b);
}

// CMP C: Compare A with register C
pub fn cmp_C(self: *Z80) !void {
    compare(self, self.register.c);
}

// CMP D: Compare A with register D
pub fn cmp_D(self: *Z80) !void {
    compare(self, self.register.d);
}

// CMP E: Compare A with register E
pub fn cmp_E(self: *Z80) !void {
    compare(self, self.register.e);
}

// CMP H: Compare A with register H
pub fn cmp_H(self: *Z80) !void {
    compare(self, self.register.h);
}

// CMP L: Compare A with register L
pub fn cmp_L(self: *Z80) !void {
    compare(self, self.register.l);
}

// CMP M: Compare A with memory address pointed to by register pair HL
pub fn cmp_M(self: *Z80) !void {
    compare(self, self.memory[self.getHL()]);
}

// CMP A: Compare A with register A
pub fn cmp_A(self: *Z80) !void {
    compare(self, self.register.a);
}
