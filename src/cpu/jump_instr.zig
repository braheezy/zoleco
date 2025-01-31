const std = @import("std");
const Z80 = @import("Z80.zig");

pub fn jump(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);

    self.pc = jump_address;
    self.wz = jump_address;
    self.cycle_count += 10;
    self.q = 0;
}

// JNZ addr: Jump if not zero.
pub fn jump_NZ(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    if (!self.flag.zero) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JZ addr: Jump if zero.
pub fn jump_Z(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    if (self.flag.zero) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JNC addr: Jump if not carry.
pub fn jump_NC(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    if (!self.flag.carry) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JC addr: Jump if carry.
pub fn jump_C(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    if (self.flag.carry) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JM addr: Jump if minus.
pub fn jump_M(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    if (self.flag.sign) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JPE addr: Jump if parity is even.
pub fn jump_PE(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    if (self.flag.parity_overflow) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JPO addr: Jump if parity is odd.
pub fn jump_PO(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    if (!self.flag.parity_overflow) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// JP addr: Jump if plus (sign bit is not set).
pub fn jump_P(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    if (!self.flag.sign) {
        self.pc = address;
    }
    self.wz = address;
    self.cycle_count += 10;
    self.q = 0;
}

// DJNZ addr: Decrement B and jump if not zero.
pub fn djnz(self: *Z80) !void {
    // Decrement register B
    self.register.b -%= 1;

    if (self.register.b != 0) {
        const displacement = Z80.signedByte(self.memory[self.pc]);
        const new_pc = self.pc +% displacement;
        self.wz = new_pc +% 1;
        self.pc = new_pc;

        self.cycle_count += 13;
    } else {
        self.cycle_count += 8;
    }
    self.pc += 1;
    self.q = 0;
}

fn jump_relative(self: *Z80, displacement: u8) void {
    // Add displacement to PC for unconditional jump
    self.pc +%= Z80.signedByte(displacement);
    self.pc += 1;
    self.wz = self.pc;
    self.q = 0;

    self.cycle_count += 12;
}
// JR d: Jump relative by signed displacement d.
pub fn jr(self: *Z80) !void {
    jump_relative(self, self.memory[self.pc]);
}

// JRNZ: If the zero flag is unset, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_NZ(self: *Z80) !void {
    if (!self.flag.zero) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
    self.q = 0;
}

// JRZ: If the zero flag is set, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_Z(self: *Z80) !void {
    if (self.flag.zero) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
    self.q = 0;
}

// JRNC: If the carry flag is unset, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_NC(self: *Z80) !void {
    if (!self.flag.carry) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
    self.q = 0;
}

// JRC: If the carry flag is set, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_C(self: *Z80) !void {
    if (self.flag.carry) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
    self.q = 0;
}

// Loads the value of HL into PC.
pub fn jp_HL(self: *Z80) !void {
    const hl = self.getHL();
    self.pc = hl;
    self.cycle_count += 4;
    self.q = 0;
}

// Loads the value of IX into PC.
pub fn jp_IX(self: *Z80) !void {
    self.pc = self.curr_index_reg.?.*;
    self.cycle_count += 4;
    self.q = 0;
}
