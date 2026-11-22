//! Deflate compression (raw, zlib and gzip containers) and CRC-32, over the
//! vendored zlib (vendor/zlib-1.3.1, through zshim.c). The calls follow
//! java.util.zip, so that the compressed bytes and the error messages are
//! the JVM implementation's.
const std = @import("std");

const pa = std.heap.c_allocator;

pub const Container = enum { raw, zlib, gzip };

pub const Error = error{ OutOfMemory, BadData };

/// The message of the last decompression error, as the JVM implementation
/// reports it (zlib's words, or GZIPInputStream's)
pub var last_error: []const u8 = "invalid compressed data";

extern fn scm_zdeflate(in: [*]const u8, inlen: usize, level: c_int, raw: c_int, chunk: c_int, finish_first: c_int, out: *?[*]u8, outlen: *usize) c_int;
extern fn scm_zinflate(in: [*]const u8, inlen: usize, raw: c_int, out: *?[*]u8, outlen: *usize, used: *usize, msg: *[*:0]const u8) c_int;
extern fn scm_zcrc32(crc: c_ulong, p: [*]const u8, n: usize) c_ulong;

/// zlib's result (malloc'ed) as an allocation of pa (the C allocator)
fn owned(p: ?[*]u8, n: usize) []u8 {
    const q = p orelse return &.{};
    if (n == 0) {
        std.c.free(q);
        return &.{};
    }
    return q[0..n];
}

fn deflateRaw(data: []const u8, level: i64, raw: bool, chunk: c_int, finish_first: bool) Error![]u8 {
    var out: ?[*]u8 = null;
    var n: usize = 0;
    const r = scm_zdeflate(data.ptr, data.len, @intCast(level), @intFromBool(raw), chunk, @intFromBool(finish_first), &out, &n);
    if (r != 0) return error.OutOfMemory;
    return owned(out, n);
}

/// Compress data; level 0 stores, 1..9 as zlib's levels, -1 the default (6).
/// raw and zlib as Deflater (finished, 4096-byte output buffer), gzip as
/// GZIPOutputStream (its header, 512-byte buffer, the CRC-32 and size).
pub fn compress(data: []const u8, container: Container, level: i64) Error![]u8 {
    switch (container) {
        .raw => return deflateRaw(data, level, true, 4096, true),
        .zlib => return deflateRaw(data, level, false, 4096, true),
        .gzip => {
            const body = try deflateRaw(data, level, true, 512, false);
            defer if (body.len > 0) pa.free(body);
            const out = pa.alloc(u8, 10 + body.len + 8) catch return error.OutOfMemory;
            @memcpy(out[0..10], &[_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff });
            @memcpy(out[10..][0..body.len], body);
            std.mem.writeInt(u32, out[10 + body.len ..][0..4], crc32(data), .little);
            std.mem.writeInt(u32, out[14 + body.len ..][0..4], @truncate(data.len), .little);
            return out;
        },
    }
}

/// Compress data as a zip entry (ZipOutputStream's Deflater)
pub fn compressEntry(data: []const u8) Error![]u8 {
    return deflateRaw(data, -1, true, 512, false);
}

const Inflated = struct { out: []u8, used: usize, status: c_int };

fn inflate(data: []const u8, raw: bool) Error!Inflated {
    var out: ?[*]u8 = null;
    var n: usize = 0;
    var used: usize = 0;
    var m: [*:0]const u8 = "invalid compressed data";
    const r = scm_zinflate(data.ptr, data.len, @intFromBool(raw), &out, &n, &used, &m);
    switch (r) {
        -1 => {
            last_error = std.mem.span(m);
            return error.BadData;
        },
        -3 => return error.OutOfMemory,
        else => return .{ .out = owned(out, n), .used = used, .status = r },
    }
}

/// Decompress data. raw and zlib as Inflater: a stream that ends early (or
/// needs a preset dictionary) gives the data so far, trailing bytes after
/// the end are ignored. gzip as GZIPInputStream, with concatenated members.
pub fn decompress(data: []const u8, container: Container) Error![]u8 {
    switch (container) {
        .raw, .zlib => return (try inflate(data, container == .raw)).out,
        .gzip => {
            var out: std.ArrayList(u8) = .empty;
            errdefer out.deinit(pa);
            var pos: usize = 0;
            var first = true;
            while (true) {
                const hlen = gzipHeader(data[pos..]) catch |e| {
                    if (first) return e;
                    break; // as GZIPInputStream: trailing bytes that are no member end the data
                };
                first = false;
                pos += hlen;
                const r = try inflate(data[pos..], true);
                defer if (r.out.len > 0) pa.free(r.out);
                if (r.status != 1) {
                    last_error = "Unexpected end of ZLIB input stream";
                    return error.BadData;
                }
                pos += r.used;
                if (data.len - pos < 8) {
                    last_error = "Unexpected end of ZLIB input stream";
                    return error.BadData;
                }
                if (std.mem.readInt(u32, data[pos..][0..4], .little) != crc32(r.out) or
                    std.mem.readInt(u32, data[pos + 4 ..][0..4], .little) != @as(u32, @truncate(r.out.len)))
                {
                    last_error = "Corrupt GZIP trailer";
                    return error.BadData;
                }
                pos += 8;
                out.appendSlice(pa, r.out) catch return error.OutOfMemory;
                if (pos >= data.len) break;
            }
            return out.toOwnedSlice(pa) catch error.OutOfMemory;
        },
    }
}

/// The length of the gzip member header at the start of b (GZIPInputStream's
/// readHeader and its messages)
fn gzipHeader(b: []const u8) Error!usize {
    const eof = struct {
        fn f() Error {
            last_error = "Unexpected end of ZLIB input stream";
            return error.BadData;
        }
    }.f;
    if (b.len < 2) return eof();
    if (b[0] != 0x1f or b[1] != 0x8b) {
        last_error = "Not in GZIP format";
        return error.BadData;
    }
    if (b.len < 3) return eof();
    if (b[2] != 8) {
        last_error = "Unsupported compression method";
        return error.BadData;
    }
    if (b.len < 10) return eof();
    const flg = b[3];
    var p: usize = 10;
    if (flg & 4 != 0) { // FEXTRA
        if (b.len < p + 2) return eof();
        p += 2 + @as(usize, std.mem.readInt(u16, b[p..][0..2], .little));
        if (b.len < p) return eof();
    }
    inline for (.{ 8, 16 }) |bit| { // FNAME, FCOMMENT
        if (flg & bit != 0) {
            while (true) {
                if (p >= b.len) return eof();
                p += 1;
                if (b[p - 1] == 0) break;
            }
        }
    }
    if (flg & 2 != 0) { // FHCRC
        if (b.len < p + 2) return eof();
        if (std.mem.readInt(u16, b[p..][0..2], .little) != @as(u16, @truncate(crc32(b[0..p])))) {
            last_error = "Corrupt GZIP header";
            return error.BadData;
        }
        p += 2;
    }
    return p;
}

pub fn crc32(data: []const u8) u32 {
    return @truncate(scm_zcrc32(0, data.ptr, data.len));
}

/// CRC-32 continued from crc (for streams)
pub fn crc32Update(crc: u32, data: []const u8) u32 {
    return @truncate(scm_zcrc32(crc, data.ptr, data.len));
}
