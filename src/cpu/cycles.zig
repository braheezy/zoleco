pub const OpcodeCycles = [256]u8{
    4, 10, 7, 6, 4, 4, 7, 4, 4, 11, 7, 6, 4, 4, 7, 4, // 0x00-0x0F
    8, 10, 7, 6, 4, 4, 7, 4, 12, 11, 7, 6, 4, 4, 7, 4, // 0x10-0x1F
    7, 10, 16, 6, 4, 4, 7, 4, 7, 11, 16, 6, 4, 4, 7, 4, // 0x20-0x2F
    7, 10, 13, 6, 11, 11, 10, 4, 7, 11, 13, 6, 4, 4, 7, 4, // 0x30-0x3F
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0x40-0x4F
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0x50-0x5F
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0x60-0x6F
    7, 7, 7, 7, 7, 7, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0x70-0x7F
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0x80-0x8F
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0x90-0x9F
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0xA0-0xAF
    4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4, // 0xB0-0xBF
    5, 10, 10, 10, 10, 11, 7, 11, 5, 4, 10, 4, 10, 10, 7, 11, // 0xC0-0xCF
    5, 10, 10, 11, 10, 11, 7, 11, 5, 4, 10, 11, 10, 4, 7, 11, // 0xD0-0xDF
    5, 10, 10, 19, 10, 11, 7, 11, 5, 4, 10, 4, 10, 4, 7, 11, // 0xE0-0xEF
    5, 10, 10, 4, 10, 11, 7, 11, 5, 6, 10, 4, 10, 4, 7, 11, // 0xF0-0xFF
};

pub const BitOpcodeCycles = [256]u8{
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0x00-0x0F
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0x10-0x1F
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0x20-0x2F
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0x30-0x3F
    4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 0x40-0x4F
    4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 0x50-0x5F
    4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 0x60-0x6F
    4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 0x70-0x7F
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0x80-0x8F
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0x90-0x9F
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0xA0-0xAF
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0xB0-0xBF
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0xC0-0xCF
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0xD0-0xDF
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0xE0-0xEF
    4, 4, 4, 4, 4, 4, 11, 4, 4, 4, 4, 4, 4, 4, 11, 4, // 0xF0-0xFF
};

pub const IndexedOpcodeCycles = [256]u8{
    0, 0, 0, 0, 4, 4, 7, 0, 0, 11, 0, 0, 4, 4, 7, 0, // 0x00-0x0F
    0, 0, 0, 0, 4, 4, 7, 0, 0, 11, 0, 0, 4, 4, 7, 0, // 0x10-0x1F
    0, 10, 16, 6, 4, 4, 7, 0, 0, 11, 16, 6, 4, 4, 7, 0, // 0x20-0x2F
    0, 0, 0, 0, 19, 19, 15, 0, 0, 11, 0, 0, 4, 4, 7, 0, // 0x30-0x3F
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0x40-0x4F
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0x50-0x5F
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0x60-0x6F
    15, 15, 15, 15, 15, 15, 0, 15, 4, 4, 4, 4, 4, 4, 15, 4, // 0x70-0x7F
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0x80-0x8F
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0x90-0x9F
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0xA0-0xAF
    4, 4, 4, 4, 4, 4, 15, 4, 4, 4, 4, 4, 4, 4, 15, 4, // 0xB0-0xBF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0xC0-0xCF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0xD0-0xDF
    0, 10, 0, 19, 0, 11, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, // 0xE0-0xEF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, // 0xF0-0xFF
};

pub const MiscOpcodeCycles = [256]u8{
    8, 9, 0, 0, 6, 0, 0, 0, 0, 8, 9, 0, 0, 0, 0, 0, // 0x00-0x0F
    8, 9, 0, 0, 6, 0, 0, 0, 0, 8, 9, 0, 0, 0, 0, 0, // 0x10-0x1F
    8, 9, 0, 0, 6, 0, 0, 0, 0, 8, 9, 0, 0, 0, 0, 0, // 0x20-0x2F
    0, 0, 0, 0, 6, 0, 0, 0, 0, 8, 9, 0, 0, 0, 0, 0, // 0x30-0x3F
    8, 8, 11, 16, 4, 10, 4, 5, 8, 8, 11, 16, 4, 10, 4, 5, // 0x40-0x4F
    8, 8, 11, 16, 4, 10, 4, 5, 8, 8, 11, 16, 4, 10, 4, 5, // 0x50-0x5F
    8, 8, 11, 16, 4, 10, 4, 14, 8, 8, 11, 16, 4, 10, 4, 14, // 0x60-0x6F
    8, 8, 11, 16, 4, 10, 4, 5, 8, 8, 11, 16, 4, 10, 4, 14, // 0x70-0x7F
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0x80-0x8F
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0x90-0x9F
    12, 12, 12, 12, 0, 0, 0, 0, 12, 12, 12, 12, 0, 0, 0, 0, // 0xA0-0xAF
    12, 12, 12, 12, 0, 0, 0, 0, 12, 12, 12, 12, 0, 0, 0, 0, // 0xB0-0xBF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0xC0-0xCF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0xD0-0xDF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0xE0-0xEF
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0xF0-0xFF
};
