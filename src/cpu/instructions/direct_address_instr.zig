const std = @import("std");
const Z80 = @import("../Z80.zig");

// SHLD A16: Store register pair HL into 16-bit immediate address.
pub fn store_HL(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    self.memory[address] = self.register.l;
    self.memory[address + 1] = self.register.h;
    self.q = 0;
    self.wz = address +% 1;
}

// LHLD A16: Load register pair HL from 16-bit immediate address.
pub fn loadImm_HL(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    self.register.l = self.memory[address];
    self.register.h = self.memory[address + 1];
    self.q = 0;
    self.wz = address +% 1;
}

// STA A16: Store accumulator in 16-bit immediate address.
pub fn store_A(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    self.memory[address] = self.register.a;
    self.q = 0;
    self.wz = (@as(u16, self.register.a) << 8) | (@as(u16, address +% 1 & 0xFF));
}

// LDA A16: Load accumulator from 16-bit immediate address.
pub fn load_A(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    self.register.a = self.memory[address];
    self.wz = address +% 1;
    self.q = 0;
}
