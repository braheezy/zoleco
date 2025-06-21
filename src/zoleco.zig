const std = @import("std");

const Memory = @import("Memory.zig");
const Cartridge = @import("Cartridge.zig");
const Z80 = @import("z80").Z80;
const ColecoVisionIO = @import("ports.zig");
const Video = @import("video.zig").Video;
const PixelFormat = @import("video.zig").PixelFormat;
const Input = @import("Input.zig");

const resolution_width_with_overscan = @import("video.zig").resolution_width_with_overscan;
const resolution_height_with_overscan = @import("video.zig").resolution_height_with_overscan;

pub const Zoleco = struct {
    memory: *Memory = undefined,
    video: *Video = undefined,
    cpu: *Z80,
    input: *Input,
    io: *ColecoVisionIO,
    cartridge: Cartridge = .{},
    pixel_format: PixelFormat = .rgb888,
    frame_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) !*Zoleco {
        // First initialize memory
        const memory = try Memory.init(
            allocator,
            @embedFile("roms/colecovision.rom"),
            false,
        );

        // Initialize the CPU with the IO
        const z80 = try Z80.init(allocator);

        // Initialize the video system
        const video = try Video.init(allocator, z80);

        // Initialize the input system
        const input = try Input.init(allocator, z80);

        // Then initialize the IO with the properly initialized memory
        const io = try ColecoVisionIO.init(
            allocator,
            memory,
            video,
            z80,
            input,
        );

        z80.io = &io.io;

        // Put everything together
        const zoleco = try allocator.create(Zoleco);
        zoleco.* = Zoleco{
            .cpu = z80,
            .memory = memory,
            .video = video,
            .input = input,
            .io = io,
        };
        return zoleco;
    }

    pub fn deinit(self: *Zoleco, allocator: std.mem.Allocator) void {
        self.cartridge.deinit(allocator);
        self.video.deinit(allocator);
        self.memory.deinit(allocator);
        self.input.deinit(allocator);
        allocator.destroy(self.io);
        allocator.destroy(self.cpu);

        allocator.destroy(self);
    }

    pub fn runToVBlank(self: *Zoleco, framebuffer: []u8) !void {
        var vblank = false;
        var total_clocks: usize = 0;
        while (!vblank) {
            const clock_cycles = try self.cpu.runFor(1);
            self.cpu.cycle_count = 0;
            vblank = self.video.tick(clock_cycles);

            total_clocks += clock_cycles;

            if (total_clocks > 702240) {
                vblank = true;
            }
        }

        self.frame_count += 1;

        self.renderFrameBuffer(framebuffer);
    }

    fn renderFrameBuffer(self: *Zoleco, framebuffer: []u8) void {
        const size = resolution_width_with_overscan * resolution_height_with_overscan;
        const src_buffer = self.video.framebuffer;

        if (self.frame_count == 13) {
            std.log.info("frame_count: {d}\n", .{self.frame_count});
        }

        switch (self.pixel_format) {
            .rgb555, .rgb565, .bgr565, .bgr555 => {
                unreachable;
                // self.video.render16bit(src_buffer, framebuffer, self.pixel_format, size, true);
            },
            .rgb888, .bgr888 => {
                self.video.render24bit(
                    src_buffer,
                    framebuffer,
                    self.pixel_format,
                    size,
                    true,
                );
            },
        }
    }
};
