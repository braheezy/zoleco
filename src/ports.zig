const std = @import("std");

const Memory = @import("Memory.zig");
const Z80 = @import("z80").Z80;
const Video = @import("video.zig").Video;
const Input = @import("Input.zig");
const Audio = @import("Audio.zig").Audio;

pub const ColecoVisionIO = @This();

io: Z80.IO,
memory: *Memory,
video: *Video,
cpu: *Z80,
input: *Input,
audio: *Audio,

pub fn init(
    allocator: std.mem.Allocator,
    memory: *Memory,
    video: *Video,
    cpu: *Z80,
    input: *Input,
    audio: *Audio,
) !*ColecoVisionIO {
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
    self.input = input;
    self.cpu = cpu;
    self.audio = audio;
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
            return self.input.read(@intCast(port));
        },
        else => {
            if (port == 0x52) {
                // std.debug.print("ioRead (sgm audio): {}\n", .{port});
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
            self.input.segment = .keypad_right_buttons;
        },
        0xA0 => {
            if (port & 0x01 != 0) {
                self.video.writeControl(value);
            } else {
                self.video.writeData(value);
            }
        },
        0xC0 => {
            self.input.segment = .joystick_left_buttons;
        },
        0xE0 => {
            self.audio.write(value);
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
