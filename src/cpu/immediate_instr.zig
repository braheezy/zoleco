const std = @import("std");
const Z80 = @import("Z80.zig");

// MVI A, D8: Move 8-bit immediate value into accumulator.
pub fn moveImm_A(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[3E]\tLD  \tA,${X:<2}", .{data[0]});
    self.register.a = data[0];
    self.cycle_count += 7;
}

// MVI B, D8: Move 8-bit immediate value into register B.
pub fn moveImm_B(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[06]\tLD  \tB,${X:<2}", .{data[0]});
    self.register.b = data[0];
    self.cycle_count += 7;
}

// MVI C, D8: Move 8-bit immediate value into register C.
pub fn moveImm_C(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[0E]\tLD  \tC,${X:<2}", .{data[0]});
    self.register.c = data[0];
    self.cycle_count += 7;
}

// MVI D, D8: Move 8-bit immediate value into register L.
pub fn moveImm_D(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[16]\tLD  \tD,${X:<2}", .{data[0]});
    self.register.d = data[0];
    self.cycle_count += 7;
}

// MVI E, D8: Move 8-bit immediate value into register E.
pub fn moveImm_E(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[1E]\tLD  \tE,${X:<2}", .{data[0]});
    self.register.e = data[0];
    self.cycle_count += 7;
}

// MVI H, D8: Move 8-bit immediate value into register H.
pub fn moveImm_H(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[26]\tLD  \tH,${X:<2}", .{data[0]});
    self.register.h = data[0];
    self.cycle_count += 7;
}

// MVI L, D8: Move 8-bit immediate value into register L.
pub fn moveImm_L(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[2E]\tLD  \tL,${X:<2}", .{data[0]});
    self.register.l = data[0];
    self.cycle_count += 7;
}

// MVI M: Move 8-bit immediate value into memory address from register pair HL
pub fn moveImm_M(self: *Z80) !void {
    const data = try self.fetchData(1);
    std.log.debug("[36]\tLD  \t(HL),${X:<2}", .{data[0]});
    const address = Z80.toUint16(self.register.h, self.register.l);
    self.memory[address] = data[0];
    self.cycle_count += 10;
}
