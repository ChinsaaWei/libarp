# libarp

[English](README.md) | 简体中文

ARP（Advanced Release Package）的写入与读取库。

## ARP 格式说明

```
┌────────────────────────────────────────┐
│ 偏移 0-63：64B 头（Header）            │
│   - magic: "ARP\x01"                   │
│   - version: u16（当前 = 1）           │
│   - info_size: u32                     │
│   - data_offset: u64                   │
│   - sig_offset: u64（预留）            │
│   - sig_size: u32（预留）              │
│   - checksum: [8]u8（预留）            │
│   - reserved: [26]u8（预留）           │
├────────────────────────────────────────┤
│ 偏移 64：.info 元数据（类 TOML 文本）  │
│   长度 = info_size                     │
├────────────────────────────────────────┤
│ 偏移 data_offset：bin.tar.zst 压缩数据 │
│   长度 = 文件大小 - data_offset        │
└────────────────────────────────────────┘
```

## 特性

- 解析 64B 头（小端序，带边界校验）
- 将 Header 序列化为字节数组
- 打包：Header + .info + 数据 → `.arp` 文件
- 解包：`.arp` 文件 → Header + .info + 数据
- 未来将支持签名与完整性校验

## 许可证

MIT
