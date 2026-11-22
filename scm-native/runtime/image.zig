//! Image decoding and encoding for (scm image): PNG and JPEG to straight
//! (not premultiplied) RGBA, 8 bits per channel, rows top to bottom;
//! resizing, EXIF orientation and baseline JPEG encoding on such pixels.
//!
//! A port of scm-java ImageCodec.java (and scm-csharp ImageCodec.cs) with
//! the same algorithms and the same float and int arithmetic (Java float as
//! f32, double as f64, int overflow wrapping, truncating division), so all
//! three implementations produce the same bytes; keep them in step.
//! Plain Zig without Scheme dependencies: slices in, malloc'ed slices out.
const std = @import("std");
const compress = @import("compress.zig");

const pa = std.heap.c_allocator;

/// Image: malformed or unsupported data, the message in last_error.
/// Malformed: data the JVM implementation trips over with an index out of
/// bounds ("truncated or malformed image").
pub const Error = error{ Image, Malformed, OutOfMemory };

/// The message of the last Image error (ImageException's text)
pub threadlocal var last_error: []const u8 = "";

fn fail(comptime m: []const u8) Error {
    last_error = m;
    return error.Image;
}

/// A decoded image; rgba is allocated with the C allocator
pub const Image = struct { width: i32, height: i32, rgba: []u8 };

// --- Java arithmetic ---------------------------------------------------------------------

/// Math.round(float): the nearest int, ties toward positive infinity, NaN 0, saturating
fn round(x: f32) i32 {
    if (std.math.isNan(x)) return 0;
    const fl = @floor(x);
    const r = if (x - fl >= 0.5) fl + 1 else fl;
    if (r >= 2147483648.0) return std.math.maxInt(i32);
    if (r <= -2147483648.0) return std.math.minInt(i32);
    return @intFromFloat(r);
}

/// (int) of a double: toward zero, NaN 0, saturating
fn d2i(x: f64) i32 {
    if (std.math.isNan(x)) return 0;
    if (x >= 2147483647.0) return std.math.maxInt(i32);
    if (x <= -2147483648.0) return std.math.minInt(i32);
    return @intFromFloat(x);
}

/// a << n on Java ints (n taken mod 32, bits shifted out dropped)
inline fn shl(a: i32, n: i32) i32 {
    const s: u5 = @intCast(n & 31);
    return @bitCast(@as(u32, @bitCast(a)) << s);
}

/// a >>> n on Java ints
inline fn ushr(a: i32, n: i32) i32 {
    const s: u5 = @intCast(n & 31);
    return @bitCast(@as(u32, @bitCast(a)) >> s);
}

/// (short) of an int
inline fn short(v: i32) i16 {
    return @truncate(v);
}

inline fn f(v: i32) f32 {
    return @floatFromInt(v);
}

inline fn us(v: i64) usize {
    return @intCast(v);
}

fn checkSize(w: i64, h: i64, max_pixels: i64) Error!void {
    if (w <= 0 or h <= 0) return fail("bad image size");
    if (w *% h > max_pixels) {
        last_error = std.fmt.allocPrint(pa, "image too large ({d} x {d} pixels)", .{ w, h }) catch return error.OutOfMemory;
        return error.Image;
    }
}

/// Decodes a PNG or JPEG image; images of more than max_pixels pixels are refused.
pub fn decode(d: []const u8, max_pixels: i64) Error!Image {
    if (d.len >= 8 and d[0] == 0x89 and d[1] == 'P' and d[2] == 'N' and d[3] == 'G') {
        var p = Png{ .d = d, .max_pixels = max_pixels };
        return p.decode();
    }
    if (d.len >= 3 and d[0] == 0xFF and d[1] == 0xD8) {
        var arena = std.heap.ArenaAllocator.init(pa);
        defer arena.deinit();
        var j = Jpeg{ .d = d, .max_pixels = max_pixels, .al = arena.allocator() };
        return j.decode();
    }
    return fail("not a PNG or JPEG image");
}

// --- PNG ---------------------------------------------------------------------------------

const Png = struct {
    d: []const u8,
    max_pixels: i64,
    width: i64 = 0,
    height: i64 = 0,
    depth: i32 = 0,
    color_type: i32 = 0,
    interlace: i32 = 0,
    palette: ?[]const u8 = null, // RGB triples
    palette_alpha: ?[]const u8 = null, // per entry, from tRNS
    transparent: [3]i32 = .{ 0, 0, 0 }, // tRNS key of gray (1 sample) or RGB (3 samples)
    transparent_len: usize = 0, // 0: none

    fn u32at(p: *const Png, i: usize) u32 {
        const d = p.d;
        return (@as(u32, d[i]) << 24) | (@as(u32, d[i + 1]) << 16) | (@as(u32, d[i + 2]) << 8) | d[i + 3];
    }

    fn decode(p: *Png) Error!Image {
        const d = p.d;
        var idat: std.ArrayList(u8) = .empty;
        defer idat.deinit(pa);
        var pos: usize = 8;
        var header = false;
        while (pos + 8 <= d.len) {
            const len32 = p.u32at(pos);
            if (len32 > 0x7FFFFFFF or pos + 12 + @as(usize, len32) > d.len) return fail("PNG: truncated chunk");
            const len: usize = len32;
            const typ = d[pos + 4 .. pos + 8];
            const body = pos + 8;
            if (std.mem.eql(u8, typ, "IHDR")) {
                if (len < 13) return fail("PNG: bad IHDR");
                p.width = p.u32at(body);
                p.height = p.u32at(body + 4);
                p.depth = d[body + 8];
                p.color_type = d[body + 9];
                p.interlace = d[body + 12];
                try checkSize(p.width, p.height, p.max_pixels);
                if (!p.validDepth()) return fail("PNG: bad bit depth or colour type");
                if (p.interlace > 1) return fail("PNG: bad interlace method");
                header = true;
            } else if (std.mem.eql(u8, typ, "PLTE")) {
                p.palette = d[body .. body + len];
            } else if (std.mem.eql(u8, typ, "tRNS")) {
                if (p.color_type == 3) {
                    p.palette_alpha = d[body .. body + len];
                } else if (p.color_type == 0 and len >= 2) {
                    p.transparent[0] = (@as(i32, d[body]) << 8) | d[body + 1];
                    p.transparent_len = 1;
                } else if (p.color_type == 2 and len >= 6) {
                    for (0..3) |i| p.transparent[i] = (@as(i32, d[body + 2 * i]) << 8) | d[body + 2 * i + 1];
                    p.transparent_len = 3;
                }
            } else if (std.mem.eql(u8, typ, "IDAT")) {
                try idat.appendSlice(pa, d[body .. body + len]);
            }
            pos = body + len + 4;
            if (std.mem.eql(u8, typ, "IEND")) break;
        }
        if (!header) return fail("PNG: no IHDR");
        if (p.color_type == 3 and p.palette == null) return fail("PNG: no palette");
        const raw = try inflate(idat.items);
        defer pa.free(raw);
        // the JVM's int arithmetic would overflow beyond these
        if (p.width > 0x7FFFFFFF or p.height > 0x7FFFFFFF or p.width * p.height > 0x1FFFFFFF) return error.Malformed;
        const width = p.width;
        const height = p.height;
        const out = try pa.alloc(u8, us(width * height * 4));
        errdefer pa.free(out);
        @memset(out, 0);
        const nch: i64 = p.channels();
        const bits_per_pixel = nch * p.depth;
        const bpp: usize = us(@max(1, @divTrunc(bits_per_pixel, 8)));
        if (p.interlace == 0) {
            const stride = us(@divTrunc(width * bits_per_pixel + 7, 8));
            if (raw.len < (stride + 1) * us(height)) return fail("PNG: not enough image data");
            try unfilter(raw, 0, stride, us(height), bpp);
            for (0..us(height)) |y|
                try p.convertRow(raw, y * (stride + 1) + 1, us(width), out, y, 0, 1);
        } else {
            const sx = [7]i64{ 0, 4, 0, 2, 0, 1, 0 };
            const sy = [7]i64{ 0, 0, 4, 0, 2, 0, 1 };
            const dx = [7]i64{ 8, 8, 4, 4, 2, 2, 1 };
            const dy = [7]i64{ 8, 8, 8, 4, 4, 2, 2 };
            var off: usize = 0;
            for (0..7) |k| {
                const pw = @divTrunc(width - sx[k] + dx[k] - 1, dx[k]);
                const ph = @divTrunc(height - sy[k] + dy[k] - 1, dy[k]);
                if (pw <= 0 or ph <= 0) continue;
                const stride = us(@divTrunc(pw * bits_per_pixel + 7, 8));
                if (raw.len < off + (stride + 1) * us(ph)) return fail("PNG: not enough image data");
                try unfilter(raw, off, stride, us(ph), bpp);
                for (0..us(ph)) |y|
                    try p.convertRow(raw, off + y * (stride + 1) + 1, us(pw), out, us(sy[k]) + y * us(dy[k]), us(sx[k]), us(dx[k]));
                off += (stride + 1) * us(ph);
            }
        }
        return .{ .width = @intCast(width), .height = @intCast(height), .rgba = out };
    }

    fn validDepth(p: *const Png) bool {
        const dp = p.depth;
        return switch (p.color_type) {
            0 => dp == 1 or dp == 2 or dp == 4 or dp == 8 or dp == 16,
            3 => dp == 1 or dp == 2 or dp == 4 or dp == 8,
            2, 4, 6 => dp == 8 or dp == 16,
            else => false,
        };
    }

    fn channels(p: *const Png) i32 {
        return switch (p.color_type) {
            2 => 3,
            4 => 2,
            6 => 4,
            else => 1,
        };
    }

    // As java.util.zip.Inflater: a stream that ends early (or needs a
    // preset dictionary) gives the data so far
    fn inflate(z: []const u8) Error![]u8 {
        return compress.decompress(z, .zlib) catch |e| switch (e) {
            error.OutOfMemory => return error.OutOfMemory,
            error.BadData => fail("PNG: bad compressed data"),
        };
    }

    // Undoes the scanline filters in place; each row is a filter byte and stride bytes.
    fn unfilter(r: []u8, off: usize, stride: usize, rows: usize, bpp: usize) Error!void {
        for (0..rows) |y| {
            const row = off + y * (stride + 1);
            const fl = r[row];
            const cur = row + 1;
            const first = y == 0;
            const prev = if (first) 0 else row - stride; // prev row's data start
            switch (fl) {
                0 => {},
                1 => {
                    var i = bpp;
                    while (i < stride) : (i += 1) r[cur + i] +%= r[cur + i - bpp];
                },
                2 => if (!first) {
                    for (0..stride) |i| r[cur + i] +%= r[prev + i];
                },
                3 => for (0..stride) |i| {
                    const a: i32 = if (i >= bpp) r[cur + i - bpp] else 0;
                    const b: i32 = if (first) 0 else r[prev + i];
                    r[cur + i] +%= @truncate(@as(u32, @intCast((a + b) >> 1)));
                },
                4 => for (0..stride) |i| {
                    const a: i32 = if (i >= bpp) r[cur + i - bpp] else 0;
                    const b: i32 = if (first) 0 else r[prev + i];
                    const c: i32 = if (i >= bpp and !first) r[prev + i - bpp] else 0;
                    const pp = a + b - c;
                    const pa_ = @abs(pp - a);
                    const pb = @abs(pp - b);
                    const pc = @abs(pp - c);
                    const pr = if (pa_ <= pb and pa_ <= pc) a else (if (pb <= pc) b else c);
                    r[cur + i] +%= @truncate(@as(u32, @intCast(pr)));
                },
                else => return fail("PNG: bad filter type"),
            }
        }
    }

    // The n-th sample of a row at full precision.
    fn sample(p: *const Png, r: []const u8, start: usize, n: usize) i32 {
        switch (p.depth) {
            16 => return (@as(i32, r[start + 2 * n]) << 8) | r[start + 2 * n + 1],
            8 => return r[start + n],
            else => {
                const dp: usize = @intCast(p.depth);
                const bit = n * dp;
                const b: u32 = r[start + (bit >> 3)];
                const sh: u5 = @intCast(8 - dp - (bit & 7));
                return @intCast((b >> sh) & ((@as(u32, 1) << @intCast(dp)) - 1));
            },
        }
    }

    fn to8(p: *const Png, v: i32) i32 {
        return switch (p.depth) {
            16 => v >> 8,
            8 => v,
            else => @divTrunc(v * 255, shl(1, p.depth) - 1),
        };
    }

    fn trans(p: *const Png, i: usize) Error!i32 {
        if (i >= p.transparent_len) return error.Malformed;
        return p.transparent[i];
    }

    fn convertRow(p: *const Png, r: []const u8, start: usize, n: usize, out: []u8, y: usize, x0: usize, dx: usize) Error!void {
        const width: usize = @intCast(p.width);
        for (0..n) |i| {
            const o = (y * width + x0 + i * dx) * 4;
            var R: i32 = undefined;
            var G: i32 = undefined;
            var B: i32 = undefined;
            var A: i32 = 255;
            switch (p.color_type) {
                0 => {
                    const g = p.sample(r, start, i);
                    R = p.to8(g);
                    G = R;
                    B = R;
                    if (p.transparent_len != 0 and g == try p.trans(0)) A = 0;
                },
                2 => {
                    const r0 = p.sample(r, start, 3 * i);
                    const g0 = p.sample(r, start, 3 * i + 1);
                    const b0 = p.sample(r, start, 3 * i + 2);
                    R = p.to8(r0);
                    G = p.to8(g0);
                    B = p.to8(b0);
                    if (p.transparent_len != 0 and r0 == try p.trans(0) and g0 == try p.trans(1) and b0 == try p.trans(2)) A = 0;
                },
                3 => {
                    const idx: usize = @intCast(p.sample(r, start, i));
                    const pal = p.palette.?;
                    if (3 * idx + 2 >= pal.len) {
                        R = 0;
                        G = 0;
                        B = 0;
                    } else {
                        R = pal[3 * idx];
                        G = pal[3 * idx + 1];
                        B = pal[3 * idx + 2];
                    }
                    if (p.palette_alpha) |pa_| {
                        if (idx < pa_.len) A = pa_[idx];
                    }
                },
                4 => {
                    R = p.to8(p.sample(r, start, 2 * i));
                    G = R;
                    B = R;
                    A = p.to8(p.sample(r, start, 2 * i + 1));
                },
                else => {
                    R = p.to8(p.sample(r, start, 4 * i));
                    G = p.to8(p.sample(r, start, 4 * i + 1));
                    B = p.to8(p.sample(r, start, 4 * i + 2));
                    A = p.to8(p.sample(r, start, 4 * i + 3));
                },
            }
            out[o] = @truncate(@as(u32, @bitCast(R)));
            out[o + 1] = @truncate(@as(u32, @bitCast(G)));
            out[o + 2] = @truncate(@as(u32, @bitCast(B)));
            out[o + 3] = @truncate(@as(u32, @bitCast(A)));
        }
    }
};

// --- JPEG decoding -----------------------------------------------------------------------

const ZIGZAG = [64]u8{
    0,  1,  8,  16, 9,  2,  3,  10, 17, 24, 32, 25, 18, 11, 4,  5,
    12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6,  7,  14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
};

/// ZIGZAG[k] for k from the data (an index out of bounds on the JVM)
inline fn zz(k: i32) Error!usize {
    if (k < 0 or k > 63) return error.Malformed;
    return ZIGZAG[@intCast(k)];
}

// IDCT basis: C(u) cos((2x + 1) u pi / 16) / 2
const IDCT: [64]f32 = blk: {
    @setEvalBranchQuota(100000);
    var t: [64]f32 = undefined;
    for (0..8) |x| {
        for (0..8) |u| {
            const cu: f64 = if (u == 0) @sqrt(0.5) else 1.0;
            const ang: f64 = @as(f64, @floatFromInt((2 * x + 1) * u)) * std.math.pi / 16.0;
            t[x * 8 + u] = @floatCast(cu * @cos(ang) / 2.0);
        }
    }
    break :blk t;
};

const Huffman = struct {
    max_code: [18]i32 = undefined,
    val_ptr: [17]i32 = undefined,
    min_code: [17]i32 = undefined,
    values: []const u8,
    // fast lookup of codes up to 9 bits: (length << 8) | value, 0 if longer
    fast: [512]i32 = @splat(0),

    fn init(h: *Huffman, counts: *const [16]i32) Error!void {
        var code: i32 = 0;
        var k: i32 = 0;
        for (1..17) |len| {
            h.val_ptr[len] = k;
            h.min_code[len] = code;
            code += counts[len - 1];
            k += counts[len - 1];
            h.max_code[len] = if (counts[len - 1] > 0) code - 1 else -1;
            code <<= 1;
        }
        h.max_code[17] = std.math.maxInt(i32);
        var kk: usize = 0;
        code = 0;
        for (1..17) |len| {
            var i: i32 = 0;
            while (i < counts[len - 1]) : ({
                i += 1;
                kk += 1;
                code += 1;
            }) {
                if (len <= 9) {
                    const shift: u5 = @intCast(9 - len);
                    for (0..(@as(usize, 1) << shift)) |j| {
                        const idx = (@as(i64, code) << shift) | @as(i64, @intCast(j));
                        if (idx >= 512) return error.Malformed;
                        h.fast[@intCast(idx)] = (@as(i32, @intCast(len)) << 8) | h.values[kk];
                    }
                }
            }
            code <<= 1;
        }
    }
};

const Component = struct {
    id: i32 = 0,
    h: i32 = 0,
    v: i32 = 0,
    tq: i32 = 0,
    bw: i32 = 0, // blocks per line / column, padded to whole MCUs
    bh: i32 = 0,
    cw: i32 = 0, // blocks actually covering the component (non-interleaved scans)
    ch: i32 = 0,
    coef: []i16 = &.{}, // bw * bh * 64, natural order
    dc_pred: i32 = 0,
    dc: ?*const Huffman = null,
    ac: ?*const Huffman = null,
    plane: []u8 = &.{}, // bw*8 x bh*8 samples after IDCT
};

const Jpeg = struct {
    d: []const u8,
    max_pixels: i64,
    al: std.mem.Allocator, // an arena, for everything but the result
    pos: usize = 0,
    qt: [4][64]i32 = undefined,
    has_qt: [4]bool = .{ false, false, false, false },
    dc_tables: [4]?*const Huffman = .{ null, null, null, null },
    ac_tables: [4]?*const Huffman = .{ null, null, null, null },
    comps: []Component = &.{},
    width: i32 = 0,
    height: i32 = 0,
    hmax: i32 = 0,
    vmax: i32 = 0,
    mcus_x: i32 = 0,
    mcus_y: i32 = 0,
    progressive: bool = false,
    restart_interval: i32 = 0,
    adobe: i32 = -1, // Adobe APP14 transform, -1 if none
    jfif: bool = false,
    // bit reader
    bit_buf: i32 = 0,
    bit_cnt: i32 = 0,
    hit_marker: bool = false,
    eobrun: i32 = 0,

    /// d[i] & 0xFF
    inline fn at(j: *const Jpeg, i: usize) Error!i32 {
        if (i >= j.d.len) return error.Malformed;
        return j.d[i];
    }

    fn u16at(j: *const Jpeg, i: usize) Error!i32 {
        if (i + 1 >= j.d.len) return fail("JPEG: truncated");
        return (@as(i32, j.d[i]) << 8) | j.d[i + 1];
    }

    fn decode(j: *Jpeg) Error!Image {
        const d = j.d;
        j.pos = 2;
        var frame = false;
        while (true) {
            // find the next marker
            while (j.pos < d.len and d[j.pos] != 0xFF) j.pos += 1;
            while (j.pos < d.len and d[j.pos] == 0xFF) j.pos += 1;
            if (j.pos >= d.len) break;
            const m = d[j.pos];
            j.pos += 1;
            if (m == 0xD9) break; // EOI
            if (m >= 0xD0 and m <= 0xD7) continue; // stray RST
            if (m == 0x01) continue;
            const len: usize = @intCast(try j.u16at(j.pos));
            const seg = j.pos + 2;
            const end = j.pos + len;
            if (end > d.len) return fail("JPEG: truncated segment");
            switch (m) {
                0xC0, 0xC1, 0xC2 => {
                    try j.readFrame(seg, m == 0xC2);
                    frame = true;
                    j.pos = end;
                },
                0xC4 => {
                    try j.readHuffman(seg, end);
                    j.pos = end;
                },
                0xDB => {
                    try j.readQuant(seg, end);
                    j.pos = end;
                },
                0xDD => {
                    j.restart_interval = try j.u16at(seg);
                    j.pos = end;
                },
                0xDA => {
                    if (!frame) return fail("JPEG: scan before frame");
                    j.pos = try j.readScan(seg);
                },
                0xEE => {
                    if (len >= 12 and try j.at(seg) == 'A' and try j.at(seg + 1) == 'd' and try j.at(seg + 2) == 'o' and
                        try j.at(seg + 3) == 'b' and try j.at(seg + 4) == 'e')
                        j.adobe = try j.at(seg + 11);
                    j.pos = end;
                },
                0xE0 => {
                    if (len >= 7 and try j.at(seg) == 'J' and try j.at(seg + 1) == 'F' and try j.at(seg + 2) == 'I' and try j.at(seg + 3) == 'F')
                        j.jfif = true;
                    j.pos = end;
                },
                else => {
                    if ((m >= 0xC3 and m <= 0xCF) and m != 0xC4 and m != 0xC8 and m != 0xCC)
                        return fail("JPEG: unsupported coding (lossless, hierarchical or arithmetic)");
                    j.pos = end;
                },
            }
        }
        if (!frame) return fail("JPEG: no frame");
        return j.output();
    }

    fn readFrame(j: *Jpeg, p: usize, prog: bool) Error!void {
        j.progressive = prog;
        if (try j.at(p) != 8) return fail("JPEG: only 8-bit samples are supported");
        j.height = try j.u16at(p + 1);
        j.width = try j.u16at(p + 3);
        const n: usize = @intCast(try j.at(p + 5));
        if (j.height == 0) return fail("JPEG: height defined by DNL is not supported");
        try checkSize(j.width, j.height, j.max_pixels);
        if (n != 1 and n != 3 and n != 4) return fail("JPEG: unsupported number of components");
        j.comps = try j.al.alloc(Component, n);
        j.hmax = 1;
        j.vmax = 1;
        for (0..n) |i| {
            var c = Component{};
            const q = p + 6 + i * 3;
            c.id = try j.at(q);
            c.h = (try j.at(q + 1)) >> 4;
            c.v = (try j.at(q + 1)) & 0x0F;
            c.tq = (try j.at(q + 2)) & 3;
            if (c.h < 1 or c.h > 4 or c.v < 1 or c.v > 4) return fail("JPEG: bad sampling factors");
            j.hmax = @max(j.hmax, c.h);
            j.vmax = @max(j.vmax, c.v);
            j.comps[i] = c;
        }
        j.mcus_x = @divTrunc(j.width + 8 * j.hmax - 1, 8 * j.hmax);
        j.mcus_y = @divTrunc(j.height + 8 * j.vmax - 1, 8 * j.vmax);
        for (j.comps) |*c| {
            c.bw = j.mcus_x * c.h;
            c.bh = j.mcus_y * c.v;
            c.cw = @divTrunc(@divTrunc(j.width * c.h + j.hmax - 1, j.hmax) + 7, 8);
            c.ch = @divTrunc(@divTrunc(j.height * c.v + j.vmax - 1, j.vmax) + 7, 8);
            c.coef = try j.al.alloc(i16, us(c.bw) * us(c.bh) * 64);
            @memset(c.coef, 0);
        }
    }

    fn readHuffman(j: *Jpeg, p0: usize, end: usize) Error!void {
        var p = p0;
        while (p < end) {
            const b = try j.at(p);
            const tc = b >> 4;
            const th = b & 0x0F;
            if (th > 3 or tc > 1) return fail("JPEG: bad Huffman table");
            var counts: [16]i32 = undefined;
            var total: usize = 0;
            for (0..16) |i| {
                counts[i] = try j.at(p + 1 + i);
                total += @intCast(counts[i]);
            }
            if (p + 17 + total > end) return fail("JPEG: bad Huffman table");
            const h = try j.al.create(Huffman);
            h.* = .{ .values = j.d[p + 17 .. p + 17 + total] };
            try h.init(&counts);
            if (tc == 0) j.dc_tables[@intCast(th)] = h else j.ac_tables[@intCast(th)] = h;
            p += 17 + total;
        }
    }

    fn readQuant(j: *Jpeg, p0: usize, end: usize) Error!void {
        var p = p0;
        while (p < end) {
            const b = try j.at(p);
            const pq = b >> 4;
            const tq = b & 0x0F;
            if (tq > 3) return fail("JPEG: bad quantization table");
            var t: [64]i32 = undefined;
            p += 1;
            for (0..64) |i| {
                if (pq == 0) {
                    t[ZIGZAG[i]] = try j.at(p);
                    p += 1;
                } else {
                    t[ZIGZAG[i]] = try j.u16at(p);
                    p += 2;
                }
            }
            j.qt[@intCast(tq)] = t;
            j.has_qt[@intCast(tq)] = true;
        }
    }

    // --- entropy-coded data ---

    inline fn readBit(j: *Jpeg) Error!i32 {
        if (j.bit_cnt == 0) try j.fill();
        j.bit_cnt -= 1;
        return (j.bit_buf >> @intCast(j.bit_cnt)) & 1;
    }

    fn fill(j: *Jpeg) Error!void {
        const d = j.d;
        var b: i32 = 0;
        if (!j.hit_marker and j.pos >= d.len) return fail("JPEG: truncated data");
        if (!j.hit_marker and j.pos < d.len) {
            b = d[j.pos];
            if (b == 0xFF) {
                const next: i32 = if (j.pos + 1 < d.len) d[j.pos + 1] else 0;
                if (next == 0) {
                    j.pos += 2;
                } else {
                    j.hit_marker = true;
                    b = 0;
                }
            } else {
                j.pos += 1;
            }
        }
        j.bit_buf = ((j.bit_buf << 8) | b) & 0xFFFF;
        j.bit_cnt += 8;
    }

    fn receive(j: *Jpeg, n: i32) Error!i32 {
        var v: i32 = 0;
        var i: i32 = 0;
        while (i < n) : (i += 1) v = shl(v, 1) | try j.readBit();
        return v;
    }

    fn extend(v: i32, n: i32) i32 {
        return if (n == 0) 0 else (if (v < shl(1, n - 1)) v -% shl(1, n) +% 1 else v);
    }

    fn decodeHuff(j: *Jpeg, hh: ?*const Huffman) Error!i32 {
        const h = hh orelse return fail("JPEG: missing Huffman table");
        if (j.bit_cnt < 9) {
            try j.fill();
            if (j.bit_cnt < 9) try j.fill();
        }
        const peek = ushr(j.bit_buf, j.bit_cnt - 9) & 0x1FF;
        const fv = h.fast[@intCast(peek)];
        if (fv != 0) {
            j.bit_cnt -= fv >> 8;
            return fv & 0xFF;
        }
        var code: i32 = 0;
        for (1..17) |len| {
            code = (code << 1) | try j.readBit();
            if (h.max_code[len] >= 0 and code <= h.max_code[len] and code >= h.min_code[len])
                return h.values[@intCast(h.val_ptr[len] + code - h.min_code[len])];
        }
        return fail("JPEG: bad Huffman code");
    }

    fn resetBits(j: *Jpeg) void {
        j.bit_buf = 0;
        j.bit_cnt = 0;
        j.hit_marker = false;
    }

    // Reads a scan and returns the position after its entropy-coded data.
    fn readScan(j: *Jpeg, p: usize) Error!usize {
        const d = j.d;
        const ns: usize = @intCast(try j.at(p));
        const sc = try j.al.alloc(*Component, ns);
        for (0..ns) |i| {
            const cid = try j.at(p + 1 + 2 * i);
            const t = try j.at(p + 2 + 2 * i);
            var cc: ?*Component = null;
            for (j.comps) |*x| {
                if (x.id == cid) cc = x;
            }
            const c = cc orelse return fail("JPEG: scan names an unknown component");
            if ((t >> 4) > 3 or (t & 15) > 3) return error.Malformed;
            c.dc = j.dc_tables[@intCast(t >> 4)];
            c.ac = j.ac_tables[@intCast(t & 15)];
            sc[i] = c;
        }
        const q = p + 1 + 2 * ns;
        const ss = try j.at(q);
        const se = try j.at(q + 1);
        const ah = (try j.at(q + 2)) >> 4;
        const al = (try j.at(q + 2)) & 0x0F;
        j.pos = q + 3;
        j.resetBits();
        j.eobrun = 0;
        for (sc) |c| c.dc_pred = 0;
        const mcus: i32 = if (ns == 1) sc[0].cw * sc[0].ch else j.mcus_x * j.mcus_y;
        var since_restart: i32 = 0;
        var n: i32 = 0;
        while (n < mcus) : (n += 1) {
            if (j.restart_interval > 0 and since_restart == j.restart_interval) {
                // expect RSTn: realign, skip the marker, reset predictions
                j.resetBits();
                while (j.pos < d.len and !(d[j.pos] == 0xFF and j.pos + 1 < d.len and
                    d[j.pos + 1] >= 0xD0 and d[j.pos + 1] <= 0xD7)) j.pos += 1;
                if (j.pos < d.len) j.pos += 2;
                for (sc) |c| c.dc_pred = 0;
                j.eobrun = 0;
                since_restart = 0;
            }
            if (ns == 1) {
                const c = sc[0];
                const bx = @rem(n, c.cw);
                const by = @divTrunc(n, c.cw);
                try j.decodeBlock(c, us((by * c.bw + bx) * 64), ss, se, ah, al);
            } else {
                const mx = @rem(n, j.mcus_x);
                const my = @divTrunc(n, j.mcus_x);
                for (sc) |c| {
                    var v: i32 = 0;
                    while (v < c.v) : (v += 1) {
                        var h: i32 = 0;
                        while (h < c.h) : (h += 1) {
                            const bx = mx * c.h + h;
                            const by = my * c.v + v;
                            try j.decodeBlock(c, us((by * c.bw + bx) * 64), ss, se, ah, al);
                        }
                    }
                }
            }
            since_restart += 1;
        }
        // skip to the next marker (past any padding)
        while (j.pos < d.len) {
            if (d[j.pos] == 0xFF and j.pos + 1 < d.len) {
                const nx = d[j.pos + 1];
                if (nx != 0 and !(nx >= 0xD0 and nx <= 0xD7)) break;
            }
            j.pos += 1;
        }
        return j.pos;
    }

    fn decodeBlock(j: *Jpeg, c: *Component, off: usize, ss: i32, se: i32, ah: i32, al: i32) Error!void {
        const z = c.coef;
        if (!j.progressive) {
            const t = try j.decodeHuff(c.dc);
            const diff = if (t == 0) 0 else extend(try j.receive(t), t);
            c.dc_pred +%= diff;
            z[off] = short(c.dc_pred);
            var k: i32 = 1;
            while (k < 64) {
                const rs = try j.decodeHuff(c.ac);
                const r = rs >> 4;
                const s = rs & 15;
                if (s == 0) {
                    if (r == 15) {
                        k += 16;
                        continue;
                    }
                    break;
                }
                k += r;
                if (k > 63) break;
                z[off + ZIGZAG[@intCast(k)]] = short(extend(try j.receive(s), s));
                k += 1;
            }
            return;
        }
        if (ss == 0) {
            // DC scans
            if (ah == 0) {
                const t = try j.decodeHuff(c.dc);
                const diff = if (t == 0) 0 else extend(try j.receive(t), t);
                c.dc_pred +%= diff;
                z[off] = short(shl(c.dc_pred, al));
            } else if (try j.readBit() != 0) {
                z[off] |= short(shl(1, al));
            }
            return;
        }
        if (ah == 0) {
            // AC first pass
            if (j.eobrun > 0) {
                j.eobrun -= 1;
                return;
            }
            var k = ss;
            while (k <= se) {
                const rs = try j.decodeHuff(c.ac);
                const r = rs >> 4;
                const s = rs & 15;
                if (s == 0) {
                    if (r < 15) {
                        j.eobrun = shl(1, r) - 1;
                        if (r > 0) j.eobrun +%= try j.receive(r);
                        break;
                    }
                    k += 16;
                    continue;
                }
                k += r;
                if (k > 63) break;
                z[off + ZIGZAG[@intCast(k)]] = short(extend(try j.receive(s), s) *% shl(1, al));
                k += 1;
            }
            return;
        }
        try j.refineAc(c, off, ss, se, al);
    }

    fn refineAc(j: *Jpeg, c: *Component, off: usize, ss: i32, se: i32, al: i32) Error!void {
        const z = c.coef;
        const p1 = shl(1, al);
        const m1 = shl(-1, al);
        var k = ss;
        if (j.eobrun <= 0) {
            while (k <= se) {
                const rs = try j.decodeHuff(c.ac);
                var r = rs >> 4;
                const s = rs & 15;
                var value: i32 = 0;
                if (s == 0) {
                    if (r < 15) {
                        j.eobrun = shl(1, r);
                        if (r > 0) j.eobrun +%= try j.receive(r);
                        break;
                    }
                } else {
                    value = if (try j.readBit() != 0) p1 else m1;
                }
                while (k <= se) {
                    const zk = off + try zz(k);
                    if (z[zk] != 0) {
                        if (try j.readBit() != 0 and (@as(i32, z[zk]) & p1) == 0)
                            z[zk] = short(@as(i32, z[zk]) + short(if (z[zk] >= 0) p1 else m1));
                    } else {
                        if (r == 0) {
                            if (value != 0) z[zk] = short(value);
                            k += 1;
                            break;
                        }
                        r -= 1;
                    }
                    k += 1;
                }
            }
        }
        if (j.eobrun > 0) {
            while (k <= se) : (k += 1) {
                const zk = off + try zz(k);
                if (z[zk] != 0 and try j.readBit() != 0 and (@as(i32, z[zk]) & p1) == 0)
                    z[zk] = short(@as(i32, z[zk]) + short(if (z[zk] >= 0) p1 else m1));
            }
            j.eobrun -= 1;
        }
    }

    // --- output ---

    fn idctPlanes(j: *Jpeg) Error!void {
        var tmp: [64]f32 = undefined;
        for (j.comps) |*c| {
            const tq: usize = @intCast(c.tq);
            if (!j.has_qt[tq]) return fail("JPEG: missing quantization table");
            const q = &j.qt[tq];
            const stride = us(c.bw) * 8;
            c.plane = try j.al.alloc(u8, stride * us(c.bh) * 8);
            const coef = c.coef;
            for (0..us(c.bh)) |by| {
                for (0..us(c.bw)) |bx| {
                    const off = (by * us(c.bw) + bx) * 64;
                    // rows: tmp[y][x] = sum_u coef[y][u] q IDCT[x][u]
                    for (0..8) |y| {
                        const r = off + y * 8;
                        var zero_ac = true;
                        for (1..8) |u| {
                            if (coef[r + u] != 0) {
                                zero_ac = false;
                                break;
                            }
                        }
                        if (zero_ac) {
                            const dc = f(@as(i32, coef[r]) *% q[y * 8]) * IDCT[0];
                            for (0..8) |x| tmp[y * 8 + x] = dc;
                            continue;
                        }
                        for (0..8) |x| {
                            var s: f32 = 0;
                            for (0..8) |u| s += f(@as(i32, coef[r + u]) *% q[y * 8 + u]) * IDCT[x * 8 + u];
                            tmp[y * 8 + x] = s;
                        }
                    }
                    // columns
                    const base = by * 8 * stride + bx * 8;
                    for (0..8) |x| {
                        for (0..8) |y| {
                            var s: f32 = 0;
                            for (0..8) |v| s += tmp[v * 8 + x] * IDCT[y * 8 + v];
                            const val = round(s + 128);
                            c.plane[base + y * stride + x] = @intCast(if (val < 0) 0 else (if (val > 255) 255 else val));
                        }
                    }
                }
            }
            c.coef = &.{};
        }
    }

    // For each of n output positions: the two component samples around
    // it and the weight of the second; f samples per fmax output pixels,
    // m samples in all.
    fn axis(n: usize, fs: i32, fmax: i32, m: i32, i_0: []usize, i_1: []usize, w: []f32) void {
        for (0..n) |x| {
            if (fs == fmax) {
                i_0[x] = x;
                i_1[x] = x;
                w[x] = 0;
                continue;
            }
            const c: f32 = (@as(f32, @floatFromInt(x)) + 0.5) * f(fs) / f(fmax) - 0.5;
            const lo = d2i(@floor(@as(f64, c)));
            const t = c - f(lo);
            const a = @max(0, @min(m - 1, lo));
            const b = @max(0, @min(m - 1, lo + 1));
            i_0[x] = @intCast(a);
            i_1[x] = @intCast(b);
            w[x] = t;
        }
    }

    fn output(j: *Jpeg) Error!Image {
        try j.idctPlanes();
        const width = us(j.width);
        const height = us(j.height);
        const out = try pa.alloc(u8, width * height * 4);
        const comps = j.comps;
        const n = comps.len;
        const rgb = n == 3 and (j.adobe == 0 or (!j.jfif and j.adobe < 0 and comps[0].id == 'R' and comps[1].id == 'G' and comps[2].id == 'B'));
        var sample: [4]i32 = .{ 0, 0, 0, 0 };
        // Subsampled components are interpolated linearly between sample
        // centres (for 2:1, libjpeg's "fancy" 3/4 + 1/4 weights).
        var x0: [4][]usize = undefined;
        var x1: [4][]usize = undefined;
        var y0: [4][]usize = undefined;
        var y1: [4][]usize = undefined;
        var fx: [4][]f32 = undefined;
        var fy: [4][]f32 = undefined;
        for (0..n) |i| {
            const c = &comps[i];
            const cw = @divTrunc(j.width * c.h + j.hmax - 1, j.hmax);
            const ch = @divTrunc(j.height * c.v + j.vmax - 1, j.vmax);
            x0[i] = try j.al.alloc(usize, width);
            x1[i] = try j.al.alloc(usize, width);
            fx[i] = try j.al.alloc(f32, width);
            y0[i] = try j.al.alloc(usize, height);
            y1[i] = try j.al.alloc(usize, height);
            fy[i] = try j.al.alloc(f32, height);
            axis(width, c.h, j.hmax, cw, x0[i], x1[i], fx[i]);
            axis(height, c.v, j.vmax, ch, y0[i], y1[i], fy[i]);
        }
        const adobe = j.adobe;
        for (0..height) |y| {
            for (0..width) |x| {
                for (0..n) |i| {
                    const c = &comps[i];
                    const stride = us(c.bw) * 8;
                    const pl = c.plane;
                    if (c.h == j.hmax and c.v == j.vmax) {
                        sample[i] = pl[y * stride + x];
                    } else {
                        const r0 = y0[i][y] * stride;
                        const r1 = y1[i][y] * stride;
                        const a = x0[i][x];
                        const b = x1[i][x];
                        const wx = fx[i][x];
                        const wy = fy[i][y];
                        const top = f(pl[r0 + a]) * (1 - wx) + f(pl[r0 + b]) * wx;
                        const bot = f(pl[r1 + a]) * (1 - wx) + f(pl[r1 + b]) * wx;
                        sample[i] = round(top * (1 - wy) + bot * wy);
                    }
                }
                const o = (y * width + x) * 4;
                var R: i32 = undefined;
                var G: i32 = undefined;
                var B: i32 = undefined;
                if (n == 1) {
                    R = sample[0];
                    G = R;
                    B = R;
                } else if (n == 3 and rgb) {
                    R = sample[0];
                    G = sample[1];
                    B = sample[2];
                } else {
                    if (n == 3 or adobe == 2) {
                        const Y = f(sample[0]);
                        const cb = f(sample[1] - 128);
                        const cr = f(sample[2] - 128);
                        R = clamp(round(Y + 1.402 * cr));
                        G = clamp(round(Y - 0.344136 * cb - 0.714136 * cr));
                        B = clamp(round(Y + 1.772 * cb));
                    } else {
                        R = sample[0];
                        G = sample[1];
                        B = sample[2];
                    }
                    if (n == 4) {
                        // Adobe stores CMYK inverted: the samples are 255 - C, ...
                        const k = sample[3];
                        if (adobe >= 0) {
                            R = @divTrunc(R * k, 255);
                            G = @divTrunc(G * k, 255);
                            B = @divTrunc(B * k, 255);
                        } else {
                            R = @divTrunc((255 - R) * (255 - k), 255);
                            G = @divTrunc((255 - G) * (255 - k), 255);
                            B = @divTrunc((255 - B) * (255 - k), 255);
                        }
                    }
                }
                out[o] = @truncate(@as(u32, @bitCast(R)));
                out[o + 1] = @truncate(@as(u32, @bitCast(G)));
                out[o + 2] = @truncate(@as(u32, @bitCast(B)));
                out[o + 3] = 255;
            }
        }
        return .{ .width = j.width, .height = j.height, .rgba = out };
    }
};

fn clamp(v: i32) i32 {
    return if (v < 0) 0 else (if (v > 255) 255 else v);
}

// --- resizing ----------------------------------------------------------------------------

/// Resizes straight RGBA pixels to nw x nh. method 0: box (the area each
/// target pixel covers, averaged), 1: bilinear (a triangle filter, widened
/// when shrinking so that every source pixel counts). Colours are averaged
/// premultiplied by alpha, so transparent pixels don't bleed.
pub fn resize(src: []const u8, w: i32, h: i32, nw: i32, nh: i32, method: i32) Error![]u8 {
    if (w <= 0 or h <= 0 or nw <= 0 or nh <= 0 or @as(i64, @intCast(src.len)) < @as(i64, w) * h * 4)
        return fail("bad image size");
    var arena = std.heap.ArenaAllocator.init(pa);
    defer arena.deinit();
    const al = arena.allocator();
    const W = us(w);
    const H = us(h);
    const NW = us(nw);
    const NH = us(nh);
    // horizontal: w x h -> nw x h, premultiplied
    const wx = try weights(al, w, nw, method);
    const mid = try al.alloc(f32, NW * H * 4);
    for (0..H) |y| {
        for (0..NW) |x| {
            var r: f32 = 0;
            var g: f32 = 0;
            var b: f32 = 0;
            var a: f32 = 0;
            const first = wx.first[x];
            for (0..wx.w[x].len) |k| {
                const s = (y * W + first + k) * 4;
                const alpha: f32 = @floatFromInt(src[s + 3]);
                const fk = wx.w[x][k];
                const fa = fk * alpha / 255.0;
                r += @as(f32, @floatFromInt(src[s])) * fa;
                g += @as(f32, @floatFromInt(src[s + 1])) * fa;
                b += @as(f32, @floatFromInt(src[s + 2])) * fa;
                a += alpha * fk;
            }
            const o = (y * NW + x) * 4;
            mid[o] = r;
            mid[o + 1] = g;
            mid[o + 2] = b;
            mid[o + 3] = a;
        }
    }
    // vertical: nw x h -> nw x nh
    const wy = try weights(al, h, nh, method);
    const out = try pa.alloc(u8, NW * NH * 4);
    for (0..NH) |y| {
        for (0..NW) |x| {
            var r: f32 = 0;
            var g: f32 = 0;
            var b: f32 = 0;
            var a: f32 = 0;
            const first = wy.first[y];
            for (0..wy.w[y].len) |k| {
                const fk = wy.w[y][k];
                const s = ((first + k) * NW + x) * 4;
                r += mid[s] * fk;
                g += mid[s + 1] * fk;
                b += mid[s + 2] * fk;
                a += mid[s + 3] * fk;
            }
            const o = (y * NW + x) * 4;
            var A = round(a);
            A = if (A < 0) 0 else (if (A > 255) 255 else A);
            if (A == 0) {
                @memset(out[o .. o + 4], 0);
            } else {
                const inv = 1.0 / (a / 255.0);
                out[o] = @intCast(clamp(round(r * inv)));
                out[o + 1] = @intCast(clamp(round(g * inv)));
                out[o + 2] = @intCast(clamp(round(b * inv)));
                out[o + 3] = @intCast(A);
            }
        }
    }
    return out;
}

const Weights = struct {
    first: []usize,
    w: [][]f32,
};

fn weights(al: std.mem.Allocator, n: i32, nn: i32, method: i32) Error!Weights {
    const ws = Weights{ .first = try al.alloc(usize, us(nn)), .w = try al.alloc([]f32, us(nn)) };
    const nf: f64 = @floatFromInt(n);
    const scale: f64 = nf / @as(f64, @floatFromInt(nn)); // source pixels per target pixel
    var tmp = try al.alloc(f64, 16);
    for (0..us(nn)) |i| {
        const fi: f64 = @floatFromInt(i);
        const center = (fi + 0.5) * scale; // in source coordinates
        var lo: i32 = undefined;
        var hi: i32 = undefined;
        if (method == 0) {
            // box: overlap of [i*scale, (i+1)*scale) with each source pixel [j, j+1)
            var a = fi * scale;
            var b = (fi + 1) * scale;
            if (scale < 1) { // enlarging: nearest pixel's area
                a = center - 0.5;
                b = center + 0.5;
            }
            lo = d2i(@floor(a));
            hi = d2i(@ceil(b)) -% 1;
            lo = @max(lo, 0);
            hi = @min(hi, n - 1);
            if (hi < lo) hi = lo;
            if (tmp.len < us(hi - lo + 1)) tmp = try al.alloc(f64, us(hi - lo + 1));
            var jj = lo;
            while (jj <= hi) : (jj += 1) {
                const fj: f64 = @floatFromInt(jj);
                tmp[us(jj - lo)] = jmax(0, @min(b, fj + 1) - @max(a, fj));
            }
        } else {
            const support = @max(1.0, scale);
            lo = d2i(@floor(center - support));
            hi = d2i(@ceil(center + support));
            lo = @max(lo, 0);
            hi = @min(hi, n - 1);
            if (hi < lo) return error.Malformed;
            if (tmp.len < us(hi - lo + 1)) tmp = try al.alloc(f64, us(hi - lo + 1));
            var jj = lo;
            while (jj <= hi) : (jj += 1) {
                const t = @abs((@as(f64, @floatFromInt(jj)) + 0.5 - center) / support);
                tmp[us(jj - lo)] = if (t < 1) 1 - t else 0;
            }
        }
        var cnt = us(hi - lo + 1);
        var sum: f64 = 0;
        for (tmp[0..cnt]) |t| sum += t;
        if (sum <= 0) { // degenerate: take the nearest pixel
            lo = @min(n - 1, @max(0, d2i(center)));
            tmp[0] = 1;
            cnt = 1;
            sum = 1;
        }
        ws.first[i] = us(lo);
        const wi = try al.alloc(f32, cnt);
        for (0..cnt) |k| wi[k] = @floatCast(tmp[k] / sum);
        ws.w[i] = wi;
    }
    return ws;
}

/// Math.max(0, x) on doubles (+0.0 for -0.0)
fn jmax(a: f64, b: f64) f64 {
    if (b > a) return b;
    if (b == a) return if (std.math.signbit(a)) b else a;
    return a;
}

// --- orientation -------------------------------------------------------------------------

/// Applies EXIF orientation o (1-8) to w x h RGBA pixels: the result is how
/// the image is meant to be shown; for 5-8 it is h x w. The result has the
/// length of src.
pub fn orient(src: []const u8, w: i32, h: i32, o: i32) Error![]u8 {
    if (o < 1 or o > 8) return fail("bad orientation (1 to 8)");
    const swap = o >= 5;
    const ow: i64 = if (swap) h else w;
    const oh: i64 = if (swap) w else h;
    const W: i64 = w;
    const H: i64 = h;
    const out = try pa.alloc(u8, src.len);
    @memset(out, 0);
    var y: i64 = 0;
    while (y < oh) : (y += 1) {
        var x: i64 = 0;
        while (x < ow) : (x += 1) {
            var sx: i64 = undefined;
            var sy: i64 = undefined;
            switch (o) {
                2 => {
                    sx = W - 1 - x;
                    sy = y;
                },
                3 => {
                    sx = W - 1 - x;
                    sy = H - 1 - y;
                },
                4 => {
                    sx = x;
                    sy = H - 1 - y;
                },
                5 => {
                    sx = y;
                    sy = x;
                },
                6 => {
                    sx = y;
                    sy = H - 1 - x;
                },
                7 => {
                    sx = W - 1 - y;
                    sy = H - 1 - x;
                },
                8 => {
                    sx = W - 1 - y;
                    sy = x;
                },
                else => {
                    sx = x;
                    sy = y;
                },
            }
            const s = us((sy * W + sx) * 4);
            const d = us((y * ow + x) * 4);
            @memcpy(out[d .. d + 4], src[s .. s + 4]);
        }
    }
    return out;
}

// --- JPEG encoding -----------------------------------------------------------------------

const STD_LUMA_Q = [64]i32{
    16, 11, 10, 16, 24,  40,  51,  61,  12, 12, 14, 19, 26,  58,  60,  55,
    14, 13, 16, 24, 40,  57,  69,  56,  14, 17, 22, 29, 51,  87,  80,  62,
    18, 22, 37, 56, 68,  109, 103, 77,  24, 35, 55, 64, 81,  104, 113, 92,
    49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99,
};
const STD_CHROMA_Q = [64]i32{
    17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99,
    24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
};
// Annex K Huffman tables: counts per length 1..16, then values
const DC_LUMA_COUNTS = [16]u8{ 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 };
const DC_LUMA_VALS = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };
const DC_CHROMA_COUNTS = [16]u8{ 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 };
const DC_CHROMA_VALS = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };
const AC_LUMA_COUNTS = [16]u8{ 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d };
const AC_LUMA_VALS = [_]u8{
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
    0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
    0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
    0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
    0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
    0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
    0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
    0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa,
};
const AC_CHROMA_COUNTS = [16]u8{ 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 };
const AC_CHROMA_VALS = [_]u8{
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
    0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
    0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
    0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
    0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
    0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
    0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
    0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa,
};

const BitWriter = struct {
    out: *std.ArrayList(u8),
    buf: u32 = 0,
    cnt: u32 = 0,

    fn write(bw: *BitWriter, code: i32, len: i32) Error!void {
        const c: u32 = @bitCast(code);
        var i = len - 1;
        while (i >= 0) : (i -= 1) {
            bw.buf = (bw.buf << 1) | ((c >> @intCast(i & 31)) & 1);
            bw.cnt += 1;
            if (bw.cnt == 8) {
                const b: u8 = @truncate(bw.buf);
                try bw.out.append(pa, b);
                if (b == 0xFF) try bw.out.append(pa, 0);
                bw.buf = 0;
                bw.cnt = 0;
            }
        }
    }

    fn flush(bw: *BitWriter) Error!void {
        while (bw.cnt != 0) try bw.write(1, 1); // pad with ones
    }
};

const HuffCodes = struct { code: [256]i32, size: [256]i32 };

// code/length per symbol from counts and values
fn huffCodes(counts: []const u8, vals: []const u8) HuffCodes {
    var hc = HuffCodes{ .code = @splat(0), .size = @splat(0) };
    var c: i32 = 0;
    var k: usize = 0;
    for (1..17) |len| {
        for (0..counts[len - 1]) |_| {
            hc.code[vals[k]] = c;
            c += 1;
            hc.size[vals[k]] = @intCast(len);
            k += 1;
        }
        c <<= 1;
    }
    return hc;
}

fn scaledQuant(std_: *const [64]i32, quality: i32) [64]i32 {
    const q = @max(1, @min(100, quality));
    const scale = if (q < 50) @divTrunc(5000, q) else 200 - 2 * q;
    var t: [64]i32 = undefined;
    for (0..64) |i| t[i] = @max(1, @min(255, @divTrunc(std_[i] * scale + 50, 100)));
    return t;
}

fn writeDht(out: *std.ArrayList(u8), tcth: u8, counts: []const u8, vals: []const u8) Error!void {
    const len = 2 + 1 + 16 + vals.len;
    try out.appendSlice(pa, &.{ 0xFF, 0xC4, @intCast(len >> 8), @intCast(len & 0xFF), tcth });
    try out.appendSlice(pa, counts);
    try out.appendSlice(pa, vals);
}

/// Baseline JPEG (YCbCr 4:2:0, quality 1-100, standard tables) of w x h
/// RGBA pixels, alpha composited over white.
pub fn encodeJpeg(rgba: []const u8, w: i32, h: i32, quality: i32) Error![]u8 {
    if (w <= 0 or h <= 0 or w > 65535 or h > 65535) return fail("JPEG: bad image size");
    const ql = scaledQuant(&STD_LUMA_Q, quality);
    const qc = scaledQuant(&STD_CHROMA_Q, quality);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(pa);
    try out.ensureTotalCapacity(pa, us(@divTrunc(@as(i64, w) * h, 4) + 1024));
    try out.appendSlice(pa, &.{ 0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 'J', 'F', 'I', 'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0 });
    for (0..2) |t| {
        const q = if (t == 0) &ql else &qc;
        try out.appendSlice(pa, &.{ 0xFF, 0xDB, 0, 67, @intCast(t) });
        for (0..64) |i| try out.append(pa, @intCast(q[ZIGZAG[i]]));
    }
    const hu: u32 = @intCast(h);
    const wu: u32 = @intCast(w);
    try out.appendSlice(pa, &.{ 0xFF, 0xC0, 0, 17, 8, @intCast(hu >> 8), @intCast(hu & 0xFF), @intCast(wu >> 8), @intCast(wu & 0xFF), 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1 });
    try writeDht(&out, 0x00, &DC_LUMA_COUNTS, &DC_LUMA_VALS);
    try writeDht(&out, 0x10, &AC_LUMA_COUNTS, &AC_LUMA_VALS);
    try writeDht(&out, 0x01, &DC_CHROMA_COUNTS, &DC_CHROMA_VALS);
    try writeDht(&out, 0x11, &AC_CHROMA_COUNTS, &AC_CHROMA_VALS);
    try out.appendSlice(pa, &.{ 0xFF, 0xDA, 0, 12, 3, 1, 0x00, 2, 0x11, 3, 0x11, 0, 63, 0 });

    // planes: Y full size, Cb/Cr averaged over 2 x 2, all padded to 16
    const W = us(w);
    const H = us(h);
    const pw = (W + 15) / 16 * 16;
    const ph = (H + 15) / 16 * 16;
    const Y = try pa.alloc(f32, pw * ph);
    defer pa.free(Y);
    const Cb = try pa.alloc(f32, pw * ph / 4);
    defer pa.free(Cb);
    const Cr = try pa.alloc(f32, pw * ph / 4);
    defer pa.free(Cr);
    const cb_full = try pa.alloc(f32, pw * ph);
    defer pa.free(cb_full);
    const cr_full = try pa.alloc(f32, pw * ph);
    defer pa.free(cr_full);
    for (0..ph) |y| {
        for (0..pw) |x| {
            const s = (@min(y, H - 1) * W + @min(x, W - 1)) * 4;
            const a: f32 = @as(f32, @floatFromInt(rgba[s + 3])) / 255.0;
            const r = @as(f32, @floatFromInt(rgba[s])) * a + 255 * (1 - a);
            const g = @as(f32, @floatFromInt(rgba[s + 1])) * a + 255 * (1 - a);
            const b = @as(f32, @floatFromInt(rgba[s + 2])) * a + 255 * (1 - a);
            const i = y * pw + x;
            Y[i] = @as(f32, 0.299) * r + @as(f32, 0.587) * g + @as(f32, 0.114) * b - 128;
            cb_full[i] = @as(f32, -0.168736) * r - @as(f32, 0.331264) * g + @as(f32, 0.5) * b;
            cr_full[i] = @as(f32, 0.5) * r - @as(f32, 0.418688) * g - @as(f32, 0.081312) * b;
        }
    }
    const cw = pw / 2;
    for (0..ph / 2) |y| {
        for (0..cw) |x| {
            const i = 2 * y * pw + 2 * x;
            Cb[y * cw + x] = (cb_full[i] + cb_full[i + 1] + cb_full[i + pw] + cb_full[i + pw + 1]) / 4;
            Cr[y * cw + x] = (cr_full[i] + cr_full[i + 1] + cr_full[i + pw] + cr_full[i + pw + 1]) / 4;
        }
    }
    const dcl = huffCodes(&DC_LUMA_COUNTS, &DC_LUMA_VALS);
    const acl = huffCodes(&AC_LUMA_COUNTS, &AC_LUMA_VALS);
    const dcc = huffCodes(&DC_CHROMA_COUNTS, &DC_CHROMA_VALS);
    const acc = huffCodes(&AC_CHROMA_COUNTS, &AC_CHROMA_VALS);
    var bw = BitWriter{ .out = &out };
    var pred = [3]i32{ 0, 0, 0 };
    var block: [64]f32 = undefined;
    for (0..ph / 16) |my| {
        for (0..pw / 16) |mx| {
            for (0..4) |k| {
                const bx = mx * 16 + (k & 1) * 8;
                const by = my * 16 + (k >> 1) * 8;
                for (0..8) |y| {
                    for (0..8) |x| block[y * 8 + x] = Y[(by + y) * pw + bx + x];
                }
                pred[0] = try encodeBlock(&bw, &block, &ql, pred[0], &dcl, &acl);
            }
            for (0..2) |c| {
                const plane = if (c == 0) Cb else Cr;
                for (0..8) |y| {
                    for (0..8) |x| block[y * 8 + x] = plane[(my * 8 + y) * cw + mx * 8 + x];
                }
                pred[c + 1] = try encodeBlock(&bw, &block, &qc, pred[c + 1], &dcc, &acc);
            }
        }
    }
    try bw.flush();
    try out.appendSlice(pa, &.{ 0xFF, 0xD9 });
    return out.toOwnedSlice(pa);
}

fn bitLength(v0: i32) i32 {
    var v: u32 = @abs(v0);
    var n: i32 = 0;
    while (v != 0) {
        n += 1;
        v >>= 1;
    }
    return n;
}

fn encodeBlock(bw: *BitWriter, block: *const [64]f32, q: *const [64]i32, pred: i32, dc: *const HuffCodes, ac: *const HuffCodes) Error!i32 {
    var tmp: [64]f32 = undefined;
    var coef: [64]i32 = undefined;
    // forward DCT: F(u,v) = sum_x sum_y f(x,y) basis(x,u) basis(y,v)
    for (0..8) |y| {
        for (0..8) |u| {
            var s: f32 = 0;
            for (0..8) |x| s += block[y * 8 + x] * IDCT[x * 8 + u];
            tmp[y * 8 + u] = s;
        }
    }
    for (0..8) |u| {
        for (0..8) |v| {
            var s: f32 = 0;
            for (0..8) |y| s += tmp[y * 8 + u] * IDCT[y * 8 + v];
            coef[v * 8 + u] = round(s / f(q[v * 8 + u]));
        }
    }
    const diff = coef[0] -% pred;
    const n = bitLength(diff);
    try bw.write(dc.code[us(n & 255)], dc.size[us(n & 255)]);
    if (n > 0) try bw.write(if (diff < 0) diff -% 1 else diff, n);
    var run: i32 = 0;
    for (1..64) |k| {
        const v = coef[ZIGZAG[k]];
        if (v == 0) {
            run += 1;
            continue;
        }
        while (run > 15) {
            try bw.write(ac.code[0xF0], ac.size[0xF0]);
            run -= 16;
        }
        const s = bitLength(v);
        const sym = (run << 4) | s;
        try bw.write(ac.code[us(sym & 255)], ac.size[us(sym & 255)]);
        try bw.write(if (v < 0) v -% 1 else v, s);
        run = 0;
    }
    if (run > 0) try bw.write(ac.code[0], ac.size[0]);
    return coef[0];
}
