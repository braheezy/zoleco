const std = @import("std");
const Z80 = @import("../Z80.zig");

// return helper
pub fn _ret(self: *Z80) void {
    const address = Z80.toUint16(self.memory[self.sp + 1], self.memory[self.sp]);
    self.pc = address;
    self.sp += 2;
    self.cycle_count += 6;
    self.wz = address;
    self.q = 0;
}

// RET: Return from subroutine.
pub fn ret(self: *Z80) !void {
    _ret(self);
}

// RZ: Return from subroutine if Z flag is set.
pub fn ret_Z(self: *Z80) !void {
    if (self.flag.zero) {
        _ret(self);
    }
    self.q = 0;
}

// RNZ: Return from subroutine if Z flag is not set.
pub fn ret_NZ(self: *Z80) !void {
    if (!self.flag.zero) {
        _ret(self);
    }
    self.q = 0;
}

// RC: Return from subroutine if C flag is set.
pub fn ret_C(self: *Z80) !void {
    if (self.flag.carry) {
        _ret(self);
    }
    self.q = 0;
}

// RNC: Return from subroutine if C flag is not set.
pub fn ret_NC(self: *Z80) !void {
    if (!self.flag.carry) {
        _ret(self);
    }
    self.q = 0;
}

// RPE: Return from subroutine if parity even (is set)
pub fn ret_PE(self: *Z80) !void {
    if (self.flag.parity_overflow) {
        _ret(self);
    }
    self.q = 0;
}

// RPO: Return from subroutine if parity odd (is not set)
pub fn ret_PO(self: *Z80) !void {
    if (!self.flag.parity_overflow) {
        _ret(self);
    }
    self.q = 0;
}

// RP: Return from subroutine if plus (sign is not set)
pub fn ret_P(self: *Z80) !void {
    if (!self.flag.sign) {
        _ret(self);
    }
    self.q = 0;
}

// RP: Return from subroutine if minus (sign is set)
pub fn ret_M(self: *Z80) !void {
    if (self.flag.sign) {
        _ret(self);
    }
    self.q = 0;
}
