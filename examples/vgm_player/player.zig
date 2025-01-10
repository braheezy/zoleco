const std = @import("std");
const SN76489 = @import("SN76489");

const Command = struct {
    tag: u8,
    data1: u8,
    data2: u8,
    wait: u16,
};

const Player = @This();

_data: []const u8 = &[_]u8{},
_chip: SN76489 = undefined,
_renderActive: bool = false,
_wait: u16 = 0,
_ptr: usize = 0,
_loop: usize = 0,
_enable: bool = false,
_looping: bool = false,
_commands: std.ArrayList(Command) = undefined,
_cmdIndex: usize = 0,

/// Initialize the Player
pub fn init(al: std.mem.Allocator) !Player {
    var player = Player{};
    player._chip = try SN76489.init(3579545, 44100);
    player._chip.set_quality(true);
    player.unload();
    player._looping = false;
    player._commands = std.ArrayList(Command).init(al);

    return player;
}

/// Unload data and reset state
pub fn unload(self: *Player) void {
    self.stop();
}

/// Read a 32-bit integer from the data array
fn readInt(self: *Player, off: usize) u32 {
    return self._data[off] +
        (@as(u32, self._data[off + 1]) << 8) +
        (@as(u32, self._data[off + 2]) << 16) +
        (@as(u32, self._data[off + 3]) << 24);
}

/// Start playback
pub fn enable(self: *Player) void {
    self._chip.reset();
    self._ptr = 0x40;
    self._enable = true;
}

/// Stop playback
pub fn stop(self: *Player) void {
    self._enable = false;
    while (self._renderActive) {}
    self._chip.reset();
}

/// Set looping behavior
pub fn setLooping(self: *Player, l: bool) void {
    self._looping = l;
}

/// Load VGM data into the player
pub fn load(self: *Player, file: []const u8) !bool {
    self.unload();
    if (file.len == 0) return false;
    self._data = file;
    if (self._data.len < 0x40) return false;
    if (self.readInt(0) != 0x206D6756) return false;
    self._loop = self.readInt(0x1C) + 0x1C;
    self._chip.clock(self.readInt(0x0C));

    // new parsing
    self._commands.clearAndFree();
    var i: usize = 0x40; // start commands after header
    while (i < file.len) {
        const tag = file[i];
        var inc: usize = 1;
        var w: u16 = 0;
        var d1: u8 = 0;
        var d2: u8 = 0;

        switch (tag) {
            0x4F => inc = 2,
            0x50 => {
                d1 = file[i + 1];
                inc = 2;
            },
            0x61 => {
                w = file[i + 1] | (@as(u16, file[i + 2]) << 8);
                inc = 3;
            },
            0x62 => w = 735,
            0x63 => w = 882,
            0x66 => {
                // end or loop
                try self._commands.append(Command{ .tag = tag, .data1 = 0, .data2 = 0, .wait = 0 });
                break;
            },
            else => {
                if (tag >= 0x70 and tag < 0x80) {
                    w = (tag & 0x0F) + 1;
                } else if (tag == 0x51 or tag == 0x52 or tag == 0x53 or tag == 0x54) {
                    d1 = file[i + 1];
                    d2 = file[i + 2];
                    inc = 3;
                } else if ((tag >= 0x55 and tag < 0x60) or (tag >= 0xa0 and tag < 0xc0)) {
                    d1 = file[i + 1];
                    d2 = file[i + 2];
                    inc = 3;
                } else if (tag >= 0xc0 and tag < 0xe0) {
                    d1 = file[i + 1];
                    d2 = file[i + 2];
                    inc = 4;
                } else if (tag >= 0xe1) {
                    d1 = file[i + 1];
                    d2 = file[i + 2];
                    inc = 5;
                }
            },
        }

        try self._commands.append(Command{ .tag = tag, .data1 = d1, .data2 = d2, .wait = w });
        if (tag == 0x66) break;
        i += inc;
    }

    return true;
}

/// Render audio samples into a buffer
pub fn render(self: *Player, buf: []i16) void {
    if (!self._enable or self._cmdIndex >= self._commands.items.len) {
        for (buf) |*sample| sample.* = 0;
        return;
    }

    var i: usize = 0;
    while (i < buf.len) {
        if (self._wait > 0) {
            const count = if (self._wait > @as(u16, @intCast(buf.len - i))) @as(u16, @intCast(buf.len - i)) else self._wait;
            self._chip.render(buf[i .. i + count]);
            i += count;
            self._wait -= count;
            if (i == buf.len) break;
        }

        if (self._cmdIndex >= self._commands.items.len) {
            for (buf[i..]) |*sample| sample.* = 0;
            break;
        }

        const cmd = self._commands.items[self._cmdIndex];
        switch (cmd.tag) {
            0x50 => self._chip.write(cmd.data1),
            0x66 => {
                if (self._looping) {
                    self._cmdIndex = if (self.readInt(0x20) != 0) @as(usize, self._loop - 0x40) else 0;
                } else {
                    self._enable = false;
                    self._chip.reset();
                    self._wait = 10000;
                }
            },
            0x51, 0x52, 0x53, 0x54 => {}, // handle if needed
            else => {},
        }
        self._wait = cmd.wait;
        self._cmdIndex += 1;
    }
}
