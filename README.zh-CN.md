# libarp

[English](README.md) | 简体中文

一个用于读写 ARP（Advanced Release Package）格式的库。

## ARP 文件格式

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

## 功能

- 解析 64 字节文件头
- 将 Header 序列化为字节数组
- 打包：把 Header、`.info` 和数据段组装成 `.arp` 文件
- 解包：从 `.arp` 文件还原 Header、`.info` 和数据段
- 后续支持签名与完整性校验

## 许可证

MIT
