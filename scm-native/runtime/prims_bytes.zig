//! Primitives: numeric bytevector accessors (R6RS style, as the JVM
//! implementation's BytevectorNumbers), Latin-1 and UTF-8 helpers,
//! get-bytes, display widths, base64.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const chars = @import("chars.zig");
const tower = @import("tower.zig");
const P = @import("prims.zig");
const T = @import("prims_text.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;
const unfix = rt.unfix;

const pa = std.heap.c_allocator;

fn msg(comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(pa, fmt, args) catch rt.oom();
}

// --- numeric accessors ------------------------------------------------------------------

fn index(t: *Thread, who: []const u8, bv: Word, size: usize) Err!usize {
    const k = arg(t, 1);
    if (!rt.isFix(k) or unfix(k) < 0 or @as(usize, @intCast(unfix(k))) + size > data.bvLen(bv))
        return raise(t, msg("{s}: index out of range: ~s", .{who}), &.{k});
    return @intCast(unfix(k));
}

fn little(t: *Thread, who: []const u8, i: usize) Err!bool {
    const e = arg(t, i);
    if (data.isSymbol(e)) {
        const n = data.symbolName(e);
        if (std.mem.eql(u8, n, "little")) return true;
        if (std.mem.eql(u8, n, "big")) return false;
    }
    return raise(t, msg("{s}: endianness must be big or little: ~s", .{who}), &.{e});
}

fn readRaw(b: []const u8, comptime size: usize, lit: bool) u64 {
    var v: u64 = 0;
    for (0..size) |i| {
        const byte = b[if (lit) size - 1 - i else i];
        v = (v << 8) | byte;
    }
    return v;
}

fn writeRaw(b: []u8, comptime size: usize, v: u64, lit: bool) void {
    for (0..size) |i| b[if (lit) i else size - 1 - i] = @truncate(v >> @intCast(8 * i));
}

fn intRef(comptime who: []const u8, comptime size: usize, comptime signed: bool) type {
    return struct {
        fn f(t: *Thread) Err!Word {
            const bv = try T.bvArg(t, 0);
            const k = try index(t, who, bv, size);
            const lit = try little(t, who, 2);
            const raw = readRaw(data.bvBytes(bv)[k..], size, lit);
            if (signed) {
                const I = if (size == 2) i16 else i32;
                const U = if (size == 2) u16 else u32;
                const v: I = @bitCast(@as(U, @truncate(raw)));
                return fix(v);
            }
            return fix(@intCast(raw));
        }
    };
}

fn intSet(comptime who: []const u8, comptime size: usize, comptime signed: bool) type {
    return struct {
        fn f(t: *Thread) Err!Word {
            const bv = try T.bvArg(t, 0);
            const k = try index(t, who, bv, size);
            const lit = try little(t, who, 3);
            const n = arg(t, 2);
            const bits = 8 * size;
            const min: i64 = if (signed) -(@as(i64, 1) << (bits - 1)) else 0;
            const max: i64 = if (signed) (@as(i64, 1) << (bits - 1)) - 1 else (@as(i64, 1) << bits) - 1;
            if (!rt.isFix(n) or unfix(n) < min or unfix(n) > max) {
                if (tower.isExactInteger(n)) return raise(t, who ++ ": value out of range: ~s", &.{n});
                return raise(t, who ++ ": not an exact integer: ~s", &.{n});
            }
            writeRaw(data.bvBytes(bv)[k..], size, @bitCast(unfix(n)), lit);
            return rt.UNSPEC;
        }
    };
}

pub const @"%bytevector-u16-ref" = WD("bytevector-u16-ref", intRef("bytevector-u16-ref", 2, false).f, 3, 3);
pub const @"%bytevector-s16-ref" = WD("bytevector-s16-ref", intRef("bytevector-s16-ref", 2, true).f, 3, 3);
pub const @"%bytevector-u32-ref" = WD("bytevector-u32-ref", intRef("bytevector-u32-ref", 4, false).f, 3, 3);
pub const @"%bytevector-s32-ref" = WD("bytevector-s32-ref", intRef("bytevector-s32-ref", 4, true).f, 3, 3);
pub const @"%bytevector-u16-set!" = WD("bytevector-u16-set!", intSet("bytevector-u16-set!", 2, false).f, 4, 4);
pub const @"%bytevector-s16-set!" = WD("bytevector-s16-set!", intSet("bytevector-s16-set!", 2, true).f, 4, 4);
pub const @"%bytevector-u32-set!" = WD("bytevector-u32-set!", intSet("bytevector-u32-set!", 4, false).f, 4, 4);
pub const @"%bytevector-s32-set!" = WD("bytevector-s32-set!", intSet("bytevector-s32-set!", 4, true).f, 4, 4);

fn floatRef(comptime who: []const u8, comptime size: usize) type {
    return struct {
        fn f(t: *Thread) Err!Word {
            const bv = try T.bvArg(t, 0);
            const k = try index(t, who, bv, size);
            const lit = try little(t, who, 2);
            const raw = readRaw(data.bvBytes(bv)[k..], size, lit);
            const x: f64 = if (size == 8) @bitCast(raw) else @floatCast(@as(f32, @bitCast(@as(u32, @truncate(raw)))));
            return rt.safeFlo(t, x);
        }
    };
}

fn floatSet(comptime who: []const u8, comptime size: usize) type {
    return struct {
        fn f(t: *Thread) Err!Word {
            const bv = try T.bvArg(t, 0);
            const k = try index(t, who, bv, size);
            const lit = try little(t, who, 3);
            const n = arg(t, 2);
            if (!tower.isReal(n)) return raise(t, who ++ ": not a real number: ~s", &.{n});
            const x = tower.toFloat(n);
            const raw: u64 = if (size == 8) @bitCast(x) else @as(u32, @bitCast(@as(f32, @floatCast(x))));
            writeRaw(data.bvBytes(bv)[k..], size, raw, lit);
            return rt.UNSPEC;
        }
    };
}

pub const @"%bytevector-ieee-double-ref" = WD("bytevector-ieee-double-ref", floatRef("bytevector-ieee-double-ref", 8).f, 3, 3);
pub const @"%bytevector-ieee-single-ref" = WD("bytevector-ieee-single-ref", floatRef("bytevector-ieee-single-ref", 4).f, 3, 3);
pub const @"%bytevector-ieee-double-set!" = WD("bytevector-ieee-double-set!", floatSet("bytevector-ieee-double-set!", 8).f, 4, 4);
pub const @"%bytevector-ieee-single-set!" = WD("bytevector-ieee-single-set!", floatSet("bytevector-ieee-single-set!", 4).f, 4, 4);

// --- Latin-1 and UTF-8 ------------------------------------------------------------------

fn latin1ToString(t: *Thread) Err!Word {
    const bv0 = try T.bvArg(t, 0);
    const r = try T.range(t, 1, data.bvLen(bv0));
    const n = r[1] - r[0];
    t.reserve(data.stringWords(n, false));
    const s = data.makeString(t, n, false);
    const bytes = data.bvBytes(arg(t, 0));
    for (0..n) |i| data.stringSetFits(s, i, bytes[r[0] + i]);
    return s;
}
pub const @"%latin1->string" = WN("latin1->string", latin1ToString, 1, 3);

fn stringToLatin1(t: *Thread) Err!Word {
    const s0 = try P.stringArg(t, 0);
    var replacement: ?u8 = null;
    if (t.argc > 1 and arg(t, 1) != rt.FALSE) {
        const r = arg(t, 1);
        if (!rt.isFix(r) or unfix(r) < 0 or unfix(r) > 255)
            return raise(t, "string->latin1: replacement ~a is not a byte", &.{r});
        replacement = @intCast(unfix(r));
    }
    const r = try T.range(t, 2, data.stringLen(s0));
    for (r[0]..r[1]) |i| {
        const c = data.stringRef(s0, i);
        if (c > 255 and replacement == null)
            return raise(t, msg("string->latin1: character #x{X} at index {d} has no Latin-1 encoding", .{ c, i }), &.{});
    }
    const n = r[1] - r[0];
    t.reserve(data.bvWords(n));
    const bv = data.makeBytevector(t, n);
    const s = arg(t, 0);
    const out = data.bvBytes(bv);
    for (0..n) |i| {
        const c = data.stringRef(s, r[0] + i);
        out[i] = if (c > 255) replacement.? else @intCast(c);
    }
    return bv;
}
pub const @"%string->latin1" = WN("string->latin1", stringToLatin1, 1, 4);

fn utf8Valid(t: *Thread) Err!Word {
    const bv = try T.bvArg(t, 0);
    const r = try T.range(t, 1, data.bvLen(bv));
    return rt.boolean(std.unicode.utf8ValidateSlice(data.bvBytes(bv)[r[0]..r[1]]));
}
pub const @"%utf8-valid?" = WD("utf8-valid?", utf8Valid, 1, 3);

/// (get-bytes x [encoding]): the bytes of a string, symbol or bytevector
fn getBytes(t: *Thread) Err!Word {
    const x = arg(t, 0);
    if (data.isBytevector(x)) return x;
    var enc: []const u8 = "utf-8";
    if (t.argc > 1) {
        const e = arg(t, 1);
        enc = if (data.isSymbol(e)) data.symbolName(e) else data.toUtf8(try P.stringArg(t, 1));
    }
    // the JVM implementation's Encoding.getEncoding: unknown names are UTF-8
    const Enc = enum { utf8, latin1, utf16, utf16be, utf16le };
    var lower_buf: [32]u8 = undefined;
    const lower = std.ascii.lowerString(lower_buf[0..@min(enc.len, 32)], enc[0..@min(enc.len, 32)]);
    const e: Enc = blk: {
        const names = .{
            .{ "latin-1", Enc.latin1 },   .{ "iso-8859-1", Enc.latin1 }, .{ "iso88591", Enc.latin1 },
            .{ "utf-16", Enc.utf16 },     .{ "utf16", Enc.utf16 },       .{ "utf-16-be", Enc.utf16be },
            .{ "utf-16be", Enc.utf16be }, .{ "utf16-be", Enc.utf16be },  .{ "utf16be", Enc.utf16be },
            .{ "utf-16-le", Enc.utf16le }, .{ "utf-16le", Enc.utf16le }, .{ "utf16-le", Enc.utf16le },
            .{ "utf16le", Enc.utf16le },
        };
        inline for (names) |nm| if (std.mem.eql(u8, lower, nm[0])) break :blk nm[1];
        break :blk .utf8;
    };
    // the code points of x
    var cps: std.ArrayList(u21) = .empty;
    defer cps.deinit(pa);
    if (data.isString(x)) {
        for (0..data.stringLen(x)) |i| cps.append(pa, data.stringRef(x, i)) catch rt.oom();
    } else {
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(pa);
        if (data.isSymbol(x)) text.appendSlice(pa, data.symbolName(x)) catch rt.oom() else @import("printer.zig").print(&text, x, false);
        var it = std.unicode.Utf8View.initUnchecked(text.items).iterator();
        while (it.nextCodepoint()) |c| cps.append(pa, c) catch rt.oom();
    }
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    if (e == .utf16) buf.appendSlice(pa, &.{ 0xFE, 0xFF }) catch rt.oom(); // Java writes a BOM, big-endian
    for (cps.items) |c| switch (e) {
        .utf8 => data.appendCp(&buf, c),
        // Java replaces unmappable characters by ?
        .latin1 => buf.append(pa, if (c > 255) '?' else @intCast(c)) catch rt.oom(),
        .utf16, .utf16be, .utf16le => {
            var units: [2]u16 = undefined;
            var nu: usize = 1;
            if (c >= 0x10000) {
                const v = c - 0x10000;
                units = .{ @intCast(0xD800 + (v >> 10)), @intCast(0xDC00 + (v & 0x3FF)) };
                nu = 2;
            } else units[0] = @intCast(c);
            for (units[0..nu]) |w| {
                const hi: u8 = @intCast(w >> 8);
                const lo: u8 = @truncate(w);
                buf.appendSlice(pa, if (e == .utf16le) &.{ lo, hi } else &.{ hi, lo }) catch rt.oom();
            }
        },
    };
    t.reserve(data.bvWords(buf.items.len));
    const bv = data.makeBytevector(t, buf.items.len);
    @memcpy(data.bvBytes(bv), buf.items);
    return bv;
}
pub const @"%get-bytes" = WN("get-bytes", getBytes, 1, 2);

// --- display width ---------------------------------------------------------------------

fn stringWidth(t: *Thread) Err!Word {
    const s = try P.stringArg(t, 0);
    const r = try T.range(t, 1, data.stringLen(s));
    var total: i64 = 0;
    for (r[0]..r[1]) |i| {
        const w = chars.width(data.stringRef(s, i));
        if (w > 0) total += w;
    }
    return fix(total);
}
pub const @"%string-width" = WD("string-width", stringWidth, 1, 3);

fn charWidth(t: *Thread) Err!Word {
    const a = arg(t, 0);
    const cp: i64 = if (rt.isChar(a)) rt.charCode(a) else if (rt.isFix(a)) unfix(a) else return P.argTypeError(t);
    if (cp < 0 or cp > 0x10FFFF) return raise(t, msg("char-width: {d} is not a code point", .{cp}), &.{});
    return fix(chars.width(@intCast(cp)));
}
pub const @"%char-width" = WD("char-width", charWidth, 1, 1);

// --- base64 --------------------------------------------------------------------------------

fn base64Encode(t: *Thread) Err!Word {
    const bv = try T.bvArg(t, 0);
    const enc = std.base64.standard.Encoder;
    const n = enc.calcSize(data.bvLen(bv));
    const tmp = pa.alloc(u8, n) catch rt.oom();
    defer pa.free(tmp);
    _ = enc.encode(tmp, data.bvBytes(bv));
    t.reserve(data.stringWords(n, false));
    const s = data.makeString(t, n, false);
    for (tmp, 0..) |c, i| data.stringSetFits(s, i, c);
    return s;
}
pub const @"%base64-encode" = WN("base64-encode", base64Encode, 1, 1);

fn base64Decode(t: *Thread) Err!Word {
    const text = data.toUtf8(try P.stringArg(t, 0));
    defer pa.free(text);
    const dec = std.base64.standard.Decoder;
    const n = dec.calcSizeForSlice(text) catch return raise(t, "base64-decode: Illegal base64 character", &.{});
    const tmp = pa.alloc(u8, n) catch rt.oom();
    defer pa.free(tmp);
    dec.decode(tmp, text) catch return raise(t, "base64-decode: Illegal base64 character", &.{});
    t.reserve(data.bvWords(n));
    const bv = data.makeBytevector(t, n);
    @memcpy(data.bvBytes(bv), tmp);
    return bv;
}
pub const @"%base64-decode" = WN("base64-decode", base64Decode, 1, 1);

// --- compression -------------------------------------------------------------------------

const compress = @import("compress.zig");

fn bytesResult(t: *Thread, bytes: []const u8) Word {
    t.reserve(data.bvWords(bytes.len));
    const bv = data.makeBytevector(t, bytes.len);
    @memcpy(data.bvBytes(bv), bytes);
    return bv;
}

fn compressPrim(comptime who: []const u8, comptime container: compress.Container) type {
    return struct {
        fn f(t: *Thread) Err!Word {
            const bv = try T.bvArg(t, 0);
            var level: i64 = -1;
            if (t.argc > 1) {
                const l = arg(t, 1);
                if (!rt.isFix(l) or unfix(l) < -1 or unfix(l) > 9) return raise(t, who ++ ": invalid compression level ~s", &.{l});
                level = unfix(l);
            }
            const out = compress.compress(data.bvBytes(bv), container, level) catch rt.oom();
            defer pa.free(out);
            return bytesResult(t, out);
        }
    };
}

fn decompressPrim(comptime who: []const u8, comptime container: compress.Container) type {
    return struct {
        fn f(t: *Thread) Err!Word {
            const bv = try T.bvArg(t, 0);
            const out = compress.decompress(data.bvBytes(bv), container) catch |e| switch (e) {
                error.OutOfMemory => rt.oom(),
                error.BadData => return raise(t, msg("{s}: {s}", .{ who, compress.last_error }), &.{}),
            };
            defer pa.free(out);
            return bytesResult(t, out);
        }
    };
}

pub const @"%deflate-compress" = WN("deflate-compress", compressPrim("deflate-compress", .raw).f, 1, 2);
pub const @"%zlib-compress" = WN("zlib-compress", compressPrim("zlib-compress", .zlib).f, 1, 2);
pub const @"%gzip-compress" = WN("gzip-compress", compressPrim("gzip-compress", .gzip).f, 1, 2);
pub const @"%deflate-decompress" = WN("deflate-decompress", decompressPrim("deflate-decompress", .raw).f, 1, 1);
pub const @"%zlib-decompress" = WN("zlib-decompress", decompressPrim("zlib-decompress", .zlib).f, 1, 1);
pub const @"%gzip-decompress" = WN("gzip-decompress", decompressPrim("gzip-decompress", .gzip).f, 1, 1);

fn crc32(t: *Thread) Err!Word {
    const bv = try T.bvArg(t, 0);
    const r = try T.range(t, 1, data.bvLen(bv));
    return fix(compress.crc32(data.bvBytes(bv)[r[0]..r[1]]));
}
pub const @"%crc32" = WD("crc32", crc32, 1, 3);
