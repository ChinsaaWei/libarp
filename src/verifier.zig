const std = @import("std");
const header = @import("header");

pub fn verify(h: header.Header) !void {
    if (h.version != 1) return error.UnsupportedVersion;
    if (h.sig_offset != 0 or h.sig_size != 0) return error.SigFieldNonZero;
    if (!isZero(&h.checksum)) return error.ChecksumNonZero;
    if (!isZero(&h.reserved)) return error.ReservedNonZero;
}

fn isZero(bytes: []const u8) bool {
    for (bytes) |b| {
        if (b != 0) return false;
    }
    return true;
}

fn baseHeader() header.Header {
    return .{
        .version = 1,
        .info_size = 0,
        .data_offset = header.HeaderSize,
        .sig_offset = 0,
        .sig_size = 0,
        .checksum = [_]u8{0} ** 8,
        .reserved = [_]u8{0} ** 26,
    };
}

test "verify accepts valid v1 header" {
    try verify(baseHeader());
}

test "verify rejects non-v1 version" {
    var h = baseHeader();
    h.version = 2;
    try std.testing.expectError(error.UnsupportedVersion, verify(h));
}

test "verify rejects nonzero sig fields" {
    var h = baseHeader();
    h.sig_size = 1;
    try std.testing.expectError(error.SigFieldNonZero, verify(h));
}

test "verify rejects nonzero checksum" {
    var h = baseHeader();
    h.checksum[0] = 1;
    try std.testing.expectError(error.ChecksumNonZero, verify(h));
}

test "verify rejects nonzero reserved" {
    var h = baseHeader();
    h.reserved[0] = 1;
    try std.testing.expectError(error.ReservedNonZero, verify(h));
}
