const std = @import("std");

const isBitSet = @import("video.zig").isBitSet;
const setBit = @import("video.zig").setBit;

const Z80 = @import("z80").Z80;

const Segment = enum {
    keypad_right_buttons,
    joystick_left_buttons,
};

pub const Controller = enum {
    one,
    two,
};

pub const Key = enum(u8) {
    pad_8 = 0x01,
    pad_4 = 0x02,
    pad_5 = 0x03,
    blue = 0x04,
    pad_7 = 0x05,
    hash = 0x06,
    pad_2 = 0x07,
    purple = 0x08,
    asterisk = 0x09,
    pad_0 = 0x0A,
    pad_9 = 0x0B,
    pad_3 = 0x0C,
    pad_1 = 0x0D,
    pad_6 = 0x0E,
    up = 0x10,
    right = 0x11,
    down = 0x12,
    left = 0x13,
    left_button = 0x14,
    right_button = 0x15,
};

pub const Input = @This();

cpu: *Z80,
segment: Segment = .keypad_right_buttons,
gamepad: [2]u8 = .{ 0xFF, 0xFF },
keypad: [2]u8 = .{ 0xFF, 0xFF },
spinner_relative: [2]i32 = .{ 0, 0 },

pub fn init(allocator: std.mem.Allocator, cpu: *Z80) !*Input {
    const self = try allocator.create(Input);
    self.* = .{
        .cpu = cpu,
    };
    return self;
}

pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
    allocator.destroy(self);
}

pub fn read(self: *Input, port: u8) u8 {
    const c = (port & 0x02) >> 1;
    var ret: u8 = 0xFF;

    const rel = @divTrunc(self.spinner_relative[c], 4);
    self.spinner_relative[c] -= rel;

    const high: u8 = 0x70;
    const low: u8 = 0x30;

    if (self.segment == .keypad_right_buttons) {
        ret = (self.keypad[c] & 0x0F) | (if (isBitSet(self.gamepad[c], 5)) high else low);
    } else {
        ret = (self.gamepad[c] & 0x0F) | (if (isBitSet(self.gamepad[c], 4)) high else low);

        if (rel > 0) {
            ret &= if (c != 0) 0xEF else 0xCF;
            self.cpu.int_requested = true;
        } else if (rel < 0) {
            ret &= if (c != 0) 0xCF else 0xEF;
            self.cpu.int_requested = true;
        }
    }

    return ret;
}

pub fn keyPressed(self: *Input, controller: Controller, key: Key) void {
    if (@intFromEnum(key) > 0x0F) {
        self.gamepad[@intFromEnum(controller)] = unsetBit(self.gamepad[@intFromEnum(controller)], @intFromEnum(key) & 0x0F);
    } else {
        self.keypad[@intFromEnum(controller)] &= (@intFromEnum(key) & 0x0F);
    }
}

pub fn keyReleased(self: *Input, controller: Controller, key: Key) void {
    if (@intFromEnum(key) > 0x0F) {
        self.gamepad[@intFromEnum(controller)] = setBit(self.gamepad[@intFromEnum(controller)], @intFromEnum(key) & 0x0F);
    } else {
        self.keypad[@intFromEnum(controller)] |= ~(@intFromEnum(key) & 0x0F);
    }
}

pub fn spinner1(self: *Input, movement: i32) void {
    self.spinner_relative[0] = movement;
}

pub fn spinner2(self: *Input, movement: i32) void {
    self.spinner_relative[1] = movement;
}

fn unsetBit(value: u8, bit: u8) u8 {
    const bit_pos: u3 = @intCast(bit);
    return value & ~(@as(u8, 1) << bit_pos);
}
