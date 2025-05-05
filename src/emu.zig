const std = @import("std");

pub const Zoleco = @import("zoleco.zig").Zoleco;

const gc_resolution_width_with_overscan = 320;
const gc_resolution_height_with_overscan = 288;

pub const Emu = struct {
    framebuffer: []u8,

    pub fn init(allocator: std.mem.Allocator) !Emu {
        const screen_size = gc_resolution_width_with_overscan * gc_resolution_height_with_overscan;

        var emu = Emu{
            .framebuffer = try allocator.alloc(u8, screen_size * 3),
        };
        emu.framebuffer = std.mem.zeroes([]u8);

        _ = try Zoleco.init(allocator);

        return emu;
    }
};
