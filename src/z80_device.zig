const std = @import("std");

const Device = @import("device.zig");
const emu = @import("emulator.zig");
const Z80 = @import("z80").Z80;
const InterruptSignal = @import("emulator.zig").InterruptSignal;

// Colecovision Z80 runs at ~3.58MHz
const clock_frequency = 3579545.0;
const max_timestemp_sec = 0.001;
const max_timestamp_steps = 3600;

// Z80 interrupt handling
fn checkInterrupt(signal: *InterruptSignal, is_requested: *bool) void {
    if (signal.* == .raise) {
        is_requested.* = true;
    } else if (signal.* == .trigger) {
        if (is_requested.*) {
            is_requested.* = false;
            signal.* = .release;
        } else {
            is_requested.* = true;
        }
    } else { // .release
        is_requested.* = false;
    }
}

const Z80Device = struct {
    z80: *Z80,
    // Interrupt signal
    int_signal: InterruptSignal = .release,
    // Non-maskable interrupt signal
    nmi_signal: InterruptSignal = .release,

    // Timing
    ticks: u64,
    ticks_halt: u64,
    extra_ticks: i32,
    secs_per_tick: f64,
    run_time_seconds: f64,

    // Device synchronization (optional if needed)
    synced_device: ?*Device,

    pub fn init(allocator: std.mem.Allocator) !Device {
        const device = Device.init("Z80");

        const z80 = try Z80.init(allocator);

        const self = try allocator.create(Z80Device);
        self.* = .{
            .z80 = z80,
            .int_signal = .release,
            .nmi_signal = .release,
            .ticks = 0,
            .ticks_halt = 0,
            .extra_ticks = 0,
            .secs_per_tick = 1.0 / clock_frequency,
            .run_time_seconds = 0.0,
            .synced_device = null,
        };

        device.data = self;
        device.reset_fn = resetZ80;
        device.destroy_fn = destroyZ80;
        device.tick_fn = tickZ80;

        return device;
    }
};

pub fn getZ80Device(device: *Device) *Z80Device {
    return @ptrCast(device.data);
}

pub fn resetZ80(self: *Device) void {
    const z80 = getZ80Device(self);
    z80.z80.reset();
    z80.ticks = 0;
    z80.run_time_seconds = 0;
}

pub fn destroyZ80(self: *Device, allocator: std.mem.Allocator) void {
    const z80 = getZ80Device(self);
    z80.z80.free(allocator);
    allocator.destroy(z80);
}

pub fn tickZ80(self: *Device, delta_ticks: u32, delta_time: f64) void {
    const z80_device = getZ80Device(self);

    // introduce a limit to the amount of time we can process in a single step
    //  to prevent a runaway condition for slow processors
    var dt = delta_ticks;
    dt += z80_device.extra_ticks;
    if (delta_time > max_timestamp_steps) {
        dt = max_timestamp_steps;
    }

    var cycles_executed: u32 = 0;

    while (dt > 0) {
        // Handle interrupts before execution using a similar pattern to HBC56
        checkInterrupt(&z80_device.int_signal, &z80_device.z80.int_requested);
        checkInterrupt(&z80_device.nmi_signal, &z80_device.z80.nmi_requested);

        // Z80-specific: Only process INT if IFF1 is enabled
        if (!z80_device.z80.iff1) {
            z80_device.z80.int_requested = false;
        }

        // Execute a single instruction
        const cycle_ticks = if (z80_device.z80.halted) 4 else blk: {
            // If CPU is not halted, execute an instruction
            if (z80_device.z80.nmi_requested) {
                z80_device.z80.nmi_requested = false;
                handleNMI(z80_device.z80);
                break :blk 11; // NMI takes 11 cycles
            } else if (z80_device.z80.int_requested and z80_device.z80.iff1) {
                z80_device.z80.int_requested = false;
                handleINT(z80_device.z80);
                // Colecovision only uses IM1 which takes 13 cycles
                break :blk 13;
            } else {
                // Execute normal instruction
                break :blk z80_device.z80.step() catch |err| {
                    std.debug.print("Z80 execution error: {}\n", .{err});
                    break :blk 4; // Default to 4 cycles on error
                };
            }
        };

        // Update timing
        z80_device.run_time_seconds += @as(f64, @floatFromInt(cycle_ticks)) * z80_device.secs_per_tick;

        cycles_executed += cycle_ticks;
        dt -= cycle_ticks;
        z80_device.ticks += cycle_ticks;

        // If we're halted, count cycles in halt
        if (z80_device.z80.halted) {
            z80_device.ticks_halt += cycle_ticks;
        }
    }

    z80_device.extra_ticks = @intCast(dt);
}

// Handler for Non-Maskable Interrupts
fn handleNMI(z80: *Z80) void {
    // Leave halt state if CPU was halted
    z80.halted = false;

    // Disable maskable interrupts (reset IFF1, preserve IFF2)
    z80.iff1 = false;
    // IFF2 remains unchanged

    // Push PC onto stack
    z80.sp -%= 2;
    z80.memory[z80.sp] = @truncate(z80.pc & 0xFF);
    z80.memory[z80.sp + 1] = @truncate(z80.pc >> 8);

    // Jump to NMI vector (0x0066)
    z80.pc = 0x0066;

    // Update WZ register for accurate emulation
    z80.wz = 0x0066;

    // Increment R register
    z80.increment_r();
}

// Handler for Maskable Interrupts - Colecovision only uses IM1
fn handleINT(z80: *Z80) void {
    // Leave halt state if CPU was halted
    z80.halted = false;

    // Disable all interrupts
    z80.iff1 = false;
    z80.iff2 = false;

    // Push PC onto stack
    z80.sp -%= 2;
    z80.memory[z80.sp] = @truncate(z80.pc & 0xFF);
    z80.memory[z80.sp + 1] = @truncate(z80.pc >> 8);

    // In IM1 (which Colecovision uses), fixed jump to 0x0038
    z80.pc = 0x0038;
    z80.wz = 0x0038;

    // Increment R register
    z80.increment_r();
}
