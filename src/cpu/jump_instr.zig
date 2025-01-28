const std = @import("std");
const Z80 = @import("Z80.zig");

pub fn jump(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);

    self.pc = jump_address;
    self.cycle_count += 10;
}

// JNZ addr: Jump if not zero.
pub fn jump_NZ(self: *Z80) !void {
    if (!self.flag.zero) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JZ addr: Jump if zero.
pub fn jump_Z(self: *Z80) !void {
    if (self.flag.zero) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JNC addr: Jump if not carry.
pub fn jump_NC(self: *Z80) !void {
    if (!self.flag.carry) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JC addr: Jump if carry.
pub fn jump_C(self: *Z80) !void {
    if (self.flag.carry) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JM addr: Jump if minus.
pub fn jump_M(self: *Z80) !void {
    if (self.flag.sign) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JPE addr: Jump if parity is even.
pub fn jump_PE(self: *Z80) !void {
    if (self.flag.parity_overflow) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JPO addr: Jump if parity is odd.
pub fn jump_PO(self: *Z80) !void {
    if (!self.flag.parity_overflow) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JP addr: Jump if plus (sign bit is not set).
pub fn jump_P(self: *Z80) !void {
    if (!self.flag.sign) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);

        self.pc = address;
    } else {
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// DJNZ addr: Decrement B and jump if not zero.
pub fn djnz(self: *Z80) !void {
    // Decrement register B
    self.register.b -%= 1;

    if (self.register.b != 0) {
        self.pc +%= Z80.signedByte(self.memory[self.pc]);

        self.cycle_count += 13;
    } else {
        self.cycle_count += 8;
    }
    self.pc += 1;
}

fn jump_relative(self: *Z80, displacement: u8) void {
    // Add displacement to PC for unconditional jump
    self.pc +%= Z80.signedByte(displacement);
    self.pc += 1;

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
}

// JRZ: If the zero flag is set, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_Z(self: *Z80) !void {
    if (self.flag.zero) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
}

// JRNC: If the carry flag is unset, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_NC(self: *Z80) !void {
    if (!self.flag.carry) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
}

// JRC: If the carry flag is set, the signed value d is added to PC. The jump is measured from the start of the instruction opcode.
pub fn jr_C(self: *Z80) !void {
    if (self.flag.carry) {
        jump_relative(self, self.memory[self.pc]);
    } else {
        self.pc += 1;
        self.cycle_count += 7;
    }
}
