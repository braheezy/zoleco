const std = @import("std");
const rl = @import("raylib");

const TMS9918 = @import("tms9918");
const Device = @import("device.zig");
const emu = @import("emulator.zig");

const display_width = 256;
const display_height = 192;
const fps = 60.0;
const tick_min_pixels = 21;

const frame_time = 1.0 / fps;
const row_time = frame_time / display_height;
const pixel_time = row_time / display_width;
const border_x = (display_width - TMS9918.pixels_x) / 2;
const border_y = (display_height - TMS9918.pixels_y) / 2;
const display_pixels = display_width * display_height;

const TMS9918Device = struct {
    data_address: u16,
    register_address: u16,
    tms9918: *TMS9918,
    framebuffer: [display_pixels]u32,
    unused_time: f32,
    current_frame_pixels: u32,
    scanline_buffer: [display_width]u8,

    pub fn init(allocator: std.mem.Allocator, data_addr: u16, register_addr: u16) !Device {
        const device = Device.init("TMS9918");

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
        };

        device.data = self;
        device.reset_fn = resetTms9918;
        device.destroy_fn = destroyTms9918;
        device.render_fn = renderTms9918;
        device.tick_fn = tickTms9918;
        device.read_fn = readTms9918;
        device.write_fn = writeTms9918;

        device.output = rl.loadRenderTexture(display_width, display_height);

        return self.*;
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

pub fn renderTms9918(self: *Device) anyerror!void {
    const tms = getTms9918Device(self);
    rl.updateTexture(self.output.texture, &tms.framebuffer);
}

// renders the portion of the screen since the last call. relies on deltaTime to determine
// how much of the screen to render. this style of rendering allows mid-frame changes to be
// shown in the display if called frequently enough. you can achieve beam racing effects.
pub fn tickTms9918(self: *Device, delta_ticks: u32, delta_time: f32) void {
    _ = delta_ticks;

    const tms = getTms9918Device(self);

    var dt = delta_time;
    // determine portion of frame to render
    dt += tms.unused_time;

    // how many pixels are we rendering?
    const mod = std.math.modf(dt / pixel_time);
    tms.unused_time = mod.fpart * pixel_time;
    var pixels_to_render = mod.ipart;

    // if we haven't reached the minimum, accumulate time for the next call and return
    if (pixels_to_render < tick_min_pixels) {
        tms.unused_time += pixels_to_render * pixel_time;
        return;
    }

    // we only render the end end of a frame. if we need to go further, accumulate the time for the next call
    if (tms.current_frame_pixels + pixels_to_render >= display_pixels) {
        tms.unused_time += ((tms.current_frame_pixels + pixels_to_render) - display_pixels) * pixel_time;
        pixels_to_render = display_pixels - tms.current_frame_pixels;
    }

    // get the background color for this run of pixels
    const bg_color = tms.tms9918.readRegisterValue(.fg_bg_color) & 0x0f;

    var first_pixel = true;
    var framebuffer_slice = tms.framebuffer[tms.current_frame_pixels..];
    var tms_row: i32 = 0;

    // iterate over the pixels we need to update in this call
    for (0..pixels_to_render) |_| {
        const current_row = tms.current_frame_pixels / display_width;
        const curren_col = tms.current_frame_pixels % display_width;

        // if this is the first pixel or the first pixel of a new row, update the scanline buffer
        if (first_pixel or curren_col == 0) {
            tms_row = current_row - border_y;
            @memset(tms.scanline_buffer[0..], bg_color);
            if (tms_row >= 0 and tms_row < TMS9918.pixels_y) {
                tms.tms9918.scanLine(@intCast(tms_row), tms.scanline_buffer[border_x..]);
            }
            first_pixel = false;
        }

        // update the frame buffer pixel from the scanline pixel
        framebuffer_slice[0] = TMS9918.palette[tms.scanline_buffer[curren_col]];
        framebuffer_slice = framebuffer_slice[1..];
        tms.currentFramePixels += 1;

        // if we're at the end of the main tms9918 frame, trigger an interrupt
        if (tms.current_frame_pixels == display_width * (display_height - border_y)) {
            if ((tms.tms9918.readRegisterValue(.reg_1) & 0x20) != 0) {
                emu.interrupt(.raise);
            }
        }
    }

    // reset pixel count if frame finished
    if (tms.current_frame_pixels >= display_pixels) {
        tms.current_frame_pixels = 0;
    }
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
