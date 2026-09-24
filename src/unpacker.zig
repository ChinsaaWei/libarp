const std = @import("std");
const header = @import("header");
const verifier = @import("verifier");
const checksum = @import("checksum");

const Sha256 = std.crypto.hash.sha2.Sha256;

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

    var sha = Sha256.init(.{});
    sha.update(info);

    var buf: [64 * 1024]u8 = undefined;
    if (h.sig_size != 0) {
        var remaining: u64 = h.sig_offset - h.data_offset;
        while (remaining > 0) {
            const chunk: usize = @intCast(@min(remaining, buf.len));
            try r.readSliceAll(buf[0..chunk]);
            sha.update(buf[0..chunk]);
            try w.writeAll(buf[0..chunk]);
            remaining -= chunk;
        }
    } else {
        while (true) {
            const n = try r.readSliceShort(buf[0..]);
            if (n == 0) break;
            sha.update(buf[0..n]);
            try w.writeAll(buf[0..n]);
        }
    }

    if (!checksum.isZero(h.checksum)) {
        const got = sha.finalResult();
        if (!std.mem.eql(u8, &h.checksum, got[0..8])) return error.BadChecksum;
    }

    return .{ .header = h, .info = info };
}
