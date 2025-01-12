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

const Flag = struct {
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
};

const InterruptMode = union {
    zero: void,
    one: void,
    two: void,
};

register: Register = Register{},
shadow_register: ShadowRegister = ShadowRegister{},
flags: Flag = Flag{},
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

pub fn init(al: std.mem.Allocator, rom_data: []const u8) !Z80 {
    const memory = try al.alloc(u8, 0x10000);

    @memcpy(memory[0..rom_data.len], rom_data);
    return Z80{
        .memory = memory,
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
    self.pc += 1;

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
