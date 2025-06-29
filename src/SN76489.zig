//! SN76489 sound chip emulator
//! Ported from: https://github.com/digital-sound-antiques/emu76489
/// References:
///  - https://map.grauw.nl/resources/sound/texas_instruments_sn76489an.pdf
///  - https://www.smspower.org/Development/SN76489
///  - docs/sn76489an.txt
const std = @import("std");

const SN76489 = @This();
/// Lookup table for SN76489 volume attenuation.
/// Each entry corresponds to a 2dB step reduction in output amplitude.
/// The table maps 4-bit volume register values (0x0 to 0xF) to linear amplitude levels.
/// This is a normalized table, where 0xFF is the maximum amplitude and 0x00 is silence.
const volume_table: [16]u32 = [_]u32{
    0xff, 0xcb, 0xa1, 0x80,
    0x65, 0x50, 0x40, 0x33,
    0x28, 0x20, 0x19, 0x14,
    0x10, 0x0c, 0x0a, 0x00,
};

/// To support fixed-point arithmetic, reserve bits for the fractional part.
const FRACTIONAL_BITS = 24;

out: i32 = 0,
clock_freq: u32 = 0,
sample_rate: u32 = 0,
base_incr: u32 = 0,
high_quality: bool = false,

count: [3]u32 = [_]u32{0} ** 3,
volume: [3]u32 = [_]u32{0} ** 3,
freq: [3]u32 = [_]u32{0} ** 3,
edge: [3]u32 = [_]u32{0} ** 3,
mute: [3]u32 = [_]u32{0} ** 3,

noise_seed: u32 = 0,
noise_count: u32 = 0,
noise_freq: u32 = 0,
noise_volume: u32 = 0,
noise_mode: u32 = 0,
// flag indicating that the noise channel’s frequency should be sourced from tone channel 2.
// When set, the noise frequency uses the current frequency of channel 2 rather than a fixed divisor.
noise_fref: bool = false,

base_count: u32 = 0,

// Rate converter: synchronize chip clock cycles to audio sample output
// using fixed-point step size for each audio sample period. It converts the sample rate into a timing increment.
realstep: u32 = 0,
// track elapsed emulated time. When it exceeds a threshold defined by realstep, a sample is produced.
sngtime: u32 = 0,
// a fixed-point step size per emulated chip cycle. It determines how much to advance time on each chip cycle.
sngstep: u32 = 0,

adr: u32 = 0,

stereo: u32 = 0,

ch_out: [4]i16 = [_]i16{0} ** 4,

pub fn init(c: u32, sample_rate: ?u32) !SN76489 {
    // var sng = try al.create(SN76489);
    var sng = SN76489{};
    sng.clock_freq = c;
    sng.sample_rate = sample_rate orelse 44100;
    sng.set_quality(false);
    return sng;
}

pub fn free(self: *SN76489, al: std.mem.Allocator) void {
    al.destroy(self);
}

pub fn set_quality(self: *SN76489, use_high_quality: bool) void {
    self.high_quality = use_high_quality;
    self.internal_refresh();
}

// recalculates timing conversion parameters based on quality settings.
// Internal step sizes and timing counters are adjusted to correctly map the chip’s clock and audio sample rate.
fn internal_refresh(self: *SN76489) void {
    if (self.high_quality) {
        self.base_incr = 1 << FRACTIONAL_BITS;
        self.realstep = (1 << 31) / self.sample_rate;
        self.sngstep = (1 << 31) / (self.clock_freq / 16);
        self.sngtime = 0;
    } else {
        self.base_count = @intCast(@as(u64, self.clock_freq) * (1 << FRACTIONAL_BITS) / (16 * self.sample_rate));
    }
}

/// This function processes a command/data byte to update tone/noise registers.
/// It distinguishes between latched and non-latched data writes based on the highest bit.
/// Latching commands set up register selection and parameters, while non-latched
/// writes provide additional data for tone frequency registers.
pub fn write(self: *SN76489, data: u32) void {
    // Check if this is a latched command (bit 7 set).
    const seven_bit_set = data & 0x80 != 0;
    if (seven_bit_set) {
        // Extract register address from bits 4-6.
        self.adr = (data & 0x70) >> 4;

        switch (self.adr) {
            // tone frequency low bits writes: channels 0,1,2.
            // Update low nibble of frequency without altering high bits.
            0, 2, 4 => self.freq[self.adr >> 1] = (self.freq[self.adr >> 1] & 0x3f0) | (data & 0x0f),
            // volume writes: channels 0,1,2.
            1, 3, 5 => self.volume[(self.adr - 1) >> 1] = data & 0xf,
            // Noise channel configuration.
            6 => {
                // Extract noise mode from bit 2.
                self.noise_mode = (data & 4) >> 2;

                // Determine noise frequency or feedback mode.
                if ((data & 0x03) == 0x03) {
                    self.noise_freq = self.freq[2];
                    self.noise_fref = true;
                } else {
                    self.noise_freq = @as(u32, 32) << @intCast(data & 0x03);
                    self.noise_fref = false;
                }

                // Ensure noise frequency isn't zero to avoid erroneous behavior.
                if (self.noise_freq == 0) self.noise_freq = 1;

                // Reset noise shift register to initial state.
                self.noise_seed = 0x8000;
            },
            // Volume control for noise channel.
            7 => self.noise_volume = data & 0x0f,
            else => {},
        }
    } else {
        // Non-latched data: update high bits of frequency for the last addressed tone channel.
        // Retain lower 4 bits, update upper bits from incoming data.
        self.freq[self.adr >> 1] = ((data & 0x3F) << 4) | (self.freq[self.adr >> 1] & 0x0F);
    }
}

/// Calculate the next audio sample output.
pub fn calc(self: *SN76489) i16 {
    if (!self.high_quality) {
        self.update_output();
        return self.mix_output();
    }

    // High-quality mode: use rate conversion to match sample rate.
    // Loop until enough emulated time has passed for the next sample.
    while (self.realstep > self.sngtime) {
        self.sngtime += self.sngstep;
        self.update_output();
    }
    // Adjust time accumulator for the next calculation cycle.
    self.sngtime = self.sngtime - self.realstep;

    return self.mix_output();
}

/// Update the audio output state for one time increment.
/// This function processes noise and tone channels, advancing internal counters
/// and accumulating sample output based on the SN76489 emulation state.
inline fn update_output(self: *SN76489) void {
    self.base_count += self.base_incr;
    const incr = self.base_count >> FRACTIONAL_BITS;
    self.base_count &= (1 << FRACTIONAL_BITS) - 1;

    // increment noise counter by how much time has passed.
    self.noise_count += incr;
    // When enough time has elapsed for a noise period, update noise state.
    if (self.noise_count & 0x100 != 0) {
        // Toggle noise shift register according to noise mode to generate new noise sample.
        self.noise_seed = if (self.noise_mode != 0)
            // white
            (self.noise_seed >> 1) | (parity(self.noise_seed & 0x0009) << 15)
        else
            // periodic
            (self.noise_seed >> 1) | ((self.noise_seed & 1) << 15);

        // Subtract the noise period length from the counter to handle overshoot.
        if (self.noise_fref) {
            if (self.freq[2] < self.noise_count) {
                self.noise_count -= self.freq[2];
            } else {
                self.noise_count = 0;
            }
        } else {
            self.noise_count -= self.noise_freq;
        }
    }

    // Accumulate noise channel output based on current noise value.
    // This adds the weighted noise amplitude when the noise signal is high.
    if ((self.noise_seed & 1) != 0) {
        self.ch_out[3] += @intCast(volume_table[self.noise_volume] << 4);
    }
    // Smooth the output by halving accumulated value to mix past results.
    self.ch_out[3] >>= 1;

    // Tone channels: process each of the three tone channels.
    for (0..3) |i| {
        self.count[i] += incr;
        // Check if it's time to toggle the tone signal for channel i.
        if (self.count[i] & 0x400 != 0) {
            // For frequencies greater than 1, toggle the tone edge to simulate square wave.
            // This updates the output waveform pattern for the channel.
            if (self.freq[i] > 1) {
                self.edge[i] = if (self.edge[i] == 0) 1 else 0;
                // Subtract period length to restart counting for the next edge toggle.
                self.count[i] -= self.freq[i];
            } else {
                // If frequency is too low, force a constant high signal.
                self.edge[i] = 1;
            }
        }

        // If channel is currently high and not muted, add its contribution to output.
        // This mixes the tone channel into the overall sound output.
        if (self.edge[i] != 0 and self.mute[i] == 0) {
            self.ch_out[i] += @intCast(volume_table[self.volume[i]] << 4);
        }

        // Smooth the output by halving the current channel accumulator.
        // This helps blend the sample over time for a more continuous sound.
        self.ch_out[i] >>= 1;
    }
}

/// Combine outputs from all channels to produce a single audio sample.
inline fn mix_output(self: *SN76489) i16 {
    self.out = (self.ch_out[0] + self.ch_out[1] + self.ch_out[2] + self.ch_out[3]);
    return @intCast(self.out);
}

pub fn clock(self: *SN76489, f: u32) void {
    self.clock_freq = f;
    self.internal_refresh();
}

pub fn render(self: *SN76489, buf: []i16) void {
    var i: usize = 0;

    while (i < buf.len) : (i += 1) {
        buf[i] = self.calc();
    }
}

pub fn reset(self: *SN76489) void {
    self.noise_seed = 0x8000;
    self.base_count = 0;

    for (0..3) |i| {
        self.freq[i] = 0;
        self.volume[i] = 0xF; // Mute channels
        self.count[i] = 0;
        self.edge[i] = 0;
        self.mute[i] = 0;
    }

    self.noise_count = 0;
    self.noise_freq = 0;
    self.noise_volume = 0xF; // Mute noise
    self.noise_mode = 0;
    self.noise_fref = false;

    for (0..4) |i| self.ch_out[i] = 0;
}

inline fn parity(x: u32) u32 {
    var local_x = x;
    local_x ^= local_x >> 8;
    local_x ^= local_x >> 4;
    local_x ^= local_x >> 2;
    local_x ^= local_x >> 1;
    return local_x & 1;
}
