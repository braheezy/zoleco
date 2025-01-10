const std = @import("std");
const sysaudio = @import("mach").sysaudio;
const SN76489 = @import("SN76489");
const Player = @import("player.zig");

var player: sysaudio.Player = undefined;
var vgmPlayer: Player = undefined;

pub fn main() !void {
    // Initialize audio context and player
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };

    // parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var fileBuf: []const u8 = @embedFile("pickupCoin0.vgm");
    if (args.len > 1) {
        const file = try std.fs.cwd().openFile(args[1], .{});
        defer file.close();
        fileBuf = try file.readToEndAlloc(allocator, 0x100000);
    }

    // setup context and device
    var ctx = try sysaudio.Context.init(null, allocator, .{});
    defer ctx.deinit();
    try ctx.refresh();
    const device = ctx.defaultDevice(.playback) orelse return error.NoDevice;

    // setup player
    player = try ctx.createPlayer(device, writeCallback, .{});
    defer player.deinit();
    try player.start();

    // vgmPlayer parses a VGM file for commands to drive the sound chip with.
    vgmPlayer = try Player.init(allocator);
    if (!try vgmPlayer.load(fileBuf)) {
        std.debug.print("Failed to load VGM file\n", .{});
        return;
    }
    // now we can free, but only if we allocated for a user-provided file
    if (args.len > 1) allocator.free(fileBuf);

    // Enable playback
    vgmPlayer.enable();
    std.debug.print("Playing VGM file\n", .{});

    // Loop until user exits
    var buf: [16]u8 = undefined;
    std.log.info("Enter 'exit' to stop playback...", .{});
    while (true) {
        const line = (try std.io.getStdIn().reader().readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        if (std.mem.eql(u8, std.mem.trimRight(u8, line, &std.ascii.whitespace), "exit")) break;
    }

    // Stop playback
    vgmPlayer.stop();
    std.debug.print("Stopped playback\n", .{});
}

// gets called by sysaudio when it needs more audio data. we need to give it audio samples
fn writeCallback(_: ?*anyopaque, output: []u8) void {
    const frame_size = player.format().frameSize(@intCast(player.channels().len));
    const frames = output.len / frame_size;

    var buf = std.heap.page_allocator.alloc(i16, frames) catch unreachable;
    defer std.heap.page_allocator.free(buf);

    // Render audio samples from the VGM emulator
    vgmPlayer.render(buf[0..frames]);

    // Convert rendered samples to the audio format
    var src: [16]i16 = undefined;
    for (0..frames) |i| {
        for (0..player.channels().len) |ch| src[ch] = buf[i];
        sysaudio.convertTo(
            i16,
            src[0..player.channels().len],
            player.format(),
            output[i * frame_size ..][0..frame_size],
        );
    }
}
