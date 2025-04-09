const std = @import("std");

/// Represents a device that can handle I/O operations
pub const IODevice = struct {
    fieldParentPtr: ?*anyopaque = null,
    inFn: *const fn (ptr: *IODevice, port: u8) u8,
    outFn: *const fn (ptr: *IODevice, port: u8, value: u8) void,
    cycles_penalty: u32 = 0, // Track cycles added by I/O operations

    /// Creates an IODevice instance for a given device type T
    pub fn init(
        al: std.mem.Allocator,
        context: anytype,
        in_fn: *const fn (@TypeOf(context), port: u8) u8,
        out_fn: *const fn (@TypeOf(context), port: u8, value: u8) void,
    ) !*IODevice {
        const Ptr = @TypeOf(context);
        const ptr_info = @typeInfo(Ptr);
        if (ptr_info != .Pointer) @compileError("context must be a pointer");

        const device = try al.create(IODevice);
        device.* = .{
            .fieldParentPtr = @ptrCast(context),
            .inFn = @ptrCast(&in_fn),
            .outFn = @ptrCast(&out_fn),
            .cycles_penalty = 0,
        };
        return device;
    }

    /// Performs an input operation on the device
    pub fn in(self: *IODevice, port: u8) u8 {
        return self.inFn(self, port);
    }

    /// Performs an output operation on the device
    pub fn out(self: *IODevice, port: u8, value: u8) void {
        self.outFn(self, port, value);
    }

    /// Gets and clears the cycle penalty
    pub fn getCyclesPenalty(self: *IODevice) u32 {
        const penalty = self.cycles_penalty;
        self.cycles_penalty = 0;
        return penalty;
    }
};

/// The main bus that connects the CPU to various devices
pub const Bus = struct {
    devices: std.ArrayList(*IODevice),
    allocator: std.mem.Allocator,
    cycles_penalty: u32 = 0, // Track total cycles added by I/O operations

    // Port masks for different device types
    const PORT_MASK = 0xE0;
    const PORT_VDP = 0xA0;
    const PORT_AUDIO = 0xE0;
    const PORT_INPUT_RIGHT = 0x80;
    const PORT_INPUT_LEFT = 0xC0;

    // Cycle penalties for different operations
    const AUDIO_PORT_PENALTY = 32;

    /// Creates a new bus instance
    pub fn init(allocator: std.mem.Allocator) !*Bus {
        const bus = try allocator.create(Bus);
        bus.* = .{
            .devices = std.ArrayList(*IODevice).init(allocator),
            .allocator = allocator,
            .cycles_penalty = 0,
        };
        return bus;
    }

    /// Cleans up bus resources
    pub fn deinit(self: *Bus) void {
        self.devices.deinit();
    }

    /// Adds a device to the bus
    pub fn addDevice(self: *Bus, device: *IODevice) !void {
        try self.devices.append(device);
    }

    /// Gets and clears the cycle penalty
    pub fn getCyclesPenalty(self: *Bus) u32 {
        const penalty = self.cycles_penalty;
        self.cycles_penalty = 0;
        return penalty;
    }

    /// Reads a value from a port
    pub fn in(self: *Bus, port: u8) !u8 {
        // const masked_port = port & PORT_MASK;

        // // Route to appropriate device based on port range
        // for (self.devices.items) |device| {
        //     switch (masked_port) {
        //         PORT_VDP => {
        //             // VDP ports (0xA0-0xBF)
        //             const value = device.in(port);
        //             self.cycles_penalty += device.getCyclesPenalty();
        //             return value;
        //         },
        //         PORT_AUDIO => {
        //             // Audio ports (0xE0-0xFF)
        //             self.cycles_penalty += AUDIO_PORT_PENALTY;
        //             return 0xFF; // TODO: Implement audio
        //         },
        //         PORT_INPUT_RIGHT => {
        //             // Input right ports (0x80-0x9F)
        //             return 0xFF; // TODO: Implement input
        //         },
        //         PORT_INPUT_LEFT => {
        //             // Input left ports (0xC0-0xDF)
        //             return 0xFF; // TODO: Implement input
        //         },
        //         else => {
        //             // Handle special ports
        //             switch (port) {
        //                 0x50, 0x51, 0x53, 0x7F => {
        //                     // SGM ports
        //                     return 0xFF; // TODO: Implement SGM
        //                 },
        //                 else => {
        //                     // std.debug.print("--> ** Unhandled input port ${X:0>2}\n", .{port});
        //                     return 0xFF;
        //                 },
        //             }
        //         },
        //     }
        // }
        // return 0xFF;
        _ = port;
        _ = self;
        return 0;
    }

    /// Writes a value to a port
    pub fn out(self: *Bus, port: u8, value: u8) !void {
        const masked_port = port & PORT_MASK;

        // Route to appropriate device based on port range
        for (self.devices.items) |device| {
            switch (masked_port) {
                PORT_VDP => {
                    // VDP ports (0xA0-0xBF)
                    device.out(port, value);
                    self.cycles_penalty += device.getCyclesPenalty();
                    return;
                },
                PORT_AUDIO => {
                    // Audio ports (0xE0-0xFF)
                    self.cycles_penalty += AUDIO_PORT_PENALTY;
                    // TODO: Implement audio device
                    return;
                },
                PORT_INPUT_RIGHT => {
                    // Input right ports (0x80-0x9F)
                    // TODO: Implement input device
                    return;
                },
                PORT_INPUT_LEFT => {
                    // Input left ports (0xC0-0xDF)
                    // TODO: Implement input device
                    return;
                },
                else => {
                    // Handle special ports
                    switch (port) {
                        0x50 => {
                            // SGM Register
                            return;
                        },
                        0x51 => {
                            // SGM Write
                            return;
                        },
                        0x53 => {
                            // Enable SGM Upper
                            return;
                        },
                        0x7F => {
                            // Enable SGM Lower
                            return;
                        },
                        else => {
                            // std.debug.print("--> ** Unhandled output port ${X:0>2}: {X:0>2}\n", .{ port, value });
                            return;
                        },
                    }
                },
            }
        }
    }
};

// Test device for verifying bus functionality
pub const TestDevice = struct {
    value: u8 = 0,

    pub fn in(self: *TestDevice, port: u16) u8 {
        _ = port;
        return self.value;
    }

    pub fn out(self: *TestDevice, port: u16, value: u8) void {
        // _ = port;
        std.debug.print("test device out: {d} {d}\n", .{ port, value });
        self.value = value;
    }
};

// test "basic bus operations" {
//     const allocator = std.testing.allocator;
//     var bus = Bus.init(allocator);
//     defer bus.deinit();

//     var test_device = TestDevice{};
//     const device = IODevice.init(
//         &test_device,
//         TestDevice.in,
//         TestDevice.out,
//     );

//     try bus.addDevice(device);

//     // Test writing and reading back a value
//     bus.out(0, 0x42);
//     try std.testing.expectEqual(@as(u8, 0x42), bus.in(0));
// }
