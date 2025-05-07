const std = @import("std");

pub const Zoleco = @import("zoleco.zig").Zoleco;

const resolution_width_with_overscan = 320;
const resolution_height_with_overscan = 288;
pub const resolution_width = 256;
pub const resolution_height = 192;

pub const Emu = struct {
    framebuffer: []u8,
    zoleco: *Zoleco,

    pub fn init(allocator: std.mem.Allocator) !Emu {
        const screen_size = resolution_width_with_overscan * resolution_height_with_overscan;

        var emu = Emu{
            .framebuffer = try allocator.alloc(u8, screen_size * 3),
            .zoleco = try Zoleco.init(allocator),
        };
        emu.framebuffer = std.mem.zeroes([]u8);

        return emu;
    }
};
