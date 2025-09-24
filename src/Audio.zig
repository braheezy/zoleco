// Audio subsystem for the ColecoVision emulator
// The ColecoVision uses the SN76489 sound chip, which is emulated here using SDL2 for audio output.
// This implementation provides real-time audio generation and playback through the host system's audio device.

const std = @import("std");
const sdl = @import("sdl2");
const SN76489 = @import("SN76489");
const SDL_AudioDeviceID = sdl.SDL_AudioDeviceID;

pub const Audio = struct {
    // The emulated SN76489 sound chip instance
    chip: SN76489,
    // SDL audio device identifier
    device: SDL_AudioDeviceID,
    // Number of frames in the audio buffer
    buffer_frames: u32,
    // Audio sampling rate in Hz (e.g., 44100)
    sample_rate: u32,
    // Number of audio channels (1 for mono, 2 for stereo)
    channels: u8,

    // Initialize the audio subsystem with the specified parameters
    // clock_hz: The clock frequency of the SN76489 chip
    // sample_rate: The desired audio sampling rate
    // buffer_frames: Size of the audio buffer in frames
    // channels: Number of audio channels
    pub fn init(
        allocator: std.mem.Allocator,
        clock_hz: u32,
        sample_rate: u32,
        buffer_frames: u32,
        channels: u8,
    ) !*Audio {
        _ = sdl.SDL_Init(sdl.SDL_INIT_AUDIO);
        var audio = try allocator.create(Audio);
        // Initialize the SN76489 sound chip emulation
        audio.chip = try SN76489.init(clock_hz, sample_rate);
        // Enable high-quality audio output
        audio.chip.set_quality(true);
        audio.chip.set_quality(true);
        audio.sample_rate = sample_rate;
        audio.buffer_frames = buffer_frames;
        audio.channels = channels;

        // Configure SDL audio specifications
        var desired_spec: sdl.SDL_AudioSpec = sdl.SDL_AudioSpec{
            .freq = @intCast(sample_rate),
            .format = sdl.AUDIO_S16SYS, // 16-bit signed audio format
            .channels = channels,
            .samples = @intCast(buffer_frames),
            .callback = audioCallback, // Function called when SDL needs more audio data
            .userdata = null,
            .silence = 0,
            .padding = 0,
            .size = 0,
        };
        var obtained_spec: sdl.SDL_AudioSpec = undefined;
        // Open the audio device with the specified configuration
        audio.device = sdl.SDL_OpenAudioDevice(
            null,
            0,
            &desired_spec,
            &obtained_spec,
            0,
        );
        // Start audio playback immediately
        sdl.SDL_PauseAudioDevice(audio.device, 0);
        std.log.info("Audio.init: device id={}", .{audio.device});
        // Store the audio instance globally for the callback function
        global_audio = audio;
        return audio;
    }

    // Clean up audio resources and close the SDL audio device
    pub fn deinit(self: *Audio, allocator: std.mem.Allocator) void {
        sdl.SDL_CloseAudioDevice(self.device);
        allocator.destroy(self);
    }

    // Write data to the SN76489 sound chip
    // This is called when the emulated system writes to the sound chip's ports
    pub fn write(self: *Audio, data: u8) void {
        self.chip.write(@as(u32, data));
    }

    // Generate audio samples and fill the provided buffer
    // This is called by the audio callback to get the next batch of samples
    pub fn render(self: *Audio, buf: []i16) void {
        self.chip.render(buf);
    }
};

// Global reference to the audio instance for use in the C-style callback
var global_audio: *Audio = undefined;
// Counter for tracking the number of audio callback invocations
var audio_callback_count: usize = 0;

// SDL audio callback function that provides new audio data when needed
// This is called by SDL in a separate thread when it needs more audio data to play
fn audioCallback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) callconv(.c) void {
    _ = userdata;
    // Calculate the number of frames based on the buffer length and audio format
    const frames = @divExact(@as(usize, @intCast(len)), @sizeOf(i16) * @as(usize, global_audio.channels));
    // Convert the raw byte stream to an array of 16-bit audio samples
    const buf = @as([*]i16, @ptrCast(@alignCast(stream)))[0 .. frames * @as(usize, global_audio.channels)];

    audio_callback_count += 1;
    // Generate new audio samples using the SN76489 emulation
    global_audio.render(buf);

    // Debug code to find the first non-zero sample in the buffer
    var first_nonzero_idx: usize = 0;
    var has_nonzero: bool = false;
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        if (buf[i] != 0) {
            first_nonzero_idx = i;
            has_nonzero = true;
            break;
        }
    }
}
