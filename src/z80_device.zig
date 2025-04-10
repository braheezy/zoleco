const std = @import("std");

const Device = @import("device.zig");
const emu = @import("emulator.zig");
const Z80 = @import("z80").Z80;
const InterruptSignal = @import("emulator.zig").InterruptSignal;
const mem_device = @import("memory_device.zig");
const Memory = mem_device.Memory;
const IOReadFn = @import("z80").IOReadFn;
const IOWriteFn = @import("z80").IOWriteFn;
const MemoryReadFn = @import("z80").MemoryReadFn;
const MemoryWriteFn = @import("z80").MemoryWriteFn;

// Colecovision Z80 runs at ~3.58MHz
const clock_frequency = 3579545.0;
const max_timestemp_sec = 0.001;
const max_timestamp_steps = 3600;

const bios_start: usize = 0x0000;
const bios_size: usize = 0x2000;

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

pub const Z80Device = struct {
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

    pub fn init(
        allocator: std.mem.Allocator,
        read_fn: IOReadFn,
        write_fn: IOWriteFn,
        memory_read_fn: MemoryReadFn,
        memory_write_fn: MemoryWriteFn,
    ) !*Z80Device {
        // Create the Z80 on the heap instead of the stack
        const z80_ptr = try allocator.create(Z80);
        z80_ptr.* = try Z80.init(
            read_fn,
            write_fn,
            memory_read_fn,
            memory_write_fn,
        );

        const self = try allocator.create(Z80Device);
        self.* = .{
            .z80 = z80_ptr,
            .int_signal = .release,
            .nmi_signal = .release,
            .ticks = 0,
            .ticks_halt = 0,
            .extra_ticks = 0,
            .secs_per_tick = 1.0 / clock_frequency,
            .run_time_seconds = 0.0,
        };

        return self;
    }

    pub fn loadBios(self: *Z80Device) void {
        const bios_data = @embedFile("roms/colecovision.rom");
        @memcpy(self.z80.memory[bios_start..(bios_start + bios_size)], bios_data);
    }

    pub fn tick(self: *Z80Device, delta_ticks: u32, delta_time: f64) void {

        // introduce a limit to the amount of time we can process in a single step
        //  to prevent a runaway condition for slow processors
        var dt = delta_ticks;
        dt += @intCast(self.extra_ticks);
        if (delta_time > max_timestamp_steps) {
            dt = max_timestamp_steps;
        }

        var cycles_executed: u32 = 0;

        while (dt > 0) {
            // Handle interrupts before execution using a similar pattern to HBC56
            checkInterrupt(&self.int_signal, &self.z80.int_requested);
            checkInterrupt(&self.nmi_signal, &self.z80.nmi_requested);

            // Z80-specific: Only process INT if IFF1 is enabled
            if (!self.z80.iff1) {
                self.z80.int_requested = false;
            }

            // Execute a single instruction
            const cycle_ticks = if (self.z80.halted) 4 else blk: {
                // If CPU is not halted, execute an instruction
                if (self.z80.nmi_requested) {
                    self.z80.nmi_requested = false;
                    handleNMI(self.z80);
                    break :blk 11; // NMI takes 11 cycles
                } else if (self.z80.int_requested and self.z80.iff1) {
                    self.z80.int_requested = false;
                    handleINT(self.z80);
                    // Colecovision only uses IM1 which takes 13 cycles
                    break :blk 13;
                } else {
                    // Execute normal instruction
                    break :blk self.z80.step() catch |err| {
                        std.debug.print("Z80 execution error: {}\n", .{err});
                        break :blk 4; // Default to 4 cycles on error
                    };
                }
            };

            // Update timing
            self.run_time_seconds += @as(f64, @floatFromInt(cycle_ticks)) * self.secs_per_tick;

            cycles_executed += @intCast(cycle_ticks);
            if (cycle_ticks > dt) {
                dt = 0;
            } else {
                dt -= @intCast(cycle_ticks);
            }
            self.ticks += cycle_ticks;

            // If we're halted, count cycles in halt
            if (self.z80.halted) {
                self.ticks_halt += cycle_ticks;
            }
        }

        self.extra_ticks = @intCast(dt);
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
    allocator.destroy(z80.z80); // Free the Z80 struct
    allocator.destroy(z80);
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
    z80.memory_write_fn(z80.sp, @truncate(z80.pc & 0xFF));
    z80.memory_write_fn(z80.sp + 1, @truncate(z80.pc >> 8));

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
    z80.memory_write_fn(z80.sp, @truncate(z80.pc & 0xFF));
    z80.memory_write_fn(z80.sp + 1, @truncate(z80.pc >> 8));

    // In IM1 (which Colecovision uses), fixed jump to 0x0038
    z80.pc = 0x0038;
    z80.wz = 0x0038;

    // Increment R register
    z80.increment_r();
}
