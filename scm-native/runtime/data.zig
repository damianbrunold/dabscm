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
    if (isWide(s)) cps32(s)[i] = cp else bytes8(s)[i] = @intCast(cp);
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
