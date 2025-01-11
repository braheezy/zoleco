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

    var z80 = try Z80.init(allocator, rom_data);
    defer z80.free(allocator);

    while (z80.pc < z80.memory.len) {
        // log each instruction for disassembly
        const opcode = z80.memory[z80.pc];

        switch (opcode) {
            0x00 => std.debug.print("NOP\n", .{}),
            0x3E => {
                const value = z80.memory[z80.pc + 1];
                std.debug.print("LD A, {x:>2}\n", .{value});
            },
            0xF3 => std.debug.print("DI\n", .{}),
            else => {
                std.debug.print("Cannot print: unknown opcode: {x}\n", .{opcode});
                std.process.exit(1);
            },
        }

        // Fetch and execute the next instruction
        try z80.step();
    }
}
