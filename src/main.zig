// const std = @import("std");

// const SN76489 = @import("SN76489.zig");
// const sysaudio = @import("mach").sysaudio;
// const VGM = @import("VGM.zig");

// var player: sysaudio.Player = undefined;
// var emulator: SN76489 = undefined;

// var vgm_commands: []const VGM.CommandEntry = undefined;
// var command_index: usize = 0;
// var wait_samples: usize = 0;

// pub fn writeCommandsToFile(
//     command_list: []const VGM.CommandEntry,
//     output_path: []const u8,
// ) !void {
//     // Open the output text file
//     var output_file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
//     defer output_file.close();

//     var writer = output_file.writer();

//     // Write commands and their data to the file
//     for (command_list) |command_entry| {
//         if (command_entry.data == null) {
//             continue;
//         }

//         for (command_entry.data.?) |byte| {
//             try writer.print("{x:0>2}", .{byte});
//         }

//         try writer.writeAll("\n");
//     }

//     std.debug.print("Commands written to {s}\n", .{output_path});
// }

// pub fn main() !void {
//     // Memory allocation setup
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     defer if (gpa.deinit() == .leak) {
//         std.process.exit(1);
//     };

//     const input_path = "example.vgm";

//     var input_file = try std.fs.cwd().openFile(input_path, .{});
//     defer input_file.close();

//     var stream = std.io.StreamSource{ .file = input_file };

//     const vgm_decoder = try VGM.decode(allocator, &stream);
//     defer {
//         for (vgm_decoder.commands) |command| {
//             if (command.data) |d| allocator.free(d);
//         }
//         allocator.free(vgm_decoder.commands);
//     }

//     vgm_commands = vgm_decoder.commands;
//     try writeCommandsToFile(vgm_commands, "commands-zig.txt");

//     emulator = try SN76489.init(3579545, 44100);

//     emulator.set_quality(true);

//     var ctx = try sysaudio.Context.init(null, allocator, .{});
//     defer ctx.deinit();
//     try ctx.refresh();

//     const device = ctx.defaultDevice(.playback) orelse return error.NoDevice;
//     player = try ctx.createPlayer(
//         device,
//         writeCallback,
//         .{ .sample_rate = 44100 },
//     );
//     defer player.deinit();

//     try player.start();

//     while (true) {
//         // std.Thread.sleep(100_000_000_00); // Prevent tight loop
//     }
// }

// fn writeCallback(_: ?*anyopaque, output: []u8) void {
//     const frame_size = player.format().frameSize(@intCast(player.channels().len));

//     var i: usize = 0;
//     var src: [16]i16 = undefined;

//     while (i < output.len) : (i += frame_size) {
//         // Handle wait_samples if set
//         if (wait_samples > 0) {
//             wait_samples -= 1;
//             return;
//         } else {
//             // Process commands
//             while (command_index < vgm_commands.len) {
//                 const command = vgm_commands[command_index];
//                 command_index += 1;

//                 switch (command.command) {
//                     // 0x4F, 0x50: Simple data commands
//                     0x4F, 0x50 => {
//                         emulator.write(command.data.?[0]);
//                     },

//                     // 0x51-0x54: Two-byte register writes
//                     0x51, 0x52, 0x53, 0x54 => {
//                         emulator.write(command.data.?[0]); // Register
//                         emulator.write(command.data.?[1]); // Value

//                     },

//                     // 0x61: Wait n samples
//                     0x61 => {
//                         wait_samples = @as(usize, command.data.?[0]) |
//                             (@as(usize, command.data.?[1]) << 8);

//                         break; // Exit the command loop and let samples generate
//                     },

//                     // 0x62, 0x63: Fixed waits (735 or 882 samples)
//                     0x62 => {
//                         wait_samples = 735;

//                         break;
//                     },
//                     0x63 => {
//                         wait_samples = 882;

//                         break;
//                     },

//                     // 0x70–0x7F: Wait n+1 samples
//                     0x70...0x7F => {
//                         wait_samples = (command.command & 0x0F) + 1;

//                         break;
//                     },

//                     // 0x80–0x8F: YM2612 port 0 write, then wait n samples
//                     0x80...0x8F => {
//                         emulator.write(0x2A); // YM2612 port 0 address 2A
//                         wait_samples = (command.command & 0x0F);
//                         break;
//                     },

//                     // 0x66: End of VGM data
//                     0x66 => {
//                         std.debug.print("End of VGM commands\n", .{});
//                         return;
//                     },

//                     else => {
//                         std.debug.print("Unhandled command: {X}\n", .{command.command});
//                     },
//                 }
//             }
//         }

//         // Generate audio sample from emulator
//         const sample = emulator.calc();

//         std.debug.print("sample: {d}\n", .{sample});

//         // Fill all channels in the audio frame
//         for (0..player.channels().len) |ch| {
//             src[ch] = @as(i16, sample * 2);
//         }

//         sysaudio.convertTo(
//             i16,
//             src[0..player.channels().len],
//             player.format(),
//             output[i..][0..frame_size],
//         );
//     }
// }

const std = @import("std");
const sysaudio = @import("mach").sysaudio;
const SN76489 = @import("SN76489.zig");
const Player = @import("player.zig");

var player: sysaudio.Player = undefined;
var vgmPlayer: Player = undefined;

pub fn main() !void {
    // Initialize audio context and player
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var ctx = try sysaudio.Context.init(null, gpa.allocator(), .{});
    defer ctx.deinit();
    try ctx.refresh();

    const device = ctx.defaultDevice(.playback) orelse return error.NoDevice;
    player = try ctx.createPlayer(device, writeCallback, .{});
    defer player.deinit();
    try player.start();

    // Load the VGM file
    const vgmFilePath = "example.vgm";
    const file = try std.fs.cwd().openFile(vgmFilePath, .{});
    defer file.close();

    const fileBuffer = try file.readToEndAlloc(gpa.allocator(), 1000000);
    defer gpa.allocator().free(fileBuffer);

    vgmPlayer = Player.init();
    if (!vgmPlayer.load(fileBuffer)) {
        std.debug.print("Failed to load VGM file: {s}\n", .{vgmFilePath});
        return;
    }

    // Start playback
    vgmPlayer.play();
    std.debug.print("Playing VGM file: {s}\n", .{vgmFilePath});

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

fn writeCallback(_: ?*anyopaque, output: []u8) void {
    const frame_size = player.format().frameSize(@intCast(player.channels().len));
    const frames = output.len / frame_size;

    var buf = std.heap.page_allocator.alloc(f32, frames) catch unreachable;
    defer std.heap.page_allocator.free(buf);

    // Render audio samples from the VGM emulator
    vgmPlayer.render(buf[0..frames]);

    // Convert rendered samples to the audio format
    var src: [16]f32 = undefined;
    for (0..frames) |i| {
        for (0..player.channels().len) |ch| src[ch] = buf[i];
        sysaudio.convertTo(
            f32,
            src[0..player.channels().len],
            player.format(),
            output[i * frame_size ..][0..frame_size],
        );
    }
}
