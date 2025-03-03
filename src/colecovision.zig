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
const cart_start: usize = 0x8000;
const cart_size: usize = 0x8000;
const window_width: u32 = 800;
const window_height: u32 = 600;

allocator: std.mem.Allocator,
// Will be initialized when loading BIOS
cpu: Z80 = undefined,
// psg: SN76489, // Sound chip
bios_loaded: bool = false,
rom_loaded: bool = false,
vdp_device: *VDPDevice,
screen_texture: rl.RenderTexture2D = undefined,
frame_count: u64 = 0,
showTitle: bool = false,
romHeader: ?RomHeader = null,

pub const RomHeader = struct {
    signature: [2]u8,
    spriteTable1: u16,
    spriteTable2: u16,
    workspacePointer: u16,
    joystickPointer: u16,
    startAddress: u16,
    jumpVectors: [8]u16, // 7 RST vectors + 1 NMI vector
    titleString: []const u8,
};

/// Parse the ROM header from a slice that represents the cartridge region
fn parseRomHeader(cart: []const u8) !RomHeader {
    // Ensure we have at least header data (header occupies through 0x0024, relative offsets)
    if (cart.len < 0x24) {
        return error.InvalidRom;
    }
    var header: RomHeader = undefined;
    header.signature = [2]u8{ cart[0], cart[1] };
    header.spriteTable1 = @as(u16, cart[2]) | (@as(u16, cart[3]) << 8);
    header.spriteTable2 = @as(u16, cart[4]) | (@as(u16, cart[5]) << 8);
    header.workspacePointer = @as(u16, cart[6]) | (@as(u16, cart[7]) << 8);
    header.joystickPointer = @as(u16, cart[8]) | (@as(u16, cart[9]) << 8);
    header.startAddress = @as(u16, cart[10]) | (@as(u16, cart[11]) << 8);

    // Parse eight jump vectors (0x800C ... 0x8023). Each vector is 3 bytes:
    // byte0 is the jump opcode (usually 0xC3), then the low and high bytes of the address.
    for (header.jumpVectors, 0..) |_, i| {
        const offset = 0xC + (i * 3);
        if (offset + 2 >= cart.len) return error.InvalidRom;
        // We ignore the opcode byte (assumed to be 0xC3) and construct the vector:
        header.jumpVectors[i] = @as(u16, cart[offset + 1]) | (@as(u16, cart[offset + 2]) << 8);
    }

    // Title screen data starts at offset 0x24.
    const titleStart = 0x24;
    // We'll scan until a zero is found (or up to 64 bytes as a safeguard).
    var titleEnd: usize = titleStart;
    while (titleEnd < cart.len and titleEnd - titleStart < 64 and cart[titleEnd] != 0) : (titleEnd += 1) {}
    header.titleString = cart[titleStart..titleEnd];

    return header;
}

// Extend your emulator state to hold ROM header info and a flag to show the title.

pub fn init(allocator: std.mem.Allocator) !Self {
    const vdp = try TMS9918.init(allocator);
    const vdp_device = try VDPDevice.init(allocator, vdp);

    return Self{
        .allocator = allocator,
        .vdp_device = vdp_device,
        .cpu = undefined, // Will be set when loading BIOS
        .bios_loaded = false,
        .rom_loaded = false,
        .showTitle = false,
        .romHeader = null,
    };
}

pub fn deinit(self: *Self) void {
    if (self.rom_loaded or self.bios_loaded) {
        self.cpu.free(self.allocator);
    }
    self.vdp_device.vdp.free(self.allocator);
    self.allocator.destroy(self.vdp_device);
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

/// Updated loadRom: copies the cartridge data, parses the header,
/// and sets a flag if the header signature requests a title screen.
pub fn loadRom(self: *Self, data: []const u8) !void {
    if (!self.bios_loaded) {
        return error.BiosNotLoaded;
    }
    if (data.len > cart_size) {
        return error.RomTooLarge;
    }

    // Clear cartridge area first (fill with 0xFF for safety)
    @memset(self.cpu.memory[cart_start .. cart_start + cart_size], 0xFF);

    // Copy ROM data into cartridge space
    @memcpy(self.cpu.memory[cart_start .. cart_start + data.len], data);

    // Parse the cartridge header
    const header = try parseRomHeader(self.cpu.memory[cart_start .. cart_start + data.len]);
    self.romHeader = header;
    std.debug.print("Cartridge header:\n", .{});
    std.debug.print("  Signature: {X} {X}\n", .{ header.signature[0], header.signature[1] });
    std.debug.print("  Start Address: {X}\n", .{header.startAddress});
    std.debug.print("  Title: \"{s}\"\n", .{header.titleString});
    std.debug.print("  Sprite Table 1 Pointer: {X}\n", .{header.spriteTable1});
    std.debug.print("  Sprite Table 2 Pointer: {X}\n", .{header.spriteTable2});

    // Determine if we should show the title screen.
    // Per documentation: if the header is AA 55 then show the title screen.
    if (header.signature[0] == 0xAA and header.signature[1] == 0x55) {
        self.showTitle = true;
    } else {
        self.showTitle = false;
    }

    // Reset CPU state. Start with BIOS.
    self.cpu.pc = 0x0000;
    self.cpu.interrupt_mode = .{ .one = {} };
    self.cpu.iff1 = false;
    self.cpu.iff2 = false;
    self.cpu.interrupt_pending = false;
    self.rom_loaded = true;
}

/// Uses Raylib to draw the title screen by converting the slash-delimited title string
/// into separate lines. Waits for an ENTER press to continue.
fn displayTitleScreen(self: *Self, header: RomHeader) !void {
    // Allocate a buffer for the title text with '/' replaced by newline.
    var titleBuffer = try self.allocator.alloc(u8, header.titleString.len);
    for (header.titleString, 0..) |byte, i| {
        titleBuffer[i] = if (byte == 0x2F) '\n' else byte;
    }
    // Create a null-terminated string (allocate one extra byte)
    const titleString = try self.allocator.allocSentinel(u8, titleBuffer.len, 0);
    @memcpy(titleString, titleBuffer);

    std.debug.print("Showing Title Screen:\n{s}\n", .{titleString.ptr});
    // Draw the title using Raylib until an ENTER key is pressed.
    while (true) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        // Draw the text at position (50, 50) with font size 20 in white.
        rl.drawText(titleString.ptr, 50, 50, 20, rl.Color.white);
        rl.endDrawing();

        if (rl.isKeyPressed(.enter)) break;
    }

    self.allocator.free(titleString);
    self.allocator.free(titleBuffer);
}

/// Updated runFrame: if showTitle flag is true then display the title screen
/// (and, upon key press, set PC to the game start address from the header).
pub fn runFrame(self: *Self) !void {
    if (!self.bios_loaded) {
        return error.BiosNotLoaded;
    }

    var vblank = false;
    var total_cycles: u32 = 0;
    const max_cycles = 702240; // Safety limit from Gearcoleco

    const render_breakpoint = 22;
    const cycle_breakpoint = 0;

    // Run until we hit VBLANK or reach max cycles
    while (!vblank) {
        if (self.vdp_device.vdp.render_line == render_breakpoint and self.vdp_device.vdp.cycle_counter == cycle_breakpoint) {
            std.debug.print("Render line: {d} Cycle counter: {d}\n", .{
                self.vdp_device.vdp.render_line,
                self.vdp_device.vdp.cycle_counter,
            });
        }
        // Run CPU for a small number of cycles (using 1 like Gearcoleco's non-performance mode)
        const prev_cycles = self.cpu.cycle_count;
        try self.cpu.step();
        const cycles_elapsed: u32 = @intCast(self.cpu.cycle_count - prev_cycles);

        // Tick the VDP with the elapsed CPU cycles
        vblank = self.vdp_device.vdp.tick(cycles_elapsed);

        // Handle VDP interrupt request
        if (vblank and (self.vdp_device.vdp.registers[1] & 0x20) != 0) {
            self.cpu.interrupt_pending = true;
        }

        // Update total cycles and check safety limit
        total_cycles += cycles_elapsed;
        if (total_cycles > max_cycles) {
            vblank = true;
        }
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

    pub fn init(al: std.mem.Allocator, vdp: *TMS9918) !*VDPDevice {
        const device = try al.create(VDPDevice);
        device.* = .{
            .vdp = vdp,
            .io_device = .{
                .inFn = safeIn,
                .outFn = safeOut,
                .fieldParentPtr = vdp,
            },
        };
        return device;
    }

    fn in(ptr: *IODevice, port: u8) u8 {
        const tms: *TMS9918 = @ptrCast(@alignCast(ptr.fieldParentPtr.?));

        // Only check lowest bit for data vs control
        if (port & 0x01 != 0) {
            const status = tms.readStatus();
            std.debug.print("VDP Status Read: ${X:0>2}\n", .{status});
            return status;
        } else {
            const data = tms.readData();
            std.debug.print("VDP Data Read: ${X:0>2}\n", .{data});
            return data;
        }
    }

    fn out(ptr: *IODevice, port: u8, value: u8) void {
        std.debug.print("VDPDevice out: port: {d}, value: {d}\n", .{ port, value });
        const tms: *TMS9918 = @ptrCast(@alignCast(ptr.fieldParentPtr.?));

        // Only check lowest bit for data vs control
        if (port & 0x01 != 0) {
            std.debug.print("VDP Control Write: {X:0>2}\n", .{value});
            tms.writeAddress(value);
        } else {
            std.debug.print("VDP Data Write: {X:0>2}\n", .{value});
            tms.writeData(value);
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
            .width = @floatFromInt(window_width),
            .height = @floatFromInt(window_height),
        },
        .{ .x = 0, .y = 0 },
        0.0,
        rl.Color.white,
    );
}

fn getScreen(self: *TMS9918, allocator: std.mem.Allocator) ![]u8 {
    var scanline = [_]u8{0} ** TMS9918.pixels_x;
    var framebuffer = try allocator.alloc(u8, TMS9918.pixels_x * TMS9918.pixels_y * 3);

    var c: usize = 0;
    for (0..TMS9918.pixels_y) |y| {
        self.scanLine(@intCast(y), &scanline);
        for (0..TMS9918.pixels_x) |x| {
            const color = TMS9918.palette[scanline[x]];
            // Fix color component order - palette is in RGBA format (0xRRGGBBAA)
            framebuffer[c] = @intCast((color >> 0) & 0xFF); // R
            framebuffer[c + 1] = @intCast((color >> 8) & 0xFF); // G
            framebuffer[c + 2] = @intCast((color >> 16) & 0xFF); // B
            c += 3;
        }
    }
    return framebuffer;
}

pub fn safeOut(device: *IODevice, port: u8, data: u8) void {
    const vdp: *TMS9918 = @ptrCast(@alignCast(device.fieldParentPtr.?));

    // Only check lowest bit for data vs control
    if (port & 0x01 != 0) {
        std.debug.print("VDP Control Write: {X:0>2}\n", .{data});
        vdp.writeAddress(data);
    } else {
        std.debug.print("VDP Data Write: {X:0>2}\n", .{data});
        vdp.writeData(data);
    }
}

pub fn safeIn(device: *IODevice, port: u8) u8 {
    const vdp: *TMS9918 = @ptrCast(@alignCast(device.fieldParentPtr.?));

    // Only check lowest bit for data vs control
    if (port & 0x01 != 0) {
        const status = vdp.readStatus();
        std.debug.print("VDP Status Read: ${X:0>2}\n", .{status});
        std.debug.print("VDP State - Buffer: ${X:0>2} Status: ${X:0>2} Address: ${X:0>4} Line: {d} Cycles: {d}\n", .{ vdp.read_ahead_buffer, vdp.status, vdp.current_address, vdp.render_line, vdp.cycle_counter });
        return status;
    } else {
        const data = vdp.readData();
        std.debug.print("VDP Data Read: ${X:0>2}\n", .{data});
        std.debug.print("VDP State - Buffer: ${X:0>2} Status: ${X:0>2} Address: ${X:0>4} Line: {d} Cycles: {d}\n", .{ vdp.read_ahead_buffer, vdp.status, vdp.current_address, vdp.render_line, vdp.cycle_counter });
        return data;
    }
}
