const std = @import("std");
const Z80 = @import("Z80.zig");

// Combine A (high bits) with immediate port_lo (low bits),
// then take only as many bits as needed, e.g. 8-bit port.
pub fn out(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = (@as(u16, self.register.a) << 8) | @as(u16, data[0]);
    const actual_port: u8 = @intCast(port & 0xFF);

    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, actual_port +% 1));

    try self.hardware.out(actual_port, self.register.a);
    self.q = 0;
    self.cycle_count += 11;
}

pub fn in(self: *Z80) !void {
    const data = try self.fetchData(1);
    const port = Z80.toUint16(self.register.a, data[0]);
    const actual_port: u8 = @intCast(port & 0xFF);

    const value = try self.hardware.in(actual_port);
    self.register.a = value;

    self.wz = port +% 1;
    self.q = 0;
    self.cycle_count += 11;
}

// A byte from the port at the 16-bit address contained in the BC register pair is written to B.
pub fn in_B(self: *Z80) !void {
    const data = self.memory[self.pc];
    const port = Z80.toUint16(self.register.b, data);
    const actual_port: u8 = @intCast(port & 0xFF);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;

    const value = try self.hardware.in(actual_port);
    self.register.b = value;

    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.parity_overflow = Z80.parity(u8, self.register.b);
    self.flag.setS(self.register.b);
    self.flag.setZ(self.register.b);
    self.flag.setUndocumentedFlags(self.register.b);
    self.q = self.flag.toByte();

    self.cycle_count += 12;
}
pub fn in_C(self: *Z80) !void {
    const data = self.memory[self.pc];
    const port = Z80.toUint16(self.register.c, data);
    const actual_port: u8 = @intCast(port & 0xFF);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;

    const value = try self.hardware.in(actual_port);
    self.register.c = value;

    self.flag.half_carry = false;
    self.flag.add_subtract = false;
    self.flag.parity_overflow = Z80.parity(u8, self.register.c);
    self.flag.setS(self.register.c);
    self.flag.setZ(self.register.c);
    self.flag.setUndocumentedFlags(self.register.c);
    self.q = self.flag.toByte();

    self.cycle_count += 12;
}

// The value of B is written to the port at the 16-bit address contained in the BC register pair.
pub fn out_B(self: *Z80) !void {
    const data = self.memory[self.pc];
    const port = Z80.toUint16(self.register.b, data);
    const actual_port: u8 = @intCast(port & 0xFF);

    try self.hardware.out(actual_port, self.register.b);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    self.q = 0;
    self.cycle_count += 12;
}

pub fn out_C(self: *Z80) !void {
    const data = self.memory[self.pc];
    const port = Z80.toUint16(self.register.c, data);
    const actual_port: u8 = @intCast(port & 0xFF);

    try self.hardware.out(actual_port, self.register.c);
    self.wz = Z80.toUint16(self.register.b, self.register.c) +% 1;
    self.q = 0;
    self.cycle_count += 12;
}
