const std = @import("std");

const Z80 = @import("z80").Z80;

const resolution_width = @import("emu.zig").resolution_width;
const resolution_height = @import("emu.zig").resolution_height;
const resolution_width_with_overscan = @import("emu.zig").resolution_width_with_overscan;
const resolution_height_with_overscan = @import("emu.zig").resolution_height_with_overscan;
const lines_per_frame_pal = 313;
const lines_per_frame_ntsc = 262;

const Overscan = enum {
    disabled,
    top_bottom,
    full_284,
    full_320,
};

const LineEvents = struct {
    vint: bool = false,
    render: bool = false,
    display: bool = false,
};

const Timing = enum {
    vint,
    render,
    display,
};

const palette_888_coleco = [_]u8{ 0, 0, 0, 0, 0, 0, 33, 200, 66, 94, 220, 120, 84, 85, 237, 125, 118, 252, 212, 82, 77, 66, 235, 245, 252, 85, 84, 255, 121, 120, 212, 193, 84, 230, 206, 128, 33, 176, 59, 201, 91, 186, 204, 204, 204, 255, 255, 255 };
const palette_888_tms9918 = [_]u8{ 0, 0, 0, 0, 8, 0, 0, 241, 1, 50, 251, 65, 67, 76, 255, 112, 110, 255, 238, 75, 28, 9, 255, 255, 255, 78, 31, 255, 112, 65, 211, 213, 0, 228, 221, 52, 0, 209, 0, 219, 79, 211, 193, 212, 190, 244, 255, 241 };

const two_bit_to_8bit = [_]u8{ 0, 85, 170, 255 };
const two_bit_to_5bit = [_]u8{ 0, 10, 21, 31 };
const two_bit_to_6bit = [_]u8{ 0, 21, 42, 63 };
const four_bit_to_8bit = [_]u8{ 0, 17, 34, 51, 68, 86, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255 };
const four_bit_to_5bit = [_]u8{ 0, 2, 4, 6, 8, 10, 12, 14, 17, 19, 21, 23, 25, 27, 29, 31 };
const four_bit_to_6bit = [_]u8{ 0, 4, 8, 13, 17, 21, 25, 29, 34, 38, 42, 46, 50, 55, 59, 63 };

pub const Video = struct {
    z80: *Z80,
    info_buffer: []u8,
    framebuffer: []u16,
    vram: []u8,
    first_byte_in_sequence: bool = true,
    registers: [8]u8,
    buffer: u8 = 0,
    address: u16 = 0,
    cycle_counter: usize = 0,
    status: u8 = 0,
    lines_per_frame: usize = 0,
    is_pal: bool = false,
    mode: usize = 0,
    render_line: usize,
    overscan: Overscan,
    line_events: LineEvents,
    timing: std.EnumArray(Timing, u8),
    display_enabled: bool = false,
    sprite_over_request: bool = false,
    no_sprite_limit: bool = false,
    palette_565_rgb: [16]u16,
    palette_555_rgb: [16]u16,
    palette_565_bgr: [16]u16,
    palette_555_bgr: [16]u16,
    custom_palette: [48]u8,
    current_palette: []u8,

    pub fn init(allocator: std.mem.Allocator, z80: *Z80) !*Video {
        const self = try allocator.create(Video);
        self.* = Video{
            .z80 = z80,
            .info_buffer = try allocator.alloc(u8, resolution_width * resolution_height),
            .framebuffer = try allocator.alloc(u16, resolution_width_with_overscan * resolution_height_with_overscan),
            .vram = try allocator.alloc(u8, 0x4000),
            .registers = std.mem.zeroes([8]u8),
            .custom_palette = std.mem.zeroes([48]u8),
            .timing = std.EnumArray(Timing, u8).initDefault(null, .{
                .vint = 220,
                .render = 195,
                .display = 37,
            }),
        };

        self.initPalettes();
        self.reset(false);

        return self;
    }

    fn initPalettes(self: *Video) void {
        var i: usize = 0;
        var j: usize = 0;
        while (i < 16) : (i += 1) {
            const red = self.custom_palette[j];
            const green = self.custom_palette[j + 1];
            const blue = self.custom_palette[j + 2];

            const red_5 = red * 31 / 255;
            const green_5 = green * 31 / 255;
            const green_6 = green * 63 / 255;
            const blue_5 = blue * 31 / 255;

            self.palette_565_rgb[i] = red_5 << 11 | green_6 << 5 | blue_5;
            self.palette_555_rgb[i] = red_5 << 10 | green_5 << 5 | blue_5;
            self.palette_565_bgr[i] = blue_5 << 11 | green_6 << 5 | red_5;
            self.palette_555_bgr[i] = blue_5 << 10 | green_5 << 5 | red_5;

            j += 3;
        }
    }

    fn reset(self: *Video, is_pal: bool) void {
        self.is_pal = is_pal;
        self.lines_per_frame = if (is_pal) lines_per_frame_pal else lines_per_frame_ntsc;
        self.first_byte_in_sequence = true;
        self.buffer = 0;
        self.address = 0;
        self.status = 0;

        @memset(self.framebuffer, 1);
        @memset(self.info_buffer, 0);
        @memset(self.vram, 0);
        @memset(self.registers, 0);

        self.display_enabled = false;
        self.sprite_over_request = false;
        self.line_events = LineEvents{};
        self.cycle_counter = 0;
        self.render_line = 0;
    }
};
