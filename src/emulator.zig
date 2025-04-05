const Device = @import("device.zig");

const max_devices = 3;
const devices: [max_devices]Device = undefined;

pub fn addDevice(device: *Device) !*Device {
    if (devices.len == max_devices) {
        return error.MaxDevicesReached;
    }
    devices[devices.len - 1] = device;
    return device;
}
