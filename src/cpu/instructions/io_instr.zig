const std = @import("std");
const Z80 = @import("../Z80.zig");

// OUT (n),A: Output the value of A to port n
pub fn out(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = data[0]; // Use immediate byte as port number

    try self.bus.out(port, self.register.a);

    // WZ = (A << 8) | ((n + 1) & 0xFF)
    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, (port +% 1) & 0xFF));
    self.q = 0;
}

// IN A,(n): Input to A from port n
pub fn in(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = data[0]; // Use immediate byte as port number

    const value = try self.bus.in(port);
    self.register.a = value;

    // WZ = (A << 8) | ((n + 1) & 0xFF)
    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, (port +% 1) & 0xFF));
    self.q = 0;
}

fn in_reg(self: *Z80) !u8 {
    const data = self.memory[self.pc];
    const port: u8 = data;

    const value = try self.bus.in(port);

    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.parity_overflow = Z80.parity(u8, value);
    self.flag.setS(value);
    self.flag.setZ(value);
    self.flag.setUndocumentedFlags(value);
    self.q = self.flag.toByte();

    // WZ = BC + 1
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;

    return value;
}

// A byte from the port whose address is formed by A in the high bits and n in the low bits is written to A.
pub fn in_B(self: *Z80) !void {
    self.register.b = try in_reg(self);
}
pub fn in_C(self: *Z80) !void {
    self.register.c = try in_reg(self);
}
pub fn in_D(self: *Z80) !void {
    self.register.d = try in_reg(self);
}
pub fn in_E(self: *Z80) !void {
    self.register.e = try in_reg(self);
}
pub fn in_H(self: *Z80) !void {
    self.register.h = try in_reg(self);
}
pub fn in_L(self: *Z80) !void {
    self.register.l = try in_reg(self);
}
pub fn in_A(self: *Z80) !void {
    self.register.a = try in_reg(self);
}
// Inputs a byte from the port at the 16-bit address contained in the BC register pair and affects flags only.
pub fn in_BC(self: *Z80) !void {
    _ = try in_reg(self);
}
fn out_reg(self: *Z80, reg: u8) !void {
    const data = self.memory[self.pc];
    const port: u8 = data;

    try self.bus.out(port, reg);
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
    try self.bus.out(@intCast(self.register.c), 0);

    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    self.q = 0;
}
