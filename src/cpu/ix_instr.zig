const std = @import("std");
const Z80 = @import("Z80.zig");

const _inc = @import("register_single_instr.zig").inc;
const _dcr = @import("register_single_instr.zig").dcr;
const getHighByte = @import("opcode.zig").getHighByte;
const getLowByte = @import("opcode.zig").getLowByte;

fn setHighByte(x: u8, n: u16) u16 {
    return (@as(u16, x) << 8) | getLowByte(n);
}

fn setLowByte(x: u8, n: u16) u16 {
    return (@as(u16, x)) | (@as(u16, getHighByte(n)) << 8);
}

pub fn addix(self: *Z80, high: u8, low: u8) void {
    const ix_val: u16 = self.ix;
    const bc_val: u16 = (@as(u16, high) << 8) | @as(u16, low);

    const sum: u32 = @as(u32, ix_val) + @as(u32, bc_val);
    const result: u16 = @intCast(sum & 0xFFFF);

    self.ix = result; // Store the new IX

    // Set carry if the 16-bit addition overflowed
    self.flag.carry = (sum > 0xFFFF);

    // Half-carry if carry from bit 11
    self.flag.half_carry = ((ix_val & 0x0FFF) + (bc_val & 0x0FFF)) > 0x0FFF;

    // N is reset
    self.flag.add_subtract = false;

    self.cycle_count += 7;
}

pub fn add_BC(self: *Z80) !void {
    std.log.debug("[DD 09]\tINC IX BC", .{});
    addix(self, self.register.b, self.register.c);
}

pub fn add_DE(self: *Z80) !void {
    std.log.debug("[DD 19]\tINC IX DE", .{});
    addix(self, self.register.d, self.register.e);
}

pub fn add_IX(self: *Z80) !void {
    std.log.debug("[DD 29]\tINC IX IX", .{});
    addix(self, getHighByte(self.ix), getLowByte(self.ix));
}

// LD IX, nn: Load 16-bit immediate into IX
pub fn load_NN(self: *Z80) !void {
    std.log.debug("[DD 21]\tLD  \tIX,NN", .{});
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    self.ix = address;
    self.cycle_count += 14;
}

pub fn load_NNMem(self: *Z80) !void {
    std.log.debug("[DD 2A]\tLD  \tIX,(NN)", .{});
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    self.ix = self.memory[address] | (@as(u16, self.memory[address + 1]) << 8);
    self.cycle_count += 20;
}

// LD (nn), IX: Load IX into 16-bit address
pub fn store(self: *Z80) !void {
    std.log.debug("[DD 22]\tLD  \t(N),IX", .{});
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    self.memory[address] = getLowByte(self.ix);
    self.memory[address + 1] = getHighByte(self.ix);
    self.cycle_count += 20;
}

pub fn load_NIXH(self: *Z80) !void {
    std.log.debug("[DD 26]\tLD  \tIXH,N", .{});
    const data = try self.fetchData(1);
    self.ix = setHighByte(data[0], self.ix);
    self.cycle_count += 11;
}

pub fn load_NIXL(self: *Z80) !void {
    std.log.debug("[DD 2E]\tLD  \tIXL,N", .{});
    const data = try self.fetchData(1);
    self.ix = setLowByte(data[0], self.ix);
    self.cycle_count += 11;
}

pub fn inc(self: *Z80) !void {
    std.log.debug("[DD 23]\tINC IX", .{});

    self.ix = self.ix +% 1;

    self.cycle_count += 10;
}

pub fn dec(self: *Z80) !void {
    std.log.debug("[DD 2B]\tDEC IX", .{});

    self.ix = self.ix -% 1;

    self.cycle_count += 10;
}

pub fn inc_High(self: *Z80) !void {
    std.log.debug("[DD 24]\tINC IXH", .{});

    const ixh: u8 = getHighByte(self.ix);

    const result = _inc(self, ixh);
    self.ix = setHighByte(result, self.ix);

    self.cycle_count +%= 8;
}

pub fn dcr_High(self: *Z80) !void {
    std.log.debug("[DD 25]\tDCR IXH", .{});

    const ixh: u8 = getHighByte(self.ix);

    const result = _dcr(self, ixh);
    self.ix = setHighByte(result, self.ix);

    self.cycle_count +%= 8;
}

pub fn inc_Low(self: *Z80) !void {
    std.log.debug("[DD 2C]\tINC IXL", .{});

    const ixl: u8 = getLowByte(self.ix);

    const result = _inc(self, ixl);
    self.ix = setLowByte(result, self.ix);

    self.cycle_count +%= 8;
}

pub fn dcr_Low(self: *Z80) !void {
    std.log.debug("[DD 2D]\tDCR IXL", .{});

    const ixh: u8 = getLowByte(self.ix);

    const result = _dcr(self, ixh);
    self.ix = setLowByte(result, self.ix);

    self.cycle_count +%= 8;
}
