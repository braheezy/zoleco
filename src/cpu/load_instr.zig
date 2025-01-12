const std = @import("std");
const Z80 = @import("Z80.zig");

const getHighByte = @import("opcode.zig").getHighByte;
const getLowByte = @import("opcode.zig").getLowByte;

const OpcodeTable = @import("opcode.zig").OpcodeTable;

pub fn pushIy(self: *Z80) void {
    self.sp = if (self.sp == 0) 0xFFFF else self.sp - 1;
    self.memory[self.sp] = getHighByte(self.iy);

    self.sp = if (self.sp == 0) 0xFFFF else self.sp - 1;
    self.memory[self.sp] = getLowByte(self.iy);

    self.cycle_count += 15;
}

test "pushIy correctly pushes IY to the stack" {
    const allocator = std.testing.allocator;

    var z80 = try Z80.init(std.testing.allocator, &[_]u8{0x1});
    defer z80.free(allocator);

    // Set initial state
    z80.sp = 0xFFFE; // Example stack pointer position
    z80.iy = 0x1234; // Example IY register value
    const original_sp = z80.sp;
    const original_cycle_count = z80.cycle_count;

    // Perform the operation
    pushIy(&z80);

    // Verify SP was decremented correctly
    try std.testing.expect(z80.sp == original_sp - 2);

    // Verify memory contains the pushed IY value
    try std.testing.expect(z80.memory[original_sp - 1] == 0x12); // High byte
    try std.testing.expect(z80.memory[original_sp - 2] == 0x34); // Low byte

    // Verify cycle count
    try std.testing.expect(z80.cycle_count == original_cycle_count + 15);
}
