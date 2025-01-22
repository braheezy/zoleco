const std = @import("std");

const Hardware = @This();

in_test_data: u8 = 0,

pub fn out(self: *Hardware, port: u8, addr: u8) !void {
    _ = self;
    _ = port;
    _ = addr;
    // std.debug.print("coleco out port: {X}, data: {X}\n", .{ port, addr });
}

pub fn in(self: *Hardware, addr: u8) !u8 {
    _ = addr;
    return self.in_test_data;
}
