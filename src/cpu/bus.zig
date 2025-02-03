const std = @import("std");

/// Represents a device that can handle I/O operations
pub const IODevice = struct {
    // Opaque pointer to the device's context/state
    context: *anyopaque,

    // Function pointers for I/O operations
    in_fn: *const fn (context: *anyopaque, port: u16) u8,
    out_fn: *const fn (context: *anyopaque, port: u16, value: u8) void,

    /// Creates an IODevice instance for a given device type T
    pub fn init(
        context: anytype,
        comptime in_func: fn (context: @TypeOf(context), port: u16) u8,
        comptime out_func: fn (context: @TypeOf(context), port: u16, value: u8) void,
    ) IODevice {
        return .{
            .context = @ptrCast(context),
            .in_fn = @ptrCast(&in_func),
            .out_fn = @ptrCast(&out_func),
        };
    }

    /// Performs an input operation on the device
    pub fn in(self: IODevice, port: u16) u8 {
        return self.in_fn(self.context, port);
    }

    /// Performs an output operation on the device
    pub fn out(self: IODevice, port: u16, value: u8) void {
        self.out_fn(self.context, port, value);
    }
};

/// The main bus that connects the CPU to various devices
pub const Bus = struct {
    devices: std.ArrayList(IODevice),
    allocator: std.mem.Allocator,

    /// Creates a new bus instance
    pub fn init(allocator: std.mem.Allocator) Bus {
        return .{
            .devices = std.ArrayList(IODevice).init(allocator),
            .allocator = allocator,
        };
    }

    /// Cleans up bus resources
    pub fn deinit(self: *Bus) void {
        self.devices.deinit();
    }

    /// Adds a device to the bus
    pub fn addDevice(self: *Bus, device: IODevice) !void {
        try self.devices.append(device);
    }

    /// Reads a value from a port
    pub fn in(self: *Bus, port: u16) !u8 {
        // For now, just try each device
        // TODO: Implement proper port mapping/routing
        for (self.devices.items) |device| {
            return device.in(port);
        }
        // If no device responds, return 0xFF (or another suitable default)
        return 0xFF;
    }

    /// Writes a value to a port
    pub fn out(self: *Bus, port: u16, value: u8) !void {
        // For now, broadcast to all devices
        // TODO: Implement proper port mapping/routing
        for (self.devices.items) |device| {
            device.out(port, value);
        }
    }
};

/// Test device for verifying bus functionality
const TestDevice = struct {
    value: u8 = 0,

    fn in(self: *TestDevice, port: u16) u8 {
        _ = port;
        return self.value;
    }

    fn out(self: *TestDevice, port: u16, value: u8) void {
        _ = port;
        self.value = value;
    }
};

test "basic bus operations" {
    const allocator = std.testing.allocator;
    var bus = Bus.init(allocator);
    defer bus.deinit();

    var test_device = TestDevice{};
    const device = IODevice.init(
        &test_device,
        TestDevice.in,
        TestDevice.out,
    );

    try bus.addDevice(device);

    // Test writing and reading back a value
    bus.out(0, 0x42);
    try std.testing.expectEqual(@as(u8, 0x42), bus.in(0));
}
