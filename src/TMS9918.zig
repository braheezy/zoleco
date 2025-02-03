//! TMS9918 video display processor
//! Ported from https://github.com/visrealm/vrEmuTms9918

const std = @import("std");

const TMS9918 = @This();

const Mode = enum {
    graphics1,
    graphics2,
    text,
    multicolor,
};

const Color = enum {
    transparent,
    black,
    medium_green,
    light_green,
    dark_blue,
    light_blue,
    dark_red,
    cyan,
    medium_red,
    light_red,
    dark_yellow,
    light_yellow,
    dark_green,
    magenta,
    gray,
    white,
};

pub const Register = enum {
    reg_0,
    reg_1,
    name_table,
    color_table,
    pattern_table,
    sprite_attribute_table,
    sprite_pattern_table,
    fg_bg_color,
    len,
};

const vram_size = (1 << 14); // 16KB
const vram_mask = (vram_size - 1); // 0x3fff

const graphics_num_cols = 32;
const graphics_num_rows = 24;
const graphics_char_width = 8;

const test_num_cols = 40;
const test_num_rows = 24;
const test_char_width = 6;
const test_padding_pixels = 8;

const pattern_bytes = 8;
const gfxi_color_group_size = 8;

const max_sprites = 32;

const sprite_attr_y = 0;
const sprite_attr_x = 1;
const sprite_attr_name = 2;
const sprite_attr_color = 3;
const sprite_attr_bytes = 4;
const last_sprite_y_pos = 0xD0;
const max_scanline_sprites = 4;

const status_int: u8 = 0x80;
const status_5s = 0x40;
const status_col = 0x20;

pub const pixels_x = 256;
pub const pixels_y = 192;

const r0_mode_graphics_1 = 0x00;
const r0_mode_graphics_2 = 0x02;
const r0_mode_multicolor = 0x00;
const r0_mode_text = 0x00;
const r0_ext_vdp_enable = 0x01;
const r0_ext_vdp_disable = 0x00;

const r1_ram_16k = 0x80;
const r1_ram_4k = 0x00;
const r1_disp_blankK = 0x00;
const r1_disp_active = 0x40;
const r1_int_enable = 0x20;
const r1_int_disable = 0x00;
const r1_mode_graphics_I = 0x00;
const r1_mode_graphics_II = 0x00;
const r1_mode_multicolor = 0x08;
const r1_mode_test = 0x10;
const r1_sprite_8 = 0x00;
const r1_sprite_16 = 0x02;
const r1_sprite_mag1 = 0x00;
const r1_sprite_mag2 = 0x01;

const default_vram_name_address = 0x3800;
const default_vram_color_address = 0x0000;
const default_vram_patt_address = 0x2000;
const default_vram_sprite_attr_address = 0x3B00;
const default_vram_sprite_patt_address = 0x1800;

// RGBA palette
pub const palette: [16]u32 = [_]u32{
    0x00000000, // transparent
    0x000000ff, // black
    0x21c942ff, // medium green
    0x5edc78ff, // light green
    0x5455edff, // dark blue
    0x7d75fcff, // light blue
    0xd3524dff, // dark red
    0x43ebf6ff, // cyan
    0xfd5554ff, // medium red
    0xff7978ff, // light red
    0xd3c153ff, // dark yellow
    0xe5ce80ff, // light yellow
    0x21b03cff, // dark green
    0xc95bbaff, // magenta
    0xccccccff, // grey
    0xffffffff, // white
};

// the eight write-only registers
registers: []u8,
// status register (read-only)
status: u8 = 0,
// current address for cpu access (auto-increments)
current_address: u16 = 0,
// address or register write stage (0 or 1)
reg_write_stage: u8 = 0,
// holds first stage of write to address/register port
reg_write_stage0_value: u8 = 0,
// buffered value
read_ahead_buffer: u8 = 0,
// current display mode
mode: Mode,
// video ram
vram: []u8 = undefined,
// collision mask
row_sprite_bits: [pixels_x]u8,
// framebuffer
framebuffer: [pixels_x * pixels_y * 3]u8,

// create a new TMS9918 instance. Call free() to clean up.
pub fn init(al: std.mem.Allocator) !*TMS9918 {
    const emu = try al.create(TMS9918);
    emu.vram = try al.alloc(u8, vram_size);
    try emu.reset(al);
    return emu;
}

pub fn free(self: *TMS9918, al: std.mem.Allocator) void {
    al.free(self.vram);
    al.free(self.registers);
    al.destroy(self);
}

// reset the TMS9918 to its initial state
pub fn reset(self: *TMS9918, al: std.mem.Allocator) !void {
    self.reg_write_stage0_value = 0;
    self.current_address = 1;
    self.reg_write_stage = 0;
    self.read_ahead_buffer = 0;
    self.registers = try al.alloc(u8, @intFromEnum(Register.len));
    for (self.registers) |*reg| {
        reg.* = 0;
    }
    self.mode = self.updateDisplayMode();
}

// write an address (mode = 1) to the TMS9918
pub fn writeAddress(self: *TMS9918, address: u8) void {
    if (self.reg_write_stage == 0) {
        // first stage byte - either an address LSB or a register value
        self.reg_write_stage0_value = address;
        self.reg_write_stage = 1;
    } else {
        // second byte - either a register number or an address MSB
        if (address & 0x80 != 0) {
            // register write
            self.registers[address & 0x07] = self.reg_write_stage0_value;
            self.mode = self.updateDisplayMode();
        } else {
            // address write
            const n: u8 = @intCast(@as(u16, address & 0x3F) << @intCast(8));
            self.current_address = self.reg_write_stage0_value | n;
            if ((address & 0x40) == 0) {
                self.read_ahead_buffer = self.vram[self.current_address & vram_mask];
                self.current_address += 1;
            }
        }
        self.reg_write_stage = 0;
    }
}

// return the current display mode
pub fn updateDisplayMode(self: *TMS9918) Mode {
    if (self.registers[@intFromEnum(Register.reg_0)] & r0_mode_graphics_2 != 0) return .graphics2;

    // MC and TEX bits 3 and 4. Shift to bits 0 and 1 to determine a value (0, 1 or 2)
    const x = @as(u16, self.registers[@intFromEnum(Register.reg_1)] & (@intFromEnum(Mode.multicolor) | @intFromEnum(Mode.text))) >> 3;
    return switch (x) {
        0 => Mode.graphics1,
        1 => Mode.multicolor,
        2 => Mode.text,
        else => Mode.graphics1,
    };
}

// write a reigister value
pub fn writeRegisterValue(self: *TMS9918, reg: Register, value: u8) void {
    self.registers[@intFromEnum(reg) & 0x07] = value;
    self.mode = self.updateDisplayMode();
}

// Set current VRAM address for writing
pub fn setAddressWrite(self: *TMS9918, address: u16) void {
    self.setAddressRead(address | 0x4000);
}
// Set current VRAM address for reading
pub fn setAddressRead(self: *TMS9918, address: u16) void {
    self.writeAddress(@intCast(address & 0x00FF));
    self.writeAddress(@intCast((address & 0xFF00) >> 8));
}
// Write a series of bytes to the VRAM
pub fn writeBytes(self: *TMS9918, data: []u8) void {
    for (data) |byte| {
        self.writeData(byte);
    }
}

// write data (mode = 0) to the tms9918
pub fn writeData(self: *TMS9918, data: u8) void {
    self.reg_write_stage = 0;
    self.read_ahead_buffer = data;
    self.vram[self.current_address & vram_mask] = data;
    self.current_address += 1;
}

// check BLANK flag
fn displayEnabled(self: *TMS9918) bool {
    return self.registers[@intFromEnum(Register.reg_1)] & r1_disp_active != 0;
}

// background color
fn mainBgColor(self: *TMS9918) Color {
    return @enumFromInt(self.registers[@intFromEnum(Register.fg_bg_color)] & 0x0F);
}

// generate a scanline
pub fn scanLine(self: *TMS9918, y: u8, pixels: *[pixels_x]u8) void {
    if (!self.displayEnabled() or y >= pixels_y) {
        @memset(pixels, @intFromEnum(self.mainBgColor()));
        return;
    }

    // switch (self.mode) {
    //     .graphics1 =>
    self.graphics1ScanLine(y, pixels);
    // .graphics2 => self.graphics2ScanLine(y, pixels),
    // .text => self.textScanLine(y, pixels),
    // .multicolor => self.multicolorScanLine(y, pixels),
    //     else => unreachable,
    // }

    if (y == pixels_y - 1 and (self.registers[1] & r1_int_enable != 0)) {
        self.status |= status_int;
    }
}

// generate a Graphics I mode scanline
pub fn graphics1ScanLine(self: *TMS9918, y: u8, pixels: *[pixels_x]u8) void {
    var i: usize = 0;
    // which name table row (0 - 23)
    const tile_y = y >> 3;
    // which pattern row (0 - 7)
    const pattern_row = y & 0x07;

    const row_names_addr = self.namesTableAddress() + @as(u16, @as(u16, tile_y) * graphics_num_cols);

    const pattern_table = self.vram[self.patternTableAddress()..];
    const color_table = self.vram[self.colorTableAddress()..];

    // iterate over each tile in this row
    for (0..graphics_num_cols) |tile_x| {
        const pattern_index = self.vram[row_names_addr + tile_x];
        const tempN = @as(u16, pattern_index) * pattern_bytes + pattern_row;
        var pattern_byte = pattern_table[tempN];
        const color_byte = color_table[pattern_index / gfxi_color_group_size];

        const fg_color = self.fgColor(color_byte);
        const bg_color = self.bgColor(color_byte);

        // iterate over each bit of this pattern byte
        for (0..graphics_char_width) |_| {
            const bit = (pattern_byte & 0x80) != 0;
            const c = if (bit) @intFromEnum(fg_color) else @intFromEnum(bg_color);

            pixels[i] = c;
            i += 1;
            pattern_byte <<= 1;
        }
    }

    self.outputSprites(y, pixels);
}

// Output Sprites to a scanline
pub fn outputSprites(self: *TMS9918, y: u8, pixels: *[pixels_x]u8) void {
    const sprite_magnify = self.spriteMagnifcation();
    const sprite_size = self.spriteSize();
    const sprite16 = sprite_size == 16;
    const sprite_size_px = sprite_size * (@intFromBool(sprite_magnify) + 1);
    const sprite_attr_table_addr = self.spriteAttrTableAddress();
    const sprite_patt_table_addr = self.spritePatternTableAddress();

    var sprites_shown: u8 = 0;

    if (y == 0) self.status = 0;

    var sprite_attr = self.vram[sprite_attr_table_addr..self.vram.len];
    for (0..max_sprites) |sprite_index| {
        var y_pos: i16 = sprite_attr[sprite_attr_y];

        // stop processing when yPos == LAST_SPRITE_YPOS
        if (y_pos == last_sprite_y_pos) {
            if ((self.status & status_5s) == 0) self.status |= @intCast(sprite_index);
            break;
        }

        // check if sprite position is in the -31 to 0 range and move back to top
        if (y_pos > 0xE0) y_pos -= 256;

        // first row is YPOS -1 (0xff). 2nd row is YPOS 0
        y_pos += 1;

        var pattern_row = @as(i16, y) - y_pos;
        // this needs to be a shift because -1 / 2 becomes 0. Bad.
        if (sprite_magnify) pattern_row >>= 1;

        if (pattern_row < 0 or pattern_row >= sprite_size) {
            sprite_attr = sprite_attr[sprite_attr_bytes..sprite_attr.len];
            continue;
        }

        if (sprites_shown == 0) {
            self.row_sprite_bits = std.mem.zeroes([pixels_x]u8);
        }

        const sprite_color = sprite_attr[sprite_attr_color] & 0x0F;

        // have we exceeded the scanline sprite limit?
        sprites_shown += 1;
        if (sprites_shown > max_scanline_sprites) {
            if (self.status & status_5s == 0) self.status |= status_5s | @as(u8, @intCast(sprite_index));
            break;
        }

        // sprite is visible on this line
        const pattern_index = sprite_attr[sprite_attr_name];
        const pattern_offset = sprite_patt_table_addr + pattern_index * pattern_bytes + @as(u16, @bitCast(pattern_row));

        const early_clock_offset: i16 = if (sprite_attr[sprite_attr_color] & 0x80 != 0) -32 else 0;
        const x_pos: i16 = sprite_attr[sprite_attr_x] + early_clock_offset;

        var pattern_byte: i8 = @bitCast(self.vram[pattern_offset]);
        var screen_bit: u8 = 0;
        var pattern_bit: u8 = 0;

        var end_x_pos = x_pos + sprite_size_px;
        if (end_x_pos > pixels_x) end_x_pos = pixels_x;

        var screen_x = x_pos;
        while (screen_x < end_x_pos) : (screen_x += 1) {
            defer screen_bit += 1;
            if (screen_x >= 0) {
                if (pattern_byte < 0) {
                    if (sprite_color != @intFromEnum(Color.transparent) and self.row_sprite_bits[@intCast(screen_x)] < 2) {
                        pixels[@intCast(screen_x)] = sprite_color;
                    }

                    // we still process transparent sprites, since
                    // they're used in 5S and collision checks
                    if (self.row_sprite_bits[@intCast(screen_x)] != 0) {
                        self.status |= status_col;
                    } else {
                        self.row_sprite_bits[@intCast(screen_x)] = sprite_color + 1;
                    }
                }
            }

            // next pattern bit if non-magnified or if odd screen bit
            if (!sprite_magnify or (screen_bit & 0x01 != 0)) {
                pattern_byte <<= 1;
                // from A -> C or B -> D of large sprite
                pattern_bit += 1;
                if (pattern_bit == graphics_char_width and sprite16) {
                    pattern_bit = 0;
                    pattern_byte = @bitCast(self.vram[pattern_offset + pattern_bytes * 2]);
                }
            }
        }
        sprite_attr = sprite_attr[sprite_attr_bytes..sprite_attr.len];
    }
}

pub fn spriteAttrTableAddress(self: *TMS9918) u16 {
    return @intCast((self.registers[@intFromEnum(Register.sprite_attribute_table)] & 0x7F) << 7);
}

pub fn spritePatternTableAddress(self: *TMS9918) u16 {
    return @as(u16, (self.registers[@intFromEnum(Register.sprite_pattern_table)] & 0x07)) << 11;
}

// sprite size (8 or 16)
pub fn spriteSize(self: *TMS9918) u8 {
    return if (self.registers[@intFromEnum(Register.reg_1)] & r1_sprite_16 != 0) 16 else 8;
}

// sprite size (0 = 1x, 1 = 2x)
pub fn spriteMagnifcation(self: *TMS9918) bool {
    return self.registers[@intFromEnum(Register.reg_1)] & r1_sprite_mag2 != 0;
}

pub fn fgColor(self: *TMS9918, color_byte: u8) Color {
    const c: Color = @enumFromInt(color_byte >> 4);
    return if (c == .transparent) self.mainBgColor() else c;
}

pub fn bgColor(self: *TMS9918, color_byte: u8) Color {
    const c: Color = @enumFromInt(color_byte & 0x0F);
    return if (c == .transparent) self.mainBgColor() else c;
}

pub fn namesTableAddress(self: *TMS9918) u16 {
    return @as(u16, (self.registers[@intFromEnum(Register.name_table)] & 0x0F)) << 10;
}

pub fn patternTableAddress(self: *TMS9918) u16 {
    const mask: u8 = if (self.mode == .graphics2) 0x04 else 0x07;
    const result = @as(u16, (self.registers[@intFromEnum(Register.pattern_table)] & mask)) << 11;
    return result;
}

pub fn colorTableAddress(self: *TMS9918) u16 {
    const mask: u8 = if (self.mode == .graphics2) 0x80 else 0xFF;
    const reg = self.registers[@intFromEnum(Register.color_table)];
    const result: u16 = @as(u16, reg & mask) << 6;
    return result;
}

// Read data from VRAM at current address
pub fn readData(self: *TMS9918) u8 {
    self.reg_write_stage = 0;
    const value = self.read_ahead_buffer;
    self.read_ahead_buffer = self.vram[self.current_address & vram_mask];
    self.current_address += 1;
    return value;
}

// Read status register
pub fn readStatus(self: *TMS9918) u8 {
    self.reg_write_stage = 0;
    const value = self.status;
    // Reading status register clears interrupt flag
    self.status &= ~status_int;
    return value;
}

pub fn updateFrame(self: *TMS9918) !void {
    var scanline = [_]u8{0} ** pixels_x;
    var c: usize = 0;

    for (0..pixels_y) |y| {
        self.scanLine(@intCast(y), &scanline);
        for (0..pixels_x) |x| {
            const color = palette[scanline[x]];
            self.framebuffer[c] = @intCast((color >> 24) & 0xFF); // R
            self.framebuffer[c + 1] = @intCast((color >> 16) & 0xFF); // G
            self.framebuffer[c + 2] = @intCast((color >> 8) & 0xFF); // B
            c += 3;
        }
    }
}
