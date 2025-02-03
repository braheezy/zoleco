const std = @import("std");
const Z80 = @import("z80").Z80;
const Bus = @import("z80").Bus;
const TMS9918 = @import("tms9918");
// const SN76489 = @import("SN76489.zig");

const Self = @This();
// Embed the BIOS ROM
const bios = @embedFile("roms/colecovision.rom");

allocator: std.mem.Allocator,
// Will be initialized when loading BIOS
cpu: Z80 = undefined,
vdp: *TMS9918,
// psg: SN76489, // Sound chip
bios_loaded: bool = false,
rom_loaded: bool = false,

pub fn init(allocator: std.mem.Allocator) !Self {
    const vdp = try TMS9918.init(allocator);

    return Self{
        .allocator = allocator,
        .vdp = vdp,
    };
}

pub fn deinit(self: *Self) void {
    if (self.rom_loaded or self.bios_loaded) {
        self.cpu.free(self.allocator);
    }
    self.vdp.free(self.allocator);
}

pub fn loadBios(self: *Self) !void {
    if (bios.len != 0x2000) { // BIOS should be 8KB
        return error.InvalidRomSize;
    }

    // Create and configure the bus with all devices
    var bus = Bus.init(self.allocator);
    try bus.addDevice(toIODevice(self.vdp));
    // Add other devices here as needed
    // try bus.addDevice(self.psg.toIODevice());

    // Initialize CPU with BIOS at 0x0000 and configured bus
    self.cpu = try Z80.init(self.allocator, bios, 0x0000, &bus);
    self.bios_loaded = true;
}

pub fn loadRom(self: *Self, data: []const u8) !void {
    if (!self.bios_loaded) {
        return error.BiosNotLoaded;
    }

    if (data.len > 0x8000) {
        return error.RomTooLarge;
    }

    // Copy the data into CPU memory at the specified address
    @memcpy(self.cpu.memory[0x8000 .. 0x8000 + data.len], data);
    self.rom_loaded = true;
}

pub fn step(self: *Self) !void {
    if (!self.bios_loaded) {
        return error.BiosNotLoaded;
    }
    try self.cpu.step();
}

pub fn runFrame(self: *Self) !void {
    // Run for one frame's worth of CPU cycles
    // ColecoVision runs at ~3.58MHz, 60fps
    // So one frame is roughly 59,667 cycles
    try self.cpu.runCycles(59667);

    // Update video
    try self.vdp.updateFrame();
}

// Add methods for getting screen buffer, handling input, etc.
pub fn getScreenBuffer(self: *Self) []const u8 {
    return self.vdp.getScreenBuffer();
}

// ************************************
// * IODevice implementation
// ************************************
const IODevice = @import("z80").IODevice;

// VDP ports
const vdp_data_port = 0x98; // Port for reading/writing VRAM data
const vdp_control_port = 0x99; // Port for reading status / writing address/register

pub fn toIODevice(self: *TMS9918) IODevice {
    return IODevice.init(
        self,
        portIn,
        portOut,
    );
}

fn portIn(self: *TMS9918, port: u16) u8 {
    return switch (port) {
        vdp_data_port => self.readData(),
        vdp_control_port => self.readStatus(),
        else => 0xFF,
    };
}

fn portOut(self: *TMS9918, port: u16, value: u8) void {
    switch (port) {
        vdp_data_port => self.writeData(value),
        vdp_control_port => self.writeAddress(value),
        else => {},
    }
}
