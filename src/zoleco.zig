const std = @import("std");

const Memory = @import("memory_device.zig").Memory;
const Cartridge = @import("Cartridge.zig");
const Z80 = @import("z80").Z80;
const ColecoVisionIO = @import("ports.zig");
const Video = @import("video.zig").Video;

pub const Zoleco = struct {
    allocator: std.mem.Allocator,
    memory: Memory = undefined,
    video: Video = undefined,
    cpu: *Z80,
    cartridge: Cartridge = .{},

    pub fn init(allocator: std.mem.Allocator) !*Zoleco {
        const zoleco = try allocator.create(Zoleco);

        const io = try ColecoVisionIO.init(allocator, &zoleco.memory);

        const z80 = try allocator.create(Z80);
        z80.* = Z80.init(&io.io);

        zoleco.* = Zoleco{
            .allocator = allocator,
            .cpu = z80,
            .memory = try Memory.init(
                allocator,
                @embedFile("roms/colecovision.rom"),
            ),
            .video = try Video.init(allocator),
        };
        return zoleco;
    }
};
