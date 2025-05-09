const std = @import("std");
const Z80 = @import("../Z80.zig");

// MVI A, D8: Move 8-bit immediate value into accumulator.
pub fn moveImm_A(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.a = data[0];
    self.q = 0;
}

// MVI B, D8: Move 8-bit immediate value into register B.
pub fn moveImm_B(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.b = data[0];
    self.q = 0;
}

// MVI C, D8: Move 8-bit immediate value into register C.
pub fn moveImm_C(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.c = data[0];
    self.q = 0;
}

// MVI D, D8: Move 8-bit immediate value into register L.
pub fn moveImm_D(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.d = data[0];
    self.q = 0;
}

// MVI E, D8: Move 8-bit immediate value into register E.
pub fn moveImm_E(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.e = data[0];
    self.q = 0;
}

// MVI H, D8: Move 8-bit immediate value into register H.
pub fn moveImm_H(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.h = data[0];
    self.q = 0;
}

// MVI L, D8: Move 8-bit immediate value into register L.
pub fn moveImm_L(self: *Z80) !void {
    const data = try self.fetchData(1);

    self.register.l = data[0];
    self.q = 0;
}

// MVI M: Move 8-bit immediate value into memory address from register pair HL
pub fn moveImm_M(self: *Z80) !void {
    const data = try self.fetchData(1);

    const address = self.getHL();
    self.io.writeMemory(self.io.ctx, address, data[0]);
    self.q = 0;
}

// LXI B, D16: Load 16-bit immediate value into register pair B.
pub fn load_BC(self: *Z80) !void {
    const data = try self.fetchData(2);

    self.register.c = data[0];
    self.register.b = data[1];
    self.q = 0;
}

// LXI D, D16: Load 16-bit immediate value into register pair D.
pub fn load_DE(self: *Z80) !void {
    const data = try self.fetchData(2);

    self.register.e = data[0];
    self.register.d = data[1];
    self.q = 0;
}

// LXI H, D16: Load 16-bit immediate value into register pair H.
pub fn load_HL(self: *Z80) !void {
    const data = try self.fetchData(2);

    self.register.l = data[0];
    self.register.h = data[1];
    self.q = 0;
}

// LXI SP, D16: Load 16-bit immediate value into register pair SP.
pub fn load_SP(self: *Z80) !void {
    const data = try self.fetchData(2);
    const operand = Z80.toUint16(data[1], data[0]);

    self.sp = operand;
    self.q = 0;
}
