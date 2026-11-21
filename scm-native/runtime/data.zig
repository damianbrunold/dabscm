//! Strings, symbols, vectors, equality, and the builders for static constants.
const std = @import("std");
const rt = @import("rt.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const hdr = rt.hdr;
const ptr = rt.ptr;
const tagPtr = rt.tagPtr;

// ---------------------------------------------------------------------------
// Strings: [hdr T_STRING 2] [char count (fixnum)] [buffer]. The buffer holds
// Latin-1 bytes (T_BUF8) until a wider character is stored; then it is
// replaced by a code point buffer (T_BUF32). string-ref stays O(1).

pub inline fn isString(w: Word) bool {
    return rt.isObj(w, rt.T_STRING);
}

pub inline fn stringLen(s: Word) usize {
    return @intCast(rt.unfix(ptr(s)[1]));
}

pub fn bufWords(n: usize, wide: bool) usize {
    return if (wide) (n + 1) / 2 else (n + 7) / 8;
}

/// Words needed by makeString.
pub fn stringWords(n: usize, wide: bool) usize {
    return 3 + 1 + bufWords(n, wide);
}

/// A new string of n characters (contents undefined). Reserve stringWords first.
pub fn makeString(t: *Thread, n: usize, wide: bool) Word {
    const b = t.allocRaw(1 + bufWords(n, wide));
    b[0] = hdr(if (wide) rt.T_BUF32 else rt.T_BUF8, bufWords(n, wide));
    const s = t.allocRaw(3);
    s[0] = hdr(rt.T_STRING, 2);
    s[1] = rt.fix(@intCast(n));
    s[2] = tagPtr(b);
    return tagPtr(s);
}

pub inline fn isWide(s: Word) bool {
    return rt.objType(ptr(s)[2]) == rt.T_BUF32;
}

pub inline fn bytes8(s: Word) [*]u8 {
    return @ptrCast(ptr(ptr(s)[2]) + 1);
}

pub inline fn cps32(s: Word) [*]u32 {
    return @ptrCast(ptr(ptr(s)[2]) + 1);
}

pub inline fn stringRef(s: Word, i: usize) u21 {
    return if (isWide(s)) @intCast(cps32(s)[i]) else bytes8(s)[i];
}

/// Store a character that fits the buffer (caller widens first if needed).
pub inline fn stringSetFits(s: Word, i: usize, cp: u21) void {
    if (isWide(s)) cps32(s)[i] = cp else bytes8(s)[i] = @truncate(cp);
}

/// Replace a Latin-1 buffer by a code point buffer. Reserve 1 + bufWords(n, true) first.
pub fn widen(t: *Thread, s: Word) void {
    const n = stringLen(s);
    const b = t.allocRaw(1 + bufWords(n, true));
    b[0] = hdr(rt.T_BUF32, bufWords(n, true));
    const dst: [*]u32 = @ptrCast(b + 1);
    const src = bytes8(s);
    for (0..n) |i| dst[i] = src[i];
    ptr(s)[2] = tagPtr(b);
}

/// Append the UTF-8 encoding of string s to buf.
pub fn appendUtf8(buf: *std.ArrayList(u8), s: Word) void {
    const n = stringLen(s);
    for (0..n) |i| appendCp(buf, stringRef(s, i));
}

pub fn appendCp(buf: *std.ArrayList(u8), cp: u21) void {
    var tmp: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(cp, &tmp) catch blk: {
        tmp[0] = '?';
        break :blk 1;
    };
    buf.appendSlice(std.heap.page_allocator, tmp[0..len]) catch rt.oom();
}

pub fn stringEq(a: Word, b: Word) bool {
    const n = stringLen(a);
    if (n != stringLen(b)) return false;
    for (0..n) |i| if (stringRef(a, i) != stringRef(b, i)) return false;
    return true;
}

pub fn stringCmp(a: Word, b: Word) std.math.Order {
    const na = stringLen(a);
    const nb = stringLen(b);
    for (0..@min(na, nb)) |i| {
        const x = stringRef(a, i);
        const y = stringRef(b, i);
        if (x != y) return std.math.order(x, y);
    }
    return std.math.order(na, nb);
}

// ---------------------------------------------------------------------------
// Symbols: static, interned. [hdr T_SYMBOL] [byte length] [UTF-8 bytes]

var symbols: std.StringHashMapUnmanaged(Word) = .empty;

pub inline fn isSymbol(w: Word) bool {
    return rt.isObj(w, rt.T_SYMBOL);
}

pub fn symbolName(w: Word) []const u8 {
    const p = ptr(w);
    const n: usize = @intCast(p[1]);
    const b: [*]const u8 = @ptrCast(p + 2);
    return b[0..n];
}

pub fn intern(name: []const u8) Word {
    const gop = symbols.getOrPut(std.heap.page_allocator, name) catch rt.oom();
    if (gop.found_existing) return gop.value_ptr.*;
    const p = rt.staticAlloc(2 + (name.len + 7) / 8, false);
    p[0] = hdr(rt.T_SYMBOL, 1 + (name.len + 7) / 8);
    p[1] = name.len;
    const b: [*]u8 = @ptrCast(p + 2);
    @memcpy(b[0..name.len], name);
    gop.key_ptr.* = b[0..name.len]; // the table keeps the symbol's own copy
    gop.value_ptr.* = tagPtr(p);
    return tagPtr(p);
}

// ---------------------------------------------------------------------------
// Vectors

pub inline fn isVector(w: Word) bool {
    return rt.isObj(w, rt.T_VECTOR);
}
pub inline fn vectorLen(w: Word) usize {
    return @intCast(rt.hdrLen(ptr(w)[0]));
}
pub inline fn vectorItems(w: Word) []Word {
    return (ptr(w) + 1)[0..vectorLen(w)];
}
pub inline fn vref(v: Word, i: Word) ?Word {
    if (!isVector(v) or !rt.isFix(i)) return null;
    const k: u64 = @bitCast(rt.unfix(i));
    if (k >= vectorLen(v)) return null;
    return ptr(v)[1 + k];
}

pub inline fn vset(v: Word, i: Word, x: Word) bool {
    if (!isVector(v) or !rt.isFix(i)) return false;
    const k: u64 = @bitCast(rt.unfix(i));
    if (k >= vectorLen(v)) return false;
    ptr(v)[1 + k] = x;
    return true;
}

/// Reserve 1 + n first.
pub fn makeVector(t: *Thread, n: usize, fill: Word) Word {
    const p = t.allocRaw(1 + n);
    p[0] = hdr(rt.T_VECTOR, n);
    @memset(p[1 .. 1 + n], fill);
    return tagPtr(p);
}

// ---------------------------------------------------------------------------
// Equality

pub fn eqv(a: Word, b: Word) bool {
    if (a == b) return true;
    if (rt.isFlonum(a) and rt.isFlonum(b)) return ptr(a)[1] == ptr(b)[1];
    return false;
}

pub fn equal(a: Word, b: Word) bool {
    var x = a;
    var y = b;
    while (true) {
        if (eqv(x, y)) return true;
        if (!rt.isPtr(x) or !rt.isPtr(y)) return false;
        const tx = rt.objType(x);
        if (tx != rt.objType(y)) return false;
        switch (tx) {
            rt.T_PAIR => {
                if (!equal(rt.car(x), rt.car(y))) return false;
                x = rt.cdr(x);
                y = rt.cdr(y);
            },
            rt.T_VECTOR => {
                const ix = vectorItems(x);
                const iy = vectorItems(y);
                if (ix.len != iy.len) return false;
                for (ix, iy) |u, v| if (!equal(u, v)) return false;
                return true;
            },
            rt.T_STRING => return stringEq(x, y),
            else => return false,
        }
    }
}

// ---------------------------------------------------------------------------
// Static constants, built by the generated init code

pub fn constString(utf8: []const u8) Word {
    var n: usize = 0;
    var wide = false;
    var it = std.unicode.Utf8View.initUnchecked(utf8).iterator();
    while (it.nextCodepoint()) |cp| {
        n += 1;
        if (cp > 255) wide = true;
    }
    const b = rt.staticAlloc(1 + bufWords(n, wide), false);
    b[0] = hdr(if (wide) rt.T_BUF32 else rt.T_BUF8, bufWords(n, wide));
    const s = rt.staticAlloc(3, true);
    s[0] = hdr(rt.T_STRING, 2);
    s[1] = rt.fix(@intCast(n));
    s[2] = tagPtr(b);
    const w = tagPtr(s);
    it = std.unicode.Utf8View.initUnchecked(utf8).iterator();
    var i: usize = 0;
    while (it.nextCodepoint()) |cp| : (i += 1) stringSetFits(w, i, cp);
    return w;
}

pub fn constPair(a: Word, d: Word) Word {
    const p = rt.staticAlloc(3, true);
    p[0] = hdr(rt.T_PAIR, 2);
    p[1] = a;
    p[2] = d;
    return tagPtr(p);
}

pub fn constVector(items: []const Word) Word {
    const p = rt.staticAlloc(1 + items.len, true);
    p[0] = hdr(rt.T_VECTOR, items.len);
    @memcpy(p[1 .. 1 + items.len], items);
    return tagPtr(p);
}

pub fn constFlonum(f: f64) Word {
    const p = rt.staticAlloc(2, false);
    p[0] = hdr(rt.T_FLONUM, 1);
    p[1] = @bitCast(f);
    return tagPtr(p);
}

// ---------------------------------------------------------------------------
// Strings from UTF-8

pub const Utf8Info = struct { n: usize, wide: bool };

pub fn utf8Info(utf8: []const u8) Utf8Info {
    var n: usize = 0;
    var wide = false;
    var i: usize = 0;
    while (i < utf8.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8[i]) catch 1;
        const cp: u21 = if (i + len <= utf8.len) (std.unicode.utf8Decode(utf8[i .. i + len]) catch 0xFFFD) else 0xFFFD;
        if (cp > 255) wide = true;
        n += 1;
        i += if (i + len <= utf8.len) len else 1;
    }
    return .{ .n = n, .wide = wide };
}

/// A heap string with the characters of utf8; reserve
/// stringWords(utf8.len, true) first (an upper bound).
pub fn heapStringUtf8(t: *Thread, utf8: []const u8) Word {
    const info = utf8Info(utf8);
    const s = makeString(t, info.n, info.wide);
    var i: usize = 0;
    var k: usize = 0;
    while (i < utf8.len) : (k += 1) {
        const len = std.unicode.utf8ByteSequenceLength(utf8[i]) catch 1;
        if (i + len <= utf8.len) {
            stringSetFits(s, k, std.unicode.utf8Decode(utf8[i .. i + len]) catch 0xFFFD);
            i += len;
        } else {
            stringSetFits(s, k, 0xFFFD);
            i += 1;
        }
    }
    return s;
}

/// The UTF-8 bytes of string s (allocated with the page allocator)
pub fn toUtf8(s: Word) []u8 {
    var buf: std.ArrayList(u8) = .empty;
    appendUtf8(&buf, s);
    return buf.items;
}

// ---------------------------------------------------------------------------
// Bytevectors: [hdr T_BYTEVECTOR] [byte length] [bytes]

pub inline fn isBytevector(w: Word) bool {
    return rt.isObj(w, rt.T_BYTEVECTOR);
}
pub inline fn bvLen(w: Word) usize {
    return @intCast(ptr(w)[1]);
}
pub inline fn bvBytes(w: Word) []u8 {
    const b: [*]u8 = @ptrCast(ptr(w) + 2);
    return b[0..bvLen(w)];
}
pub fn bvWords(n: usize) usize {
    return 2 + (n + 7) / 8;
}
/// Reserve bvWords(n) first.
pub fn makeBytevector(t: *Thread, n: usize) Word {
    const q = t.allocRaw(bvWords(n));
    q[0] = hdr(rt.T_BYTEVECTOR, 1 + (n + 7) / 8);
    q[1] = n;
    return tagPtr(q);
}
pub fn constBytevector(bytes: []const u8) Word {
    const q = rt.staticAlloc(bvWords(bytes.len), false);
    q[0] = hdr(rt.T_BYTEVECTOR, 1 + (bytes.len + 7) / 8);
    q[1] = bytes.len;
    @memcpy(bvBytes(tagPtr(q)), bytes);
    return tagPtr(q);
}

// ---------------------------------------------------------------------------
// Records: [hdr T_RECORD] [type] [fields...], as the JVM implementation's
// Record (slot 0 is the type).

pub inline fn isRecord(w: Word) bool {
    return rt.isObj(w, rt.T_RECORD);
}
pub inline fn recordSize(w: Word) usize {
    return @intCast(rt.hdrLen(ptr(w)[0]));
}
pub inline fn recordSlots(w: Word) []Word {
    return (ptr(w) + 1)[0..recordSize(w)];
}
/// Reserve 1 + size first.
pub fn makeRecord(t: *Thread, size: usize) Word {
    const q = t.allocRaw(1 + size);
    q[0] = hdr(rt.T_RECORD, size);
    @memset(q[1 .. 1 + size], rt.FALSE);
    return tagPtr(q);
}

/// A number constant from its syntax (bignums, rationals, complex numbers):
/// made once at startup and never freed.
pub fn constNumber(t: *Thread, text: []const u8) Word {
    const num = @import("num.zig");
    const lit = num.parseNumber(text, 10) orelse rt.os.fatal("bad number constant {s}", .{text});
    const w = switch (lit) {
        .fix => |n| rt.fix(n),
        .flo => |f| constFlonum(f),
        .exact => num.exactFromLit(t, lit) orelse rt.os.fatal("bad number constant {s}", .{text}),
    };
    makePermanent(w);
    return w;
}

fn makePermanent(w: Word) void {
    if (!rt.isPtr(w)) return;
    const q = ptr(w);
    if (rt.hdrFlags(q[0]) & rt.F_LARGE == 0) return;
    q[0] |= @as(Word, rt.F_PERM) << 8;
    switch (rt.hdrType(q[0])) {
        rt.T_RATNUM, rt.T_COMPNUM => {
            makePermanent(q[1]);
            makePermanent(q[2]);
        },
        else => {},
    }
}
