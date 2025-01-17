const std = @import("std");
const Z80 = @import("Z80.zig");

// STAX B: Store accumulator in 16-bit immediate address pointed to by register pair BC
pub fn stax_B(self: *Z80) !void {
    const address = Z80.toUint16(self.register.b, self.register.c);
    std.log.debug("[02]\tLD  \t(BC),A", .{});
    self.memory[address] = self.register.a;
}
