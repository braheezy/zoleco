const std = @import("std");
const SDL = @import("sdl2");
const Audio = @import("Audio.zig").Audio;

pub const Zoleco = @import("zoleco.zig").Zoleco;

const resolution_width_with_overscan = @import("video.zig").resolution_width_with_overscan;
const resolution_height_with_overscan = @import("video.zig").resolution_height_with_overscan;
// Reduce buffer size for better responsiveness to short sound effects
const audio_buffer_size = 1024;

pub const Emu = struct {
    framebuffer: []u8,
    audio: *Audio,
    zoleco: *Zoleco,

    pub fn init(allocator: std.mem.Allocator) !*Emu {
        const screen_size = resolution_width_with_overscan * resolution_height_with_overscan;

        const emu = try allocator.create(Emu);
        emu.framebuffer = try allocator.alloc(u8, screen_size * 3);
        // Enable high quality audio mode for better timing accuracy
        emu.audio = try Audio.init(allocator, 3579545, 44100, audio_buffer_size, 1);
        emu.audio.chip.set_quality(true);
        emu.zoleco = try Zoleco.init(allocator, emu.audio);
        @memset(emu.framebuffer, 0);

        return emu;
    }

    pub fn deinit(self: *Emu, allocator: std.mem.Allocator) void {
        allocator.free(self.framebuffer);
        self.audio.deinit(allocator);
        self.zoleco.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn loadRom(self: *Emu, allocator: std.mem.Allocator, rom_file: []const u8) !void {
        try self.zoleco.cartridge.loadFromFile(allocator, rom_file);
        self.zoleco.memory.rom = self.zoleco.cartridge.rom;
    }

    pub fn update(self: *Emu) !void {
        try self.zoleco.runToVBlank(self.framebuffer);
    }
};
