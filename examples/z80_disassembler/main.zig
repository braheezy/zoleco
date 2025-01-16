const std = @import("std");
const Z80 = @import("z80");

pub fn main() !void {
    // Memory allocation setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };

    // Read arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const rom_file = if (args.len > 1)
        try std.fs.cwd().openFile(args[1], .{})
    else {
        std.log.err("No ROM file provided\n", .{});
        std.process.exit(1);
    };

    const rom_data = try rom_file.readToEndAlloc(allocator, 0x8000);
    defer allocator.free(rom_data);

    var z80 = try Z80.init(allocator, rom_data, 0x8000);
    defer z80.free(allocator);

    while (z80.pc < z80.memory.len) {
        // Fetch and execute the next instruction
        try z80.step();
    }
}
