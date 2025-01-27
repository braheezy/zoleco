const std = @import("std");
const Z80 = @import("Z80.zig");

const _inc = @import("register_single_instr.zig").inc;
const _dcr = @import("register_single_instr.zig").dcr;
const getHighByte = @import("opcode.zig").getHighByte;
const getLowByte = @import("opcode.zig").getLowByte;

fn setHighByte(high_byte: u8, target: u16) u16 {
    return (@as(u16, high_byte) << 8) | getLowByte(target);
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

pub fn inc_IXD(self: *Z80) !void {
    std.log.debug("[DD 34 d]\tINC (IX+d)", .{});

    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory[address];

    // Step 4: Increment the value with wrapping
    const old_value: u8 = value;
    const new_value: u8 = value +% 1;

    self.memory[address] = new_value;

    // Step 6: Update Flags
    self.flag.setZ(new_value); // Zero Flag
    self.flag.setS(new_value); // Sign Flag
    self.flag.half_carry = Z80.auxCarryAdd(old_value, 1); // Half-Carry Flag
    self.flag.parity_overflow = old_value == 0x7F and new_value == 0x80; // Parity/Overflow Flag
    self.flag.add_subtract = false; // Add/Subtract Flag Reset

    self.cycle_count += 23;
}

pub fn dec_IXD(self: *Z80) !void {
    std.log.debug("[DD 35 d]\tDEC (IX+d)", .{});

    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory[address];

    // Step 4: Increment the value with wrapping
    const new_value: u8 = value -% 1;

    self.memory[address] = new_value;

    // Step 6: Update Flags
    self.flag.setZ(new_value); // Zero Flag
    self.flag.setS(new_value); // Sign Flag
    self.flag.half_carry = Z80.auxCarrySub(value, 1); // Half-Carry Flag
    self.flag.parity_overflow = value == 0x80 and new_value == 0x7F; // Parity/Overflow Flag
    self.flag.add_subtract = true; // Add/Subtract Flag Reset

    self.cycle_count += 23;
}

pub fn store_WithDisp(self: *Z80, n: u8) void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.memory[address] = n;

    self.cycle_count += 19;
}

pub fn store_NWithDisp(self: *Z80) !void {
    std.log.debug("[DD 36]\tLD  \t(IX+d),n", .{});

    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const data = try self.fetchData(1);
    const n: u8 = data[0];

    self.memory[address] = n;
    self.cycle_count += 19;
}

pub fn store_BWithDisp(self: *Z80) !void {
    std.log.debug("[DD 70 d]\tLD  \t(IX+d),B", .{});

    store_WithDisp(self, self.register.b);
}

pub fn store_CWithDisp(self: *Z80) !void {
    std.log.debug("[DD 71 d]\tLD  \t(IX+d),C", .{});

    store_WithDisp(self, self.register.c);
}

pub fn store_DWithDisp(self: *Z80) !void {
    std.log.debug("[DD 72 d]\tLD  \t(IX+d),D", .{});

    store_WithDisp(self, self.register.d);
}

pub fn store_EWithDisp(self: *Z80) !void {
    std.log.debug("[DD 73 d]\tLD  \t(IX+d),E", .{});

    store_WithDisp(self, self.register.e);
}

pub fn store_HWithDisp(self: *Z80) !void {
    std.log.debug("[DD 74 d]\tLD  \t(IX+d),H", .{});

    store_WithDisp(self, self.register.h);
}

pub fn store_LWithDisp(self: *Z80) !void {
    std.log.debug("[DD 75 d]\tLD  \t(IX+d),L", .{});

    store_WithDisp(self, self.register.l);
}

pub fn store_AWithDisp(self: *Z80) !void {
    std.log.debug("[DD 77 d]\tLD  \t(IX+d),A", .{});

    store_WithDisp(self, self.register.a);
}

pub fn add_SP(self: *Z80) !void {
    std.log.debug("[DD 39]\tADD IX,SP", .{});

    const ix_val: u16 = self.ix;
    const sp_val: u16 = self.sp;

    const sum: u32 = @as(u32, ix_val) + @as(u32, sp_val);
    const result: u16 = @intCast(sum & 0xFFFF);

    self.ix = result;

    // Set carry if the 16-bit addition overflowed
    self.flag.carry = (sum > 0xFFFF);

    // Half-carry if carry from bit 11
    self.flag.half_carry = ((ix_val & 0x0FFF) + (sp_val & 0x0FFF)) > 0x0FFF;

    // N is reset
    self.flag.add_subtract = false;

    self.cycle_count += 15;
}

pub fn load_BHigh(self: *Z80) !void {
    std.log.debug("[DD 44]\tLD  \tB,IXH", .{});

    self.register.b = getHighByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_BLow(self: *Z80) !void {
    std.log.debug("[DD 45]\tLD  \tB,IXL", .{});

    self.register.b = getLowByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_DHigh(self: *Z80) !void {
    std.log.debug("[DD 54]\tLD  \tD,IXH", .{});

    self.register.d = getHighByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_DLow(self: *Z80) !void {
    std.log.debug("[DD 55]\tLD  \tD,IXL", .{});

    self.register.d = getLowByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_CHigh(self: *Z80) !void {
    std.log.debug("[DD 4C]\tLD  \tC,IXH", .{});

    self.register.c = getHighByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_CLow(self: *Z80) !void {
    std.log.debug("[DD 4D]\tLD  \tC,IXL", .{});

    self.register.c = getLowByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_EHigh(self: *Z80) !void {
    std.log.debug("[DD 5C]\tLD  \tE,IXH", .{});

    self.register.e = getHighByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_ELow(self: *Z80) !void {
    std.log.debug("[DD 5D]\tLD  \tE,IXL", .{});

    self.register.e = getLowByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_AHigh(self: *Z80) !void {
    std.log.debug("[DD 4C]\tLD  \tA,IXH", .{});

    self.register.a = getHighByte(self.ix);
    self.cycle_count += 8;
}

pub fn load_ALow(self: *Z80) !void {
    std.log.debug("[DD 4D]\tLD  \tA,IXL", .{});

    self.register.a = getLowByte(self.ix);
    self.cycle_count += 8;
}

fn load_Disp(self: *Z80) u8 {
    self.cycle_count += 19;

    const displacement = self.getDisplacement();
    return self.memory[self.getDisplacedAddress(displacement)];
}

pub fn load_BDisp(self: *Z80) !void {
    std.log.debug("[DD 46 d]\tLD  \tB,(IX+d)", .{});

    self.register.b = load_Disp(self);
}

pub fn load_CDisp(self: *Z80) !void {
    std.log.debug("[DD 4E d]\tLD  \tC,(IX+d)", .{});

    self.register.c = load_Disp(self);
}

pub fn load_DDisp(self: *Z80) !void {
    std.log.debug("[DD 5E d]\tLD  \tD,(IX+d)", .{});

    self.register.d = load_Disp(self);
}

pub fn load_EDisp(self: *Z80) !void {
    std.log.debug("[DD 5E d]\tLD  \tE,(IX+d)", .{});

    self.register.e = load_Disp(self);
}

pub fn load_IXHB(self: *Z80) !void {
    std.log.debug("[DD 60]\tLD  \tIXH,B", .{});

    self.ix = setHighByte(self.register.b, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXHC(self: *Z80) !void {
    std.log.debug("[DD 61]\tLD  \tIXH,C", .{});

    self.ix = setHighByte(self.register.c, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXHD(self: *Z80) !void {
    std.log.debug("[DD 62]\tLD  \tIXH,D", .{});

    self.ix = setHighByte(self.register.d, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXHE(self: *Z80) !void {
    std.log.debug("[DD 63]\tLD  \tIXH,E", .{});

    self.ix = setHighByte(self.register.e, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXH(self: *Z80) !void {
    std.log.debug("[DD 64]\tLD  \tIXH", .{});

    // set IXH to IXH
    // we do nothing except consume cycles

    self.cycle_count +%= 8;
}

pub fn load_IXHL(self: *Z80) !void {
    std.log.debug("[DD 65]\tLD  \tIXH,L", .{});

    self.ix = setHighByte(getLowByte(self.ix), self.ix);
    self.cycle_count +%= 8;
}

// Loads the value pointed to by IX plus d into H.
pub fn load_IXHDsp(self: *Z80) !void {
    std.log.debug("[DD 66 d]\tLD  \tIXH,(IX+d)", .{});

    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.register.h = self.memory[address];
    self.cycle_count += 19;
}

// The contents of A are loaded into IXH.
pub fn load_IXHA(self: *Z80) !void {
    std.log.debug("[DD 67]\tLD  \tIXH,A", .{});

    self.ix = setHighByte(self.register.a, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXLB(self: *Z80) !void {
    std.log.debug("[DD 68]\tLD  \tIXL,B", .{});

    self.ix = setLowByte(self.register.b, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXLC(self: *Z80) !void {
    std.log.debug("[DD 69]\tLD  \tIXL,C", .{});

    self.ix = setLowByte(self.register.c, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXLD(self: *Z80) !void {
    std.log.debug("[DD 6A]\tLD  \tIXL,D", .{});

    self.ix = setLowByte(self.register.d, self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXLE(self: *Z80) !void {
    std.log.debug("[DD 6B]\tLD  \tIXL,E", .{});

    self.ix = setLowByte(self.register.e, self.ix);
    self.cycle_count +%= 8;
}

// The contents of IXH are loaded into IXL.
pub fn swap_IXBytes(self: *Z80) !void {
    std.log.debug("[DD 6C]\tLD  \tIXL", .{});

    self.ix = setLowByte(getHighByte(self.ix), self.ix);
    self.cycle_count +%= 8;
}

pub fn load_IXL(self: *Z80) !void {
    std.log.debug("[DD 6D]\tLD  \tIXL", .{});

    // set IXL to IXL
    // we do nothing except consume cycles

    self.cycle_count +%= 8;
}

// Loads the value pointed to by IX plus d into L.
pub fn loadDispL(self: *Z80) !void {
    std.log.debug("[DD 6E d]\tLD  \tIX,L,(IX+d)", .{});

    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.register.l = self.memory[address];
    self.cycle_count += 19;
}

// Loads the value pointed to by IX plus d into A.
pub fn loadDispA(self: *Z80) !void {
    std.log.debug("[DD 6E d]\tLD  \tIX,A,(IX+d)", .{});

    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.register.a = self.memory[address];
    self.cycle_count += 19;
}

pub fn load_IXLA(self: *Z80) !void {
    std.log.debug("[DD 6F]\tLD  \tIXL,A", .{});

    self.ix = setLowByte(self.register.a, self.ix);
    self.cycle_count +%= 8;
}
