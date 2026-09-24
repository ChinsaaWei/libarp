const std = @import("std");
const header = @import("header");
const checksum = @import("checksum");

pub const PackOptions = struct {
    version: u16 = 1,
    write_checksum: bool = true,
};

pub fn write(
    w: *std.Io.Writer,
    info: []const u8,
    data: []const u8,
    options: PackOptions,
) !header.Header {
    if (info.len > std.math.maxInt(u32)) return error.InfoTooLarge;

    var h = header.Header{
        .version = options.version,
        .info_size = @intCast(info.len),
        .data_offset = header.HeaderSize + info.len,
        .sig_offset = 0,
        .sig_size = 0,
        .checksum = [_]u8{0} ** 8,
        .reserved = [_]u8{0} ** 26,
    };
    if (options.write_checksum) {
        h.checksum = checksum.compute(info, data);
    }

    const hdr_bytes = h.serialize();
    try w.writeAll(&hdr_bytes);
    try w.writeAll(info);
    try w.writeAll(data);
    return h;
}
