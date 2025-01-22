const std = @import("std");
const Z80 = @import("Z80.zig");

const li = @import("load_instr.zig");
const ci = @import("call_instr.zig");
const ji = @import("jump_instr.zig");
const immi = @import("immediate_instr.zig");
const dti = @import("data_transfer_instr.zig");
const rpi = @import("register_pair_instr.zig");
const rai = @import("rotate_instr.zig");
const rsi = @import("register_single_instr.zig");
const dai = @import("direct_address_instr.zig");
const ai = @import("accumulator_instr.zig");
const ri = @import("return_instr.zig");
const ix = @import("ix_instr.zig");
const si = @import("shift_instr.zig");
const bitTest = @import("bit_test_instr.zig").bitTest;
const bitSetReset = @import("bit_test_instr.zig").bitSetReset;

pub fn getHighByte(value: u16) u8 {
    return @intCast(value >> 8);
}

pub fn getLowByte(value: u16) u8 {
    return @intCast(value & 0xFF);
}

const OpError = error{OutOfBoundsMemory};

pub const OpcodeHandler = *const fn (*Z80) OpError!void;
pub const OpcodeTable = [256]?OpcodeHandler{
    nop, immi.load_BC, dti.stax_B, rpi.inx_B, rsi.inr_B, rsi.dcr_B, immi.moveImm_B, rai.rlca, li.ex_AF, rpi.dad_B, dti.loadAddr_B, rsi.dcx_B, rsi.inr_C, rsi.dcr_C, immi.moveImm_C, rai.rrca, // 00 - 0F
    ji.djnz, immi.load_DE, dti.stax_D, rpi.inx_D, rsi.inr_D, rsi.dcr_D, immi.moveImm_D, rai.rla, ji.jr, rpi.dad_D, dti.loadAddr_D, rsi.dcx_D, rsi.inr_E, rsi.dcr_E, immi.moveImm_E, rai.rra, // 10 - 1F
    ji.jr_NZ, immi.load_HL, dai.store_HL, rpi.inx_H, rsi.inr_H, rsi.dcr_H, immi.moveImm_H, rsi.daa, ji.jr_Z, rpi.dad_H, dai.loadImm_HL, rsi.dcx_H, rsi.inr_L, rsi.dcr_L, immi.moveImm_L, rsi.cma, // 20 - 2F
    ji.jr_NC, immi.load_SP, dai.store_A, rpi.inx_SP, rsi.inr_M, rsi.dcr_M, immi.moveImm_M, rsi.scf, ji.jr_C, rpi.dad_SP, dai.load_A, rsi.dcx_SP, rsi.inr_A, rsi.dcr_A, immi.moveImm_A, rsi.ccf, // 30 - 3F
    dti.move_BB, dti.move_BC, dti.move_BD, dti.move_BE, dti.move_BH, dti.move_BL, dti.move_BM, dti.move_BA, dti.move_CB, dti.move_CC, dti.move_CD, dti.move_CE, dti.move_CH, dti.move_CL, dti.move_CM, dti.move_CA, // 40 - 4F
    dti.move_DB, dti.move_DC, dti.move_DD, dti.move_DE, dti.move_DH, dti.move_DL, dti.move_DM, dti.move_DA, dti.move_EB, dti.move_EC, dti.move_ED, dti.move_EE, dti.move_EH, dti.move_EL, dti.move_EM, dti.move_EA, // 50 - 5F
    dti.move_HB, dti.move_HC, dti.move_HD, dti.move_HE, dti.move_HH, dti.move_HL, dti.move_HM, dti.move_HA, dti.move_LB, dti.move_LC, dti.move_LD, dti.move_LE, dti.move_LH, dti.move_LL, dti.move_LM, dti.move_LA, // 60 - 6F
    dti.move_MB, dti.move_MC, dti.move_MD, dti.move_ME, dti.move_MH, dti.move_ML, halt, dti.move_MA, dti.move_AB, dti.move_AC, dti.move_AD, dti.move_AE, dti.move_AH, dti.move_AL, dti.move_AM, dti.move_AA, // 70 - 7F
    ai.add_B, ai.add_C, ai.add_D, ai.add_E, ai.add_H, ai.add_L, ai.add_M, ai.add_A, ai.adc_B, ai.adc_C, ai.adc_D, ai.adc_E, ai.adc_H, ai.adc_L, ai.adc_M, ai.adc_A, // 80 - 8F
    ai.sub_B, ai.sub_C, ai.sub_D, ai.sub_E, ai.sub_H, ai.sub_L, ai.sub_M, ai.sub_A, ai.sbb_B, ai.sbb_C, ai.sbb_D, ai.sbb_E, ai.sbb_H, ai.sbb_L, ai.sbb_M, ai.sbb_A, // 90 - 9F
    ai.ana_B, ai.ana_C, ai.ana_D, ai.ana_E, ai.ana_H, ai.ana_L, ai.ana_M, ai.ana_A, ai.xra_B, ai.xra_C, ai.xra_D, ai.xra_E, ai.xra_H, ai.xra_L, ai.xra_M, ai.xra_A, // A0 - AF
    ai.ora_B, ai.ora_C, ai.ora_D, ai.ora_E, ai.ora_H, ai.ora_L, ai.ora_M, ai.ora_A, ai.cmp_B, ai.cmp_C, ai.cmp_D, ai.cmp_E, ai.cmp_H, ai.cmp_L, ai.cmp_M, ai.cmp_A, // B0 - BF
    ri.ret_NZ, rpi.pop_BC, ji.jump_NZ, ji.jump, ci.call_NZ, rpi.push_BC, ai.add_N, rst0, ri.ret_Z, ri.ret, ji.jump_Z, lookupBitOpcode, ci.call_Z, ci.call, ai.adc_N, rst8, // C0 - CF
    ri.ret_NC, rpi.pop_DE, ji.jump_NC, out, ci.call_NC, rpi.push_DE, ai.sub_N, rst16, ri.ret_C, li.exx, ji.jump_C, in, ci.call_C, lookupIxOpcode, ai.sbb_N, rst24, // D0 - DF
    ri.ret_PO, rpi.pop_HL, ji.jump_PO, li.ex_M_HL, ci.call_PO, rpi.push_HL, null, null, ri.ret_PE, null, ji.jump_PE, li.ex_DE_HL, ci.call_PE, null, null, null, // E0 - EF
    ri.ret_P, rpi.pop_AF, ji.jump_P, di, ci.call_P, rpi.push_AF, null, null, ri.ret_M, null, ji.jump_M, null, ci.call_M, lookupIyOpcode, null, null, // F0 - FF
};

pub const IndexYOpcodeTable = [256]?OpcodeHandler{
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 00 - 0F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 10 - 1F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 20 - 2F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 30 - 3F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 40 - 4F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 50 - 5F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 60 - 6F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 70 - 7F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 80 - 8F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 90 - 9F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // A0 - AF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // B0 - BF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // C0 - CF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // D0 - DF
    null, null, null, null, null, li.pushIy, null, null, null, null, null, null, null, null, null, null, // E0 - EF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // F0 - FF
};

pub const IndexXOpcodeTable = [256]?OpcodeHandler{
    nop, immi.load_BC, dti.stax_B, rpi.inx_B, rsi.inr_B, rsi.dcr_B, immi.moveImm_B, rai.rlca, li.ex_AF, ix.add_BC, dti.loadAddr_B, rsi.dcx_B, rsi.inr_C, rsi.dcr_C, immi.moveImm_C, rai.rrca, // 00 - 0F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 10 - 1F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 20 - 2F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 30 - 3F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 40 - 4F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 50 - 5F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 60 - 6F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 70 - 7F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 80 - 8F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 90 - 9F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // A0 - AF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // B0 - BF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // C0 - CF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // D0 - DF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // E0 - EF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // F0 - FF
};

const BitOpcodeTable = [256]?OpcodeHandler{
    rai.rlc_B, rai.rlc_C, rai.rlc_D, rai.rlc_E, rai.rlc_H, rai.rlc_L, rai.rlc_M, rai.rlc_A, rai.rrc_B, rai.rrc_C, rai.rrc_D, rai.rrc_E, rai.rrc_H, rai.rrc_L, rai.rrc_M, rai.rrc_A, // 00 - 0F
    rai.rl_B, rai.rl_C, rai.rl_D, rai.rl_E, rai.rl_H, rai.rl_L, rai.rl_M, rai.rl_A, rai.rr_B, rai.rr_C, rai.rr_D, rai.rr_E, rai.rr_H, rai.rr_L, rai.rr_M, rai.rr_A, // 10 - 1F
    si.sla_B, si.sla_C, si.sla_D, si.sla_E, si.sla_H, si.sla_L, si.sla_M, si.sla_A, si.sra_B, si.sra_C, si.sra_D, si.sra_E, si.sra_H, si.sra_L, si.sra_M, si.sra_A, // 20 - 2F
    si.sll_B, si.sll_C, si.sll_D, si.sll_E, si.sll_H, si.sll_L, si.sll_M, si.sll_A, si.srl_B, si.srl_C, si.srl_D, si.srl_E, si.srl_H, si.srl_L, si.srl_M, si.srl_A, // 30 - 3F
    bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, // 40 - 4F
    bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, // 50 - 5F
    bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, // 60 - 6F
    bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, bitTest, // 70 - 7F
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // 80 - 8F
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // 90 - 9F
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // A0 - AF
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // B0 - BF
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // C0 - CF
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // D0 - DF
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // E0 - EF
    bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, bitSetReset, // F0 - FF
};

pub fn lookupBitOpcode(self: *Z80) !void {
    const next_opcode = self.memory[self.pc];

    self.pc +%= 1;
    // Increment memory register, but only the lower 7 bits
    self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F);

    if (BitOpcodeTable[next_opcode]) |handler| {
        try handler(self);
    } else {
        std.debug.print("unknown bit opcode: {x}\n", .{next_opcode});
        std.process.exit(1);
    }
}

pub fn lookupIyOpcode(self: *Z80) !void {
    const next_opcode = self.memory[self.pc];

    self.pc +%= 1;
    // Increment memory register, but only the lower 7 bits
    self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F);

    if (IndexYOpcodeTable[next_opcode]) |handler| {
        try handler(self);
    } else {
        std.debug.print("unknown bit opcode: {x}\n", .{next_opcode});
        std.process.exit(1);
    }
}

pub fn lookupIxOpcode(self: *Z80) !void {
    const next_opcode = self.memory[self.pc];

    self.pc +%= 1;
    // Increment memory register, but only the lower 7 bits
    self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F);

    if (IndexXOpcodeTable[next_opcode]) |handler| {
        self.cycle_count += 4;

        try handler(self);
    } else {
        std.debug.print("unknown bit opcode: {x}\n", .{next_opcode});
        std.process.exit(1);
    }
}

fn nop(self: *Z80) !void {
    std.log.debug("[00]\tNOP", .{});
    self.cycle_count += 4;
}

fn di(self: *Z80) !void {
    std.log.debug("[F3]\tDI", .{});
    self.interrupts_enabled = false;
    self.cycle_count += 4;
}

fn halt(self: *Z80) !void {
    std.log.debug("[76]\tHALT", .{});
    self.halted = true;
    self.cycle_count += 4;
}

fn rst24(self: *Z80) !void {
    std.log.debug("[DF]\tRST 24", .{});
    const return_addr = self.pc;
    self.sp -= 2;
    self.memory[self.sp + 1] = @intCast(return_addr >> 8);
    self.memory[self.sp] = @intCast(return_addr & 0xFF);
    self.pc = 24;
    self.cycle_count += 11;
}

fn rst16(self: *Z80) !void {
    std.log.debug("[D7]\tRST 16", .{});
    const return_addr = self.pc;
    self.sp -= 2;
    self.memory[self.sp + 1] = @intCast(return_addr >> 8);
    self.memory[self.sp] = @intCast(return_addr & 0xFF);
    self.pc = 16;
    self.cycle_count += 11;
}

fn rst8(self: *Z80) !void {
    std.log.debug("[CF]\tRST 8", .{});
    const return_addr = self.pc;
    self.sp -= 2;
    self.memory[self.sp + 1] = @intCast(return_addr >> 8);
    self.memory[self.sp] = @intCast(return_addr & 0xFF);
    self.pc = 8;
    self.cycle_count += 11;
}

fn rst0(self: *Z80) !void {
    std.log.debug("[C7]\tRST 0", .{});
    const return_addr = self.pc;
    self.sp -= 2;
    self.memory[self.sp + 1] = @intCast(return_addr >> 8);
    self.memory[self.sp] = @intCast(return_addr & 0xFF);
    self.pc = 0;
    self.cycle_count += 11;
}

// Combine A (high bits) with immediate port_lo (low bits),
// then take only as many bits as needed, e.g. 8-bit port.
fn out(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = (@as(u16, self.register.a) << 8) | @as(u16, data[0]);
    const actual_port: u8 = @intCast(port & 0xFF);

    try self.hardware.out(actual_port, self.register.a);
}

fn in(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = Z80.toUint16(self.register.a, data[0]);
    const actual_port: u8 = @intCast(port & 0xFF);

    const value = try self.hardware.in(actual_port);
    self.register.a = value;
}
