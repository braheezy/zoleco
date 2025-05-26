const std = @import("std");

const Memory = @import("memory_device.zig").Memory;
const Cartridge = @import("Cartridge.zig");
const Z80 = @import("z80").Z80;
const ColecoVisionIO = @import("ports.zig");
const Video = @import("video.zig").Video;
const PixelFormat = @import("video.zig").PixelFormat;

const resolution_width_with_overscan = @import("video.zig").resolution_width_with_overscan;
const resolution_height_with_overscan = @import("video.zig").resolution_height_with_overscan;

pub const Zoleco = struct {
    memory: *Memory = undefined,
    video: *Video = undefined,
    cpu: *Z80,
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

        // Then initialize the IO with the properly initialized memory
        const io = try ColecoVisionIO.init(
            allocator,
            memory,
            video,
            z80,
        );

        z80.io = &io.io;

        // Put everything together
        const zoleco = try allocator.create(Zoleco);
        zoleco.* = Zoleco{
            .cpu = z80,
            .memory = memory,
            .video = video,
            .io = io,
        };
        return zoleco;
    }

    pub fn deinit(self: *Zoleco, allocator: std.mem.Allocator) void {
        std.log.info("Deiniting Zoleco", .{});
        self.cartridge.deinit(allocator);
        self.video.deinit(allocator);
        self.memory.deinit(allocator);
        allocator.destroy(self.io);
        allocator.destroy(self.cpu);

        allocator.destroy(self);
    }

    pub fn runToVBlank(self: *Zoleco, framebuffer: []u8) !void {
        var vblank = false;
        var total_clocks: usize = 0;
        while (!vblank) {
            // const opcode = self.cpu.nextOpcode();
            // std.debug.print("opcode: {X}\n", .{opcode});
            // if (self.frame_count == 11 and self.video.render_line == 129 and self.video.cycle_counter == 215) {
            //     std.debug.print("frame_count: {d}\n", .{self.frame_count});
            // }

            const clock_cycles = try self.cpu.runFor(1);
            vblank = self.video.tick(clock_cycles);

            total_clocks += clock_cycles;

            if (total_clocks > 702240) {
                vblank = true;
            }
        }

        self.frame_count += 1;

        if (self.frame_count == 12) {
            std.debug.print("frame_count: {d}\n", .{self.frame_count});
            // print vram contents from address 00e0 through 038f
            // for (0..0x33f) |i| {
            //     const addr: usize = 0x00e0 + i;
            //     const value = self.video.vram[addr];
            //     std.debug.print("{X} ", .{value});
            //     // newline after 16 digits have been printed
            //     if (i % 16 == 15) {
            //         std.debug.print("\n", .{});
            //     }
            // }
            // std.debug.print("\n", .{});

            // Debug: Check video state and framebuffer
            std.debug.print("Video debug info:\n", .{});
            std.debug.print("  Display enabled: {}\n", .{self.video.display_enabled});
            std.debug.print("  Mode: {}\n", .{self.video.mode});
            std.debug.print("  VDP registers: ", .{});
            for (self.video.registers) |reg| {
                std.debug.print("{X} ", .{reg});
            }
            std.debug.print("\n", .{});

            std.debug.print("\n", .{});
        }
        self.renderFrameBuffer(framebuffer);
    }

    fn renderFrameBuffer(self: *Zoleco, framebuffer: []u8) void {
        const size = resolution_width_with_overscan * resolution_height_with_overscan;
        const src_buffer = self.video.framebuffer;

        // Print frame debug info for every frame
        var checksum2: usize = 0;
        for (src_buffer) |pixel| {
            checksum2 += pixel;
        }
        std.debug.print("Frame: {d}, src_buffer length: {d}, Checksum: {d}\n", .{
            self.frame_count,
            src_buffer.len,
            checksum2,
        });

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

        // Print frame debug info for every frame
        var checksum: usize = 0;
        for (framebuffer, 0..) |pixel, i| {
            checksum ^= (pixel * (i + 1));
        }
        std.debug.print("Frame: {d}, Framebuffer length: {d}, Checksum: {d}\n", .{ self.frame_count, framebuffer.len, checksum });

        if (self.frame_count == 15) {
            // print entire framebuffer
            std.debug.print("!!!!!!!!!!!Framebuffer:\n", .{});
            for (framebuffer, 0..) |pixel, i| {
                std.debug.print("{X:02} ", .{pixel});
                if (i % 16 == 15) {
                    std.debug.print("\n", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};
