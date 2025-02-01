const std = @import("std");
const Z80 = @import("Z80.zig");

const getHighByte = @import("opcode.zig").getHighByte;
const getLowByte = @import("opcode.zig").getLowByte;

const OpcodeTable = @import("opcode.zig").OpcodeTable;

// The 2-byte contents of register pairs DE and HL are exchanged.
pub fn ex_M_HL(self: *Z80) !void {

    // Read the values from memory at SP and SP+1
    const sp = self.sp;
    const mem_l = self.memory[sp];
    const mem_h = self.memory[sp + 1];

    // Store current HL in temporary variables
    const temp_l = self.register.l;
    const temp_h = self.register.h;

    // Exchange: update HL with values from memory
    self.register.l = mem_l;
    self.register.h = mem_h;

    // Write original HL back to memory at SP and SP+1
    self.memory[sp] = temp_l;
    self.memory[sp + 1] = temp_h;

    self.q = 0;
    self.wz = Z80.toUint16(self.register.h, self.register.l);

    self.total_cycle_count += 19;
}

// The 2-byte contents of the register pairs AF and AF' are exchanged.
pub fn ex_AF(self: *Z80) !void {

    // Swap A registers
    const temp_a = self.register.a;
    self.register.a = self.shadow_register.a;
    self.shadow_register.a = temp_a;

    // Swap Flag registers
    const temp_f = self.flag;
    self.flag = self.shadow_flag;
    self.shadow_flag = temp_f;

    self.cycle_count += 4;
    self.q = 0;
}

// The 2-byte contents of register pairs DE and HL are exchanged.
pub fn ex_DE_HL(self: *Z80) !void {
    const temp_d = self.register.d;
    self.register.d = self.register.h;
    self.register.h = temp_d;

    const temp_e = self.register.e;
    self.register.e = self.register.l;
    self.register.l = temp_e;
    self.q = 0;

    self.cycle_count += 4;
}

// Swap all register pairs with their shadow counterparts
pub fn exx(self: *Z80) !void {
    const tempB = self.register.b;
    self.register.b = self.shadow_register.b;
    self.shadow_register.b = tempB;

    const tempC = self.register.c;
    self.register.c = self.shadow_register.c;
    self.shadow_register.c = tempC;

    // Swap DE
    const tempD = self.register.d;
    self.register.d = self.shadow_register.d;
    self.shadow_register.d = tempD;

    const tempE = self.register.e;
    self.register.e = self.shadow_register.e;
    self.shadow_register.e = tempE;

    // Swap HL
    const tempH = self.register.h;
    self.register.h = self.shadow_register.h;
    self.shadow_register.h = tempH;

    const tempL = self.register.l;
    self.register.l = self.shadow_register.l;
    self.shadow_register.l = tempL;

    // Add the T-cycle cost
    self.cycle_count += 4;

    self.q = 0;
}

// Stores the value of A into register R.
pub fn load_A_R(self: *Z80) !void {
    self.r = self.register.a;
    self.cycle_count += 9;
    self.q = 0;
}

// Loads the value of register R into A.
pub fn load_R_A(self: *Z80) !void {
    self.register.a = self.r;

    self.flag.add_subtract = false;
    self.flag.half_carry = false;
    self.flag.zero = self.register.a == 0;
    self.flag.sign = self.register.a & 0x80 != 0;
    self.flag.setUndocumentedFlags(self.register.a);

    self.flag.parity_overflow = self.iff2;

    self.q = self.flag.toByte();

    self.cycle_count += 9;
}

pub fn load_A_I(self: *Z80) !void {
    self.register.a = self.i;

    self.flag.add_subtract = false;
    self.flag.half_carry = false;
    self.flag.zero = self.register.a == 0;
    self.flag.sign = self.register.a & 0x80 != 0;
    self.flag.setUndocumentedFlags(self.register.a);

    // For LD A,I the P/V flag shows the state of IFF2
    self.flag.parity_overflow = self.iff2;

    self.q = self.flag.toByte();
}

// RRD - Rotate Right Decimal
// The contents of the low-order nibble of (HL) are copied to the low-order nibble of A.
// The previous contents of the low-order nibble of A go to the high-order nibble of (HL),
// and the previous contents of the high-order nibble of (HL) go to the low-order nibble of (HL).
pub fn rrd(self: *Z80) !void {
    const hl_addr = self.getHL();
    const hl_value = self.memory[hl_addr];
    const old_a = self.register.a;

    // Extract nibbles
    const hl_high = (hl_value & 0xF0) >> 4;
    const hl_low = hl_value & 0x0F;
    const a_low = old_a & 0x0F;

    // Perform rotation
    self.register.a = (old_a & 0xF0) | hl_low; // A keeps high nibble, gets low nibble from (HL)
    self.memory[hl_addr] = (a_low << 4) | hl_high; // (HL) gets low nibble of A in high position, high nibble moves to low position

    // Set flags
    self.flag.sign = (self.register.a & 0x80) != 0;
    self.flag.zero = self.register.a == 0;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.parity_overflow = Z80.parity(u8, self.register.a);

    // Set undocumented flags
    self.flag.x = (self.register.a & 0x08) != 0;
    self.flag.y = (self.register.a & 0x20) != 0;

    // Set WZ
    self.wz = hl_addr +% 1;

    self.q = self.flag.toByte();
    self.cycle_count += 18;
}
// RLD - Rotate Left Decimal
// The contents of the low-order nibble of (HL) are copied to the high-order nibble of (HL),
// the previous contents of the high-order nibble of (HL) are copied to the low-order nibble of A,
// and the previous contents of the low-order nibble of A are copied to the low-order nibble of (HL).
pub fn rld(self: *Z80) !void {
    const hl_addr = self.getHL();
    const hl_value = self.memory[hl_addr];
    const old_a = self.register.a;

    // Extract nibbles
    const hl_high = (hl_value & 0xF0) >> 4;
    const hl_low = hl_value & 0x0F;
    const a_low = old_a & 0x0F;

    // Perform rotation
    self.register.a = (old_a & 0xF0) | hl_high; // A keeps high nibble, gets high nibble from (HL)
    self.memory[hl_addr] = (hl_low << 4) | a_low; // (HL) gets low nibble in high position, low nibble of A in low position

    // Set flags
    self.flag.sign = (self.register.a & 0x80) != 0;
    self.flag.zero = self.register.a == 0;
    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.parity_overflow = Z80.parity(u8, self.register.a);

    // Set undocumented flags
    self.flag.x = (self.register.a & 0x08) != 0;
    self.flag.y = (self.register.a & 0x20) != 0;

    // Set WZ
    self.wz = hl_addr +% 1;

    self.q = self.flag.toByte();
    self.cycle_count += 18;
}
