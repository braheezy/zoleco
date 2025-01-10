// mostly ported from https://github.com/cdodd/vgmparse

const std = @import("std");

pub const VGM = @This();

const MetadataField = enum {
    vgm_ident,
    eof_offset,
    version,
    sn76489_clock,
    ym2413_clock,
    gd3_offset,
    total_samples,
    loop_offset,
    loop_samples,
    rate,
    sn76489_feedback,
    sn76489_shift_register_width,
    ym2612_clock,
    ym2151_clock,
    vgm_data_offset,
};

pub const CommandEntry = struct {
    command: u8,
    data: ?[]u8 = null,

    pub fn deinit(self: *CommandEntry, allocator: std.mem.Allocator) void {
        if (self.data) |d| allocator.free(d);
    }
};

commands: []CommandEntry,

pub const MetadataAttribute = struct {
    offset: u32,
    size: u8,
};

pub const MetadataMap = std.EnumMap(MetadataField, MetadataAttribute);

pub var metadata_offsets = MetadataMap.init(.{
    .vgm_ident = .{ .offset = 0x00, .size = 4 },
    .eof_offset = .{ .offset = 0x04, .size = 4 },
    .version = .{ .offset = 0x08, .size = 4 },
    .sn76489_clock = .{ .offset = 0x0c, .size = 4 },
    .ym2413_clock = .{ .offset = 0x10, .size = 4 },
    .gd3_offset = .{ .offset = 0x14, .size = 4 },
    .total_samples = .{ .offset = 0x18, .size = 4 },
    .loop_offset = .{ .offset = 0x1c, .size = 4 },
    .loop_samples = .{ .offset = 0x20, .size = 4 },
    .rate = .{ .offset = 0x24, .size = 4 },
    .sn76489_feedback = .{ .offset = 0x28, .size = 2 },
    .sn76489_shift_register_width = .{ .offset = 0x2a, .size = 1 },
    .ym2612_clock = .{ .offset = 0x2c, .size = 4 },
    .ym2151_clock = .{ .offset = 0x30, .size = 4 },
    .vgm_data_offset = .{ .offset = 0x34, .size = 4 },
});

pub fn decode(al: std.mem.Allocator, vgm_data: *std.io.StreamSource) !VGM {
    const reader = vgm_data.reader().any();

    // Read the 4-byte header
    var header: [4]u8 = undefined;
    _ = try reader.readAll(header[0..4]);
    if (!std.mem.eql(u8, &header, "Vgm ")) {
        return error.InvalidFormat;
    }

    var metadata = std.EnumMap(MetadataField, u64).init(.{});

    // parse metadata
    var buffer: [8]u8 = undefined; // Maximum expected size is 4 bytes
    var metadata_iter = metadata_offsets.iterator();
    while (metadata_iter.next()) |offset| {
        const metadata_value = offset.key;
        const offset_data = offset.value;

        try vgm_data.seekTo(offset_data.offset);

        try reader.readNoEof(buffer[0..offset_data.size]);

        const value: u64 = switch (offset_data.size) {
            1 => buffer[0],
            2 => @as(u64, std.mem.bytesToValue(u16, buffer[0..2])),
            4 => @as(u64, std.mem.bytesToValue(u32, buffer[0..4])),
            8 => std.mem.bytesToValue(u64, buffer[0..8]),
            else => return error.InvalidMetadataSize,
        };

        metadata.put(metadata_value, value);
    }

    // Read the VGM commands
    try vgm_data.seekTo(metadata.get(.vgm_data_offset).? + 0x34);

    var commands_list = std.ArrayList(CommandEntry).init(al);

    var data_block: []u8 = undefined;

    while (true) {
        const command = try reader.readByte();

        // 0x4f dd - Game Gear PSG stereo, write dd to port 0x06
        // 0x50 dd - PSG (SN76489/SN76496) write value dd
        if (std.mem.containsAtLeast(
            u8,
            &[_]u8{ 0x4f, 0x50 },
            1,
            &[_]u8{command},
        )) {
            const data = try al.alloc(u8, 1);
            try reader.readNoEof(data);
            try commands_list.append(.{ .command = command, .data = data });
        } else if (std.mem.containsAtLeast(
            u8,
            &[_]u8{ 0x51, 0x52, 0x53, 0x54, 0x61 },
            1,
            &[_]u8{command},
        )) {
            // 0x51 aa dd - YM2413, write value dd to register aa
            // 0x52 aa dd - YM2612 port 0, write value dd to register aa
            // 0x53 aa dd - YM2612 port 1, write value dd to register aa
            // 0x54 aa dd - YM2151, write value dd to register aa
            // 0x61 nn nn - Wait n samples, n can range from 0 to 65535
            const data = try al.alloc(u8, 2);
            try reader.readNoEof(data);
            try commands_list.append(.{ .command = command, .data = data });
        } else if (std.mem.containsAtLeast(
            u8,
            &[_]u8{ 0x62, 0x63, 0x66 },
            1,
            &[_]u8{command},
        )) {
            // 0x62 - Wait 735 samples (60th of a second)
            // 0x63 - Wait 882 samples (50th of a second)
            // 0x66 - End of sound data
            try commands_list.append(.{ .command = command });

            if (command == 0x66) {
                break;
            }
        } else if (command == 0x67) {
            // 0x67 0x66 tt ss ss ss ss - Data block
            try reader.skipBytes(2, .{});

            // Read the size of the data block (4 bytes, little-endian)
            var size_buffer: [4]u8 = undefined;
            try reader.readNoEof(&size_buffer);
            const data_block_size = std.mem.readInt(u32, &size_buffer, .little);

            // Allocate memory for the data block
            data_block = try al.alloc(u8, data_block_size);
            defer al.free(data_block); // Ensure cleanup on failure

            // Read the data block into memory
            try reader.readNoEof(data_block);
        } else if (0x70 <= command and command <= 0x8F) {
            //  0x7n - Wait n+1 samples, n can range from 0 to 15
            // 0x8n - YM2612 port 0 address 2A write from the data bank, then
            //        wait n samples; n can range from 0 to 15
            try commands_list.append(.{ .command = command });
        } else if (command == 0xE0) {
            const data = try al.alloc(u8, 4);
            try reader.readNoEof(data);
            try commands_list.append(.{ .command = command, .data = data });
        }
    }

    return VGM{ .commands = try commands_list.toOwnedSlice() };
}
