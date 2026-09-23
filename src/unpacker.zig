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
    try verifier.verifyFormat(h);

    const info = try allocator.alloc(u8, h.info_size);
    errdefer allocator.free(info);
    try r.readSliceAll(info);

    if (h.sig_size != 0) {
        try streamExact(w, r, h.sig_offset - h.data_offset);
    } else {
        _ = try r.streamRemaining(w);
    }
    return .{ .header = h, .info = info };
}

fn streamExact(w: *std.Io.Writer, r: *std.Io.Reader, len: u64) !void {
    var remaining = len;
    var buf: [64 * 1024]u8 = undefined;
    while (remaining > 0) {
        const chunk: usize = @intCast(@min(remaining, buf.len));
        try r.readSliceAll(buf[0..chunk]);
        try w.writeAll(buf[0..chunk]);
        remaining -= chunk;
    }
}
