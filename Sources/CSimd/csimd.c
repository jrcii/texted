#include "csimd.h"

/*
 * te_scan: one pass over a file buffer producing
 *   - the '\n' count (for the window subtitle),
 *   - whether the buffer is pure ASCII,
 *   - whether it is strictly valid UTF-8.
 *
 * On x86_64 with AVX-512BW the hot loop handles 64 bytes per iteration:
 * one compare-to-mask + popcount for newlines, one movemask for the ASCII
 * check. Pure-ASCII files (the common case for large logs/data) never touch
 * the scalar validator at all. When a non-ASCII byte appears, everything
 * from the first non-ASCII chunk onward is validated by the scalar DFA —
 * that chunk is guaranteed to start on a sequence boundary because every
 * preceding chunk was ASCII.
 */

/* Strict UTF-8 validation: rejects overlongs, surrogates, > U+10FFFF. */
static bool utf8_valid(const uint8_t *p, size_t len) {
    size_t i = 0;
    while (i < len) {
        uint8_t b = p[i];
        if (b < 0x80) {
            i++;
            continue;
        }
        size_t cont;
        uint32_t cp;
        if ((b & 0xE0) == 0xC0) {
            if (b < 0xC2) return false; /* overlong 2-byte */
            cont = 1;
            cp = b & 0x1F;
        } else if ((b & 0xF0) == 0xE0) {
            cont = 2;
            cp = b & 0x0F;
        } else if ((b & 0xF8) == 0xF0) {
            if (b > 0xF4) return false; /* > U+10FFFF */
            cont = 3;
            cp = b & 0x07;
        } else {
            return false; /* stray continuation or 0xF8+ */
        }
        if (i + cont >= len) return false; /* truncated sequence */
        for (size_t k = 1; k <= cont; k++) {
            uint8_t c = p[i + k];
            if ((c & 0xC0) != 0x80) return false;
            cp = (cp << 6) | (uint32_t)(c & 0x3F);
        }
        if (cont == 2 && (cp < 0x800 || (cp >= 0xD800 && cp <= 0xDFFF))) return false;
        if (cont == 3 && (cp < 0x10000 || cp > 0x10FFFF)) return false;
        i += cont + 1;
    }
    return true;
}

static void scan_scalar(const uint8_t *p, size_t len, size_t *lines, size_t *first_non_ascii) {
    size_t count = 0;
    size_t fna = (size_t)-1;
    for (size_t i = 0; i < len; i++) {
        if (p[i] == '\n') count++;
        if (fna == (size_t)-1 && p[i] >= 0x80) fna = i;
    }
    *lines = count;
    *first_non_ascii = fna;
}

#if defined(__x86_64__)

#include <immintrin.h>

static int avx512_supported(void) {
    static int cached = -1;
    if (cached < 0) {
        cached = __builtin_cpu_supports("avx512f") && __builtin_cpu_supports("avx512bw");
    }
    return cached;
}

__attribute__((target("avx512f,avx512bw")))
static void scan_avx512(const uint8_t *p, size_t len, size_t *lines, size_t *first_non_ascii) {
    const __m512i nl = _mm512_set1_epi8('\n');
    size_t count = 0;
    size_t fna = (size_t)-1;
    size_t i = 0;
    for (; i + 64 <= len; i += 64) {
        __m512i v = _mm512_loadu_si512((const void *)(p + i));
        count += (size_t)__builtin_popcountll(_mm512_cmpeq_epi8_mask(v, nl));
        if (fna == (size_t)-1) {
            uint64_t hi = (uint64_t)_mm512_movepi8_mask(v);
            if (hi) fna = i + (size_t)__builtin_ctzll(hi);
        }
    }
    for (; i < len; i++) {
        if (p[i] == '\n') count++;
        if (fna == (size_t)-1 && p[i] >= 0x80) fna = i;
    }
    *lines = count;
    *first_non_ascii = fna;
}

#endif /* __x86_64__ */

te_scan_result te_scan(const uint8_t *buf, size_t len) {
    te_scan_result r = {0, true, true, false};
    if (buf == NULL || len == 0) return r;

    size_t fna = (size_t)-1;
#if defined(__x86_64__)
    if (avx512_supported()) {
        scan_avx512(buf, len, &r.lines, &fna);
        r.used_avx512 = true;
    } else {
        scan_scalar(buf, len, &r.lines, &fna);
    }
#else
    scan_scalar(buf, len, &r.lines, &fna);
#endif

    if (fna != (size_t)-1) {
        r.ascii = false;
        r.valid_utf8 = utf8_valid(buf + fna, len - fna);
    }
    return r;
}
