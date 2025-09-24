const std = @import("std");
const sdl = @import("sdl2");
const Player = @import("player.zig");

const MAX_SAMPLES_PER_UPDATE = 4096;
const SAMPLE_RATE = 44100;
const BITS_PER_SAMPLE = 16;
const CHANNELS = 2; // Stereo

var globalPlayer: Player = undefined;
var globalBuffer: [MAX_SAMPLES_PER_UPDATE * CHANNELS]i16 = undefined;

// Audio callback function for SDL
fn audioCallback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) callconv(.c) void {
    _ = userdata;
    const frames = @divExact(@as(usize, @intCast(len)), @sizeOf(i16) * CHANNELS);
    const buffer = @as([*]i16, @ptrCast(@alignCast(stream)))[0 .. frames * CHANNELS];

    // fill buffer with audio data from player
    globalPlayer.render(buffer);
}

pub fn main() !void {
    // Initialize SDL
    try sdl.init(.{
        .audio = true,
    });
    defer sdl.quit();

    // Initialize VGM player
    globalPlayer = try Player.init(std.heap.page_allocator);
    defer globalPlayer.deinit();

    // Load VGM file
    const fileBuf = @embedFile("example.vgm");
    if (!try globalPlayer.load(fileBuf)) {
        std.debug.print("Failed to load VGM file\n", .{});
        return;
    }

    // Open audio device
    const audio_device = try sdl.openAudioDevice(.{
        .device_name = null, // Use default device
        .is_capture = false,
        .desired_spec = .{
            .sample_rate = SAMPLE_RATE,
            .buffer_format = .s16_sys, // Use system's native endianness
            .channel_count = CHANNELS,
            .buffer_size_in_frames = MAX_SAMPLES_PER_UPDATE,
            .callback = audioCallback,
            .userdata = null,
        },
        .allowed_changes_from_desired = .{}, // Don't allow any changes
    });
    defer audio_device.device.close();

    // Start audio playback
    globalPlayer.enable();
    audio_device.device.pause(false);

    var in_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().readerStreaming(&in_buffer);
    const in = &stdin_reader.interface;

    // Wait for user input to quit
    std.debug.print("Playing VGM file. Press Enter to quit...\n", .{});
    _ = try in.takeByte();
}
