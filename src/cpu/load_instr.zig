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
