const std = @import("std");

const Z80 = @import("z80").Z80;

pub const resolution_width_with_overscan = 320;
pub const resolution_height_with_overscan = 288;
pub const resolution_width = 256;
pub const resolution_height = 192;
const resolution_overscan_v = 24;
const resolution_overscan_v_pal = 48;
const resolution_sms_oversscan_h_320_l = 32;
const resolution_sms_oversscan_h_320_r = 32;
const resolution_sms_oversscan_h_284_l = 14;
const resolution_sms_oversscan_h_284_r = 14;
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

pub const PixelFormat = enum {
    rgb565,
    rgb555,
    rgb888,
    bgr565,
    bgr555,
    bgr888,
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
    current_palette: *const [48]u8 = undefined,
    name_table_addr: u16 = 0,
    pattern_table_addr: u16 = 0,

    pub fn init(allocator: std.mem.Allocator, z80: *Z80) !*Video {
        const self = try allocator.create(Video);
        self.* = Video{
            .z80 = z80,
            .info_buffer = try allocator.alloc(u8, resolution_width * lines_per_frame_pal),
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

        self.current_palette = &palette_888_coleco;
        self.initPalettes();
        self.reset(false);

        return self;
    }

    pub fn deinit(self: *Video, allocator: std.mem.Allocator) void {
        allocator.free(self.info_buffer);
        allocator.free(self.framebuffer);
        allocator.free(self.vram);
        allocator.destroy(self);
    }

    fn initPalettes(self: *Video) void {
        var i: usize = 0;
        var j: usize = 0;
        while (i < 16) : (i += 1) {
            const red = self.current_palette[j];
            const green = self.current_palette[j + 1];
            const blue = self.current_palette[j + 2];

            const red_5: u16 = @intCast(@as(u16, red) * 31 / 255);
            const green_5: u16 = @intCast(@as(u16, green) * 31 / 255);
            const green_6: u16 = @intCast(@as(u16, green) * 63 / 255);
            const blue_5: u16 = @intCast(@as(u16, blue) * 31 / 255);

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

                const reg1_bit5 = isBitSet(self.registers[1], 5);
                const status_bit7 = isBitSet(self.status, 7);

                if (reg1_bit5 and !status_bit7) {
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
                    self.setPixel(pixel, color);
                    self.info_buffer[pixel] = 0;
                }
            }
        }
    }

    fn renderBackground(self: *Video, line: usize) void {
        const line_offset = line * resolution_width;

        self.name_table_addr = @as(u16, @intCast(self.registers[2])) << 10;
        var color_table_addr: u16 = @as(u16, @intCast(self.registers[3])) << 6;
        self.pattern_table_addr = @as(u16, @intCast(self.registers[4])) << 11;
        const region_mask = (@as(u16, @intCast(self.registers[4] & 0x03)) << 8) | 0xFF;
        const color_mask = (@as(u16, @intCast(self.registers[3] & 0x7F)) << 3) | 0x07;
        var backdrop_color = self.registers[7] & 0x0F;
        backdrop_color = if (backdrop_color > 0) backdrop_color else 1;

        const tile_y: usize = line >> 3;
        const tile_y_offset = line & 7;
        var region: u16 = 0;

        switch (self.mode) {
            1 => {
                var foreground_color = (self.registers[7] >> 4) & 0x0F;
                const background_color = backdrop_color;
                foreground_color = if (foreground_color > 0) foreground_color else backdrop_color;

                for (0..8) |i| {
                    const pixel = line_offset + i;
                    self.setPixel(pixel, background_color);
                    self.setPixel(pixel + 248, background_color);
                    self.info_buffer[pixel] = 0;
                    self.info_buffer[pixel + 248] = 0;
                }

                for (0..40) |tile_x| {
                    const tile_number = (tile_y * 40) + tile_x;
                    const name_tile_addr = self.name_table_addr + tile_number;
                    const name_tile = self.vram[name_tile_addr];
                    const pattern_line = self.vram[self.pattern_table_addr + (name_tile << 3) + tile_y_offset];

                    const screen_offset = line_offset + (tile_x * 6) + 8;

                    for (0..6) |tile_pixel| {
                        const pixel = screen_offset + tile_pixel;
                        const target_color = if (isBitSet(pattern_line, @intCast(7 - tile_pixel))) foreground_color else background_color;
                        self.setPixel(pixel, target_color);
                        self.info_buffer[pixel] = 0;
                    }
                }
                return;
            },
            2 => {
                self.pattern_table_addr &= 0x2000;
                color_table_addr &= 0x2000;
                region = @as(u16, @intCast((tile_y & 0x18) << 5));
            },
            4 => {
                self.pattern_table_addr &= 0x2000;
            },
            else => {},
        }

        for (0..32) |tile_x| {
            const tile_number = (tile_y << 5) + tile_x;
            const name_tile_addr = self.name_table_addr + tile_number;
            var name_tile: u16 = @intCast(self.vram[name_tile_addr]);
            var pattern_line: usize = 0;
            var color_line: usize = 0;

            if (self.mode == 4) {
                const delta: usize = if (line & 0x04 != 0) 1 else 0;
                const offset_color = self.pattern_table_addr + (name_tile << 3) + ((tile_y & 0x03) << 1) + delta;
                color_line = self.vram[offset_color];

                var left_color = color_line >> 4;
                var right_color = color_line & 0x0F;
                left_color = if (left_color > 0) left_color else backdrop_color;
                right_color = if (right_color > 0) right_color else backdrop_color;

                const screen_offset = line_offset + (tile_x << 3);

                for (0..4) |tile_pixel| {
                    const pixel = screen_offset + tile_pixel;

                    self.setPixel(pixel, @intCast(left_color));
                    self.info_buffer[pixel] = 0;
                }

                for (4..8) |tile_pixel| {
                    const pixel = screen_offset + tile_pixel;
                    self.setPixel(pixel, @intCast(right_color));
                    self.info_buffer[pixel] = 0;
                }
                continue;
            } else if (self.mode == 0) {
                pattern_line = self.vram[self.pattern_table_addr + (name_tile << 3) + tile_y_offset];
                color_line = self.vram[color_table_addr + (name_tile >> 3)];
            } else if (self.mode == 2) {
                name_tile += region;

                // Pattern lookup - uses region_mask to select correct 2KB bank
                pattern_line = self.vram[self.pattern_table_addr + ((name_tile & region_mask) << 3) + tile_y_offset];

                // Color lookup - uses color_mask to stay within 6KB color table
                color_line = self.vram[color_table_addr + ((name_tile & color_mask) << 3) + tile_y_offset];
            }

            var foreground_color = color_line >> 4;
            var background_color = color_line & 0x0F;
            foreground_color = if (foreground_color > 0) foreground_color else backdrop_color;
            background_color = if (background_color > 0) background_color else backdrop_color;

            const screen_offset = line_offset + (tile_x << 3);

            for (0..8) |tile_pixel| {
                const pixel = screen_offset + tile_pixel;
                const current_bit_check = 7 - tile_pixel;
                const bit_is_set_result = isBitSet(@intCast(pattern_line), @intCast(current_bit_check));
                const target_color: u16 = if (bit_is_set_result) @intCast(foreground_color) else @intCast(background_color);

                self.setPixel(pixel, target_color);
                self.info_buffer[pixel] = 0;
            }
        }
    }

    pub fn setPixel(self: *Video, pixel: usize, color: u16) void {
        self.framebuffer[pixel] = color;
    }

    pub fn renderSprites(self: *Video, line: usize) void {
        var sprite_count: usize = 0;
        const line_width: usize = line * resolution_width;
        var sprite_size: i32 = if (isBitSet(self.registers[1], 1)) 16 else 8;
        const sprite_zoom = isBitSet(self.registers[1], 0);
        if (sprite_zoom) sprite_size *= 2;

        const sprite_attribute_addr: u16 = @as(u16, @intCast(self.registers[5] & 0x7F)) << 7;
        const sprite_pattern_addr: u16 = @as(u16, @intCast(self.registers[6] & 0x07)) << 11;

        var max_sprite: i8 = 31;
        var sp: i8 = 0;
        while (sp <= max_sprite) : (sp += 1) {
            if (self.vram[sprite_attribute_addr + @as(usize, @intCast(sp << 2))] == 0xD0) {
                max_sprite = @intCast(sp - 1);
                break;
            }
        }

        var sprite: u8 = 0;
        while (sprite <= max_sprite) : (sprite += 1) {
            const sprite_attribute_offset: usize = sprite_attribute_addr + (sprite << 2);
            var sprite_y = @as(i32, @intCast((self.vram[sprite_attribute_offset] + 1) & 0xFF));

            if (sprite_y >= 0xE0) sprite_y = -(0x100 - sprite_y);
            if (sprite_y > @as(i32, @intCast(line)) or (sprite_y + sprite_size) <= @as(i32, @intCast(line))) continue;

            sprite_count += 1;
            if (!isBitSet(self.status, 6) and sprite_count > 4) {
                self.status = setBit(self.status, 6);
                self.status = (self.status & 0xE0) | sprite;
            }

            const sprite_color: u8 = self.vram[sprite_attribute_offset + 3] & 0x0F;
            if (sprite_color == 0) continue;

            const sprite_shift: u8 = if ((self.vram[sprite_attribute_offset + 3] & 0x80) != 0) 32 else 0;
            const sprite_x = @as(i32, @intCast(self.vram[sprite_attribute_offset + 1])) - @as(i32, sprite_shift);
            if (sprite_x >= @as(i32, resolution_width)) continue;

            var tile = @as(i32, @intCast(self.vram[sprite_attribute_offset + 2]));
            tile &= if (isBitSet(self.registers[1], 1)) 0xFC else 0xFF;

            const line_addr: usize = @intCast(sprite_pattern_addr + (@as(u16, @intCast(tile)) << 3) + @as(u16, @intCast((@as(i32, @intCast(line)) - sprite_y) >> (if (sprite_zoom) 1 else 0))));

            var tx: u32 = 0;
            while (tx < @as(u32, @intCast(sprite_size))) : (tx += 1) {
                const px = sprite_x + @as(i32, @intCast(tx));
                if (px >= @as(i32, resolution_width)) break;
                if (px < 0) continue;

                const pixel = line_width + @as(usize, @intCast(px));
                const tile_x_adjusted = tx >> (if (sprite_zoom) 1 else 0);
                const sprite_pixel = if (tile_x_adjusted < 8)
                    isBitSet(self.vram[line_addr], @intCast(7 - tile_x_adjusted))
                else
                    isBitSet(self.vram[line_addr + 16], @intCast(15 - tile_x_adjusted));

                if (sprite_pixel and ((sprite_count < 5) or self.no_sprite_limit)) {
                    if (!isBitSet(self.info_buffer[pixel], 0) and (sprite_color > 0)) {
                        self.setPixel(pixel, sprite_color);
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

    pub fn render24bit(
        self: *Video,
        src: []u16,
        dst: []u8,
        pixel_format: PixelFormat,
        size: usize,
        enable_overscan: bool,
    ) void {
        var x: usize = 0;
        var y: usize = 0;
        var overscan_h_l: usize = 0;
        var overscan_v: usize = 0;
        var overscan_content_h: usize = 0;
        var overscan_content_v: usize = 0;
        var overscan_total_width: usize = resolution_width;
        var overscan_total_height: usize = 0;
        var overscan_enabled = false;
        const overscan_color = @as(u16, @intCast(self.registers[7] & 0x0F)) * 3;
        const bgr = (pixel_format == .bgr888);
        const buffer_size = size * 3;

        if (enable_overscan and self.overscan != .disabled) {
            overscan_enabled = true;
            overscan_content_v = resolution_height;
            overscan_v = if (self.is_pal) resolution_overscan_v_pal else resolution_overscan_v;
            overscan_total_height = overscan_content_v + (overscan_v * 2);
        }
        if (enable_overscan and self.overscan == .full_320) {
            overscan_content_h = resolution_width;
            overscan_h_l = resolution_sms_oversscan_h_320_l;
            overscan_total_width = overscan_content_h + overscan_h_l + resolution_sms_oversscan_h_320_r;
        }
        if (enable_overscan and self.overscan == .full_284) {
            overscan_content_h = resolution_width;
            overscan_h_l = resolution_sms_oversscan_h_284_l;
            overscan_total_width = overscan_content_h + overscan_h_l + resolution_sms_oversscan_h_284_r;
        }

        var i: usize = 0;
        var j: usize = 0;
        while (j < buffer_size) : (j += 3) {
            var src_color: u16 = 0;
            if (overscan_enabled) {
                const is_h_overscan = overscan_h_l > 0 and
                    (x < overscan_h_l or x >= (overscan_h_l + overscan_content_h));
                const is_v_overscan = overscan_v > 0 and
                    (y < overscan_v or y >= (overscan_v + overscan_content_v));

                if (is_h_overscan or is_v_overscan) {
                    src_color = overscan_color;
                } else {
                    src_color = src[i] * 3;
                    i += 1;
                }
                x += 1;
                if (x == overscan_total_width) {
                    x = 0;
                    y += 1;
                    if (y == overscan_total_height) y = 0;
                }
            } else {
                src_color = src[i] * 3;
                i += 1;
            }

            dst[j + 0] = if (bgr) self.current_palette[src_color + 2] else self.current_palette[src_color];
            dst[j + 1] = self.current_palette[src_color + 1];
            dst[j + 2] = if (bgr) self.current_palette[src_color] else self.current_palette[src_color + 2];
        }
    }

    pub fn getStatusFlags(self: *Video) u8 {
        self.first_byte_in_sequence = true;
        const ret = self.status;
        self.status &= 0x1F;

        if (isBitSet(self.registers[1], 5) and isBitSet(self.status, 7)) {
            self.z80.nmi_requested = true;
        }
        return ret;
    }

    pub fn getDataPort(self: *Video) u8 {
        self.first_byte_in_sequence = true;
        const ret = self.buffer;
        self.buffer = self.vram[self.address];
        self.address = (self.address + 1) & 0x3FFF;
        return ret;
    }

    pub fn writeData(self: *Video, data: u8) void {
        self.first_byte_in_sequence = true;
        self.buffer = data;
        self.vram[self.address] = data;
        self.address = (self.address + 1) & 0x3FFF;
    }

    pub fn writeControl(self: *Video, control: u8) void {
        if (self.first_byte_in_sequence) {
            self.first_byte_in_sequence = false;
            self.address = (self.address & 0x3F00) | control;
            self.buffer = control;
        } else {
            self.first_byte_in_sequence = true;
            self.address = @as(u16, @intCast(control & 0x3F)) << 8 | self.buffer;

            switch (control & 0xC0) {
                0 => {
                    self.buffer = self.vram[self.address];
                    self.address = (self.address + 1) & 0x3FFF;
                },
                0x80 => {
                    const old_nmi = isBitSet(self.registers[1], 5);
                    const masks: [8]u8 = .{ 0x03, 0xFB, 0x0F, 0xFF, 0x07, 0x7F, 0x07, 0xFF };
                    const reg: u8 = control & 0x07;
                    self.registers[reg] = self.buffer & masks[reg];

                    if (reg == 1 and isBitSet(self.registers[1], 5) and !old_nmi and isBitSet(self.status, 7)) {
                        self.z80.nmi_requested = true;
                    }

                    if (reg < 2) {
                        self.mode = ((self.registers[1] & 0x08) >> 1) | (self.registers[0] & 0x02) | ((self.registers[1] & 0x10) >> 4);
                    }
                },
                else => {},
            }
        }
    }
};

pub fn isBitSet(value: u8, bit: u8) bool {
    const bit_pos: u3 = @intCast(bit);
    return (value & (@as(u8, 1) << bit_pos)) != 0;
}
pub fn setBit(value: u8, bit: u8) u8 {
    const bit_pos: u3 = @intCast(bit);
    return value | (@as(u8, 1) << bit_pos);
}
