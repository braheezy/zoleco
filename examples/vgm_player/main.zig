const std = @import("std");
const raylib = @import("raylib");
const SN76489 = @import("SN76489");
const Player = @import("player.zig");

const MAX_SAMPLES_PER_UPDATE = 4096;
const SAMPLE_RATE = 44100;
const BITS_PER_SAMPLE = 16;
const CHANNELS = 2; // Stereo

var globalPlayer: Player = undefined;
var globalBuffer: [MAX_SAMPLES_PER_UPDATE * CHANNELS]i16 = undefined;

// Audio callback function for raylib
fn audioCallback(buffer: ?*anyopaque, frames: c_uint) callconv(.C) void {
    const d: [*]i16 = @alignCast(@ptrCast(buffer orelse return));

    // fill buffer with audio data from player
    globalPlayer.render(d[0 .. frames * CHANNELS]);
}

pub fn main() !void {
    // Initialize raylib
    const screenWidth = 800;
    const screenHeight = 450;

    raylib.initWindow(screenWidth, screenHeight, "raylib-zig [Audio] VGM Playback Example");
    defer raylib.closeWindow();

    raylib.initAudioDevice();
    defer raylib.closeAudioDevice();

    // Allocate memory for VGM player
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Load VGM file
    var fileBuf: []const u8 = @embedFile("example.vgm");
    if (args.len > 1) {
        const file = try std.fs.cwd().openFile(args[1], .{});
        defer file.close();
        fileBuf = try file.readToEndAlloc(allocator, 0x100000);
    }

    // Initialize VGM player
    globalPlayer = try Player.init(allocator);
    defer globalPlayer.deinit();

    if (!try globalPlayer.load(fileBuf)) {
        std.debug.print("Failed to load VGM file\n", .{});
        return;
    }
    // defer allocator.free(fileBuf);

    // Free the file buffer if it was loaded from disk
    if (args.len > 1) allocator.free(fileBuf);

    // Enable playback
    globalPlayer.enable();
    std.debug.print("Playing VGM file\n", .{});

    // Initialize raylib audio stream
    const stream = try raylib.loadAudioStream(SAMPLE_RATE, BITS_PER_SAMPLE, CHANNELS);
    defer raylib.unloadAudioStream(stream);

    // Set the audio stream callback with a reference to globalPlayer
    raylib.setAudioStreamCallback(stream, &audioCallback);

    // Start playing the audio stream
    raylib.playAudioStream(stream);

    // Main loop
    while (!raylib.windowShouldClose()) {
        // Update

        // Draw
        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(raylib.Color.ray_white);

        raylib.drawText("Press 'ESC' to stop playback and exit.", 10, 10, 20, raylib.Color.dark_gray);
        raylib.drawText("Playing VGM file...", 10, 40, 20, raylib.Color.blue);
    }

    // Stop playback
    globalPlayer.stop();
    std.debug.print("Stopped playback\n", .{});
}
