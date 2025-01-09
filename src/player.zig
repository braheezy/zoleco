const std = @import("std");
const SN76489 = @import("SN76489.zig");

const Player = @This();

_data: []const u8 = &[_]u8{},
_chip: SN76489 = undefined,
_renderActive: bool = false,
_wait: u16 = 0,
_ptr: usize = 0,
_loop: usize = 0,
_enable: bool = false,
_looping: bool = false,

/// Initialize the Player
pub fn init() !Player {
    var player = Player{};
    player._chip = try SN76489.init(3579545, 44000);
    player._chip.set_quality(true);
    player.unload();
    player._looping = false;

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
pub fn play(self: *Player) void {
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

/// Load VGM data into the player
pub fn load(self: *Player, file: []const u8) bool {
    var off: usize = 0;
    var temp = std.ArrayList(u8).init(std.heap.page_allocator);
    defer temp.deinit();

    self.unload();

    if (file.len == 0) return false;
    self._data = file;

    if (self._data.len == 0) return false;

    // Check VGM signature
    if (self.readInt(0) != 0x206D6756) return false; // "Vgm "

    self._loop = self.readInt(0x1C) + 0x1C;
    self._chip.clock(self.readInt(0x0C));
    off = self.readInt(0x14);

    if (off != 0) {
        if (self.readInt(off + 0x14) != 0x20336447) return true; // "Gd3 "
        if (self.readInt(off + 0x18) != 0x00000100) return true;
    }

    return true;
}

/// Set looping behavior
pub fn setLooping(self: *Player, l: bool) void {
    self._looping = l;
}

/// Render audio samples into a buffer
pub fn render(self: *Player, buf: []i16) void {
    var i: usize = 0;
    var tag: u8 = 0;
    var inc: usize = 0;

    if (!self._enable) {
        for (buf) |*sample| sample.* = 0.0;
        return;
    }

    if (self._wait > 0) {
        if (self._wait >= buf.len) {
            self._chip.render(buf);
            self._wait -= @intCast(buf.len);
            return;
        } else {
            self._chip.render(buf[0..self._wait]);
            i = self._wait;
        }
    }

    while (i < buf.len) {
        self._wait = 0;

        while (self._wait == 0) {
            tag = self._data[self._ptr];
            switch (tag) {
                0x4F => inc = 2,
                0x50 => {
                    self._chip.write(self._data[self._ptr + 1]);
                    inc = 2;
                },
                0x61 => {
                    self._wait = self._data[self._ptr + 1] + (@as(u16, self._data[self._ptr + 2]) << 8);
                    inc = 3;
                },
                0x51, 0x52, 0x53, 0x54 => inc = 3,
                0x62 => {
                    self._wait = 735;
                    inc = 1;
                },
                0x63 => {
                    self._wait = 882;
                    inc = 1;
                },
                0x66 => {
                    if (self._looping) {
                        self._ptr = if (self.readInt(0x20) != 0) self._loop else 0x40;
                    } else {
                        self._enable = false;
                        self._chip.reset();
                        self._wait = 10000;
                    }
                    inc = 0;
                },
                0x67 => inc = 1,
                else => {
                    if (tag >= 0x70 and tag < 0x80) {
                        self._wait = (tag & 0x0F) + 1;
                        inc = 1;
                    } else if (tag >= 0x30 and tag < 0x4f) {
                        inc = 2;
                    } else if ((tag >= 0x55 and tag < 0x60) or (tag >= 0xa0 and tag < 0xc0)) {
                        inc = 3;
                    } else if (tag >= 0xc0 and tag < 0xe0) {
                        inc = 4;
                    } else if (tag >= 0xe1) {
                        inc = 5;
                    } else {
                        inc = 2;
                    }
                },
            }
            self._ptr += inc;
        }

        if (i + self._wait > buf.len) {
            self._chip.render(buf[i..]);
            self._wait -= @intCast(buf.len - i);
            break;
        }

        self._chip.render(buf[i .. i + self._wait]);
        i += self._wait;
    }
}
