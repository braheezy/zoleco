const std = @import("std");
const Z80 = @import("Z80.zig");

pub fn jump(self: *Z80) !void {
    const data = try self.fetchData(2);
    const jump_address = Z80.toUint16(data[1], data[0]);
    std.log.debug("[C3]\tJMP \t${X:<4}", .{jump_address});
    self.pc = jump_address;
    self.cycle_count += 10;
}

// JNZ addr: Jump if not zero.
pub fn jump_NZ(self: *Z80) !void {
    if (!self.flag.zero) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[C2]\tJP  \tNZ,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[C2]\tJP  \tNZ,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JZ addr: Jump if zero.
pub fn jump_Z(self: *Z80) !void {
    if (self.flag.zero) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[CA]\tJP  \tZ,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[CA]\tJP  \tZ,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JNC addr: Jump if not carry.
pub fn jump_NC(self: *Z80) !void {
    if (!self.flag.carry) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[D2]\tJP  \tNC,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[D2]\tJP  \tNC,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JC addr: Jump if carry.
pub fn jump_C(self: *Z80) !void {
    if (self.flag.carry) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[DA]\tJP  \tC,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[DA]\tJP  \tC,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JM addr: Jump if minus.
pub fn jump_M(self: *Z80) !void {
    if (self.flag.sign) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[FA]\tJP  \tM,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[FA]\tJP  \tM,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JPE addr: Jump if parity is even.
pub fn jump_PE(self: *Z80) !void {
    if (self.flag.parity_overflow) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[EA]\tJP  \tPE,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[EA]\tJP  \tPE,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JPO addr: Jump if parity is odd.
pub fn jump_PO(self: *Z80) !void {
    if (!self.flag.parity_overflow) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[E2]\tJP  \tPO,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[E2]\tJP  \tPO,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}

// JP addr: Jump if plus (sign bit is not set).
pub fn jump_P(self: *Z80) !void {
    if (!self.flag.sign) {
        const data = try self.fetchData(2);
        const address = Z80.toUint16(data[1], data[0]);
        std.log.debug("[F2]\tJP  \tP,${X:<4}", .{address});
        self.pc = address;
    } else {
        std.log.debug("[F2]\tJP  \tP,${X:<4}", .{self.pc + 2});
        self.pc += 2;
    }
    self.cycle_count += 10;
}
