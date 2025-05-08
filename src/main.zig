const std = @import("std");
const ColecoVisionEmulator = @import("colecovision.zig");
const rl = @import("raylib");
const emulator = @import("emulator.zig");

// Embed the default ROM
const default_rom = @embedFile("roms/hello.rom");

const App = @import("app.zig").App;

const usage =
    \\ColecoVision Emulator
    \\
    \\Usage: colecovision [options] [rom_path]
    \\
    \\Options:
    \\  -h, --help    Print this help message
    \\
    \\Arguments:
    \\  rom_path      Path to ROM file (optional, defaults to built-in hello.rom)
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var rom_file: ?[]const u8 = null;
    // Handle help flag
    if (args.len > 1) {
        const arg = args[1];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try std.io.getStdOut().writeAll(usage);
            return;
        }
        rom_file = arg;
    }
    if (rom_file == null) {
        rom_file = "src/roms/hello.rom";
    }

    var app = try App.init(allocator, rom_file.?);
    defer app.deinit(allocator);

    // try emulator.run(allocator);

    // Initialize emulator
    // var emu = try ColecoVisionEmulator.init(allocator);
    // defer emu.deinit();

    // // Load BIOS
    // try emu.loadBios();

    // Load ROM (either from file or default)
    // if (args.len > 1) {
    //     // Load ROM from file
    //     const rom_path = args[1];
    //     const rom_data = try std.fs.cwd().readFileAlloc(allocator, rom_path, 1024 * 1024); // 1MB max
    //     defer allocator.free(rom_data);
    //     try emu.loadRom(rom_data);
    // } else {
    //     // Load default ROM
    //     try emu.loadRom(default_rom);
    // }

    // const window_width = 800;
    // const window_height = 600;

    // rl.setTraceLogLevel(.err);
    // rl.initWindow(window_width, window_height, "zoleco");
    // defer rl.closeWindow();
    // rl.setWindowSize(window_width, window_height);
    // rl.setTargetFPS(60);

    // // Create texture at VDP's native resolution (256x192)
    // emu.screen_texture = try rl.loadRenderTexture(256, 192);
    // defer rl.unloadRenderTexture(emu.screen_texture);

    // // Main emulation loop
    // while (!rl.windowShouldClose()) {
    //     try emu.runFrame();

    //     rl.beginDrawing();
    //     defer rl.endDrawing();

    //     rl.clearBackground(rl.Color.blank);

    //     try emu.draw();
    //     // TODO: Add input handling
    // }
}
