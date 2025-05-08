const std = @import("std");

const Memory = @import("memory_device.zig").Memory;
const Cartridge = @import("Cartridge.zig");
const Z80 = @import("z80").Z80;
const ColecoVisionIO = @import("ports.zig");
const Video = @import("video.zig").Video;

pub const Zoleco = struct {
    memory: *Memory = undefined,
    video: *Video = undefined,
    cpu: *Z80,
    io: *ColecoVisionIO,
    cartridge: Cartridge = .{},

    pub fn init(allocator: std.mem.Allocator) !*Zoleco {
        const zoleco = try allocator.create(Zoleco);

        const io = try ColecoVisionIO.init(allocator, zoleco.memory);

        const z80 = try allocator.create(Z80);
        z80.* = Z80.init(&io.io);

        zoleco.* = Zoleco{
            .cpu = z80,
            .memory = try Memory.init(
                allocator,
                @embedFile("roms/colecovision.rom"),
            ),
            .video = try Video.init(allocator, z80),
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
};
