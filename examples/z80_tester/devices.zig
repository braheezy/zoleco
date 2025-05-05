const Z80 = @import("z80").Z80;
const std = @import("std");
pub const TestIO = struct {
    io: Z80.IO = undefined,

    memory: [0x10000]u8 = [_]u8{0xFF} ** 0x10000,
    value: u8 = 0,

    pub fn init(allocator: std.mem.Allocator) !*TestIO {
        const self = try allocator.create(TestIO);
        self.* = .{
            .io = Z80.IO.init(self, in, out, read, write),
        };
        return self;
    }

    pub fn in(ctx: *anyopaque, port: u16) u8 {
        _ = port;
        const self: *TestIO = @ptrCast(@alignCast(ctx));

        return self.value;
    }

    pub fn out(ctx: *anyopaque, port: u16, value: u8) !void {
        _ = port;
        const self: *TestIO = @ptrCast(@alignCast(ctx));
        // std.debug.print("test device out: {d} {d}\n", .{ port, value });
        self.value = value;
    }

    pub fn read(ctx: *anyopaque, address: u16) u8 {
        const self: *TestIO = @ptrCast(@alignCast(ctx));
        return self.memory[address];
    }

    pub fn write(ctx: *anyopaque, address: u16, value: u8) void {
        const self: *TestIO = @ptrCast(@alignCast(ctx));
        self.memory[address] = value;
    }
};

pub var test_io_device = TestIO{};
pub fn readIOFn(port: u16) u8 {
    return test_io_device.in(port);
}
pub fn writeIOFn(port: u16, value: u8) !void {
    return test_io_device.out(port, value);
}

pub const MemoryTestDevice = struct {
    memory: [0x10000]u8 = [_]u8{0xFF} ** 0x10000,

    pub fn read(self: *MemoryTestDevice, address: u16) u8 {
        return self.memory[address];
    }

    pub fn write(self: *MemoryTestDevice, address: u16, value: u8) void {
        self.memory[address] = value;
    }
};

pub var test_memory_device = MemoryTestDevice{};
pub fn readMemoryFn(address: u16) u8 {
    return test_memory_device.read(address);
}
pub fn writeMemoryFn(address: u16, value: u8) void {
    return test_memory_device.write(address, value);
}
