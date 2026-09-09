const std = @import("std");
const header = @import("header");
const verifier = @import("verifier");
const packer = @import("packer");
const unpacker = @import("unpacker");

const c = @cImport({
    @cInclude("stdio.h");
});

pub const Err = enum(c_int) {
    ok = 0,
    bad_arg = 1,
    info_too_large = 2,
    overflow = 3,
    buffer_too_small = 4,
    bad_magic = 5,
    bad_version = 6,
    truncated = 7,
    open_failed = 8,
    io_failed = 9,
    nonzero_reserved = 10,
    unknown = 99,
};

pub const CHeader = extern struct {
    version: u16,
    info_size: u32,
    data_offset: u64,
    sig_offset: u64,
    sig_size: u32,
    checksum: [8]u8,
    reserved: [26]u8,
};

fn codeOf(e: anyerror) Err {
    return switch (e) {
        error.BadArg => .bad_arg,
        error.InfoTooLarge => .info_too_large,
        error.Overflow => .overflow,
        error.BufferTooSmall => .buffer_too_small,
        error.BadMagic => .bad_magic,
        error.UnsupportedVersion => .bad_version,
        error.SigFieldNonZero => .nonzero_reserved,
        error.ChecksumNonZero => .nonzero_reserved,
        error.ReservedNonZero => .nonzero_reserved,
        error.Truncated => .truncated,
        error.OpenFailed => .open_failed,
        error.IOFailed => .io_failed,
        else => .unknown,
    };
}

fn computeTotal(info_len: usize, data_len: usize) !usize {
    if (info_len > std.math.maxInt(u32)) return error.InfoTooLarge;
    const data_offset: u64 = header.HeaderSize + info_len;
    const total = std.math.add(u64, data_offset, data_len) catch return error.Overflow;
    if (total > std.math.maxInt(usize)) return error.Overflow;
    return @intCast(total);
}

export fn arp_pack_size(info_len: usize, data_len: usize) usize {
    return computeTotal(info_len, data_len) catch 0;
}

export fn arp_pack_mem(
    info: ?[*]const u8,
    info_len: usize,
    data: ?[*]const u8,
    data_len: usize,
    out: ?[*]u8,
    out_cap: usize,
) Err {
    const ip = info orelse return .bad_arg;
    const dp = data orelse return .bad_arg;
    const op = out orelse return .bad_arg;
    packMemInternal(ip[0..info_len], dp[0..data_len], op[0..out_cap]) catch |e| return codeOf(e);
    return .ok;
}

fn packMemInternal(info: []const u8, data: []const u8, out: []u8) !void {
    const total = try computeTotal(info.len, data.len);
    if (out.len < total) return error.BufferTooSmall;
    var w = std.Io.Writer.fixed(out[0..total]);
    var r = std.Io.Reader.fixed(data);
    _ = try packer.write(&w, info, &r, .{});
}

export fn arp_pack_stream(
    out_path: [*:0]const u8,
    info: ?[*]const u8,
    info_len: usize,
    data_path: [*:0]const u8,
) Err {
    const ip = info orelse return .bad_arg;
    packStreamInternal(out_path, ip[0..info_len], data_path) catch |e| return codeOf(e);
    return .ok;
}

fn packStreamInternal(out_path: [*:0]const u8, info: []const u8, data_path: [*:0]const u8) !void {
    if (info.len > std.math.maxInt(u32)) return error.InfoTooLarge;

    const fout = c.fopen(out_path, "wb") orelse return error.OpenFailed;
    defer _ = c.fclose(fout);

    const h = header.Header{
        .version = 1,
        .info_size = @intCast(info.len),
        .data_offset = header.HeaderSize + info.len,
        .sig_offset = 0,
        .sig_size = 0,
        .checksum = [_]u8{0} ** 8,
        .reserved = [_]u8{0} ** 26,
    };
    const hdr_bytes = h.serialize();
    if (@as(usize, @intCast(c.fwrite(&hdr_bytes, 1, hdr_bytes.len, fout))) != hdr_bytes.len)
        return error.IOFailed;
    if (info.len > 0 and @as(usize, @intCast(c.fwrite(info.ptr, 1, info.len, fout))) != info.len)
        return error.IOFailed;

    const fin = c.fopen(data_path, "rb") orelse return error.OpenFailed;
    defer _ = c.fclose(fin);

    var buf: [64 * 1024]u8 = undefined;
    while (true) {
        const n: usize = @intCast(c.fread(&buf, 1, buf.len, fin));
        if (n == 0) {
            if (c.ferror(fin) != 0) return error.IOFailed;
            return;
        }
        if (@as(usize, @intCast(c.fwrite(&buf, 1, n, fout))) != n) return error.IOFailed;
    }
}

export fn arp_header_parse(
    bytes: ?[*]const u8,
    bytes_len: usize,
    out: ?*CHeader,
) Err {
    const b = bytes orelse return .bad_arg;
    const o = out orelse return .bad_arg;
    if (bytes_len < header.HeaderSize) return .truncated;

    var arr: [header.HeaderSize]u8 = undefined;
    @memcpy(&arr, b[0..header.HeaderSize]);
    const h = header.Header.parse(arr) catch |e| return codeOf(e);
    verifier.verify(h) catch |e| return codeOf(e);

    o.* = .{
        .version = h.version,
        .info_size = h.info_size,
        .data_offset = h.data_offset,
        .sig_offset = h.sig_offset,
        .sig_size = h.sig_size,
        .checksum = h.checksum,
        .reserved = h.reserved,
    };
    return .ok;
}

export fn arp_unpack_stream(
    arp_path: [*:0]const u8,
    data_out_path: [*:0]const u8,
) Err {
    unpackStreamInternal(arp_path, data_out_path) catch |e| return codeOf(e);
    return .ok;
}

fn unpackStreamInternal(arp_path: [*:0]const u8, data_out_path: [*:0]const u8) !void {
    const fin = c.fopen(arp_path, "rb") orelse return error.OpenFailed;
    defer _ = c.fclose(fin);

    var hdr_bytes: [header.HeaderSize]u8 = undefined;
    var off: usize = 0;
    while (off < hdr_bytes.len) {
        const n: usize = @intCast(c.fread(&hdr_bytes[off], 1, hdr_bytes.len - off, fin));
        if (n == 0) return error.Truncated;
        off += n;
    }
    const h = try header.Header.parse(hdr_bytes);
    try verifier.verify(h);
    if (h.data_offset < header.HeaderSize) return error.Truncated;

    const fout = c.fopen(data_out_path, "wb") orelse return error.OpenFailed;
    defer _ = c.fclose(fout);

    var buf: [64 * 1024]u8 = undefined;

    var skip: u64 = h.data_offset - header.HeaderSize;
    while (skip > 0) {
        const want: usize = @intCast(@min(skip, buf.len));
        const n: usize = @intCast(c.fread(&buf, 1, want, fin));
        if (n == 0) return error.Truncated;
        skip -= n;
    }

    while (true) {
        const n: usize = @intCast(c.fread(&buf, 1, buf.len, fin));
        if (n == 0) {
            if (c.ferror(fin) != 0) return error.IOFailed;
            return;
        }
        if (@as(usize, @intCast(c.fwrite(&buf, 1, n, fout))) != n) return error.IOFailed;
    }
}

fn writePathBytes(path: [*:0]const u8, bytes: []const u8) !void {
    const f = c.fopen(path, "wb") orelse return error.OpenFailed;
    defer _ = c.fclose(f);
    if (bytes.len == 0) return;
    if (@as(usize, @intCast(c.fwrite(bytes.ptr, 1, bytes.len, f))) != bytes.len)
        return error.IOFailed;
}

fn readPathBytes(path: [*:0]const u8, allocator: std.mem.Allocator) ![]u8 {
    const f = c.fopen(path, "rb") orelse return error.OpenFailed;
    defer _ = c.fclose(f);
    if (c.fseek(f, 0, c.SEEK_END) != 0) return error.IOFailed;
    const end: usize = @intCast(c.ftell(f));
    if (c.fseek(f, 0, c.SEEK_SET) != 0) return error.IOFailed;
    const buf = try allocator.alloc(u8, end);
    if (buf.len == 0) return buf;
    var off: usize = 0;
    while (off < buf.len) {
        const n: usize = @intCast(c.fread(@ptrCast(buf.ptr + off), 1, buf.len - off, f));
        if (n == 0) return error.Truncated;
        off += n;
    }
    return buf;
}

fn validHeader() header.Header {
    return .{
        .version = 1,
        .info_size = 18,
        .data_offset = 82,
        .sig_offset = 0,
        .sig_size = 0,
        .checksum = [_]u8{0} ** 8,
        .reserved = [_]u8{0} ** 26,
    };
}

test "cabi arp_pack_mem roundtrip" {
    const info = "name = \"demo\"\n";
    const data = "payload-bytes";

    const total = arp_pack_size(info.len, data.len);
    try std.testing.expectEqual(@as(usize, 64 + info.len + data.len), total);

    const out = try std.testing.allocator.alloc(u8, total);
    defer std.testing.allocator.free(out);

    const rc = arp_pack_mem(info.ptr, info.len, data.ptr, data.len, out.ptr, out.len);
    try std.testing.expectEqual(Err.ok, rc);

    var r = std.Io.Reader.fixed(out);
    const data_out = try std.testing.allocator.alloc(u8, data.len);
    defer std.testing.allocator.free(data_out);
    var w = std.Io.Writer.fixed(data_out);
    const res = try unpacker.read(std.testing.allocator, &w, &r);
    defer std.testing.allocator.free(res.info);

    try std.testing.expectEqualSlices(u8, info, res.info);
    try std.testing.expectEqualSlices(u8, data, data_out);
}

test "cabi arp_pack_stream writes valid arp" {
    const data_path = "zlibarp_cabi_data.bin";
    const out_path = "zlibarp_cabi_out.arp";
    defer _ = c.remove(data_path);
    defer _ = c.remove(out_path);

    const info = "name = \"demo\"\n";
    const data = "stream-payload-bytes";
    try writePathBytes(data_path, data);

    const rc = arp_pack_stream(out_path, info.ptr, info.len, data_path);
    try std.testing.expectEqual(Err.ok, rc);

    const whole = try readPathBytes(out_path, std.testing.allocator);
    defer std.testing.allocator.free(whole);

    try std.testing.expectEqual(@as(usize, 64 + info.len + data.len), whole.len);
    try std.testing.expectEqualSlices(u8, &header.Magic, whole[0..4]);
    try std.testing.expectEqualSlices(u8, info, whole[64 .. 64 + info.len]);
    try std.testing.expectEqualSlices(u8, data, whole[64 + info.len ..]);
}

test "cabi arp_header_parse validates" {
    const h = validHeader();
    const bytes = h.serialize();
    var ch: CHeader = undefined;
    try std.testing.expectEqual(Err.ok, arp_header_parse(&bytes, bytes.len, &ch));
    try std.testing.expectEqual(@as(u16, 1), ch.version);
    try std.testing.expectEqual(@as(u32, 18), ch.info_size);
    try std.testing.expectEqual(@as(u64, 82), ch.data_offset);

    var short: [10]u8 = undefined;
    try std.testing.expectEqual(Err.truncated, arp_header_parse(&short, short.len, &ch));

    var garbage = [_]u8{'X'} ** 64;
    try std.testing.expectEqual(Err.bad_magic, arp_header_parse(&garbage, garbage.len, &ch));

    var bad_ver = h;
    bad_ver.version = 2;
    const bv_bytes = bad_ver.serialize();
    try std.testing.expectEqual(Err.bad_version, arp_header_parse(&bv_bytes, bv_bytes.len, &ch));

    try std.testing.expectEqual(Err.bad_arg, arp_header_parse(null, 0, &ch));
}

test "cabi arp_header_parse rejects nonzero reserved" {
    var h = validHeader();
    h.sig_size = 1;
    const bytes = h.serialize();
    var ch: CHeader = undefined;
    try std.testing.expectEqual(Err.nonzero_reserved, arp_header_parse(&bytes, bytes.len, &ch));
}

test "cabi arp_unpack_stream extracts data" {
    const data_path = "zlibarp_cabi_in_data.bin";
    const arp_path = "zlibarp_cabi_src.arp";
    const out_path = "zlibarp_cabi_out_data.bin";
    defer _ = c.remove(data_path);
    defer _ = c.remove(arp_path);
    defer _ = c.remove(out_path);

    const info = "name = \"demo\"\n";
    const data = "stream-payload-bytes";
    try writePathBytes(data_path, data);

    try std.testing.expectEqual(Err.ok, arp_pack_stream(arp_path, info.ptr, info.len, data_path));
    try std.testing.expectEqual(Err.ok, arp_unpack_stream(arp_path, out_path));

    const extracted = try readPathBytes(out_path, std.testing.allocator);
    defer std.testing.allocator.free(extracted);
    try std.testing.expectEqualSlices(u8, data, extracted);
}

test "cabi read side errors" {
    const garbage_path = "zlibarp_cabi_bad.arp";
    defer _ = c.remove(garbage_path);
    var garbage = [_]u8{'X'} ** 64;
    try writePathBytes(garbage_path, &garbage);
    try std.testing.expectEqual(Err.bad_magic, arp_unpack_stream(garbage_path, "zlibarp_cabi_never.bin"));

    try std.testing.expectEqual(Err.open_failed, arp_unpack_stream("zlibarp_cabi_missing.arp", "zlibarp_cabi_never.bin"));
}

test "cabi pack error cases" {
    try std.testing.expectEqual(@as(usize, 0), arp_pack_size(std.math.maxInt(u32) + 1, 0));
    var buf: [64]u8 = undefined;
    try std.testing.expectEqual(Err.buffer_too_small, arp_pack_mem("a", 1, "b", 1, &buf, buf.len));
}
