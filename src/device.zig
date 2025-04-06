const rl = @import("raylib");

const Device = @This();

name: []const u8,
data: ?*anyopaque = null,
output: rl.RenderTexture2D = undefined,

reset_fn: ?*const fn (self: *Device) void = null,
destroy_fn: ?*const fn (self: *Device) void = null,
tick_fn: ?*const fn (self: *Device, delta_ticks: u32, delta_time: f64) void = null,
read_fn: ?*const fn (self: *Device, address: u16) anyerror!u8 = null,
write_fn: ?*const fn (self: *Device, address: u16, value: u8) anyerror!void = null,
render_fn: ?*const fn (self: *Device) anyerror!void = null,

pub fn init(name: []const u8) Device {
    return .{
        .name = name,
    };
}

pub fn destroy(self: *Device) void {
    if (self.destroy_fn) |destroy_fn| {
        destroy_fn(self);
    }
}

pub fn reset(self: *Device) void {
    if (self.reset_fn) |reset_fn| {
        reset_fn(self);
    }
}

pub fn tick(self: *Device, delta_ticks: u32, delta_time: f64) void {
    if (self.tick_fn) |tick_fn| {
        tick_fn(self, delta_ticks, delta_time);
    }
}

pub fn read(self: *Device, address: u16) anyerror!u8 {
    if (self.read_fn) |read_fn| {
        return try read_fn(self, address);
    }
}

pub fn write(self: *Device, address: u16, value: u8) anyerror!void {
    if (self.write_fn) |write_fn| {
        return try write_fn(self, address, value);
    }
}

pub fn render(self: *Device) anyerror!void {
    if (self.render_fn) |render_fn| {
        return try render_fn(self);
    }
}
