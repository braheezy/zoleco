const std = @import("std");
const Z80 = @import("../Z80.zig");
const rpi = @import("register_pair_instr.zig");

fn _call(self: *Z80, jump_address: u16) void {
    const returnAddress = self.pc;
    rpi.push(self, @as(u8, @intCast(returnAddress & 0xFF)), @as(u8, @intCast(returnAddress >> 8)));
    self.pc = jump_address;
    self.cycle_count += 17;
}

pub fn call(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);

    _call(self, jump_address);
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_NZ(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (!self.flag.zero) {
        _call(self, jump_address);
    } else {
        self.cycle_count += 10;
    }
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_Z(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (self.flag.zero) {
        _call(self, jump_address);
    } else {
        self.cycle_count += 10;
    }
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_C(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (self.flag.carry) {
        _call(self, jump_address);
    } else {
        self.cycle_count += 10;
    }
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_NC(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (!self.flag.carry) {
        _call(self, jump_address);
    } else {
        self.cycle_count += 10;
    }
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_P(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (!self.flag.sign) {
        _call(self, jump_address);
    }
    self.cycle_count += 10;
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_M(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (self.flag.sign) {
        _call(self, jump_address);
    }

    self.cycle_count += 10;
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_PO(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (!self.flag.parity_overflow) {
        _call(self, jump_address);
    }
    self.cycle_count += 10;
    self.wz = jump_address;
    self.q = 0;
}

pub fn call_PE(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    if (self.flag.parity_overflow) {
        _call(self, jump_address);
    }
    self.cycle_count += 10;
    self.wz = jump_address;
    self.q = 0;
}
