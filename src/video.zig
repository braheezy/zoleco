const std = @import("std");

const Z80 = @import("z80").Z80;

pub const resolution_width_with_overscan = 320;
pub const resolution_height_with_overscan = 288;
pub const resolution_width = 256;
pub const resolution_height = 192;
const lines_per_frame_pal = 313;
const lines_per_frame_ntsc = 262;
const cycles_per_line = 228;

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
    render_line: usize = 0,
    overscan: Overscan = .disabled,
    line_events: LineEvents = .{},
    timing: std.EnumArray(Timing, u8) = undefined,
    display_enabled: bool = false,
    sprite_over_request: bool = false,
    no_sprite_limit: bool = false,
    palette_565_rgb: [16]u16 = undefined,
    palette_555_rgb: [16]u16 = undefined,
    palette_565_bgr: [16]u16 = undefined,
    palette_555_bgr: [16]u16 = undefined,
    custom_palette: [48]u8 = undefined,
    current_palette: []u8 = undefined,

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

    pub fn deinit(self: *Video, allocator: std.mem.Allocator) void {
        std.log.info("Deiniting Video", .{});
        allocator.free(self.info_buffer);
        allocator.free(self.framebuffer);
        allocator.free(self.vram);
        allocator.destroy(self);
    }

    fn initPalettes(self: *Video) void {
        var i: usize = 0;
        var j: usize = 0;
        while (i < 16) : (i += 1) {
            const red = self.custom_palette[j];
            const green = self.custom_palette[j + 1];
            const blue = self.custom_palette[j + 2];

            const red_5: u16 = @intCast(red * 31 / 255);
            const green_5: u16 = @intCast(green * 31 / 255);
            const green_6: u16 = @intCast(green * 63 / 255);
            const blue_5: u16 = @intCast(blue * 31 / 255);

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
        @memset(&self.registers, 0);

        self.display_enabled = false;
        self.sprite_over_request = false;
        self.line_events = LineEvents{};
        self.cycle_counter = 0;
        self.render_line = 0;
    }

    pub fn tick(self: *Video, clock_cycles: usize) bool {
        var return_vblank = false;

        self.cycle_counter += clock_cycles;

        // vint
        if (self.render_line == resolution_height) {
            if (!self.line_events.vint and self.cycle_counter >= self.timing.get(.vint)) {
                self.line_events.vint = true;

                if (isBitSet(self.registers[1], 5) and !isBitSet(self.status, 7)) {
                    self.z80.nmi_requested = true;
                }
                self.status = setBit(self.status, 7);
            }
        }

        // display on/off
        if (!self.line_events.display and self.cycle_counter >= self.timing.get(.display)) {
            self.line_events.display = true;
            self.display_enabled = isBitSet(self.registers[1], 6);
        }

        // render
        if (!self.line_events.render and self.cycle_counter >= self.timing.get(.render)) {
            self.line_events.render = true;
            self.scanLine(self.render_line);
        }

        // end of line
        if (self.cycle_counter >= cycles_per_line) {
            if (self.render_line == resolution_height) {
                return_vblank = true;
            }
            self.render_line += 1;
            self.render_line %= self.lines_per_frame;
            self.cycle_counter -= cycles_per_line;
            self.line_events.vint = false;
            self.line_events.render = false;
            self.line_events.display = false;
        }

        return return_vblank;
    }

    fn scanLine(self: *Video, line: usize) void {
        if (self.display_enabled) {
            if (line < resolution_height) {
                self.renderBackground(line);

                if (self.mode != 0x01) {
                    self.renderSprites(line);
                }
            }
        } else {
            if (line < resolution_height) {
                const color = self.registers[7] & 0x0F;
                const line_width = line * resolution_width;

                for (0..resolution_width) |scx| {
                    const pixel = line_width + scx;
                    self.framebuffer[pixel] = self.palette_565_rgb[color];
                    self.info_buffer[pixel] = 0;
                }
            }
        }
    }

    fn renderBackground(self: *Video, line: usize) void {
        const line_offset = line * resolution_width;

        const name_table_addr = self.registers[2] << 10;
        var color_table_addr = self.registers[3] << 6;
        var pattern_table_addr = self.registers[4] << 11;
        const region_mask = ((self.registers[4] & 0x03) << 8) | 0xFF;
        const color_mask = ((self.registers[3] & 0x7F) << 3) | 0x07;
        const backdrop_color = self.registers[7] & 0x0F;
        backdrop_color = if (backdrop_color > 0) backdrop_color else 1;

        const tile_y = line >> 3;
        const tile_y_offset = line & 7;
        var region = 0;

        switch (self.mode) {
            1 => {
                var foreground_color = (self.registers[7] >> 4) & 0x0F;
                const background_color = backdrop_color;
                foreground_color = if (foreground_color > 0) foreground_color else backdrop_color;

                for (0..8) |i| {
                    const pixel = line_offset + i;
                    self.framebuffer[pixel] = background_color;
                    self.framebuffer[pixel + 248] = background_color;
                    self.info_buffer[pixel] = 0;
                    self.info_buffer[pixel + 248] = 0;
                }

                for (0..40) |tile_x| {
                    const tile_number = (tile_y * 40) + tile_x;
                    const name_tile_addr = name_table_addr + tile_number;
                    const name_tile = self.vram[name_tile_addr];
                    const pattern_line = self.vram[pattern_table_addr + (name_tile << 3) + tile_y_offset];

                    const screen_offset = line_offset + (tile_x * 6) + 8;

                    for (0..6) |tile_pixel| {
                        const pixel = screen_offset + tile_pixel;
                        self.framebuffer[pixel] = if (isBitSet(pattern_line, 7 - tile_pixel)) foreground_color else background_color;
                        self.info_buffer[pixel] = 0;
                    }
                }
                return;
            },
            2 => {
                pattern_table_addr &= 0x2000;
                color_table_addr &= 0x2000;
                region = (tile_y & 0x18) << 5;
            },
            4 => {
                pattern_table_addr &= 0x2000;
            },
        }

        for (0..32) |tile_x| {
            const tile_number = (tile_y << 5) + tile_x;
            const name_tile_addr = name_table_addr + tile_number;
            var name_tile = self.vram[name_tile_addr];
            var pattern_line = 0;
            var color_line = 0;

            if (self.mode == 4) {
                const offset_color = pattern_table_addr + (name_tile << 3) + ((tile_y & 0x03) << 1) + (if (line & 0x04 != 0) 1 else 0);
                color_line = self.vram[offset_color];

                const left_color = color_line >> 4;
                const right_color = color_line & 0x0F;
                left_color = if (left_color > 0) left_color else backdrop_color;
                right_color = if (right_color > 0) right_color else backdrop_color;

                const screen_offset = line_offset + (tile_x << 3);

                for (0..4) |tile_pixel| {
                    const pixel = screen_offset + tile_pixel;
                    self.framebuffer[pixel] = left_color;
                    self.info_buffer[pixel] = 0;
                }

                for (4..8) |tile_pixel| {
                    const pixel = screen_offset + tile_pixel;
                    self.framebuffer[pixel] = right_color;
                    self.info_buffer[pixel] = 0;
                }
                continue;
            } else if (self.mode == 0) {
                pattern_line = self.vram[pattern_table_addr + (name_tile << 3) + tile_y_offset];
                color_line = self.vram[color_table_addr + (name_tile << 3)];
            } else if (self.mode == 2) {
                name_tile += region;
                pattern_line = self.vram[pattern_table_addr + ((name_tile & region_mask) << 3) + tile_y_offset];
                color_line = self.vram[color_table_addr + ((name_tile & color_mask) << 3) + tile_y_offset];
            }

            const foreground_color = color_line >> 4;
            const background_color = color_line & 0x0F;
            foreground_color = if (foreground_color > 0) foreground_color else backdrop_color;
            background_color = if (background_color > 0) background_color else backdrop_color;

            const screen_offset = line_offset + (tile_x << 3);

            for (0..8) |tile_pixel| {
                const pixel = screen_offset + tile_pixel;
                self.framebuffer[pixel] = if (isBitSet(pattern_line, 7 - tile_pixel)) foreground_color else background_color;
                self.info_buffer[pixel] = 0;
            }
        }
    }

    fn renderSprites(self: *Video, line: usize) void {
        var sprite_count = 0;
        const line_width = line * resolution_width;
        var sprite_size = if (isBitSet(self.registers[1], 1)) 16 else 8;
        const sprite_zoom = isBitSet(self.registers[1], 0);
        if (sprite_zoom) sprite_size *= 2;
        const sprite_attribute_addr = (self.registers[5] & 0x7F) << 7;
        const sprite_pattern_addr = (self.registers[6] & 0x07) << 11;

        var max_sprite = 31;

        var spr = 0;
        while (spr <= max_sprite) : (spr += 1) {
            if (self.vram[sprite_attribute_addr + (spr << 2)] == 0xD0) {
                max_sprite = spr - 1;
                break;
            }
        }

        for (0..max_sprite) |sprite| {
            const sprite_attribute_offset = sprite_attribute_addr + (sprite << 2);
            const sprite_y = (self.vram[sprite_attribute_offset] + 1) & 0xFF;

            if (sprite_y >= 0xE0) {
                sprite_y = -(0x100 - sprite_y);
            }
            if ((sprite_y > line) or ((sprite_y + sprite_size) <= line)) {
                continue;
            }

            sprite_count += 1;
            if (!isBitSet(self.status, 6) and (sprite_count > 4)) {
                self.status = setBit(self.status, 6);
                self.status = (self.status & 0xE0) | sprite;
            }

            const sprite_color = self.vram[sprite_attribute_offset + 3] & 0x0F;
            if (sprite_color == 0) continue;

            const sprite_shift = if (self.vram[sprite_attribute_offset + 3] & 0x80) 32 else 0;
            const sprite_x = (self.vram[sprite_attribute_offset + 1] - sprite_shift) & 0xFF;
            if (sprite_x > 0) continue;

            var sprite_tile = self.vram[sprite_attribute_offset + 2];
            sprite_tile &= if (isBitSet(self.registers[1], 1)) 0xFC else 0xFF;

            const sprite_line_address = sprite_pattern_addr + (sprite_tile << 3) + ((line - sprite_y) >> if (sprite_zoom) 1 else 0);
            for (0..sprite_size) |tile_x| {
                const sprite_pixel_x = sprite_x + tile_x;
                if (sprite_pixel_x >= resolution_width) break;
                if (sprite_pixel_x < 0) break;

                const pixel = line_width + sprite_pixel_x;
                var sprite_pixel = false;

                const tile_x_adjusted = tile_x >> if (sprite_zoom) 1 else 0;
                sprite_pixel = if (tile_x_adjusted < 8)
                    isBitSet(self.vram[sprite_line_address], 7 - tile_x_adjusted)
                else
                    isBitSet(self.vram[sprite_line_address + 16], 15 - tile_x_adjusted);

                if (sprite_pixel and ((sprite_count < 5) or self.no_sprite_limit)) {
                    if (!isBitSet(self.info_buffer[pixel], 0) and (sprite_color > 0)) {
                        self.framebuffer[pixel] = sprite_color;
                        self.info_buffer[pixel] = setBit(self.info_buffer[pixel], 0);
                    }

                    if (isBitSet(self.info_buffer[pixel], 1)) {
                        self.status = setBit(self.status, 5);
                    } else {
                        self.info_buffer[pixel] = setBit(self.info_buffer[pixel], 1);
                    }
                }
            }
        }
    }
};

fn isBitSet(value: u8, bit: u8) bool {
    return (value & (1 << bit)) != 0;
}
fn setBit(value: u8, bit: u8) u8 {
    return value | (1 << bit);
}
fn unsetBit(value: u8, bit: u8) u8 {
    return value & ~(1 << bit);
}
