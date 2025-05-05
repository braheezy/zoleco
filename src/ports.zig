const std = @import("std");

const Memory = @import("memory_device.zig").Memory;
const Z80 = @import("z80").Z80;

pub const ColecoVisionIO = @This();

// Interface instance
io: Z80.IO,
memory: *Memory,

pub fn init(allocator: std.mem.Allocator, memory: *Memory) !*ColecoVisionIO {
    const self = try allocator.create(ColecoVisionIO);

    self.io = Z80.IO.init(
        self,
        ioRead,
        ioWrite,
        readMemory,
        writeMemory,
    );

    self.memory = memory;
    return self;
}

pub fn ioRead(ctx: *anyopaque, port: u16) u8 {
    const self: *ColecoVisionIO = @ptrCast(@alignCast(ctx));
    _ = self;
    const region = port & 0xE0;
    switch (region) {
        0xA0 => {
            if ((port & 0x01) != 0) {
                // return video_device.tms9918.readStatus();
            } else {
                // return video_device.tms9918.readData();
            }
        },
        0xE0 => {
            std.debug.print("ioRead (input): {}\n", .{port});
            // return input.read(port)
        },
        else => return 0xFF,
    }
    return 0xFF;
}
pub fn ioWrite(ctx: *anyopaque, port: u16, value: u8) !void {
    const self: *ColecoVisionIO = @ptrCast(@alignCast(ctx));
    _ = self;
    const region = port & 0xE0;
    switch (region) {
        0xA0 => {
            if ((port & 0x01) != 0) {
                // video_device.tms9918.writeAddress(value);
            } else {
                // video_device.tms9918.writeData(value);
            }
        },
        0xE0 => {
            // Stub: call audio routine if needed
            std.debug.print("ioWrite (audio): {}\n", .{value});
            // audio.writeRegister(value);
        },
        else => {
            // Optionally log or ignore writes to other ports.
        },
    }
}
pub fn readMemory(ctx: *anyopaque, address: u16) u8 {
    const self: *ColecoVisionIO = @ptrCast(@alignCast(ctx));
    return self.memory.read(address);
}
pub fn writeMemory(ctx: *anyopaque, address: u16, value: u8) void {
    const self: *ColecoVisionIO = @ptrCast(@alignCast(ctx));
    return self.memory.write(address, value);
}
