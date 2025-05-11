const std = @import("std");
const Z80 = @import("../Z80.zig");

// OUT (n),A: Output the value of A to port n
pub fn out(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = data[0]; // Use immediate byte as port number

    try self.io.writePort(self.io.ctx, port, self.register.a);

    // WZ = (A << 8) | ((n + 1) & 0xFF)
    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, (port +% 1) & 0xFF));
    self.q = 0;
}

// IN A,(n): Input to A from port n
pub fn in(self: *Z80) !void {
    if (self.input_last_cycle) {
        const data = try self.fetchData(1);
        const port = Z80.toUint16(self.register.a, data[0]);
        const actual_port: u8 = @intCast(port & 0xFF);

        const value = self.io.readPort(self.io.ctx, actual_port);
        self.register.a = value;

        self.wz = port +% 1;
        self.q = 0;

        self.input_last_cycle = false;
    } else {
        self.pc -= 1;
        self.cycle_count -= 11;
        self.input_last_cycle = true;
    }
}

fn in_reg(self: *Z80, reg: u8) u8 {
    const data = self.io.readMemory(self.io.ctx, self.pc);
    const port = Z80.toUint16(reg, data);
    const actual_port: u8 = @intCast(port & 0xFF);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;

    const value = self.io.readPort(self.io.ctx, actual_port);

    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.parity_overflow = Z80.parity(u8, value);
    self.flag.setS(value);
    self.flag.setZ(value);
    self.flag.setUndocumentedFlags(value);
    self.q = self.flag.toByte();

    // self.cycle_count += 12;
    return value;
}

// A byte from the port at the 16-bit address contained in the BC register pair is written to B.
pub fn in_B(self: *Z80) !void {
    self.register.b = in_reg(self, self.register.b);
}
pub fn in_C(self: *Z80) !void {
    self.register.c = in_reg(self, self.register.c);
}
pub fn in_D(self: *Z80) !void {
    self.register.d = in_reg(self, self.register.d);
}
pub fn in_E(self: *Z80) !void {
    self.register.e = in_reg(self, self.register.e);
}
pub fn in_H(self: *Z80) !void {
    self.register.h = in_reg(self, self.register.h);
}
pub fn in_L(self: *Z80) !void {
    self.register.l = in_reg(self, self.register.l);
}
pub fn in_A(self: *Z80) !void {
    self.register.a = in_reg(self, self.register.a);
}
// Inputs a byte from the port at the 16-bit address contained in the BC register pair and affects flags only.
pub fn in_BC(self: *Z80) !void {
    _ = in_reg(self, self.register.b);
}
fn out_reg(self: *Z80, reg: u8) !void {
    const data = self.io.readMemory(self.io.ctx, self.pc);
    const port: u8 = data;

    try self.io.writePort(self.io.ctx, port, reg);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    self.q = 0;
}

// The value of B is written to the port at the 16-bit address contained in the BC register pair.
pub fn out_B(self: *Z80) !void {
    try out_reg(self, self.register.b);
}
pub fn out_C(self: *Z80) !void {
    try out_reg(self, self.register.c);
}
pub fn out_D(self: *Z80) !void {
    try out_reg(self, self.register.d);
}
pub fn out_E(self: *Z80) !void {
    try out_reg(self, self.register.e);
}
pub fn out_H(self: *Z80) !void {
    try out_reg(self, self.register.h);
}
pub fn out_L(self: *Z80) !void {
    try out_reg(self, self.register.l);
}
pub fn out_A(self: *Z80) !void {
    try out_reg(self, self.register.a);
}

pub fn out_BC(self: *Z80) !void {
    // For NMOS Z80 (used in ColecoVision), output 0
    try self.io.writePort(self.io.ctx, @intCast(self.register.c), 0);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    self.q = 0;
}
