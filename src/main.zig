const std = @import("std");
const App = @import("app.zig").App;

const usage =
    \\zoleco: A ColecoVision emulator
    \\
    \\Usage: zoleco [options] [rom_path]
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

    try app.loop();
}
