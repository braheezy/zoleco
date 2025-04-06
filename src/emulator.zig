const Device = @import("device.zig");

const InterruptSignal = enum {
    release,
    raise,
    trigger,
};

pub fn interrupt(signal: InterruptSignal) void {
    _ = signal;
}

const max_devices = 3;
const devices: [max_devices]Device = undefined;

pub fn addDevice(device: *Device) !*Device {
    if (devices.len == max_devices) {
        return error.MaxDevicesReached;
    }
    devices[devices.len - 1] = device;
    return device;
}
