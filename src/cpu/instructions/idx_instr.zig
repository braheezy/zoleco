const std = @import("std");
const Z80 = @import("../Z80.zig");

const _inc = @import("register_single_instr.zig").inc;
const _dcr = @import("register_single_instr.zig").dcr;
const add = @import("accumulator_instr.zig").add;
const adc = @import("accumulator_instr.zig").adc;
const sub = @import("accumulator_instr.zig").sub;
const sbb = @import("accumulator_instr.zig").sbb;
const ana = @import("accumulator_instr.zig").ana;
const xra = @import("accumulator_instr.zig").xra;
const ora = @import("accumulator_instr.zig").ora;
const compare = @import("accumulator_instr.zig").compare;

const getHighByte = @import("util.zig").getHighByte;
const getLowByte = @import("util.zig").getLowByte;

fn setHighByte(high_byte: u8, target: u16) u16 {
    return (@as(u16, high_byte) << 8) | getLowByte(target);
}

fn setLowByte(x: u8, n: u16) u16 {
    return (@as(u16, x)) | (@as(u16, getHighByte(n)) << 8);
}

pub fn add_IdxReg(self: *Z80, high: u8, low: u8) void {
    const idx_reg_val: u16 = self.curr_index_reg.?.*;
    const bc_val: u16 = (@as(u16, high) << 8) | @as(u16, low);

    // Set WZ to IX/IY + 1 before the addition
    self.wz = idx_reg_val +% 1;

    const sum: u32 = @as(u32, idx_reg_val) + @as(u32, bc_val);
    const result: u16 = @intCast(sum & 0xFFFF);

    self.curr_index_reg.?.* = result;

    // Set carry if the 16-bit addition overflowed
    self.flag.carry = (sum > 0xFFFF);

    // Half-carry if carry from bit 11
    self.flag.half_carry = ((idx_reg_val & 0x0FFF) + (bc_val & 0x0FFF)) > 0x0FFF;

    // N is reset
    self.flag.add_subtract = false;

    // X and Y flags come from bits 3 and 5 of high byte of result
    self.flag.x = ((@as(u8, @truncate(result >> 8)) & 0x08) != 0);
    self.flag.y = ((@as(u8, @truncate(result >> 8)) & 0x20) != 0);

    // Update Q with new flags
    self.q = self.flag.toByte();
}

pub fn add_BC(self: *Z80) !void {
    add_IdxReg(self, self.register.b, self.register.c);
}

pub fn add_DE(self: *Z80) !void {
    add_IdxReg(self, self.register.d, self.register.e);
}

pub fn add_IX(self: *Z80) !void {
    add_IdxReg(self, getHighByte(self.curr_index_reg.?.*), getLowByte(self.curr_index_reg.?.*));
}

// LD IX, nn: Load 16-bit immediate into IX
pub fn load_NN(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    self.curr_index_reg.?.* = address;
    self.q = 0;
}

pub fn load_NNMem(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);
    self.curr_index_reg.?.* = self.memory_read_fn(address) | (@as(u16, self.memory_read_fn(address + 1)) << 8);
    self.wz = address +% 1;
    self.q = 0;
}

// LD (nn), IX: Load IX into 16-bit address
pub fn store(self: *Z80) !void {
    const data = try self.fetchData(2);
    const address = Z80.toUint16(data[1], data[0]);

    self.memory_write_fn(address, getLowByte(self.curr_index_reg.?.*));
    self.memory_write_fn(address + 1, getHighByte(self.curr_index_reg.?.*));
    self.q = 0;
    self.wz = address +% 1;
}

pub fn load_NIXH(self: *Z80) !void {
    const data = try self.fetchData(1);
    self.curr_index_reg.?.* = setHighByte(data[0], self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_NIXL(self: *Z80) !void {
    const data = try self.fetchData(1);
    self.curr_index_reg.?.* = setLowByte(data[0], self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn inc(self: *Z80) !void {
    self.curr_index_reg.?.* = self.curr_index_reg.?.* +% 1;
    self.q = 0;
}

pub fn dec(self: *Z80) !void {
    self.curr_index_reg.?.* = self.curr_index_reg.?.* -% 1;
    self.q = 0;
}

pub fn inc_High(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);

    const result = _inc(self, reg_high);
    self.curr_index_reg.?.* = setHighByte(result, self.curr_index_reg.?.*);
}

pub fn dcr_High(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);

    const result = _dcr(self, reg_high);
    self.curr_index_reg.?.* = setHighByte(result, self.curr_index_reg.?.*);
}

pub fn inc_Low(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);

    const result = _inc(self, reg_low);
    self.curr_index_reg.?.* = setLowByte(result, self.curr_index_reg.?.*);
}

pub fn dcr_Low(self: *Z80) !void {
    const reg_high: u8 = getLowByte(self.curr_index_reg.?.*);

    const result = _dcr(self, reg_high);
    self.curr_index_reg.?.* = setLowByte(result, self.curr_index_reg.?.*);
}

pub fn inc_IXD(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);

    // Step 4: Increment the value with wrapping
    const old_value: u8 = value;
    const new_value: u8 = value +% 1;

    self.memory_write_fn(address, new_value);

    // Step 6: Update Flags
    self.flag.setZ(new_value); // Zero Flag
    self.flag.setS(new_value); // Sign Flag
    self.flag.half_carry = Z80.auxCarryAdd(old_value, 1); // Half-Carry Flag
    self.flag.parity_overflow = old_value == 0x7F and new_value == 0x80; // Parity/Overflow Flag
    self.flag.add_subtract = false; // Add/Subtract Flag Reset

    self.flag.setUndocumentedFlags(new_value);
    self.q = self.flag.toByte();
}

pub fn dec_IXD(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);

    // Step 4: Increment the value with wrapping
    const new_value: u8 = value -% 1;

    self.memory_write_fn(address, new_value);

    // Step 6: Update Flags
    self.flag.setZ(new_value); // Zero Flag
    self.flag.setS(new_value); // Sign Flag
    self.flag.half_carry = Z80.auxCarrySub(value, 1); // Half-Carry Flag
    self.flag.parity_overflow = value == 0x80 and new_value == 0x7F; // Parity/Overflow Flag
    self.flag.add_subtract = true; // Add/Subtract Flag Reset

    self.flag.setUndocumentedFlags(new_value);
    self.q = self.flag.toByte();
}

pub fn store_WithDisp(self: *Z80, n: u8) void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);
    self.q = 0;

    self.memory_write_fn(address, n);
}

pub fn store_NWithDisp(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const data = try self.fetchData(1);
    const n: u8 = data[0];

    self.memory_write_fn(address, n);
    self.q = 0;
}

pub fn store_BWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.b);
}

pub fn store_CWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.c);
}

pub fn store_DWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.d);
}

pub fn store_EWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.e);
}

pub fn store_HWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.h);
}

pub fn store_LWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.l);
}

pub fn store_AWithDisp(self: *Z80) !void {
    store_WithDisp(self, self.register.a);
}

pub fn add_SP(self: *Z80) !void {
    const idx_reg_val: u16 = self.curr_index_reg.?.*;
    const sp_val: u16 = self.sp;

    // Set WZ to IX/IY + 1 before the addition
    self.wz = idx_reg_val +% 1;

    const sum: u32 = @as(u32, idx_reg_val) + @as(u32, sp_val);
    const result: u16 = @intCast(sum & 0xFFFF);

    self.curr_index_reg.?.* = result;

    // Set carry if the 16-bit addition overflowed
    self.flag.carry = (sum > 0xFFFF);

    // Half-carry if carry from bit 11
    self.flag.half_carry = ((idx_reg_val & 0x0FFF) + (sp_val & 0x0FFF)) > 0x0FFF;

    // N is reset
    self.flag.add_subtract = false;

    // X and Y flags come from bits 3 and 5 of high byte of result
    self.flag.x = ((@as(u8, @truncate(result >> 8)) & 0x08) != 0);
    self.flag.y = ((@as(u8, @truncate(result >> 8)) & 0x20) != 0);

    // Update Q with new flags
    self.q = self.flag.toByte();
}

pub fn load_BHigh(self: *Z80) !void {
    self.register.b = getHighByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_BLow(self: *Z80) !void {
    self.register.b = getLowByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_DHigh(self: *Z80) !void {
    self.register.d = getHighByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_DLow(self: *Z80) !void {
    self.register.d = getLowByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_CHigh(self: *Z80) !void {
    self.register.c = getHighByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_CLow(self: *Z80) !void {
    self.register.c = getLowByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_EHigh(self: *Z80) !void {
    self.register.e = getHighByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_ELow(self: *Z80) !void {
    self.register.e = getLowByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_AHigh(self: *Z80) !void {
    self.register.a = getHighByte(self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_ALow(self: *Z80) !void {
    self.register.a = getLowByte(self.curr_index_reg.?.*);
    self.q = 0;
}

fn load_Disp(self: *Z80) u8 {
    self.q = 0;

    const displacement = self.getDisplacement();
    return self.memory_read_fn(self.getDisplacedAddress(displacement));
}

pub fn load_BDisp(self: *Z80) !void {
    self.register.b = load_Disp(self);
}

pub fn load_CDisp(self: *Z80) !void {
    self.register.c = load_Disp(self);
}

pub fn load_DDisp(self: *Z80) !void {
    self.register.d = load_Disp(self);
}

pub fn load_EDisp(self: *Z80) !void {
    self.register.e = load_Disp(self);
}

pub fn load_IXHB(self: *Z80) !void {
    self.curr_index_reg.?.* = setHighByte(self.register.b, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXHC(self: *Z80) !void {
    self.curr_index_reg.?.* = setHighByte(self.register.c, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXHD(self: *Z80) !void {
    self.curr_index_reg.?.* = setHighByte(self.register.d, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXHE(self: *Z80) !void {
    self.curr_index_reg.?.* = setHighByte(self.register.e, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXH(self: *Z80) !void {
    self.q = 0;
    // set IXH to IXH
    // we do nothing
}

pub fn load_IXHL(self: *Z80) !void {
    self.curr_index_reg.?.* = setHighByte(getLowByte(self.curr_index_reg.?.*), self.curr_index_reg.?.*);
    self.q = 0;
}

// Loads the value pointed to by IX plus d into H.
pub fn load_IXHDsp(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.register.h = self.memory_read_fn(address);
    self.q = 0;
}

// The contents of A are loaded into IXH.
pub fn load_IXHA(self: *Z80) !void {
    self.curr_index_reg.?.* = setHighByte(self.register.a, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXLB(self: *Z80) !void {
    self.curr_index_reg.?.* = setLowByte(self.register.b, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXLC(self: *Z80) !void {
    self.curr_index_reg.?.* = setLowByte(self.register.c, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXLD(self: *Z80) !void {
    self.curr_index_reg.?.* = setLowByte(self.register.d, self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXLE(self: *Z80) !void {
    self.curr_index_reg.?.* = setLowByte(self.register.e, self.curr_index_reg.?.*);
    self.q = 0;
}

// The contents of IXH are loaded into IXL.
pub fn swap_IXBytes(self: *Z80) !void {
    self.curr_index_reg.?.* = setLowByte(getHighByte(self.curr_index_reg.?.*), self.curr_index_reg.?.*);
    self.q = 0;
}

pub fn load_IXL(self: *Z80) !void {

    // set IXL to IXL
    // we do nothing
    self.q = 0;
}

// Loads the value pointed to by IX plus d into L.
pub fn loadDispL(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.register.l = self.memory_read_fn(address);
    self.q = 0;
}

// Loads the value pointed to by IX plus d into A.
pub fn loadDispA(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    self.register.a = self.memory_read_fn(address);
    self.q = 0;
}

pub fn load_IXLA(self: *Z80) !void {
    self.curr_index_reg.?.* = setLowByte(self.register.a, self.curr_index_reg.?.*);
    self.q = 0;
}

// Adds IXH to A.
pub fn add_IXH_A(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    self.register.a = add(self, reg_high);
}

// Adds IXL to A.
pub fn add_IXL_A(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    self.register.a = add(self, reg_low);
}

// Adds the value pointed to by IX plus d to A.
pub fn add_IXD_A(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    self.register.a = add(self, value);
}

// Adds IXH and the carry flag to A.
pub fn adc_IXH_A(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    self.register.a = adc(self, reg_high);
}

pub fn adc_IXL_A(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    self.register.a = adc(self, reg_low);
}
// Adds the value pointed to by IX plus d and the carry flag to A.
pub fn adc_IXD_A(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    self.register.a = adc(self, value);
}
// Subtracts IXH from A.
pub fn sub_IXH_A(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    self.register.a = sub(self, reg_high);
}

// Subtracts IXL from A.
pub fn sub_IXL_A(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    self.register.a = sub(self, reg_low);
}
// Subtracts the value pointed to by IX plus d from A.
pub fn sub_IXD_A(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    self.register.a = sub(self, value);
}

// Subtracts IXH and the carry flag from A.
pub fn sbb_IXH_A(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    self.register.a = sbb(self, reg_high);
}

pub fn sbb_IXL_A(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    self.register.a = sbb(self, reg_low);
}

// Subtracts the value pointed to by IX plus d and the carry flag from A.
pub fn sbb_IXD_A(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    self.register.a = sbb(self, value);
}

pub fn ana_IDXH(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    ana(self, reg_high);
}

// Bitwise AND on A with IDXL.
pub fn ana_IDXL(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    ana(self, reg_low);
}

// Bitwise AND on A with the value pointed to by IX plus d.
pub fn ana_IDXDisp(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    ana(self, value);
}

// Bitwise XOR on A with high byte of index register.
pub fn xor_IDXH(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    xra(self, reg_high);
}
pub fn xor_IDXL(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    xra(self, reg_low);
}

// Bitwise XOR on A with the value pointed to by IX plus d.
pub fn xor_IDXDisp(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    xra(self, value);
}

pub fn ora_IDXH(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    ora(self, reg_high);
}
pub fn ora_IDXL(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    ora(self, reg_low);
}

pub fn ora_IDXDisp(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    ora(self, value);
}

pub fn cmp_IDXH(self: *Z80) !void {
    const reg_high: u8 = getHighByte(self.curr_index_reg.?.*);
    compare(self, reg_high);
}
pub fn cmp_IDXL(self: *Z80) !void {
    const reg_low: u8 = getLowByte(self.curr_index_reg.?.*);
    compare(self, reg_low);
}

pub fn cmp_IDXDisp(self: *Z80) !void {
    const displacement = self.getDisplacement();
    const address = self.getDisplacedAddress(displacement);

    const value: u8 = self.memory_read_fn(address);
    compare(self, value);
}

// For indexed instructions (IX+d), (IY+d)
pub fn getIndexedAddress(self: *Z80) !u16 {
    const displacement = try self.getDisplacement();
    const base = self.curr_index_reg.?.*;
    const addr = @as(i32, @intCast(base)) + @as(i32, @intCast(displacement));
    self.wz = @intCast(addr & 0xFFFF); // Set WZ to effective address
    return self.wz;
}
