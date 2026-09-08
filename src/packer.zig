const std = @import("std");
const header = @import("header");

pub const PackOptions = struct {
    version: u16 = 1,
};

pub fn write(
    w: *std.Io.Writer,
    info: []const u8,
    r: *std.Io.Reader,
    options: PackOptions,
) !header.Header {
    if (info.len > std.math.maxInt(u32)) return error.InfoTooLarge;

    const h = header.Header{
        .version = options.version,
        .info_size = @intCast(info.len),
        .data_offset = header.HeaderSize + info.len,
        .sig_offset = 0,
        .sig_size = 0,
        .checksum = [_]u8{0} ** 8,
        .reserved = [_]u8{0} ** 26,
    };

    const hdr_bytes = h.serialize();
    try w.writeAll(&hdr_bytes);
    try w.writeAll(info);
    _ = try r.streamRemaining(w);
    return h;
}
