const std = @import("std");
const TMS9918 = @import("tms9918");
const rl = @import("raylib");

pub fn main() !void {
    const window_width = 800;
    const window_height = 600;
    const screen_width = 256;
    const screen_height = 192;

    rl.setTraceLogLevel(.err);

    rl.initWindow(window_width, window_height, "tms9918");
    defer rl.closeWindow();
    rl.setWindowSize(window_width, window_height);

    // Initialize audio context and player
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const default_file = @embedFile("image.bin");
    var clean_needed = false;

    var rom_bytes: []u8 = undefined;
    if (args.len >= 2) {
        // Read ROM from provided file path
        clean_needed = true;
        rom_bytes = try std.fs.cwd().readFileAlloc(allocator, args[1], 0x10000);
    } else {
        // Allocate a mutable buffer and copy the embedded data into it
        const buffer = try allocator.alloc(u8, default_file.len);
        @memcpy(buffer, default_file);
        rom_bytes = buffer;
    }
    defer allocator.free(rom_bytes);

    const vram = rom_bytes[0 .. 16 * 1024];
    const regs = rom_bytes[16 * 1024 .. rom_bytes.len];

    const emu = try TMS9918.init(allocator);
    defer emu.free(allocator);

    setRegistersFromSlice(emu, regs);
    setVramFromSlice(emu, 0, vram);

    rl.setTargetFPS(60);

    const pixels = try getScreen(emu, allocator);
    defer allocator.free(pixels);

    var rgba_pixels = try allocator.alloc(u8, screen_width * screen_height * 4);
    defer allocator.free(rgba_pixels);

    for (0..(screen_width * screen_height)) |i| {
        rgba_pixels[i * 4 + 0] = pixels[i * 3 + 0]; // R
        rgba_pixels[i * 4 + 1] = pixels[i * 3 + 1]; // G
        rgba_pixels[i * 4 + 2] = pixels[i * 3 + 2]; // B
        rgba_pixels[i * 4 + 3] = 255; // A
    }

    // Initialize Texture2D
    const texture = try rl.loadRenderTexture(screen_width, screen_height);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.blank);

        // Update the render texture with the pixel data
        rl.updateTexture(texture.texture, rgba_pixels.ptr);

        // Draw the render texture's texture to the screen
        rl.drawTexturePro(
            texture.texture,
            rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(screen_width),
                .height = @floatFromInt(screen_height),
            },
            rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(window_width),
                .height = @floatFromInt(window_height),
            },
            rl.Vector2{ .x = 0, .y = 0 },
            0.0,
            rl.Color.white,
        );
    }
}

fn setRegistersFromSlice(self: *TMS9918, regs: []u8) void {
    for (regs, 0..) |reg, i| {
        const reg_enum: TMS9918.Register = @enumFromInt(i);
        self.writeRegisterValue(reg_enum, reg);
    }
}

fn setVramFromSlice(self: *TMS9918, address: u16, data: []u8) void {
    self.setAddressWrite(address);
    self.writeBytes(data);
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
