const std = @import("std");
const Z80 = @import("../Z80.zig");

const getHighByte = @import("util.zig").getHighByte;
const getLowByte = @import("util.zig").getLowByte;

// Helper functions for register pairs
fn getHL(self: *Z80) u16 {
    return (@as(u16, self.register.h) << 8) | self.register.l;
}

fn setHL(self: *Z80, value: u16) void {
    self.register.h = @truncate((value & 0xFF00) >> 8);
    self.register.l = @truncate(value & 0x00FF);
}

fn getDE(self: *Z80) u16 {
    return (@as(u16, self.register.d) << 8) | self.register.e;
}

fn setDE(self: *Z80, value: u16) void {
    self.register.d = @truncate((value & 0xFF00) >> 8);
    self.register.e = @truncate(value & 0x00FF);
}

fn getBC(self: *Z80) u16 {
    return (@as(u16, self.register.b) << 8) | self.register.c;
}

fn setBC(self: *Z80, value: u16) void {
    self.register.b = @truncate((value & 0xFF00) >> 8);
    self.register.c = @truncate(value & 0x00FF);
}

// Helper to update flags for CP operations
fn updateCPFlags(self: *Z80, value: u8, n: u8) void {
    const result = @as(u16, value) -% @as(u16, n);
    self.flag.sign = (result & 0x80) != 0;
    self.flag.zero = (result & 0xFF) == 0;

    // Fix half-carry calculation using wrapping subtraction
    const low_a = value & 0x0F;
    const low_n = n & 0x0F;
    self.flag.half_carry = low_a < low_n;

    const bc = Z80.toUint16(self.register.b, self.register.c);
    self.flag.parity_overflow = bc != 0;
    self.flag.add_subtract = true;

    // Undocumented flags
    self.flag.x = (result & 0x08) != 0;
    self.flag.y = (result & 0x20) != 0;
}

// LDI - Load and Increment
pub fn ldi(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    const de = Z80.toUint16(self.register.d, self.register.e);

    self.memory[de] = value;
    const new_hl = self.getHL() +% 1;
    self.register.h = getHighByte(new_hl);
    self.register.l = getLowByte(new_hl);
    const new_de = de +% 1;
    self.register.d = getHighByte(new_de);
    self.register.e = getLowByte(new_de);

    // Decrement BC as 16-bit value
    const bc = Z80.toUint16(self.register.b, self.register.c);
    const new_bc = bc -% 1;
    self.register.b = getHighByte(new_bc);
    self.register.c = getLowByte(new_bc);

    self.flag.half_carry = false;
    self.flag.parity_overflow = new_bc != 0; // Changed to use new_bc
    self.flag.add_subtract = false;

    // Undocumented flags
    const n = @as(u8, @truncate(self.register.a +% value));
    self.flag.x = (n & 0x08) != 0;
    self.flag.y = (n & 0x02) != 0;

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// CPI - Compare and Increment
pub fn cpi(self: *Z80) !void {
    const hl = self.getHL();
    const value = self.memory[hl];
    const old_a = self.register.a;

    // Calculate result before incrementing HL
    const result = @as(u16, old_a) -% value;

    // Update HL and BC
    const new_hl = hl +% 1;
    self.register.h = getHighByte(new_hl);
    self.register.l = getLowByte(new_hl);

    const bc = Z80.toUint16(self.register.b, self.register.c);
    const new_bc = bc -% 1;
    self.register.b = getHighByte(new_bc);
    self.register.c = getLowByte(new_bc);

    // Set flags
    self.flag.sign = (result & 0x80) != 0;
    self.flag.zero = (result & 0xFF) == 0;

    const low_a = old_a & 0x0F;
    const low_n = value & 0x0F;
    self.flag.half_carry = low_a < low_n;

    self.flag.parity_overflow = new_bc != 0;
    self.flag.add_subtract = true;

    // Undocumented flags - X and Y come from A - (*HL) - H
    const k = @as(u8, @truncate(result)) -% @as(u8, @intFromBool(self.flag.half_carry));
    self.flag.x = (k & 0x08) != 0;
    self.flag.y = (k & 0x02) != 0; // Changed from 0x20 to 0x02

    // WZ is incremented after each operation
    self.wz = self.wz +% 1;

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// INI - Input and Increment
pub fn ini(self: *Z80) !void {
    const value = try self.bus.in(self.register.c);
    const temp = @as(u16, value) +% @as(u16, self.register.c +% 1);

    self.memory[self.getHL()] = value;
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    self.register.b -%= 1;

    // Set flags
    self.flag.sign = (self.register.b & 0x80) != 0;
    self.flag.zero = self.register.b == 0;
    self.flag.half_carry = temp > 0xFF;
    self.flag.carry = temp > 0xFF;
    self.flag.parity_overflow = Z80.parity(u8, @intCast((temp & 7) ^ self.register.b));
    self.flag.add_subtract = (value & 0x80) != 0;

    // Undocumented flags from B
    self.flag.y = (self.register.b & 0x20) != 0; // B.5
    self.flag.x = (self.register.b & 0x08) != 0; // B.3

    setHL(self, self.getHL() +% 1);

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// OUTI - Output and Increment
// B is decremented. A byte from the memory location pointed to by HL is written to the port at the 16-bit address contained in the BC register pair. Then HL is incremented.
pub fn outi(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() +% 1);

    self.register.b -%= 1;
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    try self.bus.out(self.register.c, value);

    // Set flags
    self.flag.sign = (self.register.b & 0x80) != 0;
    self.flag.zero = self.register.b == 0;
    self.flag.half_carry = value > 0xFF - self.register.l;
    self.flag.carry = self.flag.half_carry;
    self.flag.parity_overflow = Z80.parity(u8, @intCast((self.register.l +% value & 7) ^ self.register.b));
    self.flag.add_subtract = (value & 0x80) != 0;

    // Undocumented flags from B
    self.flag.y = (self.register.b & 0x20) != 0;
    self.flag.x = (self.register.b & 0x08) != 0;

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// LDD - Load and Decrement
pub fn ldd(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    const de = getDE(self);

    self.memory[de] = value;
    setHL(self, self.getHL() -% 1);
    setDE(self, de -% 1);

    // Decrement BC as 16-bit value
    const bc = Z80.toUint16(self.register.b, self.register.c);
    const new_bc = bc -% 1;
    self.register.b = getHighByte(new_bc);
    self.register.c = getLowByte(new_bc);

    self.flag.half_carry = false;
    self.flag.parity_overflow = new_bc != 0;
    self.flag.add_subtract = false;

    // Undocumented flags
    const n = @as(u8, @truncate(self.register.a +% value));
    self.flag.x = (n & 0x08) != 0;
    self.flag.y = (n & 0x02) != 0;

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// CPD - Compare and Decrement
pub fn cpd(self: *Z80) !void {
    const hl = self.getHL();
    const value = self.memory[hl];
    const old_a = self.register.a;

    // Calculate result before decrementing HL
    const result = @as(u16, old_a) -% value;

    // Update HL and BC
    const new_hl = hl -% 1;
    self.register.h = getHighByte(new_hl);
    self.register.l = getLowByte(new_hl);

    const bc = Z80.toUint16(self.register.b, self.register.c);
    const new_bc = bc -% 1;
    self.register.b = getHighByte(new_bc);
    self.register.c = getLowByte(new_bc);

    // Set flags
    self.flag.sign = (result & 0x80) != 0;
    self.flag.zero = (result & 0xFF) == 0;

    const low_a = old_a & 0x0F;
    const low_n = value & 0x0F;
    self.flag.half_carry = low_a < low_n;

    self.flag.parity_overflow = new_bc != 0;
    self.flag.add_subtract = true;

    // Undocumented flags - X and Y come from A - (*HL) - H
    const k = @as(u8, @truncate(result)) -% @as(u8, @intFromBool(self.flag.half_carry));
    self.flag.x = (k & 0x08) != 0;
    self.flag.y = (k & 0x02) != 0;

    // WZ is decremented after each operation
    self.wz -= 1;

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// IND - Input and Decrement
// A byte from the port at the 16-bit address contained in the BC register pair is written to the memory location pointed to by HL. Then HL and B are decremented.
pub fn ind(self: *Z80) !void {
    const value = try self.bus.in(self.register.c);
    const temp = @as(u16, value) +% @as(u16, self.register.c -% 1);

    self.memory[self.getHL()] = value;
    self.wz = Z80.toUint16(self.register.b, self.register.c) -% 1;
    self.register.b -%= 1;

    // Set flags
    self.flag.sign = (self.register.b & 0x80) != 0;
    self.flag.zero = self.register.b == 0;
    self.flag.half_carry = temp > 0xFF;
    self.flag.carry = temp > 0xFF;
    self.flag.parity_overflow = Z80.parity(u8, @intCast((temp & 7) ^ self.register.b));
    self.flag.add_subtract = (value & 0x80) != 0;

    // Undocumented flags from B
    self.flag.y = (self.register.b & 0x20) != 0; // B.5
    self.flag.x = (self.register.b & 0x08) != 0; // B.3

    setHL(self, self.getHL() -% 1);

    self.cycle_count += 16;
    self.q = self.flag.toByte();
}

// OUTD - Output and Decrement
pub fn outd(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() -% 1);

    self.register.b -%= 1;
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    try self.bus.out(self.register.c, value);

    // Set flags
    self.flag.sign = (self.register.b & 0x80) != 0;
    self.flag.zero = self.register.b == 0;
    self.flag.half_carry = value > 0xFF - self.register.l;
    self.flag.carry = self.flag.half_carry;
    self.flag.parity_overflow = Z80.parity(u8, (self.register.l +% value & 7) ^ self.register.b);
    self.flag.add_subtract = (value & 0x80) != 0;

    // Undocumented flags from B
    self.flag.y = (self.register.b & 0x20) != 0;
    self.flag.x = (self.register.b & 0x08) != 0;

    self.cycle_count += 16;
    self.q = self.flag.toByte();
    self.wz -= 2;
}

pub fn ldir(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() +% 1);
    const de = getDE(self);

    self.memory[de] = value;
    setDE(self, de +% 1);

    // Decrement BC as 16-bit value
    const bc = getBC(self);
    const new_bc = bc -% 1;
    setBC(self, new_bc);

    // Add value to A for flag computation
    const t = value +% self.register.a;

    if (new_bc != 0) {
        // If BC is not zero, we continue the loop
        self.flag.half_carry = false;
        self.flag.parity_overflow = true;
        self.flag.add_subtract = false;
        self.pc -= 2; // Repeat instruction
        // YF and XF come from PC high byte
        self.flag.y = (self.pc & 0x2000) != 0;
        self.flag.x = (self.pc & 0x0800) != 0;

        self.wz = self.pc + 1; // MEMPTR = PC + 1
        self.cycle_count += 21;
    } else {
        // If BC is zero, we're done
        self.flag.half_carry = false;
        self.flag.parity_overflow = false;
        self.flag.add_subtract = false;
        // YF comes from bit 1 of (A + value)
        self.flag.y = (t & 0x02) << 4 != 0;
        // XF comes from bit 3 of (A + value)
        self.flag.x = (t & @intFromBool(self.flag.x)) != 0;
        // self.wz = self.pc +% 1;
        self.cycle_count += 16;
    }

    self.q = self.flag.toByte();
}

pub fn lddr(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() -% 1);
    const de = getDE(self);

    self.memory[de] = value;
    setDE(self, de -% 1);

    // Decrement BC as 16-bit value
    const bc = getBC(self);
    const new_bc = bc -% 1;
    setBC(self, new_bc);

    // Add value to A for flag computation
    const t = value +% self.register.a;

    if (new_bc != 0) {
        // If BC is not zero, we continue the loop
        self.flag.half_carry = false;
        self.flag.parity_overflow = true;
        self.flag.add_subtract = false;
        self.pc -= 2; // Repeat instruction
        // YF and XF come from PC high byte
        self.flag.y = (self.pc & 0x2000) != 0;
        self.flag.x = (self.pc & 0x0800) != 0;

        self.wz = self.pc + 1; // MEMPTR = PC + 1
        self.cycle_count += 21;
    } else {
        // If BC is zero, we're done
        self.flag.half_carry = false;
        self.flag.parity_overflow = false;
        self.flag.add_subtract = false;
        // YF comes from bit 1 of (A + value)
        self.flag.y = (t & 0x02) << 4 != 0;
        // XF comes from bit 3 of (A + value)
        self.flag.x = (t & @intFromBool(self.flag.x)) != 0;
        // self.wz = self.pc +% 1;
        self.cycle_count += 16;
    }

    self.q = self.flag.toByte();
}

pub fn cpir(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() +% 1);

    // Calculate initial subtraction
    const t0 = self.register.a -% value;

    // Calculate half-carry using XOR method
    const hf = (self.register.a ^ value ^ t0) & 0x10;

    // Calculate t1 for undocumented flags
    const t1 = t0 -% (hf >> 4);

    // Decrement BC
    const bc = getBC(self);
    const new_bc = bc -% 1;
    setBC(self, new_bc);

    // Set standard flags
    self.flag.sign = (t0 & 0x80) != 0;
    self.flag.zero = t0 == 0;
    self.flag.half_carry = hf != 0;
    self.flag.parity_overflow = new_bc != 0;
    self.flag.add_subtract = true;
    // carry flag remains unchanged

    if (t0 != 0 and new_bc != 0) {
        self.pc -= 2; // Repeat instruction
        // Continue searching
        // YF and XF come from PC high byte
        self.flag.y = ((self.pc >> 8) & 0x20) != 0;
        self.flag.x = ((self.pc >> 8) & 0x08) != 0;

        self.wz = self.pc + 1;
        self.cycle_count += 21;
    } else {
        // Search complete (either match found or BC=0)
        // YF and XF come from (A - [HLi] - HFo)
        self.flag.y = (t1 & 0x02) != 0;
        self.flag.x = (t1 & 0x08) != 0;

        self.wz +%= 1;
        self.cycle_count += 16;
    }

    self.q = self.flag.toByte();
}

pub fn cpdr(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() -% 1);

    // Calculate initial subtraction
    const t0 = self.register.a -% value;

    // Calculate half-carry using XOR method
    const hf = (self.register.a ^ value ^ t0) & 0x10;

    // Calculate t1 for undocumented flags
    const t1 = t0 -% (hf >> 4);

    // Decrement BC
    const bc = getBC(self);
    const new_bc = bc -% 1;
    setBC(self, new_bc);

    // Set standard flags
    self.flag.sign = (t0 & 0x80) != 0;
    self.flag.zero = t0 == 0;
    self.flag.half_carry = hf != 0;
    self.flag.parity_overflow = new_bc != 0;
    self.flag.add_subtract = true;
    // carry flag remains unchanged

    if (t0 != 0 and new_bc != 0) {
        self.pc -= 2; // Repeat instruction
        // Continue searching
        // YF and XF come from PC high byte
        self.flag.y = ((self.pc >> 8) & 0x20) != 0;
        self.flag.x = ((self.pc >> 8) & 0x08) != 0;

        self.wz = self.pc + 1;
        self.cycle_count += 21;
    } else {
        // Search complete (either match found or BC=0)
        // YF and XF come from (A - [HLi] - HFo)
        self.flag.y = (t1 & 0x02) != 0;
        self.flag.x = (t1 & 0x08) != 0;

        self.wz -%= 1;
        self.cycle_count += 16;
    }

    self.q = self.flag.toByte();
}

fn setInOutFlags(self: *Z80, b: u8, nf: u8, hcf: bool, p: u8, repeating: bool) void {
    if (repeating) {
        // B is not zero
        self.flag.sign = (b & 0x80) != 0;
        self.flag.zero = false;
        // YF and XF come from PC high byte
        self.flag.y = (self.pc & 0x2000) != 0;
        self.flag.x = (self.pc & 0x0800) != 0;
        self.flag.add_subtract = (nf != 0);

        if (hcf) {
            self.flag.carry = true;
            if (nf != 0) {
                self.flag.half_carry = (b & 0x0F) == 0;
                self.flag.parity_overflow = Z80.parity(u8, p ^ ((b -% 1) & 7));
            } else {
                self.flag.half_carry = (b & 0x0F) == 0x0F;
                self.flag.parity_overflow = Z80.parity(u8, p ^ ((b +% 1) & 7));
            }
        } else {
            self.flag.carry = false;
            self.flag.half_carry = false;
            self.flag.parity_overflow = Z80.parity(u8, p ^ (b & 7));
        }
    } else {
        // B is zero
        self.flag.sign = false;
        self.flag.zero = true;
        self.flag.y = false;
        self.flag.x = false;
        self.flag.half_carry = hcf;
        self.flag.carry = hcf;
        self.flag.parity_overflow = Z80.parity(u8, p);
        self.flag.add_subtract = (nf != 0);
    }
}

pub fn inir(self: *Z80) !void {
    // Read from port BC
    const io_value = try self.bus.in(self.register.c);

    // Calculate NF from bits 7-6 of input
    const nf = (io_value >> 6) & 0x02; // NF is bit 1

    // Write to (HL) and increment HL
    self.memory[self.getHL()] = io_value;
    setHL(self, self.getHL() +% 1);

    // Calculate MEMPTR = BC + 1
    self.wz = getBC(self) +% 1;

    // Calculate overflow for HC flag
    const t = @as(u16, io_value) +% self.wz;
    const hcf = @as(u8, @intCast(self.wz & 0xFF)) > 255 - io_value;

    // Decrement B
    self.register.b -%= 1;

    // Calculate parity
    const p: u8 = @intCast((t & 7) ^ self.register.b);

    if (self.register.b != 0) {
        self.pc -= 2; // Repeat instruction
        self.wz = self.pc + 1; // MEMPTR = PC + 1
        self.cycle_count += 21;
    } else {
        self.cycle_count += 16;
    }

    // Set flags based on whether we're repeating
    setInOutFlags(self, self.register.b, nf, hcf, p, self.register.b != 0);

    self.q = self.flag.toByte();
}

pub fn indr(self: *Z80) !void {
    // Read from port BC
    const io_value = try self.bus.in(self.register.c);

    // Calculate NF from bits 7-6 of input
    const nf = (io_value >> 6) & 0x02; // NF is bit 1

    // Write to (HL) and increment HL
    self.memory[self.getHL()] = io_value;
    setHL(self, self.getHL() -% 1);

    // Calculate MEMPTR = BC + 1
    self.wz = getBC(self) -% 1;

    // Calculate overflow for HC flag
    const t = @as(u16, io_value) +% self.wz;
    const hcf = @as(u8, @intCast(self.wz & 0xFF)) > 255 - io_value;

    // Decrement B
    self.register.b -%= 1;

    // Calculate parity
    const p: u8 = @intCast((t & 7) ^ self.register.b);

    if (self.register.b != 0) {
        self.pc -= 2; // Repeat instruction
        self.wz = self.pc + 1; // MEMPTR = PC + 1
        self.cycle_count += 21;
    } else {
        self.cycle_count += 16;
    }

    // Set flags based on whether we're repeating
    setInOutFlags(self, self.register.b, nf, hcf, p, self.register.b != 0);

    self.q = self.flag.toByte();
}

pub fn otir(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() +% 1);

    // Calculate NF from bits 7-6 of output value
    const nf = (value >> 6) & 0x02; // NF is bit 1

    // Calculate overflow for HC flag using L register
    const t = @as(u16, value) +% self.register.l;
    const hcf = t > 255;

    // Decrement B
    self.register.b -%= 1;

    // Calculate parity
    const p = @as(u8, @truncate(t & 7)) ^ self.register.b;

    // Output the value
    try self.bus.out(self.register.c, value);

    if (self.register.b != 0) {
        self.pc -= 2; // Repeat instruction
        self.wz = self.pc + 1; // MEMPTR = PC + 1
        self.cycle_count += 21;
    } else {
        self.wz = getBC(self) +% 1; // MEMPTR = BC + 1
        self.cycle_count += 16;
    }
    // Set flags based on whether we're repeating
    setInOutFlags(self, self.register.b, nf, hcf, p, self.register.b != 0);

    self.q = self.flag.toByte();
}

pub fn otdr(self: *Z80) !void {
    const value = self.memory[self.getHL()];
    setHL(self, self.getHL() -% 1);

    // Calculate NF from bits 7-6 of output value
    const nf = (value >> 6) & 0x02; // NF is bit 1

    // Calculate overflow for HC flag using L register
    const t = @as(u16, value) +% self.register.l;
    const hcf = t > 255;

    // Decrement B
    self.register.b -%= 1;

    // Calculate parity
    const p = @as(u8, @truncate(t & 7)) ^ self.register.b;

    // Output the value
    try self.bus.out(self.register.c, value);

    if (self.register.b != 0) {
        self.pc -= 2; // Repeat instruction
        self.wz = self.pc + 1; // MEMPTR = PC + 1
        self.cycle_count += 21;
    } else {
        self.wz = getBC(self) -% 1; // MEMPTR = BC - 1
        self.cycle_count += 16;
    }
    // Set flags based on whether we're repeating
    setInOutFlags(self, self.register.b, nf, hcf, p, self.register.b != 0);

    self.q = self.flag.toByte();
}
