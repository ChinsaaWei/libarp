#ifndef LIBARP_H
#define LIBARP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum arp_err {
    ARP_OK = 0,
    ARP_ERR_BAD_ARG = 1,
    ARP_ERR_INFO_TOO_LARGE = 2,
    ARP_ERR_OVERFLOW = 3,
    ARP_ERR_BUFFER_TOO_SMALL = 4,
    ARP_ERR_BAD_MAGIC = 5,
    ARP_ERR_BAD_VERSION = 6,
    ARP_ERR_TRUNCATED = 7,
    ARP_ERR_OPEN_FAILED = 8,
    ARP_ERR_IO_FAILED = 9,
    ARP_ERR_NONZERO_RESERVED = 10,
    ARP_ERR_UNKNOWN = 99,
};

struct arp_header {
    uint16_t version;
    uint32_t info_size;
    uint64_t data_offset;
    uint64_t sig_offset;
    uint32_t sig_size;
    uint8_t checksum[8];
    uint8_t reserved[26];
};

size_t arp_pack_size(size_t info_len, size_t data_len);

enum arp_err arp_pack_mem(const void *info, size_t info_len,
                          const void *data, size_t data_len,
                          void *out, size_t out_cap);

enum arp_err arp_pack_stream(const char *out_path,
                             const void *info, size_t info_len,
                             const char *data_path);

enum arp_err arp_header_parse(const void *bytes, size_t bytes_len,
                              struct arp_header *out);

enum arp_err arp_unpack_stream(const char *arp_path,
                               const char *data_out_path);

#ifdef __cplusplus
}
#endif

#endif /* LIBARP_H */
