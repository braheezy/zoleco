pub fn getHighByte(value: u16) u8 {
    return @intCast(value >> 8);
}

pub fn getLowByte(value: u16) u8 {
    return @intCast(value & 0xFF);
}
