const std = @import("std");
const OpcodeTable = @import("opcode.zig").OpcodeTable;
const Hardware = @import("hardware.zig");
const Z80 = @This();

pub const Register = struct {
    a: u8 = 0,
    b: u8 = 0,
    c: u8 = 0,
    d: u8 = 0,
    e: u8 = 0,
    h: u8 = 0,
    l: u8 = 0,
};

pub const Flag = struct {
    zero: bool = false,
    sign: bool = false,
    half_carry: bool = false,
    parity_overflow: bool = false,
    add_subtract: bool = false,
    carry: bool = false,
    y: bool = false,
    x: bool = false,

    pub fn fromByte(b: u8) Flag {
        return Flag{
            .sign = b & (1 << 7) != 0,
            .zero = b & (1 << 6) != 0,
            .y = b & (1 << 5) != 0,
            .half_carry = b & (1 << 4) != 0,
            .x = b & (1 << 3) != 0,
            .parity_overflow = b & (1 << 2) != 0,
            .add_subtract = b & (1 << 1) != 0,
            .carry = b & 1 != 0,
        };
    }

    pub fn toByte(self: Flag) u8 {
        var result: u8 = 0;

        // bit 7
        if (self.sign) {
            result |= 0x80;
        }
        // bit 6
        if (self.zero) {
            result |= 0x40;
        }
        // bit 5
        if (self.y) {
            result |= 0x20;
        }
        // bit 4
        if (self.half_carry) {
            result |= 0x10;
        }
        // bit 3
        if (self.x) {
            result |= 0x08;
        }
        // bit 2
        if (self.parity_overflow) {
            result |= 0x04;
        }
        // bit 1 for N flag
        if (self.add_subtract) {
            result |= 0x02;
        }
        // bit 0
        if (self.carry) {
            result |= 0x01;
        }
        return result;
    }

    pub fn setZ(self: *Flag, value: u16) void {
        self.zero = value == 0;
    }

    pub fn setS(self: *Flag, value: u16) void {
        self.sign = (value & 0x80) != 0;
    }

    pub fn setUndocumentedFlags(self: *Flag, result: anytype) void {
        // Always look at bits 3 and 5 of the lower byte
        const lower_byte: u8 = switch (@TypeOf(result)) {
            u8 => result,
            u16 => @truncate(result),
            u32 => @truncate(result),
            else => @compileError("Unsupported type for setUndocumentedFlags"),
        };

        self.x = (lower_byte & 0x08) != 0; // bit 3
        self.y = (lower_byte & 0x20) != 0; // bit 5
    }
};

const Interrupts = enum {
    zero,
    one,
    two,
};

pub const InterruptMode = union(Interrupts) {
    zero: void,
    one: void,
    two: void,
};

register: Register = Register{},
shadow_register: Register = Register{},
flag: Flag = Flag{},
shadow_flag: Flag = Flag{},
// program counter
pc: u16 = 0,
// stack pointer
sp: u16 = 0,
// index registers
ix: u16 = 0,
iy: u16 = 0,
curr_index_reg: ?*u16 = null,
// memory refresh register
r: u8 = 0,
// cpu memory
memory: []u8 = undefined,
// cycle tracking
cycle_count: usize = 0,
total_cycle_count: usize = 0,
// interrupts
interrupts_enabled: bool = false,
interrupt_mode: InterruptMode = .{ .zero = {} },
halted: bool = false,
hardware: Hardware = Hardware{},
scratch: [2]u8 = [_]u8{0} ** 2,
displacement: i8 = 0,
// Q is a special flag to track flag state. used in 2 opcodes
// https://github.com/redcode/Z80/blob/f7ec2be293880059374bc9546370979fc97f69c5/sources/Z80.c#L501
q: u8 = 0,
wz: u16 = 0,

pub fn init(al: std.mem.Allocator, rom_data: []const u8, start_address: u16) !Z80 {
    const memory = try al.alloc(u8, 0x10000);
    var z80 = Z80{
        .memory = memory,
        .pc = start_address,
    };
    z80.zeroMemory();

    @memcpy(memory[start_address .. start_address + rom_data.len], rom_data);
    return z80;
}

pub fn zeroMemory(self: Z80) void {
    for (self.memory) |*byte| {
        byte.* = 0;
    }
}

pub fn free(self: *Z80, al: std.mem.Allocator) void {
    al.free(self.memory);
}

pub fn step(self: *Z80) !void {
    // Ensure we are within memory bounds
    if (self.pc >= self.memory.len) {
        return error.OutOfBoundsPC;
    }
    if (self.halted) {
        return error.Halted;
    }

    // Fetch the opcode
    const opcode = self.memory[self.pc];
    // Move PC to the next byte
    self.pc +%= 1;
    // Increment memory register, but only the lower 7 bits
    self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F);

    // Execute the instruction
    if (OpcodeTable[opcode]) |handler| {
        try handler(self);
    } else {
        std.debug.print("Cannot step: unknown opcode: {X}\n", .{opcode});
        std.process.exit(1);
    }
}

pub fn fetchData(self: *Z80, count: u16) ![]const u8 {
    // Safely compute PC + count in a wider type, then wrap to 16 bits
    const sum = @as(u32, self.pc) + @as(u32, count);
    const end_pc = @as(u16, @intCast(sum & 0xFFFF));

    // If sum <= 0xFFFF, no wrapping is needed
    if (sum <= 0xFFFF) {
        @memcpy(self.scratch[0..count], self.memory[self.pc .. self.pc + count]);
    } else {
        // Handle wrap-around by splitting the copy
        const first_part_len = 0xFFFF - self.pc + 1;
        const second_part_len = count - first_part_len;

        @memcpy(self.scratch[0..first_part_len], self.memory[self.pc..]);
        @memcpy(self.scratch[first_part_len..count], self.memory[0..second_part_len]);
    }

    // Update PC with wrap-around
    self.pc = end_pc;
    return self.scratch[0..count];
}

pub fn getHL(self: *Z80) u16 {
    return toUint16(self.register.h, self.register.l);
}

pub fn runCycles(self: *Z80, cycle_count: usize) !void {
    // TODO: Update to measure how long the frame takes and
    //  slow down or speed up accordingly to hardware-specific info

    while (self.cycle_count < cycle_count) {
        if (self.interrupts_enabled) {
            // TODO: do interrupt handling
            std.debug.print("interrupts enabled\n", .{});
        }

        // fetch and execute next instruction
        self.step();

        if (self.pc >= self.memory.len) {
            return error.OutOfBounds;
        }
    }

    self.total_cycle_count += cycle_count;
    self.cycle_count = 0;
}

pub fn toUint16(high: u8, low: u8) u16 {
    return @as(u16, @intCast(high)) << 8 | @as(u16, @intCast((low)));
}

// carrySub returns true if a carry would happen if subtrahend is subtracted from value.
pub fn carrySub(value: u8, subtrahend: u8) bool {
    return value < subtrahend;
}

// carryAdd returns true if a carry would happen if addend is added to value.
pub fn carryAdd(value: u8, addend: u8) bool {
    return @as(u16, value) + @as(u16, addend) > 0xFF;
}

// auxCarrySub returns true if auxilary carry would happen if subtrahend is subtracted from value.
pub fn auxCarrySub(value: u8, subtrahend: u8) bool {
    // Check if borrow is needed from higher nibble to lower nibble
    return (value & 0xF) < (subtrahend & 0xF);
}

// auxCarryAdd returns true if auxillary carry would happen if addend is added to value.
pub fn auxCarryAdd(value: u8, addend: u8) bool {
    // Check if carry is needed from higher nibble to lower nibble
    return (value & 0xF) + (addend & 0xF) > 0xF;
}

// parity returns true if the number of bits in x is even.
pub fn parity(comptime T: type, x: T) bool {
    var count: T = 0;
    var val = x;
    while (val != 0) {
        count += val & 1;
        val >>= 1;
    }
    return (count & 1) == 0;
}

pub fn parity_add(data: u8) bool {
    const sdata: i8 = @bitCast(data);
    // overflow occurs only when adding 1 to 127.
    return sdata == 127;
}

pub fn parity_sub(data: u8) bool {
    const sdata: i8 = @bitCast(data);
    // Overflow occurs only when subtracting 1 from -128.
    return sdata == -128;
}

pub inline fn signedByte(value: u8) u16 {
    return @bitCast(@as(i16, @as(i8, @bitCast(value))));
}

pub inline fn getDisplacement(self: *Z80) i8 {
    const data = try self.fetchData(1);
    return @bitCast(data[0]);
}

pub inline fn getDisplacedAddress(self: *Z80, displacement: i8) u16 {
    const idx_i32: i32 = @intCast(self.curr_index_reg.?.*);
    const displacement_i32: i32 = @intCast(displacement);
    const address_i32: i32 = idx_i32 + displacement_i32;
    self.wz = @intCast(address_i32 & 0xFFFF);
    return @intCast(address_i32 & 0xFFFF);
}
