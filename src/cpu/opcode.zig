const std = @import("std");
const Z80 = @import("Z80.zig");

const load_instr = @import("load_instr.zig");

pub fn getHighByte(value: u16) u8 {
    return @intCast(value >> 8);
}

pub fn getLowByte(value: u16) u8 {
    return @intCast(value & 0xFF);
}

pub const OpcodeHandler = *const fn (*Z80) void;
pub const OpcodeTable = [256]?OpcodeHandler{
    nop, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // 00 - 0F
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
    null, null, null, di, null, null, null, null, null, null, null, null, null, indexAddressY, null, null, // F0 - FF
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
    null, null, null, null, null, load_instr.pushIy, null, null, null, null, null, null, null, null, null, null, // E0 - EF
    null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, // F0 - FF
};

fn nop(self: *Z80) void {
    self.cycle_count += 4;
}

fn di(self: *Z80) void {
    self.interrupts_enabled = false;
    self.cycle_count += 4;
}

pub fn indexAddressY(self: *Z80) void {
    const next_opcode = self.memory[self.pc];
    self.pc += 1;

    if (IndexYOpcodeTable[next_opcode]) |handler| {
        handler(self);
    } else {
        std.debug.print("unknown IY opcode: {x}\n", .{next_opcode});
        std.process.exit(1);
    }
}
