# libarp

English | [简体中文](README.zh-CN.md)

An ARP (Advanced Release Package) write and read library.

## ARP Format

```
┌─────────────────────────────────────────────────┐
│ Offset 0-63: 64-byte header                     │
│   - magic: "ARP\x01"                            │
│   - version: u16 (current = 1)                  │
│   - info_size: u32                              │
│   - data_offset: u64                            │
│   - sig_offset: u64 (reserved)                  │
│   - sig_size: u32 (reserved)                    │
│   - checksum: [8]u8 (reserved)                  │
│   - reserved: [26]u8 (reserved)                 │
├─────────────────────────────────────────────────┤
│ Offset 64: .info metadata (TOML-like text)      │
│   Length = info_size                            │
├─────────────────────────────────────────────────┤
│ Offset data_offset: bin.tar.zst compressed data │
│   Length = file size - data_offset              │
└─────────────────────────────────────────────────┘
```

## Features

- Parse the 64-byte header (little-endian, with bounds checking)
- Serialize a header into a byte array
- Pack: header + `.info` + data into an `.arp` file
- Unpack: `.arp` file into header + `.info` + data
- Signature and integrity verification will be supported in the future

## License

MIT
