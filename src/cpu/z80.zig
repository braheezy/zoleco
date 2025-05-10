const std = @import("std");
const OpcodeTable = @import("opcode.zig").OpcodeTable;
const handleInterrupt = @import("opcode.zig").handleInterrupt;
const Bus = @import("bus.zig").Bus;
const push = @import("instructions/register_pair_instr.zig").push;
const OpcodeCycles = @import("cycles.zig").OpcodeCycles;
const getHighByte = @import("instructions/util.zig").getHighByte;
const getLowByte = @import("instructions/util.zig").getLowByte;

pub const IO = struct {
    readPort: *const fn (ctx: *anyopaque, port: u16) u8,
    writePort: *const fn (ctx: *anyopaque, port: u16, value: u8) anyerror!void,
    readMemory: *const fn (ctx: *anyopaque, address: u16) u8,
    writeMemory: *const fn (ctx: *anyopaque, address: u16, value: u8) void,

    /// Context pointer for the implementation
    ctx: *anyopaque,

    pub fn init(
        ctx: *anyopaque,
        readPort: *const fn (ctx: *anyopaque, port: u16) u8,
        writePort: *const fn (ctx: *anyopaque, port: u16, value: u8) anyerror!void,
        readMemory: *const fn (ctx: *anyopaque, address: u16) u8,
        writeMemory: *const fn (ctx: *anyopaque, address: u16, value: u8) void,
    ) IO {
        return .{
            .readPort = readPort,
            .writePort = writePort,
            .readMemory = readMemory,
            .writeMemory = writeMemory,
            .ctx = ctx,
        };
    }
};

const total_memory_size = 0x10000;

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
flag: Flag = Flag{ .zero = true },
shadow_flag: Flag = Flag{},
// program counter
pc: u16 = 0,
// stack pointer
sp: u16 = 0xDFF0,
// index registers
ix: u16 = 0xffff,
iy: u16 = 0xffff,
curr_index_reg: ?*u16 = null,
// memory refresh register
r: u8 = 0,
// cycle tracking
cycle_count: usize = 0,
// injected_cycles: usize = 0,
// total_cycle_count: usize = 0,
// interrupts
interrupt_mode: InterruptMode = .{ .zero = {} },
iff1: bool = false, // Main interrupt enable flag
iff2: bool = false, // Backup interrupt enable flag
after_end_interrupt: bool = false,
nmi_requested: bool = false,
int_requested: bool = false,
input_last_cycle: bool = false,
i: u8 = 0, // interrupt vector
interrupt_pending: bool = false,
halted: bool = false,
// rom_size: usize = 0,
start_address: u16 = 0,
io: *IO,
// bus: *Bus = undefined,
scratch: [2]u8 = [_]u8{0} ** 2,
displacement: i8 = 0,
// Q is a special flag to track flag state. used in 2 opcodes
// https://github.com/redcode/Z80/blob/f7ec2be293880059374bc9546370979fc97f69c5/sources/Z80.c#L501
q: u8 = 0,
wz: u16 = 0,

// pub fn initWithRom(al: std.mem.Allocator, rom_data: []const u8, start_address: u16, bus: *Bus) !Z80 {
//     // const memory = try al.alloc(u8, 0x10000);
//     var z80 = Z80{
//         .pc = start_address,
//         .bus = bus,
//         .read_fn = undefined,
//         .write_fn = undefined,
//         .memory_read_fn = undefined,
//         .memory_write_fn = undefined,
//     };

//     @memcpy(memory[start_address .. start_address + rom_data.len], rom_data);
//     return z80;
// }

pub fn init(allocator: std.mem.Allocator) !*Z80 {
    const z80 = try allocator.create(Z80);
    z80.reset();
    return z80;
}

pub fn reset(self: *Z80) void {
    self.resetRegisters();

    self.* = Z80{ .io = self.io };

    self.flag.zero = true;
    self.sp = 0xDFF0;
}

fn resetRegisters(self: *Z80) void {
    self.register = Register{};
    self.shadow_register = Register{};
    self.flag = Flag{ .zero = true };
    self.shadow_flag = Flag{};
    self.ix = 0xFFFF;
    self.iy = 0xFFFF;
}

pub fn runFor(self: *Z80, cycles: usize) !usize {
    var executed_cycles: usize = 0;
    while (executed_cycles < cycles) {
        if (!self.input_last_cycle) {
            if (self.nmi_requested) {
                std.debug.print("handling NMI\n", .{});
                self.leaveHalt();
                self.nmi_requested = false;
                self.iff1 = false;
                const pc_high = getHighByte(self.pc);
                const pc_low = getLowByte(self.pc);
                push(self, pc_low, pc_high);
                self.pc = 0x0066;
                self.cycle_count += 11;
                self.increment_r();
                self.wz = self.pc;
                return self.cycle_count;
            } else if (self.iff1 and self.int_requested and !self.after_end_interrupt) {
                self.leaveHalt();
                self.int_requested = false;
                self.iff1 = false;
                self.iff2 = false;
                const pc_high = getHighByte(self.pc);
                const pc_low = getLowByte(self.pc);
                push(self, pc_low, pc_high);
                self.pc = 0x0038;
                self.cycle_count += 13;
                self.increment_r();
                self.wz = self.pc;
                return self.cycle_count;
            }
            self.after_end_interrupt = false;
        }

        executed_cycles += try self.step();
    }
    self.cycle_count = 0;
    return executed_cycles;
}

pub fn step(self: *Z80) !usize {
    if (self.pc >= total_memory_size) {
        return error.OutOfBoundsPC;
    }

    // Handle pending interrupts
    // try handleInterrupt(self);

    // If halted, count cycles but don't execute
    // if (self.halted) {
    //     self.cycle_count += 4;
    //     return;
    // }

    // Fetch the opcode
    const opcode = self.nextOpcode();
    self.pc +%= 1;
    self.increment_r();

    // Execute the instruction
    if (OpcodeTable[opcode]) |handler| {
        self.cycle_count += OpcodeCycles[opcode];
        try handler(self);
        return self.cycle_count;
    } else {
        std.debug.print("Cannot step: unknown opcode: {X}\n", .{opcode});
        std.process.exit(1);
    }

    // Add any I/O cycle penalties
    // self.cycle_count += self.bus.getCyclesPenalty();
}

pub fn nextOpcode(self: *Z80) u8 {
    return self.io.readMemory(self.io.ctx, self.pc);
}

fn leaveHalt(self: *Z80) void {
    if (self.halted) {
        self.halted = false;
        self.pc += 1;
    }
}
pub fn fetchData(self: *Z80, count: u16) ![]const u8 {
    for (self.scratch[0..count]) |*b| {
        b.* = self.io.readMemory(self.io.ctx, self.pc);
        self.pc = (self.pc + 1) & 0xFFFF;
    }
    return self.scratch[0..count];
}

pub fn getHL(self: *Z80) u16 {
    return toUint16(self.register.h, self.register.l);
}

pub fn runCycles(self: *Z80, cycle_count: usize) !void {
    // TODO: Update to measure how long the frame takes and
    //  slow down or speed up accordingly to hardware-specific info

    while (self.cycle_count < cycle_count) {
        if (self.iff1 or self.iff2) {
            // TODO: do interrupt handling
            std.debug.print("interrupts enabled\n", .{});
        }

        // fetch and execute next instruction
        try self.step();

        if (self.pc >= total_memory_size) {
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

pub inline fn increment_r(self: *Z80) void {
    // Increment memory register, but only the lower 7 bits
    self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F);
}
