const std = @import("std");
const Z80 = @import("Z80.zig");

// increment helper
pub fn inc(self: *Z80, data: u8) u8 {
    const result = data +% 1;

    // Handle condition bits
    self.flag.setZ(@as(u16, result));
    self.flag.setS(@as(u16, result));
    self.flag.half_carry = Z80.auxCarryAdd(data, 1);
    self.flag.parity_overflow = Z80.parity_add(data);
    self.flag.add_subtract = false;
    self.flag.setUndocumentedFlags(result);
    self.q = self.flag.toByte();

    return result;
}

// INR A: Increment register A.
pub fn inr_A(self: *Z80) !void {
    self.register.a = inc(self, self.register.a);
    self.cycle_count += 4;
}

// INR B: Increment register B.
pub fn inr_B(self: *Z80) !void {
    self.register.b = inc(self, self.register.b);
    self.cycle_count += 4;
}

// INR C: Increment register C.
pub fn inr_C(self: *Z80) !void {
    self.register.c = inc(self, self.register.c);
    self.cycle_count += 4;
}

// INR D: Increment register D.
pub fn inr_D(self: *Z80) !void {
    self.register.d = inc(self, self.register.d);
    self.cycle_count += 4;
}

// INR E: Increment register E.
pub fn inr_E(self: *Z80) !void {
    self.register.e = inc(self, self.register.e);
    self.cycle_count += 4;
}

// INR H: Increment register H.
pub fn inr_H(self: *Z80) !void {
    self.register.h = inc(self, self.register.h);
    self.cycle_count += 4;
}

// INR L: Increment register L.
pub fn inr_L(self: *Z80) !void {
    self.register.l = inc(self, self.register.l);
    self.cycle_count += 4;
}

// INR M: Increment memory address pointed to by register pair HL.
pub fn inr_M(self: *Z80) !void {
    self.memory[self.getHL()] = inc(self, self.memory[self.getHL()]);
    self.cycle_count += 11;
}

// decrement helper
pub fn dcr(self: *Z80, data: u8) u8 {
    const result = data -% 1;

    // Handle condition bits
    self.flag.setZ(result);
    self.flag.setS(result);
    self.flag.half_carry = Z80.auxCarrySub(data, 1);
    self.flag.parity_overflow = Z80.parity_sub(data);
    self.flag.add_subtract = true;
    self.flag.setUndocumentedFlags(result);
    self.q = self.flag.toByte();

    return result;
}

// DCR A: Decrement register A.
pub fn dcr_A(self: *Z80) !void {
    self.register.a = dcr(self, self.register.a);
    self.cycle_count += 4;
}

// DCR B: Decrement register B.
pub fn dcr_B(self: *Z80) !void {
    self.register.b = dcr(self, self.register.b);
    self.cycle_count += 4;
}

// DCR C: Decrement register C.
pub fn dcr_C(self: *Z80) !void {
    self.register.c = dcr(self, self.register.c);
    self.cycle_count += 4;
}

// DCR D: Decrement register D.
pub fn dcr_D(self: *Z80) !void {
    self.register.d = dcr(self, self.register.d);
    self.cycle_count += 4;
}

// DCR E: Decrement register E.
pub fn dcr_E(self: *Z80) !void {
    self.register.e = dcr(self, self.register.e);
    self.cycle_count += 4;
}

// DCR H: Decrement register H.
pub fn dcr_H(self: *Z80) !void {
    self.register.h = dcr(self, self.register.h);
    self.cycle_count += 4;
}

// DCR L: Decrement register L.
pub fn dcr_L(self: *Z80) !void {
    self.register.l = dcr(self, self.register.l);
    self.cycle_count += 4;
}

// DCR M: Decrement memory location pointed to by register pair HL.
pub fn dcr_M(self: *Z80) !void {
    const memory_address = self.getHL();
    self.memory[memory_address] = dcr(self, self.memory[memory_address]);
    self.cycle_count += 11;
}

// decrement pair helper
fn decPair(self: *Z80, reg1: u8, reg2: u8) struct { u8, u8 } {
    var combined = Z80.toUint16(reg1, reg2);
    combined -= 1;
    self.q = 0;

    return .{ @as(u8, @intCast(combined >> 8)), @as(u8, @intCast(combined & 0xFF)) };
}

// DCX B: Decrement register pair B.
pub fn dcx_B(self: *Z80) !void {
    self.register.b, self.register.c = decPair(self, self.register.b, self.register.c);
    self.cycle_count += 6;
}

// DCX D: Decrement register pair D.
pub fn dcx_D(self: *Z80) !void {
    self.register.d, self.register.e = decPair(self, self.register.d, self.register.e);
    self.cycle_count += 6;
}

// DCX H: Decrement register pair H.
pub fn dcx_H(self: *Z80) !void {
    self.register.h, self.register.l = decPair(self, self.register.h, self.register.l);
    self.cycle_count += 6;
}

// DCX SP: Decrement stack pointer
pub fn dcx_SP(self: *Z80) !void {
    self.sp -= 1;
    // WZ is not affected by DCX SP
    self.cycle_count += 6;
    self.q = 0;
}

// DAA: Decimal Adjust Accumulator
// The eight bit hex number in the accumulator is adjusted to form two
// four bit binary decimal digits.
pub fn daa(self: *Z80) !void {
    var adjust: u8 = 0;
    if (self.flag.half_carry or self.register.a & 0x0f > 0x09) {
        adjust += 0x06;
    }
    if (self.flag.carry or self.register.a > 0x99) {
        self.flag.carry = true;
        adjust += 0x60;
    }

    if (self.flag.add_subtract) {
        if (self.register.a & 0x0f > 0x05) self.flag.half_carry = false;
        self.register.a -%= adjust;
    } else {
        if (self.register.a & 0x0f > 0x09) {
            self.flag.half_carry = true;
        } else {
            self.flag.half_carry = false;
        }
        self.register.a +%= adjust;
    }

    self.flag.setZ(@as(u16, self.register.a));
    self.flag.setS(@as(u16, self.register.a));
    self.flag.parity_overflow = Z80.parity(u8, self.register.a);
    self.flag.setUndocumentedFlags(self.register.a);
    self.q = self.flag.toByte();
    self.cycle_count += 4;
}

// CMA: Complement accumulator.
pub fn cma(self: *Z80) !void {
    self.register.a = ~self.register.a;
    self.flag.add_subtract = true;
    self.flag.half_carry = true;
    self.flag.setUndocumentedFlags(self.register.a);
    self.q = self.flag.toByte();
    self.cycle_count += 4;
}

// CCF: Invert carry.
pub fn ccf(self: *Z80) !void {
    self.flag.half_carry = self.flag.carry;
    self.flag.add_subtract = false;

    const prev_flags = self.flag.toByte();
    self.flag.carry = !self.flag.carry;

    // Q register is used to calculate X/Y flags
    const q_xor_f = self.q ^ prev_flags;
    const result = q_xor_f | self.register.a;
    self.flag.y = (result & 0x20) != 0;
    self.flag.x = (result & 0x08) != 0;

    // Update Q to new flags state
    self.q = self.flag.toByte();
    self.cycle_count += 4;
}

// SCF: Set carry.
pub fn scf(self: *Z80) !void {
    self.flag.half_carry = false;
    self.flag.add_subtract = false;

    const prev_flags = self.flag.toByte();
    self.flag.carry = true;

    // Q register is used to calculate X/Y flags
    const q_xor_f = self.q ^ prev_flags;
    const result = q_xor_f | self.register.a;
    self.flag.y = (result & 0x20) != 0;
    self.flag.x = (result & 0x08) != 0;

    // Update Q to new flags state
    self.q = self.flag.toByte();
    self.cycle_count += 4;
}
