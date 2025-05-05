const std = @import("std");

const CartridgeType = enum(u4) {
    colecovision,
    mega,
    activision,
    unsupported,
};

const Region = enum(u2) {
    ntsc,
    pal,
};

pub const Cartridge = @This();

rom: []const u8 = undefined,
cart_type: CartridgeType = .unsupported,
filepath: ?[]const u8 = null,
filename: ?[]const u8 = null,
rom_bank_count: u8 = 0,
is_pal: bool = false,
has_sram: bool = false,

pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !void {
    std.log.info("Loading cartridge from {s}", .{file_path});

    const cart = Cartridge{
        .filepath = file_path,
        .filename = std.fs.path.basename(file_path),
    };

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_buffer = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_buffer);

    try cart.loadFromBuffer(file_buffer);
}

pub fn loadFromBuffer(self: *Cartridge, allocator: std.mem.Allocator, buffer: []const u8) !void {
    if (buffer.len % 1024 != 0) {
        std.log.warn("Buffer length is not a multiple of 1024", .{});
        return error.InvalidBufferLength;
    }

    self.rom = try allocator.dupe(u8, buffer);
    self.gatherMetadata();
}

fn gatherMetadata(self: *Cartridge) void {
    std.log.info("ROM Size: {d} KB", .{self.rom.len / 1024});

    self.rom_bank_count = (self.rom.len / 0x4000) + (if (self.rom.len % 0x4000 > 0) 1 else 0);

    std.log.info("ROM Banks: {d}", .{self.rom_bank_count});

    var header_offset: u16 = 0;
    var header = self.rom[header_offset + 1] | self.rom[header_offset + 0] << 8;
    var is_valid_rom = header == 0xAA55 or header == 0x55AA;

    if (header == 0x6699) std.log.info("Found Adam expansion ROM", .{});
    if (is_valid_rom and self.rom.len <= 0x8000) {
        std.log.info("Found ColecoVision ROM. Size: {d} bytes", .{self.rom.len});
        self.cart_type = .colecovision;
    } else if (is_valid_rom and self.rom.len > 0x8000) {
        std.log.info("Found Activision ROM. Size: {d} bytes. Banks: {d}", .{
            self.rom.len,
            self.rom_bank_count,
        });
        self.cart_type = .activision;
    } else if (!is_valid_rom and self.rom.len > 0x8000) {
        header_offset = self.rom.len - 0x4000;
        header = self.rom[header_offset + 1] | self.rom[header_offset + 0] << 8;
        is_valid_rom = header == 0xAA55 or header == 0x55AA;

        if (is_valid_rom) {
            std.log.info("Found MegaCart ROM. Size: {d} bytes. Banks: {d}", .{
                self.rom.len,
                self.rom_bank_count,
            });
            self.cart_type = .mega;
        }
    } else {
        std.log.info("Invalid ROM header.", .{});
        self.cart_type = .unsupported;
    }

    if (self.cart_type == .unsupported) {
        return error.UnsupportedCartridgeType;
    }
}
