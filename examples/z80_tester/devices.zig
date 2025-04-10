pub const IOTestDevice = struct {
    value: u8 = 0,

    pub fn in(self: *IOTestDevice, port: u16) u8 {
        _ = port;
        return self.value;
    }

    pub fn out(self: *IOTestDevice, port: u16, value: u8) !void {
        _ = port;
        // std.debug.print("test device out: {d} {d}\n", .{ port, value });
        self.value = value;
    }
};

pub var test_io_device = IOTestDevice{};
pub fn readIOFn(port: u16) u8 {
    return test_io_device.in(port);
}
pub fn writeIOFn(port: u16, value: u8) !void {
    return test_io_device.out(port, value);
}

pub const MemoryTestDevice = struct {
    memory: [0x10000]u8 = [_]u8{0xFF} ** 0x10000,

    pub fn read(self: *MemoryTestDevice, address: u16) u8 {
        return self.memory[address];
    }

    pub fn write(self: *MemoryTestDevice, address: u16, value: u8) void {
        self.memory[address] = value;
    }
};

pub var test_memory_device = MemoryTestDevice{};
pub fn readMemoryFn(address: u16) u8 {
    return test_memory_device.read(address);
}
pub fn writeMemoryFn(address: u16, value: u8) void {
    return test_memory_device.write(address, value);
}
