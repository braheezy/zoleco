const std = @import("std");
const Z80 = @import("Z80.zig");
const li = @import("load_instr.zig");

fn _call(self: *Z80, jumpAddress: u16) void {
    const returnAddress = self.pc + 2;
    try li.push(self, @as(u8, @intCast(returnAddress & 0xFF)), @as(u8, @intCast(returnAddress >> 8)));
    self.pc = jumpAddress;
    self.cycle_count += 17;
}

pub fn call(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    std.log.debug("[CD]\tCALL\t${X:<4}", .{jump_address});
    _call(self, jump_address);
}

pub fn call_NZ(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flag.zero) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[C4]\tCALL\tNZ,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[C4]\tCALL\tNZ,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_Z(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flag.zero) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[CC]\tCALL\tZ,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[CC]\tCALL\tZ,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_C(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flag.carry) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[DC]\tCALL\tC,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[DC]\tCALL\tC,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_NC(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flag.carry) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[D4]\tCALL\tNC,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[D4]\tCALL\tNC,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_P(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flag.sign) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[F4]\tCALL\tP,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[F4]\tCALL\tP,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_M(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flag.sign) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[FC]\tCALL\tM,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[FC]\tCALL\tM,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_PO(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (!self.flag.parity_overflow) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[E4]\tCALL\tPO,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[E4]\tCALL\tPO,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}

pub fn call_PE(self: *Z80) !void {
    const data = try self.fetchData(2);
    if (self.flag.parity_overflow) {
        const jump_address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[EC]\tCALL\tPE,${X:<4}", .{jump_address});
        _call(self, jump_address);
    } else {
        std.log.debug("[EC]\tCALL\tPE,${X:<4} (not taken)", .{self.pc + 2});
        self.pc += 2;
        self.cycle_count += 10;
    }
}
