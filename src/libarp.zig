const std = @import("std");
const header = @import("header");
pub const packer = @import("packer");
const unpack = @import("unpacker");

test "packer.write writes header, info and data in order" {
    const info = "name = \"demo\"\n";
    const data = "compressed-bytes";
    const total = 64 + info.len + data.len;

    const buf = try std.testing.allocator.alloc(u8, total);
    defer std.testing.allocator.free(buf);

    var w = std.Io.Writer.fixed(buf);
    var r = std.Io.Reader.fixed(data);

    const h = try packer.write(&w, info, &r, .{});

    try std.testing.expectEqual(@as(u32, @intCast(info.len)), h.info_size);
    try std.testing.expectEqual(@as(u64, @intCast(64 + info.len)), h.data_offset);
    try std.testing.expectEqual(@as(usize, total), w.end);
    try std.testing.expectEqualSlices(u8, &header.Magic, buf[0..4]);
    try std.testing.expectEqualSlices(u8, info, buf[64 .. 64 + info.len]);
    try std.testing.expectEqualSlices(u8, data, buf[64 + info.len ..]);
}
