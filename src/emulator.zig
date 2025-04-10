const std = @import("std");
const rl = @import("raylib");
const Device = @import("device.zig");
const Z80Device = @import("z80_device.zig").Z80Device;
const Memory = @import("memory_device.zig").Memory;
const TMS9918Device = @import("tms9918_device.zig").TMS9918Device;

// Memory map constants
const bios_start: usize = 0x0000;
const bios_size: usize = 0x2000;

pub const InterruptSignal = enum {
    release,
    raise,
    trigger,
};

pub fn interrupt(signal: InterruptSignal) void {
    _ = signal;
}

var video_device: *TMS9918Device = undefined;
var cpu_device: *Z80Device = undefined;
var memory_device: *Memory = undefined;

pub fn ioRead(port: u16) u8 {
    const region = port & 0xE0;
    switch (region) {
        0xA0 => {
            if ((port & 0x01) != 0) {
                return video_device.tms9918.readStatus();
            } else {
                return video_device.tms9918.readData();
            }
        },
        0xE0 => {
            std.debug.print("ioRead (input): {}\n", .{port});
            // return input.read(port)
        },
        else => return 0xFF,
    }
    return 0xFF;
}
pub fn ioWrite(port: u16, value: u8) !void {
    const region = port & 0xE0;
    switch (region) {
        0xA0 => {
            if ((port & 0x01) != 0) {
                video_device.tms9918.writeAddress(value);
            } else {
                video_device.tms9918.writeData(value);
            }
        },
        0xE0 => {
            // Stub: call audio routine if needed
            std.debug.print("ioWrite (audio): {}\n", .{value});
            // audio.writeRegister(value);
        },
        else => {
            // Optionally log or ignore writes to other ports.
        },
    }
}
pub fn run(allocator: std.mem.Allocator) !void {
    const window_width = 800;
    const window_height = 600;

    rl.setTraceLogLevel(.err);
    rl.initWindow(window_width, window_height, "zoleco");
    defer rl.closeWindow();
    rl.setWindowSize(window_width, window_height);
    rl.setTargetFPS(60);

    // Initialize devices
    memory_device = try Memory.init(allocator, @embedFile("roms/colecovision.rom"));
    memory_device.loadRom(@embedFile("roms/hello.rom"));
    video_device = try TMS9918Device.init(allocator, 0xA0, 0xA1);
    cpu_device = try Z80Device.init(
        allocator,
        ioRead,
        ioWrite,
        readMemoryFn,
        writeMemoryFn,
    );

    // Set up cleanup when function exits
    defer {
        // Free Z80 emulator resources
        const z80_cpu = cpu_device.z80;
        allocator.destroy(z80_cpu);
        allocator.destroy(cpu_device);

        // Free TMS9918 resources
        video_device.tms9918.free(allocator);
        allocator.destroy(video_device);

        // Free memory resources
        allocator.free(memory_device.bios);
        allocator.free(memory_device.ram);
        allocator.destroy(memory_device);
    }

    while (!rl.windowShouldClose()) {
        loop();
    }
}

// the main loop. will be called many times per frame
var last_time: f64 = 0.0;
var tick_count: usize = 0;
var delta_time: f64 = 0.0;
var delta_ticks: u32 = 0;

fn loop() void {
    tick();

    tick_count += 1;

    render();

    // handleInput();
}

fn tick() void {
    const current_time = rl.getTime();
    delta_time = @floatCast(current_time - last_time);
    last_time = current_time;

    // Calculate delta ticks (simulating SDL ticks)
    delta_ticks = @intFromFloat(delta_time * 1000.0);

    cpu_device.tick(delta_ticks, delta_time);
    video_device.tick(delta_ticks, delta_time);
}

fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(rl.Color.blank);

    video_device.render();
}
pub fn readMemoryFn(address: u16) u8 {
    return memory_device.read(address);
}
pub fn writeMemoryFn(address: u16, value: u8) void {
    return memory_device.write(address, value);
}
