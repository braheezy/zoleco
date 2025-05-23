const std = @import("std");
const Z80 = @import("../Z80.zig");

const getHighByte = @import("util.zig").getHighByte;

fn bitTestFlags(self: *Z80, value: u8, bit_index: u3, xy_src: u8, reg_index: u3) void {
    const mask = @as(u8, 1) << bit_index;
    const is_set = (value & mask) != 0;

    // Z set if bit is 0, reset otherwise
    self.flag.zero = !is_set;

    // P/V matches Z for BIT instructions
    self.flag.parity_overflow = !is_set;

    // H is always set
    self.flag.half_carry = true;

    // N is always reset
    self.flag.add_subtract = false;

    // S is set only if we tested bit 7 and it's set
    self.flag.sign = bit_index == 7 and is_set;

    // Carry flag is unaffected

    if (self.curr_index_reg != null) {
        // For BIT n,(IX+d)/(IY+d), X and Y come from high byte of IX+d/IY+d
        self.flag.x = (xy_src & 0x08) != 0;
        self.flag.y = (xy_src & 0x20) != 0;
    } else if (reg_index == 6) {
        // For BIT n,(HL), X and Y come from the internal register (Q)
        self.flag.x = (self.wz & 0x0800) != 0;
        self.flag.y = (self.wz & 0x2000) != 0;
    } else {
        // For BIT n,r (non-HL, non-indexed), X and Y come from the tested register
        self.flag.x = (value & 0x08) != 0; // bit 3 of register K
        self.flag.y = (value & 0x20) != 0; // bit 5 of register K
    }

    self.q = self.flag.toByte();
}

pub fn bitTest(self: *Z80) !void {
    const opcode = self.io.readMemory(self.io.ctx, self.pc -% 1);
    const bit_index: u3 = @intCast((opcode >> 3) & 0x07);
    const reg_index = opcode & 0x07;

    var val: u8 = undefined;
    var xy_src: u8 = undefined;

    if (self.curr_index_reg != null) {
        // For DD CB / FD CB opcodes, we've already read the displacement
        const addr = self.getDisplacedAddress(self.displacement);
        // Set WZ (MEMPTR) to IX+d/IY+d for indexed instructions
        self.wz = addr;
        val = self.io.readMemory(self.io.ctx, addr);
        // For indexed instructions, xy flags come from high byte of final address
        xy_src = @intCast(addr >> 8);
    } else {
        val = switch (reg_index) {
            0 => self.register.b,
            1 => self.register.c,
            2 => self.register.d,
            3 => self.register.e,
            4 => self.register.h,
            5 => self.register.l,
            6 => blk: {
                const addr = (@as(u16, self.register.h) << 8) | @as(u16, self.register.l);
                // For non-indexed memory access (HL), WZ is not affected
                break :blk self.io.readMemory(self.io.ctx, addr);
            },
            7 => self.register.a,
            else => unreachable,
        };
        // For non-indexed instructions, xy flags depend on bit_index and result
        xy_src = val;
    }

    bitTestFlags(self, val, bit_index, xy_src, @intCast(reg_index));
}

pub fn bitSetReset(self: *Z80) !void {
    const opcode = self.io.readMemory(self.io.ctx, self.pc -% 1);
    const is_set = opcode >= 0xC0;
    const bit_index = @as(u3, @intCast((opcode >> 3) & 0x07));
    const reg_index = opcode & 0x07;
    self.q = 0;

    var val: u8 = undefined;
    var result: u8 = undefined;

    if (self.curr_index_reg != null) {
        // For DD CB / FD CB opcodes, we've already read the displacement
        const addr = self.getDisplacedAddress(self.displacement);
        // Set WZ (MEMPTR) to IX+d/IY+d for indexed instructions
        self.wz = addr;
        val = self.io.readMemory(self.io.ctx, addr);

        if (is_set) {
            result = val | (@as(u8, 1) << bit_index);
        } else {
            result = val & ~(@as(u8, 1) << bit_index);
        }

        // Always write result to memory for indexed operations
        self.io.writeMemory(self.io.ctx, addr, result);

        // For DD/FD CB opcodes, also store result in target register
        switch (reg_index) {
            0 => self.register.b = result,
            1 => self.register.c = result,
            2 => self.register.d = result,
            3 => self.register.e = result,
            4 => self.register.h = result,
            5 => self.register.l = result,
            6 => {}, // For (HL), we've already written to memory
            7 => self.register.a = result,
            else => unreachable,
        }
    } else {
        // Original non-indexed behavior remains unchanged
        val = switch (reg_index) {
            0 => self.register.b,
            1 => self.register.c,
            2 => self.register.d,
            3 => self.register.e,
            4 => self.register.h,
            5 => self.register.l,
            6 => blk: {
                const addr = (@as(u16, self.register.h) << 8) | @as(u16, self.register.l);
                break :blk self.io.readMemory(self.io.ctx, addr);
            },
            7 => self.register.a,
            else => unreachable,
        };

        if (is_set) {
            result = val | (@as(u8, 1) << bit_index);
        } else {
            result = val & ~(@as(u8, 1) << bit_index);
        }

        switch (reg_index) {
            0 => self.register.b = result,
            1 => self.register.c = result,
            2 => self.register.d = result,
            3 => self.register.e = result,
            4 => self.register.h = result,
            5 => self.register.l = result,
            6 => {
                const addr = (@as(u16, self.register.h) << 8) | @as(u16, self.register.l);
                self.io.writeMemory(self.io.ctx, addr, result);
            },
            7 => self.register.a = result,
            else => unreachable,
        }
    }
}
