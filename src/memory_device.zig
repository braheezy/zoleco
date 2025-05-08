const std = @import("std");
const assert = std.debug.assert;

pub const Memory = struct {

    // 8KB BIOS at 0x0000–0x1FFF
    bios: []u8,
    // 1KB internal RAM at 0x6000–0x63FF
    ram: []u8,
    // Cartridge ROM (variable size)
    rom: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, bios_data: []const u8) !*Memory {
        assert(bios_data.len == 0x2000);

        const bios = try allocator.alloc(u8, 0x2000);
        @memcpy(bios, bios_data);

        const ram = try allocator.alloc(u8, 0x0400);
        @memset(ram, 0xFF);

        const memory = try allocator.create(Memory);
        memory.* = Memory{
            .bios = bios,
            .ram = ram,
        };
        return memory;
    }

    pub fn deinit(self: *Memory, allocator: std.mem.Allocator) void {
        std.log.info("Deiniting Memory", .{});
        allocator.free(self.bios);
        allocator.free(self.ram);
        allocator.destroy(self);
    }

    pub fn read(self: *Memory, address: u16) u8 {
        return switch (address & 0xE000) {
            0x0000 => self.bios[address],
            0x2000, 0x4000 => 0xFF,
            0x6000 => self.ram[address & 0x03FF],
            0x8000, 0xA000, 0xC000, 0xE000 => blk: {
                if (self.rom) |rom| {
                    const rom_index = address - 0x8000;
                    if (rom_index >= rom.len) break :blk 0xFF;
                    break :blk rom[rom_index];
                } else {
                    break :blk 0xFF;
                }
            },
            else => 0xFF,
        };
    }

    pub fn write(self: *Memory, address: u16, value: u8) void {
        switch (address & 0xE000) {
            0x6000 => self.ram[address & 0x03FF] = value,
            0x8000, 0xA000, 0xC000, 0xE000 => {}, // Ignore writes to ROM
            else => {},
        }
    }

    pub fn loadRom(self: *Memory, rom_data: []const u8) void {
        self.rom = rom_data;
    }
};
