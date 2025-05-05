const std = @import("std");
const Z80 = @import("../Z80.zig");

// STAX B: Store accumulator in 16-bit immediate address pointed to by register pair BC
pub fn stax_B(self: *Z80) !void {
    const address = Z80.toUint16(self.register.b, self.register.c);

    self.io.writeMemory(self.io.ctx, address, self.register.a);

    // Set WZ: high byte = A, low byte = (C + 1)
    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, self.register.c +% 1));

    self.q = 0;
}

fn store_pair_to_nn(self: *Z80, high: u8, low: u8) !void {
    const data = try self.fetchData(2);
    const nn = Z80.toUint16(data[1], data[0]);

    self.io.writeMemory(self.io.ctx, nn + 1, high);
    self.io.writeMemory(self.io.ctx, nn, low);

    self.wz = nn +% 1;
    self.q = 0;
}

// Stores BC into the memory location pointed to by nn.
pub fn load_BC_nn(self: *Z80) !void {
    try store_pair_to_nn(self, self.register.b, self.register.c);
}

// Stores DE into the memory location pointed to by nn.
pub fn load_DE_nn(self: *Z80) !void {
    try store_pair_to_nn(self, self.register.d, self.register.e);
}

// Stores HL into the memory location pointed to by nn.
pub fn load_HL_nn(self: *Z80) !void {
    try store_pair_to_nn(self, self.register.h, self.register.l);
}

// Stores SP into the memory location pointed to by nn.
pub fn load_SP_nn(self: *Z80) !void {
    const data = try self.fetchData(2);
    const nn = Z80.toUint16(data[1], data[0]);

    // Store SP into memory location nn (low byte) and nn+1 (high byte)
    self.io.writeMemory(self.io.ctx, nn, @truncate(self.sp & 0xFF)); // Low byte
    self.io.writeMemory(self.io.ctx, nn +% 1, @truncate(self.sp >> 8)); // High byte

    self.wz = nn +% 1;
    self.q = 0;
}

// Loads the value pointed to by nn into BC.
pub fn load_nn_BC(self: *Z80) !void {
    const data = try self.fetchData(2);
    const nn = Z80.toUint16(data[1], data[0]);

    // Load BC from memory location nn (low byte) and nn+1 (high byte)
    self.register.c = self.io.readMemory(self.io.ctx, nn);
    self.register.b = self.io.readMemory(self.io.ctx, nn +% 1);

    // Set WZ to nn+1
    self.wz = nn +% 1;

    self.q = 0;
}

pub fn load_nn_DE(self: *Z80) !void {
    const data = try self.fetchData(2);
    const nn = Z80.toUint16(data[1], data[0]);

    // Load DE from memory location nn (low byte) and nn+1 (high byte)
    self.register.e = self.io.readMemory(self.io.ctx, nn);
    self.register.d = self.io.readMemory(self.io.ctx, nn +% 1);

    // Set WZ to nn+1
    self.wz = nn +% 1;

    self.q = 0;
}

pub fn load_nn_HL(self: *Z80) !void {
    const data = try self.fetchData(2);
    const nn = Z80.toUint16(data[1], data[0]);

    // Load HL from memory location nn (low byte) and nn+1 (high byte)
    self.register.l = self.io.readMemory(self.io.ctx, nn);
    self.register.h = self.io.readMemory(self.io.ctx, nn +% 1);

    // Set WZ to nn+1
    self.wz = nn +% 1;

    self.q = 0;
}

pub fn load_nn_SP(self: *Z80) !void {
    const data = try self.fetchData(2);
    const nn = Z80.toUint16(data[1], data[0]);

    // Load SP from memory location nn (low byte) and nn+1 (high byte)
    const low = self.io.readMemory(self.io.ctx, nn);
    const high = self.io.readMemory(self.io.ctx, nn +% 1);
    self.sp = Z80.toUint16(high, low);

    self.wz = nn +% 1;
    self.q = 0;
}

// LDAX B: Load value from address in register pair B into accumulator.
pub fn loadAddr_B(self: *Z80) !void {
    const addr = Z80.toUint16(self.register.b, self.register.c);
    self.register.a = self.io.readMemory(self.io.ctx, addr);
    self.wz = addr +% 1;
    self.q = 0;
}

// LDAX D: Load value from address in register pair D into accumulator.
pub fn loadAddr_D(self: *Z80) !void {
    const addr = Z80.toUint16(self.register.d, self.register.e);
    self.register.a = self.io.readMemory(self.io.ctx, addr);
    self.wz = addr +% 1;
    self.q = 0;
}

// Loads the value of HL into SP.
pub fn load_HL_SP(self: *Z80) !void {
    self.sp = self.getHL();
    self.q = 0;
}

// MOV M,A: Move value from accumulator into register pair H.
pub fn move_MA(self: *Z80) !void {
    const address = self.getHL();

    self.io.writeMemory(self.io.ctx, address, self.register.a);
    self.q = 0;
}

// MOV L,A: Load value from accumulator into register L.
pub fn move_LA(self: *Z80) !void {
    self.register.l = self.register.a;
    self.q = 0;
}

// MOV L,B: Load value from register B into register L.
pub fn move_LB(self: *Z80) !void {
    self.register.l = self.register.b;
    self.q = 0;
}

// MOV L,M: Load value from register B into memory address from register pair HL
pub fn move_LM(self: *Z80) !void {
    self.register.l = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV D,B: Load value from register B into register D.
pub fn move_DB(self: *Z80) !void {
    self.register.d = self.register.b;
    self.q = 0;
}

// MOV D,E: Load value from register E into register D.
pub fn move_DE(self: *Z80) !void {
    self.register.d = self.register.e;
    self.q = 0;
}

// MOV E,B: Load value from register B into register E.
pub fn move_EB(self: *Z80) !void {
    self.register.e = self.register.b;
    self.q = 0;
}

// MOV E,L: Load value from register L into register E.
pub fn move_EL(self: *Z80) !void {
    self.register.e = self.register.l;
    self.q = 0;
}

// MOV B,A: Load value from accumulator into register B.
pub fn move_BA(self: *Z80) !void {
    self.register.b = self.register.a;
    self.q = 0;
}

// MOV B,D: Load value from register B into register D.
pub fn move_BD(self: *Z80) !void {
    self.register.b = self.register.d;
    self.q = 0;
}

// MOV B,E: Load value from register B into register E.
pub fn move_BE(self: *Z80) !void {
    self.register.b = self.register.e;
    self.q = 0;
}

// MOV C,A: Load value from accumulator into register C.
pub fn move_CA(self: *Z80) !void {
    self.register.c = self.register.a;
    self.q = 0;
}

// MOV C,B: Load value from register B into register C.
pub fn move_CB(self: *Z80) !void {
    self.register.c = self.register.b;
    self.q = 0;
}

// MOV C,D: Load value from register D into register C.
pub fn move_CD(self: *Z80) !void {
    self.register.c = self.register.d;
    self.q = 0;
}

// MOV C,E: Load value from register E into register C.
pub fn move_CE(self: *Z80) !void {
    self.register.c = self.register.e;
    self.q = 0;
}

// MOV C,H: Load value from register H into register C.
pub fn move_CH(self: *Z80) !void {
    self.register.c = self.register.h;
    self.q = 0;
}

// MOV H,B: Load value from register B into register H.
pub fn move_HB(self: *Z80) !void {
    self.register.h = self.register.b;
    self.q = 0;
}

// MOV H,L: Load value from register L into register H.
pub fn move_HL(self: *Z80) !void {
    self.register.h = self.register.l;
    self.q = 0;
}

// MOV A,C: Load value from register C into accumulator.
pub fn move_AC(self: *Z80) !void {
    self.register.a = self.register.c;
    self.q = 0;
}

// MOV D,C: Load value from register C into register D.
pub fn move_DC(self: *Z80) !void {
    self.register.d = self.register.c;
    self.q = 0;
}

// MOV D,H: Load value from register H into register D.
pub fn move_DH(self: *Z80) !void {
    self.register.d = self.register.h;
    self.q = 0;
}

// MOV D,L: Load value from register L into register D.
pub fn move_DL(self: *Z80) !void {
    self.register.d = self.register.l;
    self.q = 0;
}

// MOV H,C: Load value from register C into register H.
pub fn move_HC(self: *Z80) !void {
    self.register.h = self.register.c;
    self.q = 0;
}

// MOV E,M: Move memory location pointed to by register pair HL into register E.
pub fn move_EM(self: *Z80) !void {
    self.register.e = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV B,M: Move memory location pointed to by register pair HL into register B.
pub fn move_BM(self: *Z80) !void {
    self.register.b = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV C,M: Move memory location pointed to by register pair HL into register C.
pub fn move_CM(self: *Z80) !void {
    self.register.c = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV D,M: Move memory location pointed to by register pair HL into register D.
pub fn move_DM(self: *Z80) !void {
    self.register.d = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV A,M: Move memory location pointed to by register pair HL into register A.
pub fn move_AM(self: *Z80) !void {
    self.register.a = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV H,M: Move memory location pointed to by register pair HL into register H.
pub fn move_HM(self: *Z80) !void {
    self.register.h = self.io.readMemory(self.io.ctx, self.getHL());
    self.q = 0;
}

// MOV M,B: Move register B into memory location pointed to by register pair HL.
pub fn move_MB(self: *Z80) !void {
    self.io.writeMemory(self.io.ctx, self.getHL(), self.register.b);
    self.q = 0;
}

// MOV M,C: Move register C into memory location pointed to by register pair HL.
pub fn move_MC(self: *Z80) !void {
    self.io.writeMemory(self.io.ctx, self.getHL(), self.register.c);
    self.q = 0;
}

// MOV M,D: Move register D into memory location pointed to by register pair HL.
pub fn move_MD(self: *Z80) !void {
    self.io.writeMemory(self.io.ctx, self.getHL(), self.register.d);
    self.q = 0;
}

// MOV M,E: Move register E into memory location pointed to by register pair HL.
pub fn move_ME(self: *Z80) !void {
    self.io.writeMemory(self.io.ctx, self.getHL(), self.register.e);
    self.q = 0;
}

// MOV M,H: Move register H into memory location pointed to by register pair HL.
pub fn move_MH(self: *Z80) !void {
    self.io.writeMemory(self.io.ctx, self.getHL(), self.register.h);
    self.q = 0;
}

// MOV M,L: Move register L into memory location pointed to by register pair HL.
pub fn move_ML(self: *Z80) !void {
    self.io.writeMemory(self.io.ctx, self.getHL(), self.register.l);
    self.q = 0;
}

// MOV A,H: Move value from register H into accumulator.
pub fn move_AH(self: *Z80) !void {
    self.register.a = self.register.h;
    self.q = 0;
}

// MOV A,L: Move value from register L into accumulator.
pub fn move_AL(self: *Z80) !void {
    self.register.a = self.register.l;
    self.q = 0;
}

// MOV B,B: Move value from register B into register B.
pub fn move_BB(self: *Z80) !void {
    self.register.b = self.register.b;
    self.q = 0;
}

// MOV B,C: Move value from register C into register B.
pub fn move_BC(self: *Z80) !void {
    self.register.b = self.register.c;
    self.q = 0;
}

// MOV B,L: Move value from register L into register B.
pub fn move_BL(self: *Z80) !void {
    self.register.b = self.register.l;
    self.q = 0;
}

// MOV B,H: Move value from register H into register B.
pub fn move_BH(self: *Z80) !void {
    self.register.b = self.register.h;
    self.q = 0;
}

// MOV C,C: Move value from register C into register C.
pub fn move_CC(self: *Z80) !void {
    self.register.c = self.register.c;
    self.q = 0;
}

// MOV C,L: Move value from register C into register L.
pub fn move_CL(self: *Z80) !void {
    self.register.c = self.register.l;
    self.q = 0;
}

// MOV A,D: Move value from register D into accumulator.
pub fn move_AD(self: *Z80) !void {
    self.register.a = self.register.d;
    self.q = 0;
}

// MOV D,D: Move value from register D into register D.
pub fn move_DD(self: *Z80) !void {
    self.register.d = self.register.d;
    self.q = 0;
}

// MOV E,D: Move value from register D into register E.
pub fn move_ED(self: *Z80) !void {
    self.register.e = self.register.d;
    self.q = 0;
}

// MOV E,E: Move value from register E into register E.
pub fn move_EE(self: *Z80) !void {
    self.register.e = self.register.e;
    self.q = 0;
}

// MOV E,H: Move value from register H into register E.
pub fn move_EH(self: *Z80) !void {
    self.register.e = self.register.h;
    self.q = 0;
}

// MOV H,D: Move value from register D into register H.
pub fn move_HD(self: *Z80) !void {
    self.register.h = self.register.d;
    self.q = 0;
}

// MOV H,H: Move value from register H into register H.
pub fn move_HH(self: *Z80) !void {
    self.register.h = self.register.h;
    self.q = 0;
}

// MOV L,C: Move value from register C into register L.
pub fn move_LC(self: *Z80) !void {
    self.register.l = self.register.c;
    self.q = 0;
}

// MOV L,D: Move value from register D into register L.
pub fn move_LD(self: *Z80) !void {
    self.register.l = self.register.d;
    self.q = 0;
}

// MOV L,L: Move value from register L into register L.
pub fn move_LL(self: *Z80) !void {
    self.register.l = self.register.l;
    self.q = 0;
}

// MOV A,E: Move value from register E into accumulator.
pub fn move_AE(self: *Z80) !void {
    self.register.a = self.register.e;
    self.q = 0;
}

// MOV H,A: Move value from accumulator into register H.
pub fn move_HA(self: *Z80) !void {
    self.register.h = self.register.a;
    self.q = 0;
}

// MOV H,E: Move value from register E into register H.
pub fn move_HE(self: *Z80) !void {
    self.register.h = self.register.e;
    self.q = 0;
}

// MOV E,C: Move value from register C into register E.
pub fn move_EC(self: *Z80) !void {
    self.register.e = self.register.c;
    self.q = 0;
}

// MOV L,E: Move value from register E into register L.
pub fn move_LE(self: *Z80) !void {
    self.register.l = self.register.e;
    self.q = 0;
}

// MOV A,B: Move value from register B into accumulator.
pub fn move_AB(self: *Z80) !void {
    self.register.a = self.register.b;
    self.q = 0;
}

// MOV A,A: Move value from register A into register A.
pub fn move_AA(self: *Z80) !void {
    self.register.a = self.register.a;
    self.q = 0;
}

// MOV E,A: Move value from accumulator into register E.
pub fn move_EA(self: *Z80) !void {
    self.register.e = self.register.a;
    self.q = 0;
}

// MOV L,H: Move value from register H into register L.
pub fn move_LH(self: *Z80) !void {
    self.register.l = self.register.h;
    self.q = 0;
}

// MOV D,A: Move value from accumulator into register D.
pub fn move_DA(self: *Z80) !void {
    self.register.d = self.register.a;
    self.q = 0;
}

// STAX D: Store accumulator in 16-bit immediate address pointed to by register pair DE
pub fn stax_D(self: *Z80) !void {
    const address = Z80.toUint16(self.register.d, self.register.e);

    self.io.writeMemory(self.io.ctx, address, self.register.a);
    self.q = 0;
    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, address +% 1 & 0xFF));
}
