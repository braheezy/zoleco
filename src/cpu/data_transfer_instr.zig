const std = @import("std");
const Z80 = @import("Z80.zig");

// STAX B: Store accumulator in 16-bit immediate address pointed to by register pair BC
pub fn stax_B(self: *Z80) !void {
    const address = Z80.toUint16(self.register.b, self.register.c);
    std.log.debug("[02]\tLD  \t(BC),A", .{});
    self.memory[address] = self.register.a;
    self.cycle_count += 7;
}

// LDAX B: Load value from address in register pair B into accumulator.
pub fn loadAddr_B(self: *Z80) !void {
    std.log.debug("[0A]\tLD  \tA,(BC)", .{});
    self.register.a = self.memory[Z80.toUint16(self.register.b, self.register.c)];
    self.cycle_count += 7;
}

// LDAX D: Load value from address in register pair D into accumulator.
pub fn loadAddr_D(self: *Z80) !void {
    std.log.debug("[1A]\tLD  \tA,(DE)", .{});
    self.register.a = self.memory[Z80.toUint16(self.register.d, self.register.e)];
    self.cycle_count += 7;
}
// MOV M,A: Move value from accumulator into register pair H.
pub fn move_MA(self: *Z80) !void {
    const address = Z80.toUint16(self.register.h, self.register.l);
    std.log.debug("[77]\tLD  \t(HL),A ({X:<4})", .{address});
    self.memory[address] = self.register.a;
    self.cycle_count += 7;
}

// MOV L,A: Load value from accumulator into register L.
pub fn move_LA(self: *Z80) !void {
    std.log.debug("[6F]\tLD  \tL,A", .{});
    self.register.l = self.register.a;
    self.cycle_count += 4;
}

// MOV L,B: Load value from register B into register L.
pub fn move_LB(self: *Z80) !void {
    std.log.debug("[68]\tLD  \tL,B", .{});
    self.register.l = self.register.b;
    self.cycle_count += 4;
}

// MOV L,M: Load value from register B into memory address from register pair HL
pub fn move_LM(self: *Z80) !void {
    std.log.debug("[6E]\tLD  \tL,(HL)", .{});
    self.register.l = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV D,B: Load value from register B into register D.
pub fn move_DB(self: *Z80) !void {
    std.log.debug("[50]\tLD  \tD,B", .{});
    self.register.d = self.register.b;
    self.cycle_count += 4;
}

// MOV D,E: Load value from register E into register D.
pub fn move_DE(self: *Z80) !void {
    std.log.debug("[53]\tLD  \tD,E", .{});
    self.register.d = self.register.e;
    self.cycle_count += 4;
}

// MOV E,B: Load value from register B into register E.
pub fn move_EB(self: *Z80) !void {
    std.log.debug("[58]\tLD  \tE,B", .{});
    self.register.e = self.register.b;
    self.cycle_count += 4;
}

// MOV E,L: Load value from register L into register E.
pub fn move_EL(self: *Z80) !void {
    std.log.debug("[5D]\tLD  \tE,L", .{});
    self.register.e = self.register.l;
    self.cycle_count += 4;
}

// MOV B,A: Load value from accumulator into register B.
pub fn move_BA(self: *Z80) !void {
    std.log.debug("[47]\tLD  \tB,A", .{});
    self.register.b = self.register.a;
    self.cycle_count += 4;
}

// MOV B,D: Load value from register B into register D.
pub fn move_BD(self: *Z80) !void {
    std.log.debug("[42]\tLD  \tB,D", .{});
    self.register.b = self.register.d;
    self.cycle_count += 4;
}

// MOV B,E: Load value from register B into register E.
pub fn move_BE(self: *Z80) !void {
    std.log.debug("[43]\tLD  \tB,E", .{});
    self.register.b = self.register.e;
    self.cycle_count += 4;
}

// MOV C,A: Load value from accumulator into register C.
pub fn move_CA(self: *Z80) !void {
    std.log.debug("[4F]\tLD  \tC,A", .{});
    self.register.c = self.register.a;
    self.cycle_count += 4;
}

// MOV C,B: Load value from register B into register C.
pub fn move_CB(self: *Z80) !void {
    std.log.debug("[48]\tLD  \tC,B", .{});
    self.register.c = self.register.b;
    self.cycle_count += 4;
}

// MOV C,D: Load value from register D into register C.
pub fn move_CD(self: *Z80) !void {
    std.log.debug("[4A]\tLD  \tC,D", .{});
    self.register.c = self.register.d;
    self.cycle_count += 4;
}

// MOV C,E: Load value from register E into register C.
pub fn move_CE(self: *Z80) !void {
    std.log.debug("[4B]\tLD  \tC,E", .{});
    self.register.c = self.register.e;
    self.cycle_count += 4;
}

// MOV C,H: Load value from register H into register C.
pub fn move_CH(self: *Z80) !void {
    std.log.debug("[4C]\tLD  \tC,H", .{});
    self.register.c = self.register.h;
    self.cycle_count += 4;
}

// MOV H,B: Load value from register B into register H.
pub fn move_HB(self: *Z80) !void {
    std.log.debug("[60]\tLD  \tH,B", .{});
    self.register.h = self.register.b;
    self.cycle_count += 4;
}

// MOV H,L: Load value from register L into register H.
pub fn move_HL(self: *Z80) !void {
    std.log.debug("[65]\tLD  \tH,L", .{});
    self.register.h = self.register.l;
    self.cycle_count += 4;
}

// MOV A,C: Load value from register C into accumulator.
pub fn move_AC(self: *Z80) !void {
    std.log.debug("[79]\tLD  \tA,C", .{});
    self.register.a = self.register.c;
    self.cycle_count += 4;
}

// MOV D,C: Load value from register C into register D.
pub fn move_DC(self: *Z80) !void {
    std.log.debug("[51]\tLD  \tD,C", .{});
    self.register.d = self.register.c;
    self.cycle_count += 4;
}

// MOV D,H: Load value from register H into register D.
pub fn move_DH(self: *Z80) !void {
    std.log.debug("[54]\tLD  \tD,H", .{});
    self.register.d = self.register.h;
    self.cycle_count += 4;
}

// MOV D,L: Load value from register L into register D.
pub fn move_DL(self: *Z80) !void {
    std.log.debug("[55]\tLD  \tD,L", .{});
    self.register.d = self.register.l;
    self.cycle_count += 4;
}

// MOV H,C: Load value from register C into register H.
pub fn move_HC(self: *Z80) !void {
    std.log.debug("[61]\tLD  \tH,C", .{});
    self.register.h = self.register.c;
    self.cycle_count += 4;
}

// MOV E,M: Move memory location pointed to by register pair HL into register E.
pub fn move_EM(self: *Z80) !void {
    std.log.debug("[5E]\tLD  \tE,(HL)", .{});
    self.register.e = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV B,M: Move memory location pointed to by register pair HL into register B.
pub fn move_BM(self: *Z80) !void {
    std.log.debug("[46]\tLD  \tB,(HL)", .{});
    self.register.b = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV C,M: Move memory location pointed to by register pair HL into register C.
pub fn move_CM(self: *Z80) !void {
    std.log.debug("[4E]\tLD  \tC,(HL)", .{});
    self.register.c = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV D,M: Move memory location pointed to by register pair HL into register D.
pub fn move_DM(self: *Z80) !void {
    std.log.debug("[56]\tLD  \tD,(HL)", .{});
    self.register.d = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV A,M: Move memory location pointed to by register pair HL into register A.
pub fn move_AM(self: *Z80) !void {
    std.log.debug("[7E]\tLD  \tA,(HL)", .{});
    self.register.a = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV H,M: Move memory location pointed to by register pair HL into register H.
pub fn move_HM(self: *Z80) !void {
    std.log.debug("[66]\tLD  \tH,(HL)", .{});
    self.register.h = self.memory[Z80.toUint16(self.register.h, self.register.l)];
    self.cycle_count += 7;
}

// MOV M,B: Move register B into memory location pointed to by register pair HL.
pub fn move_MB(self: *Z80) !void {
    std.log.debug("[70]\tLD  \t(HL),B", .{});
    self.memory[Z80.toUint16(self.register.h, self.register.l)] = self.register.b;
    self.cycle_count += 7;
}

// MOV M,C: Move register C into memory location pointed to by register pair HL.
pub fn move_MC(self: *Z80) !void {
    std.log.debug("[71]\tLD  \t(HL),C", .{});
    self.memory[Z80.toUint16(self.register.h, self.register.l)] = self.register.c;
    self.cycle_count += 7;
}

// MOV M,D: Move register D into memory location pointed to by register pair HL.
pub fn move_MD(self: *Z80) !void {
    std.log.debug("[72]\tLD  \t(HL),D", .{});
    self.memory[Z80.toUint16(self.register.h, self.register.l)] = self.register.d;
    self.cycle_count += 7;
}

// MOV M,E: Move register E into memory location pointed to by register pair HL.
pub fn move_ME(self: *Z80) !void {
    std.log.debug("[73]\tLD  \t(HL),E", .{});
    self.memory[Z80.toUint16(self.register.h, self.register.l)] = self.register.e;
    self.cycle_count += 7;
}

// MOV M,H: Move register H into memory location pointed to by register pair HL.
pub fn move_MH(self: *Z80) !void {
    std.log.debug("[74]\tLD  \t(HL),H", .{});
    self.memory[Z80.toUint16(self.register.h, self.register.l)] = self.register.h;
    self.cycle_count += 7;
}

// MOV M,L: Move register L into memory location pointed to by register pair HL.
pub fn move_ML(self: *Z80) !void {
    std.log.debug("[75]\tLD  \t(HL),L", .{});
    self.memory[Z80.toUint16(self.register.h, self.register.l)] = self.register.l;
    self.cycle_count += 7;
}

// MOV A,H: Move value from register H into accumulator.
pub fn move_AH(self: *Z80) !void {
    std.log.debug("[7C]\tLD  \tA,H", .{});
    self.register.a = self.register.h;
    self.cycle_count += 4;
}

// MOV A,L: Move value from register L into accumulator.
pub fn move_AL(self: *Z80) !void {
    std.log.debug("[7D]\tLD  \tA,L", .{});
    self.register.a = self.register.l;
    self.cycle_count += 4;
}

// MOV B,B: Move value from register B into register B.
pub fn move_BB(self: *Z80) !void {
    std.log.debug("[40]\tLD  \tB,B", .{});
    self.register.b = self.register.b;
    self.cycle_count += 4;
}

// MOV B,C: Move value from register C into register B.
pub fn move_BC(self: *Z80) !void {
    std.log.debug("[41]\tLD  \tB,C", .{});
    self.register.b = self.register.c;
    self.cycle_count += 4;
}

// MOV B,L: Move value from register L into register B.
pub fn move_BL(self: *Z80) !void {
    std.log.debug("[45]\tLD  \tB,L", .{});
    self.register.b = self.register.l;
    self.cycle_count += 4;
}

// MOV B,H: Move value from register H into register B.
pub fn move_BH(self: *Z80) !void {
    std.log.debug("[44]\tLD  \tB,H", .{});
    self.register.b = self.register.h;
    self.cycle_count += 4;
}

// MOV C,C: Move value from register C into register C.
pub fn move_CC(self: *Z80) !void {
    std.log.debug("[49]\tLD  \tC,C", .{});
    self.register.c = self.register.c;
    self.cycle_count += 4;
}

// MOV C,L: Move value from register C into register L.
pub fn move_CL(self: *Z80) !void {
    std.log.debug("[4D]\tLD  \tC,L", .{});
    self.register.c = self.register.l;
    self.cycle_count += 4;
}

// MOV A,D: Move value from register D into accumulator.
pub fn move_AD(self: *Z80) !void {
    std.log.debug("[7A]\tLD  \tA,D", .{});
    self.register.a = self.register.d;
    self.cycle_count += 4;
}

// MOV D,D: Move value from register D into register D.
pub fn move_DD(self: *Z80) !void {
    std.log.debug("[52]\tLD  \tD,D", .{});
    self.register.d = self.register.d;
    self.cycle_count += 4;
}

// MOV E,D: Move value from register D into register E.
pub fn move_ED(self: *Z80) !void {
    std.log.debug("[5A]\tLD  \tE,D", .{});
    self.register.e = self.register.d;
    self.cycle_count += 4;
}

// MOV E,E: Move value from register E into register E.
pub fn move_EE(self: *Z80) !void {
    std.log.debug("[5B]\tLD  \tE,E", .{});
    self.register.e = self.register.e;
    self.cycle_count += 4;
}

// MOV E,H: Move value from register H into register E.
pub fn move_EH(self: *Z80) !void {
    std.log.debug("[5C]\tLD  \tE,H", .{});
    self.register.e = self.register.h;
    self.cycle_count += 4;
}

// MOV H,D: Move value from register D into register H.
pub fn move_HD(self: *Z80) !void {
    std.log.debug("[62]\tLD  \tH,D", .{});
    self.register.h = self.register.d;
    self.cycle_count += 4;
}

// MOV L,C: Move value from register C into register L.
pub fn move_LC(self: *Z80) !void {
    std.log.debug("[69]\tLD  \tL,C", .{});
    self.register.l = self.register.c;
    self.cycle_count += 4;
}

// MOV L,D: Move value from register D into register L.
pub fn move_LD(self: *Z80) !void {
    std.log.debug("[6A]\tLD  \tL,D", .{});
    self.register.l = self.register.d;
    self.cycle_count += 4;
}

// MOV A,E: Move value from register E into accumulator.
pub fn move_AE(self: *Z80) !void {
    std.log.debug("[7B]\tLD  \tA,E", .{});
    self.register.a = self.register.e;
    self.cycle_count += 4;
}

// MOV H,A: Move value from accumulator into register H.
pub fn move_HA(self: *Z80) !void {
    std.log.debug("[67]\tLD  \tH,A", .{});
    self.register.h = self.register.a;
    self.cycle_count += 4;
}

// MOV H,E: Move value from register E into register H.
pub fn move_HE(self: *Z80) !void {
    std.log.debug("[63]\tLD  \tH,E", .{});
    self.register.h = self.register.e;
    self.cycle_count += 4;
}

// MOV E,C: Move value from register C into register E.
pub fn move_EC(self: *Z80) !void {
    std.log.debug("[59]\tLD  \tE,C", .{});
    self.register.e = self.register.c;
    self.cycle_count += 4;
}

// MOV L,E: Move value from register E into register L.
pub fn move_LE(self: *Z80) !void {
    std.log.debug("[6B]\tLD  \tL,E", .{});
    self.register.l = self.register.e;
    self.cycle_count += 4;
}

// MOV A,B: Move value from register B into accumulator.
pub fn move_AB(self: *Z80) !void {
    std.log.debug("[78]\tLD  \tA,B", .{});
    self.register.a = self.register.b;
    self.cycle_count += 4;
}

// MOV E,A: Move value from accumulator into register E.
pub fn move_EA(self: *Z80) !void {
    std.log.debug("[5F]\tLD  \tE,A", .{});
    self.register.e = self.register.a;
    self.cycle_count += 4;
}

// MOV L,H: Move value from register H into register L.
pub fn move_LH(self: *Z80) !void {
    std.log.debug("[6C]\tLD  \tH,L", .{});
    self.register.l = self.register.h;
    self.cycle_count += 4;
}

// MOV D,A: Move value from accumulator into register D.
pub fn move_DA(self: *Z80) !void {
    std.log.debug("[57]\tLD  \tD,A", .{});
    self.register.d = self.register.a;
    self.cycle_count += 4;
}

// STAX D: Store accumulator in 16-bit immediate address pointed to by register pair DE
pub fn stax_D(self: *Z80) !void {
    const address = Z80.toUint16(self.register.d, self.register.e);
    std.log.debug("[12]\tLD  \t(DE),A", .{});
    self.memory[address] = self.register.a;
    self.cycle_count += 7;
}
