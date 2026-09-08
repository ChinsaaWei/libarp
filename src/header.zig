const std = @import("std");

pub const Magic = [4]u8{'A', 'R', 'P', 0x01};
pub const HeaderSize = 64;

pub const Header = struct {
    version: u16,
    info_size: u32,
    data_offset: u64,
    sig_offset: u64,
    sig_size: u32,
    checksum: [8]u8,
    reserved: [26]u8,

    pub fn parse(bytes: [HeaderSize]u8) !Header {
        if (!std.mem.eql(u8,bytes[0..4],&Magic)){
            return error.BadMagic;
        }

        const version = std.mem.readInt(u16, bytes[4..6], .little);
        const info_size = std.mem.readInt(u32, bytes[6..10], .little);
        const data_offset = std.mem.readInt(u64, bytes[10..18], .little);
        const sig_offset = std.mem.readInt(u64, bytes[18..26], .little);
        const sig_size = std.mem.readInt(u32, bytes[26..30], .little);
        const checksum = bytes[30..38].*;
        const reserved = bytes[38..64].*;

        const hdr = Header{
            .version = version,
            .info_size = info_size,
            .data_offset = data_offset,
            .sig_offset = sig_offset,
            .sig_size = sig_size,
            .checksum = checksum,
            .reserved = reserved,
        };

        return hdr;
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

};
