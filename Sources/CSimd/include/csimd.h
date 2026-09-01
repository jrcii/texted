#ifndef CSIMD_H
#define CSIMD_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    size_t lines;     /* number of '\n' bytes */
    bool ascii;       /* every byte < 0x80 */
    bool valid_utf8;  /* strictly valid UTF-8 (true for empty input) */
    bool used_avx512; /* the AVX-512 kernel ran */
} te_scan_result;

/* One pass over the buffer: newline count, ASCII detection, UTF-8 validation. */
te_scan_result te_scan(const uint8_t *buf, size_t len);

#endif
