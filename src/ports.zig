const std = @import("std");

const Memory = @import("memory_device.zig").Memory;
const Z80 = @import("z80").Z80;
const Video = @import("video.zig").Video;

pub const ColecoVisionIO = @This();

// Interface instance
io: Z80.IO,
memory: *Memory,
video: *Video,
cpu: *Z80,

pub fn init(allocator: std.mem.Allocator, memory: *Memory, video: *Video, cpu: *Z80) !*ColecoVisionIO {
    const self = try allocator.create(ColecoVisionIO);

    self.io = Z80.IO.init(
        self,
        ioRead,
        ioWrite,
        readMemory,
        writeMemory,
    );

    self.memory = memory;
    self.video = video;
    self.cpu = cpu;
    return self;
}

pub fn ioRead(ctx: *anyopaque, port: u16) u8 {
    const self: *ColecoVisionIO = @ptrCast(@alignCast(ctx));

    const region = port & 0xE0;
    switch (region) {
        0xA0 => {
            if ((port & 0x01) != 0) {
                return self.video.getStatusFlags();
            } else {
                return self.video.getDataPort();
            }
        },
        0xE0 => {
            std.debug.print("ioRead (input): {}\n", .{port});
            // return input.read(port)
        },
        else => {
            if (port == 0x52) {
                std.debug.print("ioRead (sgm audio): {}\n", .{port});
                return 0xAA;
            }
            return 0xFF;
        },
    }
    return 0xFF;
}
pub fn ioWrite(ctx: *anyopaque, port: u16, value: u8) !void {
    const self: *ColecoVisionIO = @ptrCast(@alignCast(ctx));

    const region = port & 0xE0;
    switch (region) {
        0x80 => {
            std.debug.print("ioWrite (input right): {d}\n", .{value});
        },
        0xA0 => {
            if (port & 0x01 != 0) {
                self.video.writeControl(value);
            } else {
                self.video.writeData(value);
            }
        },
        0xC0 => {
            // std.debug.print("ioWrite (input left): {d}\n", .{value});
        },
        0xE0 => {
            // std.debug.print("ioWrite (audio reg): {d}\n", .{value});
            self.cpu.cycle_count += 32;
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
