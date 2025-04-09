const std = @import("std");
const rl = @import("raylib");
const Device = @import("device.zig");
const Z80Device = @import("z80_device.zig").Z80Device;

// Memory map constants
const bios_start: usize = 0x0000;
const bios_size: usize = 0x2000;

const InterruptSignal = enum {
    release,
    raise,
    trigger,
};

pub fn interrupt(signal: InterruptSignal) void {
    _ = signal;
}

const Emulator = struct {
    rom_loaded: bool = false,
};

pub fn run(allocator: std.mem.Allocator) void {
    const window_width = 800;
    const window_height = 600;

    rl.setTraceLogLevel(.err);
    rl.initWindow(window_width, window_height, "zoleco");
    defer rl.closeWindow();
    rl.setWindowSize(window_width, window_height);
    rl.setTargetFPS(60);

    const cpu_device = try Z80Device.init(allocator);
    cpu_device.loadBios();

    // const emulator = Emulator{};
}
