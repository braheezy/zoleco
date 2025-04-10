const std = @import("std");
const rl = @import("raylib");

const TMS9918 = @import("tms9918");
const Device = @import("device.zig");
const emu = @import("emulator.zig");

const display_width = 256;
const display_height = 192;
const fps = 60.0;
const tick_min_pixels = 21.0;

const frame_time = 1.0 / fps;
const row_time = frame_time / @as(f64, @floatFromInt(display_height));
const pixel_time = row_time / @as(f64, @floatFromInt(display_width));
const border_x = (display_width - TMS9918.pixels_x) / 2;
const border_y = (display_height - TMS9918.pixels_y) / 2;
const display_pixels = display_width * display_height;

pub const TMS9918Device = struct {
    data_address: u16,
    register_address: u16,
    tms9918: *TMS9918,
    framebuffer: [display_pixels]u32,
    unused_time: f64,
    current_frame_pixels: u32,
    scanline_buffer: [display_width]u8,
    output: rl.RenderTexture2D,
    window_width: u32 = 800,
    window_height: u32 = 600,

    pub fn init(allocator: std.mem.Allocator, data_addr: u16, register_addr: u16) !*TMS9918Device {
        const tms9918 = try TMS9918.init(allocator);

        var framebuffer: [display_pixels]u32 = undefined;
        @memset(framebuffer[0..], 0);

        var scanline_buffer: [display_width]u8 = undefined;
        @memset(scanline_buffer[0..], 6);

        const self = try allocator.create(TMS9918Device);
        self.* = .{
            .data_address = data_addr,
            .register_address = register_addr,
            .tms9918 = tms9918,
            .framebuffer = framebuffer,
            .unused_time = 0.0,
            .current_frame_pixels = 0,
            .scanline_buffer = scanline_buffer,
            .output = try rl.RenderTexture2D.init(display_width, display_height),
        };

        return self;
    }

    // renders the portion of the screen since the last call. relies on deltaTime to determine
    // how much of the screen to render. this style of rendering allows mid-frame changes to be
    // shown in the display if called frequently enough. you can achieve beam racing effects.
    pub fn tick(self: *TMS9918Device, delta_ticks: u32, delta_time: f64) void {
        _ = delta_ticks;

        var dt = delta_time;
        // determine portion of frame to render
        dt += self.unused_time;
        var pixels_to_render_int: u32 = 0;

        // Ensure dt is valid
        if (std.math.isNan(dt) or std.math.isInf(dt)) {
            std.debug.print("Warning: Invalid delta_time value, skipping tick\n", .{});
            dt = 0.0;
            self.unused_time = 0.0;
            return;
        }

        // how many pixels are we rendering?
        std.debug.print("dt: {d}, pixel_time: {d}\n", .{ dt, pixel_time });

        // Prevent division by zero
        if (pixel_time <= 0.0) {
            std.debug.print("Warning: pixel_time is zero or negative, using default\n", .{});
            // Use a reasonable default value
            var pixels_to_render: f64 = 1000.0;
            self.unused_time = 0.0;

            // Ensure the value is within a safe range for u32
            if (pixels_to_render < 0) {
                pixels_to_render = 0;
            } else if (pixels_to_render > 1000000) {
                pixels_to_render = 1000; // Use a conservative default
            }

            pixels_to_render_int = @intFromFloat(pixels_to_render);
            const pixels_to_render_int_plus_current: u32 = self.current_frame_pixels + pixels_to_render_int;

            // we only render the end end of a frame. if we need to go further, accumulate the time for the next call
            if (pixels_to_render_int_plus_current >= display_pixels) {
                self.unused_time += (@as(f32, @floatFromInt(pixels_to_render_int_plus_current)) - display_pixels) * pixel_time;
                pixels_to_render = @floatFromInt(display_pixels - self.current_frame_pixels);
            }
            pixels_to_render_int = @intFromFloat(pixels_to_render);
        } else {
            const mod = std.math.modf(dt / pixel_time);
            self.unused_time = mod.fpart * pixel_time;
            var pixels_to_render = mod.ipart;

            // if we haven't reached the minimum, accumulate time for the next call and return
            if (pixels_to_render < tick_min_pixels) {
                self.unused_time += pixels_to_render * pixel_time;
                return;
            }

            // Ensure the value is within a safe range for u32
            if (pixels_to_render < 0) {
                pixels_to_render = 0;
            } else if (pixels_to_render > 1000000) {
                // Use a safe default if the value is extreme
                pixels_to_render = 1000; // Reasonable default
            }

            std.debug.print("pixels_to_render: {d}\n", .{pixels_to_render});
            pixels_to_render_int = @intFromFloat(pixels_to_render);
            const pixels_to_render_int_plus_current: u32 = self.current_frame_pixels + pixels_to_render_int;

            // we only render the end end of a frame. if we need to go further, accumulate the time for the next call
            if (pixels_to_render_int_plus_current >= display_pixels) {
                self.unused_time += (@as(f32, @floatFromInt(pixels_to_render_int_plus_current)) - display_pixels) * pixel_time;
                pixels_to_render = @floatFromInt(display_pixels - self.current_frame_pixels);
            }
            pixels_to_render_int = @intFromFloat(pixels_to_render);
        }

        // get the background color for this run of pixels
        const bg_color = self.tms9918.readRegisterValue(.fg_bg_color) & 0x0f;

        var first_pixel = true;
        var framebuffer_slice = self.framebuffer[self.current_frame_pixels..];
        var tms_row: i32 = 0;

        // iterate over the pixels we need to update in this call
        for (0..pixels_to_render_int) |_| {
            const current_row = self.current_frame_pixels / display_width;
            const curren_col = self.current_frame_pixels % display_width;

            // if this is the first pixel or the first pixel of a new row, update the scanline buffer
            if (first_pixel or curren_col == 0) {
                tms_row = @intCast(current_row - border_y);
                @memset(self.scanline_buffer[0..], bg_color);
                if (tms_row >= 0 and tms_row < TMS9918.pixels_y) {
                    self.tms9918.scanLine(@intCast(tms_row), self.scanline_buffer[border_x..]);
                }
                first_pixel = false;
            }

            // update the frame buffer pixel from the scanline pixel
            framebuffer_slice[0] = TMS9918.palette[self.scanline_buffer[curren_col]];
            framebuffer_slice = framebuffer_slice[1..];
            self.current_frame_pixels += 1;

            // if we're at the end of the main tms9918 frame, trigger an interrupt
            if (self.current_frame_pixels == display_width * (display_height - border_y)) {
                if ((self.tms9918.readRegisterValue(.reg_1) & 0x20) != 0) {
                    emu.interrupt(.raise);
                }
            }
        }

        // reset pixel count if frame finished
        if (self.current_frame_pixels >= display_pixels) {
            self.current_frame_pixels = 0;
        }
    }

    pub fn render(self: *TMS9918Device) void {
        rl.updateTexture(self.output.texture, &self.framebuffer);
        // Draw scaled texture to window
        rl.drawTexturePro(
            self.output.texture,
            .{
                .x = 0,
                .y = 0,
                .width = 256,
                .height = 192,
            },
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.window_width),
                .height = @floatFromInt(self.window_height),
            },
            .{ .x = 0, .y = 0 },
            0.0,
            rl.Color.white,
        );
    }
};

pub fn getTms9918Device(device: *Device) *TMS9918Device {
    return @ptrCast(device.data);
}

pub fn resetTms9918(self: *Device) void {
    const tms = getTms9918Device(self);
    tms.tms9918.reset();
}

pub fn destroyTms9918(self: *Device, allocator: std.mem.Allocator) void {
    const tms = getTms9918Device(self);
    tms.tms9918.free(allocator);
    allocator.destroy(self);
}

// read from the tms. address determines status or data
pub fn readTms9918(self: *Device, address: u16) u8 {
    const tms = getTms9918Device(self);
    if (address == tms.register_address) {
        const val = tms.tms9918.readStatus();
        emu.interrupt(.release);
        return val;
    } else if (address == tms.data_address) {
        const val = tms.tms9918.readData();
        return val;
    }
    return 0;
}

// write to the tms. address determines address/register or data
pub fn writeTms9918(self: *Device, address: u16, value: u8) void {
    const tms = getTms9918Device(self);
    if (address == tms.register_address) {
        tms.tms9918.writeAddress(value);
    } else if (address == tms.data_address) {
        tms.tms9918.writeData(value);
    }
}
