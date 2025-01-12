const std = @import("std");
const Z80 = @import("Z80.zig");
const li = @import("load_instr.zig");

fn _call(self: *Z80, jumpAddress: u16) void {
    const returnAddress = self.pc + 2;
    try li.push(self, @as(u8, @intCast(returnAddress & 0xFF)), @as(u8, @intCast(returnAddress >> 8)));
    self.pc = jumpAddress;
}

fn toUint16(high: u8, low: u8) u16 {
    return @as(u16, @intCast(high)) << 8 | @as(u16, @intCast((low)));
}

pub fn call(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jumpAddress = toUint16(data[1], data[0]);

    _call(self, jumpAddress);
}

pub fn call_NZ(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flags.zero) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_Z(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flags.zero) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_C(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flags.carry) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_NC(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flags.carry) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_P(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flags.sign) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_M(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flags.sign) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_PO(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flags.parity_overflow) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}

pub fn call_PE(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flags.parity_overflow) {
        const jumpAddress = toUint16(data[1], data[0]);

        _call(self, jumpAddress);
    } else {
        self.pc += 2;
    }
}
