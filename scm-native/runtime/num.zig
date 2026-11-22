//! Arithmetic. Phase 1: fixnums and flonums; bignums, rationals and complex
//! numbers come in Phase 2. The open-coded operations return null on a type
//! error or an overflow; the generated code then reports the error.
//! Operations that can produce a flonum need 2 reserved words.
const std = @import("std");
const rt = @import("rt.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const isFix = rt.isFix;
pub const tower = @import("tower.zig");

pub inline fn isNumber(w: Word) bool {
    return isFix(w) or rt.isFlonum(w) or tower.isNumber(w);
}

/// A real as an f64; null if not a real
pub inline fn toF(w: Word) ?f64 {
    if (isFix(w)) return @floatFromInt(rt.unfix(w));
    if (rt.isFlonum(w)) return rt.flo(w);
    if (tower.isReal(w)) return tower.toFloat(w);
    return null;
}

pub inline fn add(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b)) {
        const r = @addWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
        if (r[1] == 0) return @bitCast(r[0]);
        return tower.arith(t, a, b, .add);
    }
    return floOp(t, a, b, .add);
}

pub inline fn sub(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b)) {
        const r = @subWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
        if (r[1] == 0) return @bitCast(r[0]);
        return tower.arith(t, a, b, .sub);
    }
    return floOp(t, a, b, .sub);
}

pub inline fn mul(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b)) {
        const r = @mulWithOverflow(rt.unfix(a), @as(i64, @bitCast(b)));
        if (r[1] == 0) return @bitCast(r[0]);
        return tower.arith(t, a, b, .mul);
    }
    return floOp(t, a, b, .mul);
}

const Op = enum { add, sub, mul, div };

noinline fn floOp(t: *Thread, a: Word, b: Word, comptime op: Op) ?Word {
    if (!((isFix(a) or rt.isFlonum(a)) and (isFix(b) or rt.isFlonum(b)))) return tower.arith(t, a, b, switch (op) {
        .add => .add,
        .sub => .sub,
        .mul => .mul,
        .div => .div,
    });
    const x = toF(a).?;
    const y = toF(b).?;
    return rt.safeFlo(t, switch (op) {
        .add => x + y,
        .sub => x - y,
        .mul => x * y,
        .div => x / y,
    });
}

pub inline fn div(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b) and b != rt.fix(0)) {
        const x = rt.unfix(a);
        const y = rt.unfix(b);
        if (@rem(x, y) == 0 and !(x == rt.fix_min and y == -1)) return rt.fix(@divTrunc(x, y));
        return tower.arith(t, a, b, .div);
    }
    return floOp(t, a, b, .div);
}

pub const Cmp = enum { lt, gt, le, ge, eq };

pub inline fn cmp(a: Word, b: Word, comptime c: Cmp) ?bool {
    if (isFix(a | b)) {
        const x: i64 = @bitCast(a);
        const y: i64 = @bitCast(b);
        return switch (c) {
            .lt => x < y,
            .gt => x > y,
            .le => x <= y,
            .ge => x >= y,
            .eq => x == y,
        };
    }
    return cmpSlow(a, b, c);
}

noinline fn cmpSlow(a: Word, b: Word, comptime c: Cmp) ?bool {
    if (!((isFix(a) or rt.isFlonum(a)) and (isFix(b) or rt.isFlonum(b)))) {
        const t = current_thread;
        if (c == .eq) return tower.numEq(t, a, b);
        const o = tower.order(t, a, b) orelse return if (tower.isReal(a) and tower.isReal(b)) false else null;
        return switch (c) {
            .lt => o == .lt,
            .gt => o == .gt,
            .le => o != .gt,
            .ge => o != .lt,
            .eq => o == .eq,
        };
    }
    // a fixnum and a flonum: exactly, unless the fixnum converts exactly
    if (isFix(a) != isFix(b)) {
        const n = rt.unfix(if (isFix(a)) a else b);
        if (n > (1 << 53) or n < -(1 << 53)) {
            const t = current_thread;
            if (c == .eq) return tower.numEq(t, a, b);
            const o = tower.order(t, a, b) orelse return false;
            return switch (c) {
                .lt => o == .lt,
                .gt => o == .gt,
                .le => o != .gt,
                .ge => o != .lt,
                .eq => o == .eq,
            };
        }
    }
    const x = toF(a).?;
    const y = toF(b).?;
    return switch (c) {
        .lt => x < y,
        .gt => x > y,
        .le => x <= y,
        .ge => x >= y,
        .eq => x == y,
    };
}

/// The thread, for comparisons that allocate exact intermediates
pub var current_thread: *Thread = undefined;

pub fn isInteger(w: Word) bool {
    if (isFix(w) or tower.isBig(w)) return true;
    if (rt.isFlonum(w)) {
        const f = rt.flo(w);
        return std.math.isFinite(f) and @floor(f) == f;
    }
    return false;
}

/// Shortest representation in the layout of Java's %.{15..17}g, as the
/// JVM implementation prints flonums: 1.5, 3.0, 1.0e+21, 1.0e-7, +inf.0
pub fn formatFlonum(buf: *std.ArrayList(u8), f: f64) void {
    const a = std.heap.c_allocator;
    if (std.math.isNan(f)) return buf.appendSlice(a, "+nan.0") catch rt.oom();
    if (std.math.isInf(f)) return buf.appendSlice(a, if (f > 0) "+inf.0" else "-inf.0") catch rt.oom();
    if (std.math.signbit(f)) buf.append(a, '-') catch rt.oom();
    const x = @abs(f);
    if (x == 0) return buf.appendSlice(a, "0.0") catch rt.oom();
    // shortest round-trip digits d1 d2 ... dn and the decimal exponent
    var tmp: [64]u8 = undefined;
    const sci = std.fmt.float.render(&tmp, x, .{ .mode = .scientific }) catch unreachable;
    const e_idx = std.mem.indexOfScalar(u8, sci, 'e').?;
    var digits: [24]u8 = undefined;
    var nd: usize = 0;
    for (sci[0..e_idx]) |ch| if (ch != '.') {
        digits[nd] = ch;
        nd += 1;
    };
    while (nd > 1 and digits[nd - 1] == '0') nd -= 1;
    const exp = std.fmt.parseInt(i32, sci[e_idx + 1 ..], 10) catch unreachable;
    const p: i32 = @intCast(@max(15, nd));
    if (exp < -4 or exp >= p) {
        buf.append(a, digits[0]) catch rt.oom();
        buf.append(a, '.') catch rt.oom();
        if (nd > 1) buf.appendSlice(a, digits[1..nd]) catch rt.oom() else buf.append(a, '0') catch rt.oom();
        var eb: [16]u8 = undefined;
        const es = std.fmt.bufPrint(&eb, "e{s}{d}", .{ if (exp >= 0) "+" else "-", @abs(exp) }) catch unreachable;
        buf.appendSlice(a, es) catch rt.oom();
    } else if (exp < 0) {
        buf.appendSlice(a, "0.") catch rt.oom();
        for (0..@intCast(-exp - 1)) |_| buf.append(a, '0') catch rt.oom();
        buf.appendSlice(a, digits[0..nd]) catch rt.oom();
    } else {
        const ip: usize = @intCast(exp + 1);
        for (0..ip) |i| buf.append(a, if (i < nd) digits[i] else '0') catch rt.oom();
        buf.append(a, '.') catch rt.oom();
        if (nd > ip) buf.appendSlice(a, digits[ip..nd]) catch rt.oom() else buf.append(a, '0') catch rt.oom();
    }
}

// ---------------------------------------------------------------------------
// Number syntax

pub const Lit = union(enum) {
    fix: i64,
    flo: f64,
    /// an exact integer beyond the fixnum range, or a rational: the text
    /// (without prefixes) and its radix; made by the numeric tower
    exact: struct { text: []const u8, radix: u8 },
    /// a complex number (rectangular a+bi or polar r@angle): the whole
    /// text, prefixes included; made by exactFromLit
    complex: struct { text: []const u8, radix: u8 },
};

/// Parse a number in Scheme syntax; null if text is not a number.
pub fn parseNumber(text0: []const u8, default_radix: u8) ?Lit {
    var text = text0;
    var radix = default_radix;
    var exactness: u8 = 0; // 'e', 'i' or 0
    while (text.len >= 2 and text[0] == '#') {
        switch (std.ascii.toLower(text[1])) {
            'x' => radix = 16,
            'b' => radix = 2,
            'o' => radix = 8,
            'd' => radix = 10,
            'e' => exactness = 'e',
            'i' => exactness = 'i',
            else => return null,
        }
        text = text[2..];
    }
    if (text.len == 0) return null;
    if (complexParts(text, radix) != null) return .{ .complex = .{ .text = text0, .radix = default_radix } };
    const lit = parseReal(text, radix) orelse return null;
    return switch (exactness) {
        'i' => switch (lit) {
            .fix => |n| .{ .flo = @floatFromInt(n) },
            .flo => lit,
            .exact => |e| .{ .flo = exactTextToFloat(e.text, e.radix) orelse return null },
            .complex => unreachable,
        },
        'e' => switch (lit) {
            .flo => |f| blk: {
                if (std.math.isFinite(f) and @floor(f) == f and @abs(f) < 4.0e18) break :blk .{ .fix = @intFromFloat(f) };
                // other inexact-to-exact conversions need rationals
                break :blk .{ .exact = .{ .text = text, .radix = radix } };
            },
            else => lit,
        },
        else => lit,
    };
}

fn parseReal(text: []const u8, radix: u8) ?Lit {
    if (std.ascii.eqlIgnoreCase(text, "+inf.0")) return .{ .flo = std.math.inf(f64) };
    if (std.ascii.eqlIgnoreCase(text, "-inf.0")) return .{ .flo = -std.math.inf(f64) };
    if (std.ascii.eqlIgnoreCase(text, "+nan.0") or std.ascii.eqlIgnoreCase(text, "-nan.0")) return .{ .flo = std.math.nan(f64) };
    var i: usize = 0;
    if (text[0] == '+' or text[0] == '-') i = 1;
    if (i == text.len) return null;
    // integer or rational
    var j = i;
    while (j < text.len and digitOf(text[j], radix) != null) j += 1;
    if (j == text.len and j > i) {
        const n = std.fmt.parseInt(i64, text, radix) catch return .{ .exact = .{ .text = text, .radix = radix } };
        if (n < fix_min_num or n > fix_max_num) return .{ .exact = .{ .text = text, .radix = radix } };
        return .{ .fix = n };
    }
    if (j < text.len and text[j] == '/' and j > i) {
        var k = j + 1;
        if (k == text.len) return null;
        while (k < text.len and digitOf(text[k], radix) != null) k += 1;
        if (k != text.len) return null;
        return .{ .exact = .{ .text = text, .radix = radix } };
    }
    // decimal
    if (radix != 10) return null;
    var k = i;
    var digits: usize = 0;
    while (k < text.len and std.ascii.isDigit(text[k])) : (k += 1) digits += 1;
    if (k < text.len and text[k] == '.') {
        k += 1;
        while (k < text.len and std.ascii.isDigit(text[k])) : (k += 1) digits += 1;
    }
    if (digits == 0) return null;
    var marker: ?usize = null;
    if (k < text.len and isExponentMarker(text[k])) {
        marker = k;
        k += 1;
        if (k < text.len and (text[k] == '+' or text[k] == '-')) k += 1;
        const start = k;
        while (k < text.len and std.ascii.isDigit(text[k])) k += 1;
        if (k == start) return null;
    }
    if (k != text.len) return null;
    // the exponent markers s, f, d and l (R7RS) as e
    var buf: [400]u8 = undefined;
    const t = if (marker) |m| blk: {
        if (text.len > buf.len) return null;
        @memcpy(buf[0..text.len], text);
        buf[m] = 'e';
        break :blk buf[0..text.len];
    } else text;
    return .{ .flo = std.fmt.parseFloat(f64, t) catch return null };
}

fn isExponentMarker(c: u8) bool {
    return switch (c) {
        'e', 'E', 's', 'S', 'f', 'F', 'd', 'D', 'l', 'L' => true,
        else => false,
    };
}

const fix_min_num: i64 = -(1 << 62);
const fix_max_num: i64 = (1 << 62) - 1;

pub fn digitOf(c: u8, radix: u8) ?u8 {
    const d: u8 = switch (c) {
        '0'...'9' => c - '0',
        'a'...'z' => c - 'a' + 10,
        'A'...'Z' => c - 'A' + 10,
        else => return null,
    };
    return if (d < radix) d else null;
}

fn exactTextToFloat(text: []const u8, radix: u8) ?f64 {
    if (std.mem.indexOfScalar(u8, text, '/')) |slash| {
        const a = exactTextToFloat(text[0..slash], radix) orelse return null;
        const b = exactTextToFloat(text[slash + 1 ..], radix) orelse return null;
        return a / b;
    }
    var f: f64 = 0;
    var neg = false;
    for (text, 0..) |c, i| {
        if (i == 0 and (c == '-' or c == '+')) {
            neg = c == '-';
            continue;
        }
        f = f * @as(f64, @floatFromInt(radix)) + @as(f64, @floatFromInt(digitOf(c, radix) orelse return null));
    }
    return if (neg) -f else f;
}

/// An exact number beyond the fixnums (bignum, rational) from its syntax.
/// Made by the numeric tower; null until then.
pub fn exactFromLit(t: *Thread, lit: Lit) ?Word {
    return switch (lit) {
        .fix => |n| rt.fix(n),
        .flo => null,
        .exact => |e| tower.fromText(t, e.text, e.radix),
        .complex => |c| complexFromText(t, c.text, c.radix),
    };
}

const Parts = struct { re: []const u8, im: []const u8, polar: bool };

/// The real and imaginary parts (or magnitude and angle) of a complex
/// number's text without prefixes; null if it is not one
fn complexParts(text: []const u8, radix: u8) ?Parts {
    if (std.mem.indexOfScalar(u8, text, '@')) |at| {
        if (at == 0 or at + 1 == text.len) return null;
        if (parseReal(text[0..at], radix) == null or parseReal(text[at + 1 ..], radix) == null) return null;
        return .{ .re = text[0..at], .im = text[at + 1 ..], .polar = true };
    }
    if (text.len < 2 or (text[text.len - 1] != 'i' and text[text.len - 1] != 'I')) return null;
    const body = text[0 .. text.len - 1];
    // the sign that starts the imaginary part: the last + or - not at the
    // start and not in an exponent (nor in inf.0/nan.0 of the real part)
    var k: ?usize = null;
    var i = body.len;
    while (i > 1) {
        i -= 1;
        const c = body[i];
        if (c != '+' and c != '-') continue;
        const prev = body[i - 1];
        if (radix == 10 and isExponentMarker(prev)) continue;
        k = i;
        break;
    }
    const re: []const u8 = if (k) |x| body[0..x] else "0";
    const im = if (k) |x| body[x..] else body;
    if (im.len == 0 or (im[0] != '+' and im[0] != '-')) return null;
    if (k) |x| if (parseReal(body[0..x], radix) == null) return null;
    if (im.len > 1 and parseReal(im, radix) == null) return null;
    return .{ .re = re, .im = im, .polar = false };
}

/// A complex number from its text (with prefixes)
fn complexFromText(t: *Thread, text0: []const u8, default_radix: u8) ?Word {
    var text = text0;
    var radix = default_radix;
    var exactness: u8 = 0;
    while (text.len >= 2 and text[0] == '#') {
        switch (std.ascii.toLower(text[1])) {
            'x' => radix = 16,
            'b' => radix = 2,
            'o' => radix = 8,
            'd' => radix = 10,
            'e' => exactness = 'e',
            'i' => exactness = 'i',
            else => return null,
        }
        text = text[2..];
    }
    const p = complexParts(text, radix) orelse return null;
    const re = partValue(t, p.re, radix, exactness) orelse return null;
    const im = if (std.mem.eql(u8, p.im, "+")) rt.fix(1) else if (std.mem.eql(u8, p.im, "-")) rt.fix(-1) else partValue(t, p.im, radix, exactness) orelse return null;
    const im2 = if (exactness == 'i' and !rt.isFlonum(im)) rt.safeFlo(t, toF(im).?) else im;
    if (p.polar) {
        const m = toF(re).?;
        const a = toF(im2).?;
        if (a == 0 and !rt.isFlonum(im2)) return re;
        return tower.makeRect(t, rt.safeFlo(t, m * @cos(a)), rt.safeFlo(t, m * @sin(a)));
    }
    return tower.makeRect(t, re, im2);
}

fn partValue(t: *Thread, text: []const u8, radix: u8, exactness: u8) ?Word {
    const lit = parseReal(text, radix) orelse return null;
    const w = switch (lit) {
        .fix => |n| rt.fix(n),
        .flo => |f| rt.safeFlo(t, f),
        .exact => |e| tower.fromText(t, e.text, e.radix) orelse return null,
        .complex => return null,
    };
    if (exactness == 'i' and !rt.isFlonum(w)) return rt.safeFlo(t, toF(w).?);
    if (exactness == 'e' and rt.isFlonum(w)) return tower.floatToExact(t, rt.flo(w));
    return w;
}

/// Exact b^e beyond the fixnums or with a negative exponent (bignum,
/// rational). Made by the numeric tower; null until then.
pub fn exactExpt(t: *Thread, b: Word, e: Word) ?Word {
    return tower.exactExpt(t, b, e);
}

/// Print a bignum, ratnum or compnum (the numeric tower)
pub fn formatExact(buf: *std.ArrayList(u8), w: Word) void {
    tower.format(buf, w, 10);
}
