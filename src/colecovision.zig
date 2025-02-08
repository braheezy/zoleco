const std = @import("std");
const rl = @import("raylib");

const Z80 = @import("z80").Z80;
const Bus = @import("z80").Bus;
const TMS9918 = @import("tms9918");
// const SN76489 = @import("SN76489.zig");

const Self = @This();
// Embed the BIOS ROM
const bios = @embedFile("roms/colecovision.rom");

// Constants for timing
const target_fps = 60;
const cycles_per_second: u32 = 3_579_545; // Z80 at 3.58MHz
const cycles_per_frame = cycles_per_second / target_fps; // ~59,659 cycles per frame
const cycles_per_line = cycles_per_frame / 262; // NTSC has 262 lines per frame
const vdp_interrupt_line = 192; // Line where VDP triggers interrupt
const vdp_interrupt_cycles = cycles_per_line * vdp_interrupt_line; // When to trigger interrupt

// Memory map constants
const bios_start: usize = 0x0000;
const bios_size: usize = 0x2000;
const ram_start: usize = 0x6000;
const ram_size: usize = 0x0400;
const cart_start: usize = 0x800;
const cart_size: usize = 0x8000;

allocator: std.mem.Allocator,
// Will be initialized when loading BIOS
cpu: Z80 = undefined,
// psg: SN76489, // Sound chip
bios_loaded: bool = false,
rom_loaded: bool = false,
vdp_device: *VDPDevice,
screen_texture: rl.RenderTexture = undefined,
window_width: u32 = 800,
window_height: u32 = 600,
frame_count: u64 = 0,

pub fn init(allocator: std.mem.Allocator) !Self {
    const vdp = try TMS9918.init(allocator);
    const device = try allocator.create(VDPDevice);
    device.* = VDPDevice.init(vdp);

    return Self{
        .allocator = allocator,
        .vdp_device = device,
    };
}

pub fn deinit(self: *Self) void {
    if (self.rom_loaded or self.bios_loaded) {
        self.cpu.free(self.allocator);
    }
    self.vdp_device.vdp.free(self.allocator);
}

pub fn loadBios(self: *Self) !void {
    if (bios.len != 0x2000) {
        return error.InvalidRomSize;
    }

    var bus = try Bus.init(self.allocator);
    try bus.addDevice(&self.vdp_device.io_device);

    self.cpu = try Z80.init(self.allocator, bios, 0x0000, bus);
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
    self.cpu.pc = 0x8020;
    self.cpu.start_address = 0x8000;
    self.cpu.rom_size = data.len;
    self.rom_loaded = true;
}

pub fn runFrame(self: *Self) !void {
    const frame_start = std.time.nanoTimestamp();
    var cycles_this_frame: usize = 0;

    // Run CPU until we hit cycles_per_frame
    while (cycles_this_frame < cycles_per_frame) {
        const cycles_before = self.cpu.cycle_count;
        try self.cpu.step(); // Will handle both executing and halted states
        cycles_this_frame += self.cpu.cycle_count - cycles_before;

        // Check if we should generate VBlank interrupt
        if (cycles_this_frame >= cycles_per_frame) {
            self.cpu.interrupt_pending = true;
        }
    }

    // Update video
    try self.vdp_device.vdp.updateFrame();

    // Frame timing
    const frame_end = std.time.nanoTimestamp();
    const frame_duration_ns = frame_end - frame_start;
    const target_duration_ns = std.time.ns_per_s / target_fps;

    if (frame_duration_ns < target_duration_ns) {
        std.time.sleep(@intCast(target_duration_ns - frame_duration_ns));
    }
}

// Add methods for getting screen buffer, handling input, etc.
pub fn getScreenBuffer(self: *Self) []const u8 {
    return self.vdp_device.vdp.getScreenBuffer();
}

// ************************************
// * IODevice implementation
// ************************************
const IODevice = @import("z80").IODevice;

// VDP ports
const vdp_data_port = 0x98; // Port for reading/writing VRAM data
const vdp_control_port = 0x99; // Port for reading status / writing address/register

const VDPDevice = struct {
    vdp: *TMS9918,
    io_device: IODevice,

    pub fn init(vdp: *TMS9918) VDPDevice {
        return .{
            .vdp = vdp,
            .io_device = .{
                .inFn = in,
                .outFn = out,
            },
        };
    }

    // Make these static functions of the struct
    fn in(ptr: *IODevice, port: u16) u8 {
        const self: *VDPDevice = @fieldParentPtr("io_device", ptr);
        return switch (port) {
            vdp_data_port => self.vdp.readData(),
            vdp_control_port => self.vdp.readStatus(),
            else => 0xFF,
        };
    }

    fn out(ptr: *IODevice, port: u16, value: u8) void {
        std.debug.print("out: fieldParentPtr: {d}\n", .{port});
        const self: *VDPDevice = @fieldParentPtr("io_device", ptr);
        switch (port) {
            vdp_data_port => self.vdp.writeData(value),
            vdp_control_port => self.vdp.writeAddress(value),
            else => {},
        }
    }
};

pub fn draw(self: *Self) !void {
    // Get RGB pixels from VDP
    const pixels = try getScreen(self.vdp_device.vdp, self.allocator);
    defer self.allocator.free(pixels);

    // Convert RGB to RGBA for raylib
    var rgba_pixels = try self.allocator.alloc(u8, 256 * 192 * 4);
    defer self.allocator.free(rgba_pixels);

    for (0..(256 * 192)) |i| {
        rgba_pixels[i * 4 + 0] = pixels[i * 3 + 0]; // R
        rgba_pixels[i * 4 + 1] = pixels[i * 3 + 1]; // G
        rgba_pixels[i * 4 + 2] = pixels[i * 3 + 2]; // B
        rgba_pixels[i * 4 + 3] = 255; // A
    }

    // Update texture with new pixel data
    rl.updateTexture(self.screen_texture.texture, rgba_pixels.ptr);

    // Draw scaled texture to window
    rl.drawTexturePro(
        self.screen_texture.texture,
        .{
            .x = 0,
            .y = 0,
            .width = 256,
            .height = 192,
        },
        .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(self.window_width),
            .height = @floatFromInt(self.window_height),
        },
        .{ .x = 0, .y = 0 },
        0.0,
        rl.Color.white,
    );
}

fn getScreen(self: *TMS9918, allocator: std.mem.Allocator) ![]u8 {
    // scanline buffer
    var scanline = [_]u8{0} ** TMS9918.pixels_x;

    // framebuffer
    var framebuffer = try allocator.alloc(u8, TMS9918.pixels_x * TMS9918.pixels_y * 3);

    // generate all scanlines and render to framebuffer
    var c: usize = 0;
    for (0..TMS9918.pixels_y) |y| {
        // get the scanline pixels
        self.scanLine(@intCast(y), &scanline);
        for (0..TMS9918.pixels_x) |x| {
            // values returned from scanLine() are palette indexes
            // use the Palette array to convert to an RGBA value
            const color = TMS9918.palette[scanline[x]];
            framebuffer[c] = @intCast((color >> 24) & 0xFF);
            framebuffer[c + 1] = @intCast((color >> 16) & 0xFF);
            framebuffer[c + 2] = @intCast((color >> 8) & 0xFF);
            c += 3;
        }
    }
    return framebuffer;
}
