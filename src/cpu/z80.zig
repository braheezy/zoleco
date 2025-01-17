const std = @import("std");
const OpcodeTable = @import("opcode.zig").OpcodeTable;
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

pub const ShadowRegister = struct {
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
    carry: bool = false,
    parity_overflow: bool = false,

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
        // bit 4
        if (self.half_carry) {
            result |= 0x10;
        }
        // bit 2
        if (self.parity_overflow) {
            result |= 0x04;
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

    pub fn setP(self: *Flag, value: u16) void {
        self.parity_overflow = parity(value);
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
shadow_register: ShadowRegister = ShadowRegister{},
flag: Flag = Flag{},
// program counter
pc: u16 = 0,
// stack pointer
sp: u16 = 0,
// index registers
ix: u16 = 0,
iy: u16 = 0,
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

pub fn init(al: std.mem.Allocator, rom_data: []const u8, start_address: u16) !Z80 {
    const memory = try al.alloc(u8, 0x10000);

    @memcpy(memory[start_address .. start_address + rom_data.len], rom_data);
    return Z80{
        .memory = memory,
        .pc = start_address,
    };
}

pub fn free(self: *Z80, al: std.mem.Allocator) void {
    al.free(self.memory);
}

pub fn step(self: *Z80) !void {
    // Ensure we are within memory bounds
    if (self.pc >= self.memory.len) {
        return error.OutOfBoundsPC;
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
    // Ensure fetching count bytes doesn't exceed memory bounds
    if (self.pc + count > self.memory.len) {
        return error.OutOfBoundsMemory;
    }
    // Create a slice of the next `count` bytes from memory
    const data = self.memory[self.pc .. self.pc + count];
    // Advance the program counter past the fetched bytes
    self.pc += count;
    return data;
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
pub fn parity(x: u16) bool {
    var y = x ^ (x >> 1);
    y = y ^ (y >> 2);
    y = y ^ (y >> 4);
    y = y ^ (y >> 8);

    // Rightmost bit of y holds the parity value
    // if (y&1) is 1 then parity is odd else even
    return (y & 1) == 0;
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

// pub inline fn parity(x: u16) bool {
//     var local_x = x;
//     local_x ^= local_x >> 8;
//     local_x ^= local_x >> 4;
//     local_x ^= local_x >> 2;
//     local_x ^= local_x >> 1;
//     return local_x & 1 == 0;
// }
