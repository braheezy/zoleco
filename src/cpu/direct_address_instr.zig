const std = @import("std");
const Z80 = @import("Z80.zig");

// SHLD A16: Store register pair HL into 16-bit immediate address.
pub fn store_HL(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    std.log.debug("[22]\tLD  \t${X:<4},HL", .{address});

    self.memory[address] = self.register.l;
    self.memory[address + 1] = self.register.h;
    self.cycle_count += 16;
}

// LHLD A16: Load register pair HL from 16-bit immediate address.
pub fn loadImm_HL(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    std.log.debug("[2A]\tLD  \tHL,${X:<4}", .{address});

    self.register.l = self.memory[address];
    self.register.h = self.memory[address + 1];
    self.cycle_count += 16;
}

// STA A16: Store accumulator in 16-bit immediate address.
pub fn store_A(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    std.log.debug("[32]\tLD  \t${X:<4},A", .{address});
    self.memory[address] = self.register.a;
    self.cycle_count += 13;
}

// LDA A16: Load accumulator from 16-bit immediate address.
pub fn load_A(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    std.log.debug("[3A]\tLD  \tA,${X:<4}", .{address});
    self.register.a = self.memory[address];
    self.cycle_count += 13;
}
