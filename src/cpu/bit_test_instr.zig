const std = @import("std");
const Z80 = @import("Z80.zig");

fn bitTestFlags(self: *Z80, value: u8, bit_index: u3) void {
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
}

pub fn bitTest(self: *Z80) !void {
    const opcode = self.memory[self.pc -% 1];
    const bit_index: u3 = @intCast((opcode >> 3) & 0x07);
    const reg_index = opcode & 0x07;

    const val = switch (reg_index) {
        0 => self.register.b,
        1 => self.register.c,
        2 => self.register.d,
        3 => self.register.e,
        4 => self.register.h,
        5 => self.register.l,
        6 => blk: {
            // BIT n, (HL)
            self.cycle_count +%= 4;
            const addr = (@as(u16, self.register.h) << 8) | @as(u16, self.register.l);
            break :blk self.memory[addr];
        },
        7 => self.register.a,
        else => unreachable,
    };

    bitTestFlags(self, val, bit_index);

    self.cycle_count +%= 8;
}

pub fn bitSetReset(self: *Z80) !void {
    const opcode = self.memory[self.pc -% 1];

    const is_set = opcode >= 0xC0;
    const bit_index = @as(u3, @intCast((opcode >> 3) & 0x07));
    const reg_index = opcode & 0x07;

    var val: u8 = undefined;
    const addr: u16 = (@as(u16, self.register.h) << 8) | @as(u16, self.register.l);

    switch (reg_index) {
        0 => val = self.register.b,
        1 => val = self.register.c,
        2 => val = self.register.d,
        3 => val = self.register.e,
        4 => val = self.register.h,
        5 => val = self.register.l,
        6 => val = self.memory[addr],
        7 => val = self.register.a,
        else => unreachable,
    }

    if (is_set) {
        val |= (@as(u8, 1) << bit_index);
    } else {
        val &= ~(@as(u8, 1) << bit_index);
    }

    switch (reg_index) {
        0 => self.register.b = val,
        1 => self.register.c = val,
        2 => self.register.d = val,
        3 => self.register.e = val,
        4 => self.register.h = val,
        5 => self.register.l = val,
        6 => {
            self.memory[addr] = val;
            self.cycle_count +%= 7;
        },
        7 => self.register.a = val,
        else => unreachable,
    }

    self.cycle_count +%= 8;
}
