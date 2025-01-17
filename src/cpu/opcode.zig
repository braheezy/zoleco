const std = @import("std");
const Z80 = @import("Z80.zig");

const li = @import("load_instr.zig");
const ci = @import("call_instr.zig");
const ji = @import("jump_instr.zig");
const immi = @import("immediate_instr.zig");
const dti = @import("data_transfer_instr.zig");
const rpi = @import("register_pair_instr.zig");
const rsi = @import("register_single_instr.zig");

pub fn getHighByte(value: u16) u8 {
    return @intCast(value >> 8);
}

pub fn getLowByte(value: u16) u8 {
    return @intCast(value & 0xFF);
}

const OpError = error{OutOfBoundsMemory};

pub const OpcodeHandler = *const fn (*Z80) OpError!void;
pub const OpcodeTable = [256]?OpcodeHandler{
    nop, immi.load_BC, dti.stax_B, rpi.inx_B, rsi.inr_B, rsi.dcr_B, immi.moveImm_B, null, null, null, null, null, rsi.inr_C, rsi.dcr_C, immi.moveImm_C, null, // 00 - 0F
    null, immi.load_DE, null, rpi.inx_D, rsi.inr_D, rsi.dcr_D, immi.moveImm_D, null, null, null, null, null, rsi.inr_E, rsi.dcr_E, immi.moveImm_E, null, // 10 - 1F
    null, immi.load_HL, null, rpi.inx_H, rsi.inr_H, rsi.dcr_H, immi.moveImm_H, null, null, null, null, null, rsi.inr_L, rsi.dcr_L, immi.moveImm_L, null, // 20 - 2F
    null, immi.load_SP, null, rpi.inx_SP, rsi.inr_M, rsi.dcr_M, immi.moveImm_M, null, null, null, null, null, rsi.inr_A, rsi.dcr_A, immi.moveImm_A, null, // 30 - 3F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 40 - 4F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 50 - 5F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 60 - 6F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 70 - 7F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 80 - 8F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 90 - 9F
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // A0 - AF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // B0 - BF
    null, null, ji.jump_NZ, ji.jump, ci.call_NZ, li.push_BC, null, null, null, null, ji.jump_Z, null, ci.call_Z, ci.call, null, null, // C0 - CF
    null, null, ji.jump_NC, null, ci.call_NC, li.push_DE, null, null, null, li.exx, ji.jump_C, null, null, ci.call_C, null, null, // D0 - DF
    null, null, ji.jump_PO, null, ci.call_PO, li.push_HL, null, null, null, null, ji.jump_PE, null, ci.call_PE, null, null, null, // E0 - EF
    null, null, ji.jump_P, di, ci.call_P, li.push_AF, null, null, null, null, ji.jump_M, null, ci.call_M, indexAddressY, null, null, // F0 - FF
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

fn nop(self: *Z80) !void {
    std.log.debug("[00]\tNOP", .{});
    self.cycle_count += 4;
}

fn di(self: *Z80) !void {
    std.log.debug("[F3]\tDI", .{});
    self.interrupts_enabled = false;
    self.cycle_count += 4;
}

pub fn indexAddressY(self: *Z80) !void {
    const next_opcode = self.memory[self.pc];
    self.pc += 1;

    if (IndexYOpcodeTable[next_opcode]) |handler| {
        try handler(self);
    } else {
        std.debug.print("unknown IY opcode: {x}\n", .{next_opcode});
        std.process.exit(1);
    }
}
