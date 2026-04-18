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

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Get command line arguments
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var rom_file: ?[]const u8 = null;
    // Handle help flag
    if (args.len > 1) {
        const arg = args[1];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try stdout.writeAll(usage);
            try stdout.flush();
            return;
        }
        rom_file = arg;
    }
    if (rom_file == null) {
        rom_file = "src/roms/hello.rom";
    }

    var app = try App.init(init.io, allocator, rom_file.?);
    defer app.deinit(allocator);

    try app.loop();
}
