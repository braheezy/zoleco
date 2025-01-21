const std = @import("std");
const Z80 = @import("Z80.zig");

// return helper
pub fn _ret(self: *Z80) void {
    const address = Z80.toUint16(self.memory[self.sp + 1], self.memory[self.sp]);
    self.pc = address;
    self.sp += 2;
    self.cycle_count += 11;
}

// RET: Return from subroutine.
pub fn ret(self: *Z80) !void {
    _ret(self);
    std.log.debug("[C9]\tRET \t($%04X)", .{self.pc});
    self.cycle_count += 10;
}

// RZ: Return from subroutine if Z flag is set.
pub fn ret_Z(self: *Z80) !void {
    if (self.flag.zero) {
        _ret(self);
        std.log.debug("[C8]\tRET \tZ($%04X)", .{self.pc});
    } else {
        std.log.debug("[C8]\tRET \tZ (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RNZ: Return from subroutine if Z flag is not set.
pub fn ret_NZ(self: *Z80) !void {
    if (!self.flag.zero) {
        _ret(self);
        std.log.debug("[C0]\tRET \tNZ($%04X)", .{self.pc});
    } else {
        std.log.debug("[C0]\tRET \tNZ (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RC: Return from subroutine if C flag is set.
pub fn ret_C(self: *Z80) !void {
    if (self.flag.carry) {
        _ret(self);
        std.log.debug("[D8]\tRET \tC($%04X)", .{self.pc});
    } else {
        std.log.debug("[D8]\tRET \tC (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RNC: Return from subroutine if C flag is not set.
pub fn ret_NC(self: *Z80) !void {
    if (!self.flag.carry) {
        _ret(self);
        std.log.debug("[D0]\tRET \tNC($%04X)", .{self.pc});
    } else {
        std.log.debug("[D0]\tRET \tNC (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RPE: Return from subroutine if parity even (is set)
pub fn ret_PE(self: *Z80) !void {
    if (self.flag.parity_overflow) {
        _ret(self);
        std.log.debug("[E8]\tRET \tPE($%04X)", .{self.pc});
    } else {
        std.log.debug("[E8]\tRET \tPE (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RPO: Return from subroutine if parity odd (is not set)
pub fn ret_PO(self: *Z80) !void {
    if (!self.flag.parity_overflow) {
        _ret(self);
        std.log.debug("[E0]\tRET \tPO($%04X)", .{self.pc});
    } else {
        std.log.debug("[E0]\tRET \tPO (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RP: Return from subroutine if plus (sign is not set)
pub fn ret_P(self: *Z80) !void {
    if (!self.flag.sign) {
        _ret(self);
        std.log.debug("[F0]\tRET \tP($%04X)", .{self.pc});
    } else {
        std.log.debug("[F0]\tRET \tP (not taken)", .{});
        self.cycle_count += 5;
    }
}

// RP: Return from subroutine if minus (sign is set)
pub fn ret_M(self: *Z80) !void {
    if (self.flag.sign) {
        _ret(self);
        std.log.debug("[F8]\tRET \tM($%04X)", .{self.pc});
    } else {
        std.log.debug("[F8]\tRET \tM (not taken)", .{});
        self.cycle_count += 5;
    }
}
