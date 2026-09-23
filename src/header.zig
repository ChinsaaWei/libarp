const std = @import("std");

pub const Magic = [4]u8{ 'A', 'R', 'P', 0x01 };
pub const HeaderSize = 64;
pub const SignatureSize = 109;

pub const Header = struct {
    version: u16,
    info_size: u32,
    data_offset: u64,
    sig_offset: u64,
    sig_size: u32,
    checksum: [8]u8,
    reserved: [26]u8,

    pub fn parse(bytes: [HeaderSize]u8) !Header {
        if (!std.mem.eql(u8, bytes[0..4], &Magic)) {
            return error.BadMagic;
        }

        const version = std.mem.readInt(u16, bytes[4..6], .little);
        const info_size = std.mem.readInt(u32, bytes[6..10], .little);
        const data_offset = std.mem.readInt(u64, bytes[10..18], .little);
        const sig_offset = std.mem.readInt(u64, bytes[18..26], .little);
        const sig_size = std.mem.readInt(u32, bytes[26..30], .little);
        const checksum = bytes[30..38].*;
        const reserved = bytes[38..64].*;

        return .{
            .version = version,
            .info_size = info_size,
            .data_offset = data_offset,
            .sig_offset = sig_offset,
            .sig_size = sig_size,
            .checksum = checksum,
            .reserved = reserved,
        };
    }

    pub fn serialize(self: Header) [HeaderSize]u8 {
        var bytes: [HeaderSize]u8 = undefined;
        @memcpy(bytes[0..4], &Magic);
        std.mem.writeInt(u16, bytes[4..6], self.version, .little);
        std.mem.writeInt(u32, bytes[6..10], self.info_size, .little);
        std.mem.writeInt(u64, bytes[10..18], self.data_offset, .little);
        std.mem.writeInt(u64, bytes[18..26], self.sig_offset, .little);
        std.mem.writeInt(u32, bytes[26..30], self.sig_size, .little);
        @memcpy(bytes[30..38], &self.checksum);
        @memcpy(bytes[38..64], &self.reserved);
        return bytes;
    }

    pub fn validateFormat(self: Header) !void {
        if (self.version != 1) return error.UnsupportedVersion;
        if (self.data_offset != @as(u64, HeaderSize) + self.info_size) {
            return error.DataOffsetMismatch;
        }
        if (self.sig_size != 0 and self.sig_size != SignatureSize) {
            return error.SigSizeBad;
        }
        if ((self.sig_offset == 0) != (self.sig_size == 0)) {
            return error.SigSizeBad;
        }
        if (self.sig_size != 0 and self.sig_offset < self.data_offset) {
            return error.SigOutOfBounds;
        }
        for (self.reserved) |b| {
            if (b != 0) return error.ReservedNonZero;
        }
    }

    pub fn validateBounds(self: Header, file_size: u64) !void {
        if (self.data_offset > file_size) return error.Truncated;
        if (self.sig_size != 0) {
            const end = std.math.add(u64, self.sig_offset, self.sig_size) catch
                return error.SigOutOfBounds;
            if (end > file_size) return error.SigOutOfBounds;
        }
    }

    pub fn dataLen(self: Header, file_size: u64) u64 {
        const end: u64 = if (self.sig_size != 0) self.sig_offset else file_size;
        if (end <= self.data_offset) return 0;
        return end - self.data_offset;
    }
};

pub fn parseChecked(bytes: []const u8, file_size: u64) !Header {
    if (bytes.len < HeaderSize) return error.Truncated;
    var arr: [HeaderSize]u8 = undefined;
    @memcpy(&arr, bytes[0..HeaderSize]);
    const h = try Header.parse(arr);
    try h.validateFormat();
    try h.validateBounds(file_size);
    return h;
}
