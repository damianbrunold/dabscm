/* The runtime's interface to the vendored zlib (vendor/zlib-1.3.1), used by
   compress.zig. The calls follow java.util.zip's Deflater and Inflater, so
   that the bytes are the JVM implementation's. */
#include <stdlib.h>
#include <string.h>
#include "zlib.h"

static int grow(unsigned char **out, size_t *cap, size_t need) {
    if (need <= *cap) return 1;
    size_t c = *cap ? *cap : 256;
    while (c < need) c *= 2;
    unsigned char *p = realloc(*out, c);
    if (!p) return 0;
    *out = p;
    *cap = c;
    return 1;
}

/* Compress in. raw: no zlib header (Deflater(level, true)). chunk: the size
   of the output buffer per deflate call; finish_first: as Deflater.finish()
   before the first deflate (else as DeflaterOutputStream: the input is
   deflated without flushing, then finished). The result is malloc'ed.
   Returns 0, or -1 when out of memory, -2 for a bad level. */
int scm_zdeflate(const unsigned char *in, size_t inlen, int level, int raw, int chunk,
                 int finish_first, unsigned char **out, size_t *outlen) {
    z_stream s;
    memset(&s, 0, sizeof s);
    int r = deflateInit2(&s, level, Z_DEFLATED, raw ? -MAX_WBITS : MAX_WBITS, 8, Z_DEFAULT_STRATEGY);
    if (r == Z_STREAM_ERROR) return -2;
    if (r != Z_OK) return -1;
    size_t cap = 0, len = 0;
    unsigned char *buf = NULL;
    s.next_in = (unsigned char *)in;
    s.avail_in = (uInt)inlen;
    int flush = finish_first || inlen == 0 ? Z_FINISH : Z_NO_FLUSH;
    for (;;) {
        if (!grow(&buf, &cap, len + chunk)) { deflateEnd(&s); free(buf); return -1; }
        s.next_out = buf + len;
        s.avail_out = chunk;
        r = deflate(&s, flush);
        len += chunk - s.avail_out;
        if (r == Z_STREAM_END) break;
        if (r != Z_OK && r != Z_BUF_ERROR) { deflateEnd(&s); free(buf); return -1; }
        if (s.avail_in == 0) flush = Z_FINISH;
    }
    deflateEnd(&s);
    *out = buf;
    *outlen = len;
    return 0;
}

/* Inflate in (raw: no zlib header). *used: the input bytes consumed.
   Returns 1 at the end of the stream, 0 when the input ended first, 2 when
   a preset dictionary is needed (the output so far is returned in all
   three cases), -1 for bad data (*msg: zlib's message), -3 when out of
   memory. */
int scm_zinflate(const unsigned char *in, size_t inlen, int raw, unsigned char **out,
                 size_t *outlen, size_t *used, const char **msg) {
    z_stream s;
    memset(&s, 0, sizeof s);
    if (inflateInit2(&s, raw ? -MAX_WBITS : MAX_WBITS) != Z_OK) return -3;
    size_t cap = 0, len = 0;
    unsigned char *buf = NULL;
    s.next_in = (unsigned char *)in;
    s.avail_in = (uInt)inlen;
    int status;
    for (;;) {
        if (!grow(&buf, &cap, len + 65536)) { inflateEnd(&s); free(buf); return -3; }
        s.next_out = buf + len;
        s.avail_out = 65536;
        int r = inflate(&s, Z_SYNC_FLUSH);
        len += 65536 - s.avail_out;
        if (r == Z_STREAM_END) { status = 1; break; }
        if (r == Z_NEED_DICT) { status = 2; break; }
        if (r == Z_DATA_ERROR) {
            *msg = s.msg ? s.msg : "invalid compressed data";
            inflateEnd(&s);
            free(buf);
            return -1;
        }
        if (r == Z_MEM_ERROR) { inflateEnd(&s); free(buf); return -3; }
        if (s.avail_in == 0 && s.avail_out != 0) { status = 0; break; }
        if (r == Z_BUF_ERROR && s.avail_out != 0) { status = 0; break; }
    }
    *used = inlen - s.avail_in;
    inflateEnd(&s);
    *out = buf;
    *outlen = len;
    return status;
}

unsigned long scm_zcrc32(unsigned long crc, const unsigned char *p, size_t n) {
    return crc32_z(crc, p, n);
}
