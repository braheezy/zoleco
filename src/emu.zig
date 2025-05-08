const std = @import("std");

pub const Zoleco = @import("zoleco.zig").Zoleco;

const resolution_width_with_overscan = @import("Video.zig").resolution_width_with_overscan;
const resolution_height_with_overscan = @import("Video.zig").resolution_height_with_overscan;

pub const Emu = struct {
    framebuffer: []u8,
    zoleco: *Zoleco,

    pub fn init(allocator: std.mem.Allocator) !Emu {
        const screen_size = resolution_width_with_overscan * resolution_height_with_overscan;

        const emu = Emu{
            .framebuffer = try allocator.alloc(u8, screen_size * 3),
            .zoleco = try Zoleco.init(allocator),
        };
        @memset(emu.framebuffer, 0);

        return emu;
    }

    pub fn deinit(self: *Emu, allocator: std.mem.Allocator) void {
        std.log.info("Deiniting Emu", .{});
        allocator.free(self.framebuffer);
        self.zoleco.deinit(allocator);
    }

    pub fn loadRom(self: *Emu, allocator: std.mem.Allocator, rom_file: []const u8) !void {
        try self.zoleco.cartridge.loadFromFile(allocator, rom_file);
    }
};
