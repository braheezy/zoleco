const std = @import("std");
const TMS9918 = @import("TMS9918.zig");
const sdl = @import("sdl2");

pub fn main() !void {
    const window_width = 800;
    const window_height = 600;
    const screen_width = 256;
    const screen_height = 192;

    // Initialize SDL
    try sdl.init(.{
        .video = true,
    });
    defer sdl.quit();

    // Create window
    const window = try sdl.createWindow(
        "TMS9918 Viewer",
        .centered,
        .centered,
        window_width,
        window_height,
        .{},
    );
    defer window.destroy();

    // Create renderer
    const renderer = try sdl.createRenderer(window, null, .{
        .accelerated = true,
        .present_vsync = true,
    });
    defer renderer.destroy();

    // Initialize allocator and other resources
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

    // Create SDL texture
    const texture = try sdl.createTexture(
        renderer,
        .rgb24,
        .streaming,
        screen_width,
        screen_height,
    );
    defer texture.destroy();

    // Get initial screen pixels
    const pixels = try getScreen(emu, allocator);
    defer allocator.free(pixels);

    var running = true;
    while (running) {
        // Handle events
        while (sdl.pollEvent()) |ev| {
            switch (ev) {
                .quit => running = false,
                .key_down => |key| {
                    if (key.scancode == .escape) {
                        running = false;
                    }
                },
                else => {},
            }
        }

        // Clear screen
        try renderer.setColorRGB(0, 0, 0);
        try renderer.clear();

        // Update texture with pixel data
        try texture.update(pixels, screen_width * 3, null);

        // Calculate destination rectangle to maintain aspect ratio
        const dest_rect = calculateAspectRatioRect(window_width, window_height, screen_width, screen_height);

        // Render the texture
        try renderer.copy(texture, null, dest_rect);
        renderer.present();

        // Cap to ~60 FPS
        sdl.delay(16);
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

fn calculateAspectRatioRect(window_w: i32, window_h: i32, texture_w: i32, texture_h: i32) sdl.Rectangle {
    const window_aspect = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));
    const texture_aspect = @as(f32, @floatFromInt(texture_w)) / @as(f32, @floatFromInt(texture_h));

    var dest_rect: sdl.Rectangle = undefined;
    if (window_aspect > texture_aspect) {
        dest_rect.height = window_h;
        dest_rect.width = @intFromFloat(@as(f32, @floatFromInt(window_h)) * texture_aspect);
        dest_rect.x = @divExact(window_w - dest_rect.width, 2);
        dest_rect.y = 0;
    } else {
        dest_rect.width = window_w;
        dest_rect.height = @intFromFloat(@as(f32, @floatFromInt(window_w)) / texture_aspect);
        dest_rect.x = 0;
        dest_rect.y = @divExact(window_h - dest_rect.height, 2);
    }
    return dest_rect;
}
