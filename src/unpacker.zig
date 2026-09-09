const std = @import("std");
const header = @import("header");
const verifier = @import("verifier");

pub const UnpackResult = struct {
    header: header.Header,
    info: []u8,
};

pub fn read(
    allocator: std.mem.Allocator,
    w: *std.Io.Writer,
    r: *std.Io.Reader,
) !UnpackResult {
    var header_bytes: [header.HeaderSize]u8 = undefined;
    try r.readSliceAll(&header_bytes);
    const h = try header.Header.parse(header_bytes);
    try verifier.verify(h);

    const info = try allocator.alloc(u8, h.info_size);
    errdefer allocator.free(info);
    try r.readSliceAll(info);

    const consumed: u64 = header.HeaderSize + h.info_size;
    if (h.data_offset < consumed) return error.BadDataOffset;
    try r.discardAll64(h.data_offset - consumed);

    _ = try r.streamRemaining(w);
    return .{ .header = h, .info = info };
}
