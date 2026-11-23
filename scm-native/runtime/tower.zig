//! The numeric tower beyond fixnums and flonums: bignums, exact rationals
//! and complex numbers, as in the JVM implementation (whose complex parts
//! may be exact). Bignum arithmetic uses std.math.big.int.
//!
//! Every object made here comes from the large-object space, which never
//! collects; so the arithmetic slow paths are safe in any code.
//!   bignum  [hdr T_BIGNUM]  [limb count << 1 | negative] [limbs...]
//!   ratnum  [hdr T_RATNUM]  [numerator] [denominator > 1]  (lowest terms)
//!   compnum [hdr T_COMPNUM] [real] [imaginary /= exact 0]
const std = @import("std");
const big = std.math.big.int;
const rt = @import("rt.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const fix = rt.fix;
const unfix = rt.unfix;
const isFix = rt.isFix;
const ptr = rt.ptr;

const pa = std.heap.c_allocator;
const Managed = big.Managed;
const Const = big.Const;
const Limb = std.math.big.Limb;

pub inline fn isBig(w: Word) bool {
    return rt.isObj(w, rt.T_BIGNUM);
}
pub inline fn isRat(w: Word) bool {
    return rt.isObj(w, rt.T_RATNUM);
}
pub inline fn isComp(w: Word) bool {
    return rt.isObj(w, rt.T_COMPNUM);
}
pub inline fn isExactInteger(w: Word) bool {
    return isFix(w) or isBig(w);
}
pub inline fn isExactRational(w: Word) bool {
    return isExactInteger(w) or isRat(w);
}
pub inline fn isReal(w: Word) bool {
    return isExactRational(w) or rt.isFlonum(w);
}
pub inline fn isNumber(w: Word) bool {
    return isReal(w) or isComp(w);
}
pub inline fn isExact(w: Word) bool {
    if (isComp(w)) return isExactRational(ptr(w)[1]) and isExactRational(ptr(w)[2]);
    return isExactRational(w);
}

fn oom() noreturn {
    rt.oom();
}

// --- bignums -------------------------------------------------------------------

fn bigConst(w: Word) Const {
    const q = ptr(w);
    const n: usize = @intCast(q[1] >> 1);
    const limbs: [*]const Limb = @ptrCast(q + 2);
    return .{ .limbs = limbs[0..n], .positive = q[1] & 1 == 0 };
}

/// An exact integer as a Managed (the caller deinits it)
fn toManaged(w: Word) Managed {
    if (isFix(w)) return Managed.initSet(pa, unfix(w)) catch oom();
    var m = Managed.init(pa) catch oom();
    m.copy(bigConst(w)) catch oom();
    return m;
}

/// The exact integer c: a fixnum if it fits, else a bignum
fn fromConst(t: *Thread, c: Const) Word {
    if (c.fits(i64)) {
        const n = c.toInt(i64) catch unreachable;
        if (rt.fixFits(n)) return fix(n);
    }
    var n = c.limbs.len;
    while (n > 1 and c.limbs[n - 1] == 0) n -= 1;
    const q = rt.allocLarge(t, 2 + n);
    q[0] = rt.hdr(rt.T_BIGNUM, 1 + n) | (@as(Word, rt.F_LARGE) << 8);
    q[1] = (@as(Word, n) << 1) | @intFromBool(!c.positive);
    const dst: [*]Limb = @ptrCast(q + 2);
    @memcpy(dst[0..n], c.limbs[0..n]);
    return rt.tagPtr(q);
}

fn fromManaged(t: *Thread, m: *Managed) Word {
    defer m.deinit();
    return fromConst(t, m.toConst());
}

fn intOp(t: *Thread, a: Word, b: Word, comptime op: enum { add, sub, mul }) Word {
    var x = toManaged(a);
    defer x.deinit();
    var y = toManaged(b);
    defer y.deinit();
    var r = Managed.init(pa) catch oom();
    switch (op) {
        .add => r.add(&x, &y) catch oom(),
        .sub => r.sub(&x, &y) catch oom(),
        .mul => r.mul(&x, &y) catch oom(),
    }
    return fromManaged(t, &r);
}

fn intOrder(a: Word, b: Word) std.math.Order {
    if (isFix(a) and isFix(b)) return std.math.order(unfix(a), unfix(b));
    var x = toManaged(a);
    defer x.deinit();
    var y = toManaged(b);
    defer y.deinit();
    return x.order(y);
}

fn intSign(a: Word) i2 {
    if (isFix(a)) return if (unfix(a) < 0) -1 else if (unfix(a) > 0) 1 else 0;
    return if (bigConst(a).positive) 1 else -1;
}

pub const DivKind = enum { trunc, floor };

/// Quotient and remainder of exact integers (b /= 0)
pub fn intDiv(t: *Thread, a: Word, b: Word, kind: DivKind) [2]Word {
    if (isFix(a) and isFix(b)) {
        const x = unfix(a);
        const y = unfix(b);
        if (!(x == rt.fix_min and y == -1)) {
            return switch (kind) {
                .trunc => .{ fix(@divTrunc(x, y)), fix(@rem(x, y)) },
                .floor => .{ fix(@divFloor(x, y)), fix(@mod(x, y)) },
            };
        }
    }
    var x = toManaged(a);
    defer x.deinit();
    var y = toManaged(b);
    defer y.deinit();
    var q = Managed.init(pa) catch oom();
    var r = Managed.init(pa) catch oom();
    switch (kind) {
        .trunc => q.divTrunc(&r, &x, &y) catch oom(),
        .floor => q.divFloor(&r, &x, &y) catch oom(),
    }
    return .{ fromManaged(t, &q), fromManaged(t, &r) };
}

pub fn intGcd(t: *Thread, a: Word, b: Word) Word {
    if (isFix(a) and isFix(b)) {
        var x: u64 = @abs(unfix(a));
        var y: u64 = @abs(unfix(b));
        while (y != 0) {
            const r = x % y;
            x = y;
            y = r;
        }
        return fix(@intCast(x));
    }
    var x = toManaged(a);
    defer x.deinit();
    var y = toManaged(b);
    defer y.deinit();
    x.abs();
    y.abs();
    if (x.eqlZero()) return fromConst(t, y.toConst());
    if (y.eqlZero()) return fromConst(t, x.toConst());
    var r = Managed.init(pa) catch oom();
    r.gcd(&x, &y) catch oom();
    return fromManaged(t, &r);
}

fn intToFloat(w: Word) f64 {
    if (isFix(w)) return @floatFromInt(unfix(w));
    return bigConst(w).toFloat(f64, .nearest_even)[0];
}

fn intNegate(t: *Thread, a: Word) Word {
    return intOp(t, fix(0), a, .sub);
}

// --- rationals -------------------------------------------------------------------

fn ratNum(w: Word) Word {
    return if (isRat(w)) ptr(w)[1] else w;
}
fn ratDen(w: Word) Word {
    return if (isRat(w)) ptr(w)[2] else fix(1);
}

/// n/d in lowest terms (d /= 0); an integer when d divides n
pub fn makeRational(t: *Thread, n0: Word, d0: Word) Word {
    var n = n0;
    var d = d0;
    if (intSign(d) < 0) {
        n = intNegate(t, n);
        d = intNegate(t, d);
    }
    const g = intGcd(t, n, d);
    if (g != fix(1)) {
        n = intDiv(t, n, g, .trunc)[0];
        d = intDiv(t, d, g, .trunc)[0];
    }
    if (d == fix(1)) return n;
    const q = rt.allocLarge(t, 3);
    q[0] = rt.hdr(rt.T_RATNUM, 2) | (@as(Word, rt.F_LARGE) << 8);
    q[1] = n;
    q[2] = d;
    return rt.tagPtr(q);
}

fn ratOp(t: *Thread, a: Word, b: Word, comptime op: enum { add, sub, mul, div }) ?Word {
    const an = ratNum(a);
    const ad = ratDen(a);
    const bn = ratNum(b);
    const bd = ratDen(b);
    return switch (op) {
        .add => makeRational(t, intOp(t, intOp(t, an, bd, .mul), intOp(t, bn, ad, .mul), .add), intOp(t, ad, bd, .mul)),
        .sub => makeRational(t, intOp(t, intOp(t, an, bd, .mul), intOp(t, bn, ad, .mul), .sub), intOp(t, ad, bd, .mul)),
        .mul => makeRational(t, intOp(t, an, bn, .mul), intOp(t, ad, bd, .mul)),
        .div => if (intSign(bn) == 0) null else makeRational(t, intOp(t, an, bd, .mul), intOp(t, ad, bn, .mul)),
    };
}

fn ratOrder(a: Word, b: Word, t: *Thread) std.math.Order {
    // a/b < c/d  <=>  a*d < c*b  (denominators positive)
    return intOrder(intOp(t, ratNum(a), ratDen(b), .mul), intOp(t, ratNum(b), ratDen(a), .mul));
}

fn ratToFloat(w: Word) f64 {
    if (!isRat(w)) return intToFloat(w);
    const n = ratNum(w);
    const d = ratDen(w);
    const fnum = intToFloat(n);
    const fden = intToFloat(d);
    // exact terms: one correctly rounded division
    if (@abs(fnum) < 9007199254740992.0 and fden < 9007199254740992.0) return fnum / fden;
    return divideRounded(n, d);
}

/// n / d (d > 0) correctly rounded to the nearest double (ties to even),
/// subnormals and overflow included
fn divideRounded(nw: Word, dw: Word) f64 {
    var n = toManaged(nw);
    defer n.deinit();
    var d = toManaged(dw);
    defer d.deinit();
    const negative = !n.isPositive() and !n.eqlZero();
    n.abs();
    if (n.eqlZero()) return 0.0;
    const k: i64 = @as(i64, @intCast(n.bitCountAbs())) - @as(i64, @intCast(d.bitCountAbs()));
    // the value lies in [2^(k-1), 2^(k+1)): the last place first assuming 2^(k-1)
    var u: i64 = @max(k - 54, -1074);
    var q = Managed.init(pa) catch oom();
    defer q.deinit();
    var r = Managed.init(pa) catch oom();
    defer r.deinit();
    var a = Managed.init(pa) catch oom();
    defer a.deinit();
    var b = Managed.init(pa) catch oom();
    defer b.deinit();
    while (true) {
        // q = floor(n * 2^-u / d)
        if (u < 0) {
            a.shiftLeft(&n, @intCast(-u)) catch oom();
            b.copy(d.toConst()) catch oom();
        } else {
            a.copy(n.toConst()) catch oom();
            b.shiftLeft(&d, @intCast(u)) catch oom();
        }
        q.divFloor(&r, &a, &b) catch oom();
        if (q.bitCountAbs() > 53 and u < 2000) {
            u += @as(i64, @intCast(q.bitCountAbs())) - 53;
            continue;
        }
        break;
    }
    // round half to even on the remainder
    r.shiftLeft(&r, 1) catch oom();
    const cmp = r.order(b);
    const odd = q.isOdd();
    if (cmp == .gt or (cmp == .eq and odd)) {
        var one = Managed.initSet(pa, 1) catch oom();
        defer one.deinit();
        q.add(&q, &one) catch oom();
    }
    const m = q.toConst().toFloat(f64, .nearest_even)[0]; // exact: at most 2^53
    const x = std.math.ldexp(m, @intCast(@max(@min(u, 4000), -4000)));
    return if (negative) -x else x;
}

fn shrinkToFloat(w: Word, shift: i64) f64 {
    const f = intToFloat(w);
    if (std.math.isFinite(f)) return std.math.ldexp(f, @intCast(-shift));
    var m = toManaged(w);
    defer m.deinit();
    var r = Managed.init(pa) catch oom();
    defer r.deinit();
    r.shiftRight(&m, @intCast(shift)) catch oom();
    return r.toConst().toFloat(f64, .nearest_even)[0];
}

/// The exact value of a finite flonum
pub fn floatToExact(t: *Thread, f: f64) ?Word {
    if (!std.math.isFinite(f)) return null;
    if (@floor(f) == f and @abs(f) < 4.0e18) return fix(@intFromFloat(f));
    const fr = std.math.frexp(f); // f = m * 2^e, 0.5 <= |m| < 1
    // m * 2^53 is an integer
    const mant: i64 = @intFromFloat(std.math.ldexp(fr.significand, 53));
    const e: i32 = fr.exponent - 53;
    var m = Managed.initSet(pa, mant) catch oom();
    if (e >= 0) {
        var r = Managed.init(pa) catch oom();
        r.shiftLeft(&m, @intCast(e)) catch oom();
        m.deinit();
        return fromManaged(t, &r);
    }
    defer m.deinit();
    var d = Managed.initSet(pa, 1) catch oom();
    var d2 = Managed.init(pa) catch oom();
    d2.shiftLeft(&d, @intCast(-e)) catch oom();
    d.deinit();
    return makeRational(t, fromConst(t, m.toConst()), fromManaged(t, &d2));
}

// --- complex numbers -------------------------------------------------------------------

pub fn makeRect(t: *Thread, re0: Word, im0: Word) Word {
    if (im0 == fix(0)) return re0;
    // one inexact part makes the number inexact (as the JVM implementation:
    // (make-rectangular 1 2.5) is 1.0+2.5i)
    var re = re0;
    var im = im0;
    if (rt.isFlonum(re) and !rt.isFlonum(im)) im = rt.safeFlo(t, toFloat(im));
    if (rt.isFlonum(im) and !rt.isFlonum(re)) re = rt.safeFlo(t, toFloat(re));
    const q = rt.allocLarge(t, 3);
    q[0] = rt.hdr(rt.T_COMPNUM, 2) | (@as(Word, rt.F_LARGE) << 8);
    q[1] = re;
    q[2] = im;
    // the parts may be young flonums
    rt.remember(rt.tagPtr(q));
    return rt.tagPtr(q);
}

pub fn realPart(w: Word) Word {
    return if (isComp(w)) ptr(w)[1] else w;
}
pub fn imagPart(w: Word) Word {
    return if (isComp(w)) ptr(w)[2] else fix(0);
}

fn floWord(t: *Thread, f: f64) Word {
    return rt.safeFlo(t, f);
}

// --- generic operations ----------------------------------------------------------------

pub const Op = enum { add, sub, mul, div };

/// a op b for any numbers; null on a type error or division by exact zero
pub fn arith(t: *Thread, a: Word, b: Word, op: Op) ?Word {
    if (!isNumber(a) or !isNumber(b)) return null;
    if (isComp(a) or isComp(b)) return compArith(t, a, b, op);
    if (rt.isFlonum(a) or rt.isFlonum(b)) {
        const x = toFloat(a);
        const y = toFloat(b);
        return floWord(t, switch (op) {
            .add => x + y,
            .sub => x - y,
            .mul => x * y,
            .div => x / y,
        });
    }
    if (isExactInteger(a) and isExactInteger(b)) {
        return switch (op) {
            .add => intOp(t, a, b, .add),
            .sub => intOp(t, a, b, .sub),
            .mul => intOp(t, a, b, .mul),
            .div => if (intSign(b) == 0) null else makeRational(t, a, b),
        };
    }
    return switch (op) {
        .add => ratOp(t, a, b, .add),
        .sub => ratOp(t, a, b, .sub),
        .mul => ratOp(t, a, b, .mul),
        .div => ratOp(t, a, b, .div),
    };
}

fn compArith(t: *Thread, a: Word, b: Word, op: Op) ?Word {
    const ar = realPart(a);
    const ai = imagPart(a);
    const br = realPart(b);
    const bi = imagPart(b);
    switch (op) {
        .add => return makeRect(t, arith(t, ar, br, .add).?, arith(t, ai, bi, .add).?),
        .sub => return makeRect(t, arith(t, ar, br, .sub).?, arith(t, ai, bi, .sub).?),
        .mul => return makeRect(
            t,
            arith(t, arith(t, ar, br, .mul).?, arith(t, ai, bi, .mul).?, .sub).?,
            arith(t, arith(t, ar, bi, .mul).?, arith(t, ai, br, .mul).?, .add).?,
        ),
        .div => {
            const den = arith(t, arith(t, br, br, .mul).?, arith(t, bi, bi, .mul).?, .add).?;
            const re = arith(t, arith(t, ar, br, .mul).?, arith(t, ai, bi, .mul).?, .add).?;
            const im = arith(t, arith(t, ai, br, .mul).?, arith(t, ar, bi, .mul).?, .sub).?;
            return makeRect(t, arith(t, re, den, .div) orelse return null, arith(t, im, den, .div) orelse return null);
        },
    }
}

pub fn toFloat(w: Word) f64 {
    if (rt.isFlonum(w)) return rt.flo(w);
    if (isRat(w)) return ratToFloat(w);
    return intToFloat(w);
}

/// Order of two reals; null if one is not a real (or is NaN)
pub fn order(t: *Thread, a: Word, b: Word) ?std.math.Order {
    if (!isReal(a) or !isReal(b)) return null;
    if (rt.isFlonum(a) or rt.isFlonum(b)) {
        const x = toFloat(a);
        const y = toFloat(b);
        if (std.math.isNan(x) or std.math.isNan(y)) return null;
        // compare exactly when the flonum is finite and the other exact
        if (rt.isFlonum(a) and !rt.isFlonum(b) and std.math.isFinite(x)) return order(t, floatToExact(t, x).?, b);
        if (rt.isFlonum(b) and !rt.isFlonum(a) and std.math.isFinite(y)) return order(t, a, floatToExact(t, y).?);
        return std.math.order(x, y);
    }
    if (isExactInteger(a) and isExactInteger(b)) return intOrder(a, b);
    return ratOrder(a, b, t);
}

/// = for any numbers (false for NaN)
pub fn numEq(t: *Thread, a: Word, b: Word) ?bool {
    if (!isNumber(a) or !isNumber(b)) return null;
    if (isComp(a) or isComp(b)) {
        const r = order(t, realPart(a), realPart(b)) orelse return false;
        const i = order(t, imagPart(a), imagPart(b)) orelse return false;
        return r == .eq and i == .eq;
    }
    const o = order(t, a, b) orelse return false;
    return o == .eq;
}

pub fn sign(w: Word) i2 {
    if (rt.isFlonum(w)) {
        const f = rt.flo(w);
        return if (f < 0) -1 else if (f > 0) 1 else 0;
    }
    return intSign(ratNum(w));
}

pub fn negate(t: *Thread, w: Word) Word {
    return arith(t, fix(0), w, .sub).?;
}

pub fn numerator(t: *Thread, w: Word) Word {
    if (rt.isFlonum(w)) return floWord(t, toFloat(numerator(t, floatToExact(t, rt.flo(w)) orelse return w)));
    return ratNum(w);
}
pub fn denominator(t: *Thread, w: Word) Word {
    if (rt.isFlonum(w)) return floWord(t, toFloat(denominator(t, floatToExact(t, rt.flo(w)) orelse return w)));
    return ratDen(w);
}

/// floor, ceiling, truncate, round of an exact rational
pub fn ratRound(t: *Thread, w: Word, comptime mode: enum { floor, ceiling, truncate, round }) Word {
    if (!isRat(w)) return w;
    const n = ratNum(w);
    const d = ratDen(w);
    const fl = intDiv(t, n, d, .floor)[0];
    return switch (mode) {
        .floor => fl,
        .ceiling => intOp(t, fl, fix(1), .add),
        .truncate => intDiv(t, n, d, .trunc)[0],
        .round => blk: {
            // fraction part = w - fl, compare with 1/2
            const frac = arith(t, w, fl, .sub).?;
            const o = order(t, frac, makeRational(t, fix(1), fix(2))).?;
            if (o == .lt) break :blk fl;
            if (o == .gt) break :blk intOp(t, fl, fix(1), .add);
            break :blk if (intDiv(t, fl, fix(2), .floor)[1] == fix(0)) fl else intOp(t, fl, fix(1), .add);
        },
    };
}

/// Exact b^e (e an exact integer); null if not exact-representable here
pub fn exactExpt(t: *Thread, b: Word, e: Word) ?Word {
    if (!isExactRational(b) or !isFix(e)) return null;
    const k = unfix(e);
    if (k < 0) {
        const p = exactExpt(t, b, fix(-k)) orelse return null;
        return arith(t, fix(1), p, .div);
    }
    if (k > std.math.maxInt(u32)) return null;
    if (isRat(b)) {
        return makeRational(t, exactExpt(t, ratNum(b), e).?, exactExpt(t, ratDen(b), e).?);
    }
    var x = toManaged(b);
    defer x.deinit();
    var r = Managed.init(pa) catch oom();
    r.pow(&x, @intCast(k)) catch oom();
    return fromManaged(t, &r);
}

/// Exact integer square root: s with s^2 <= n < (s+1)^2
pub fn exactIntegerSqrt(t: *Thread, n: Word) [2]Word {
    var x = toManaged(n);
    defer x.deinit();
    var s = Managed.init(pa) catch oom();
    s.sqrt(&x) catch oom();
    const sw = fromConst(t, s.toConst());
    s.deinit();
    return .{ sw, intOp(t, n, intOp(t, sw, sw, .mul), .sub) };
}

// --- syntax ----------------------------------------------------------------------------

pub fn format(buf: *std.ArrayList(u8), w: Word, radix: u8) void {
    const fmtFlo = @import("num.zig").formatFlonum;
    if (isFix(w) or isBig(w)) {
        var m = toManaged(w);
        defer m.deinit();
        const str = m.toString(pa, radix, .lower) catch oom();
        defer pa.free(str);
        buf.appendSlice(pa, str) catch oom();
    } else if (isRat(w)) {
        format(buf, ratNum(w), radix);
        buf.append(pa, '/') catch oom();
        format(buf, ratDen(w), radix);
    } else if (rt.isFlonum(w)) {
        fmtFlo(buf, rt.flo(w));
    } else if (isComp(w)) {
        const re = realPart(w);
        const im = imagPart(w);
        // both parts, always (as the JVM implementation: 0+1i)
        format(buf, re, radix);
        const im_neg = sign(im) < 0 or (rt.isFlonum(im) and std.math.signbit(rt.flo(im)));
        const im_special = rt.isFlonum(im) and !std.math.isFinite(rt.flo(im));
        if (!im_neg and !im_special) buf.append(pa, '+') catch oom();
        format(buf, im, radix);
        buf.append(pa, 'i') catch oom();
    }
}

/// Exact integers and rationals from their syntax (num.Lit.exact)
pub fn fromText(t: *Thread, text: []const u8, radix: u8) ?Word {
    if (std.mem.indexOfScalar(u8, text, '/')) |slash| {
        const n = fromText(t, text[0..slash], radix) orelse return null;
        const d = fromText(t, text[slash + 1 ..], radix) orelse return null;
        if (intSign(d) == 0) return null;
        return makeRational(t, n, d);
    }
    if (std.mem.indexOfAny(u8, text, ".eE") != null and radix == 10) {
        // #e with a decimal: digits * 10^exp exactly
        return exactDecimal(t, text);
    }
    var m = Managed.init(pa) catch oom();
    const body = if (text.len > 0 and text[0] == '+') text[1..] else text;
    m.setString(radix, body) catch {
        m.deinit();
        return null;
    };
    return fromManaged(t, &m);
}

fn exactDecimal(t: *Thread, text: []const u8) ?Word {
    var digits: std.ArrayList(u8) = .empty;
    defer digits.deinit(pa);
    var scale: i64 = 0;
    var exp: i64 = 0;
    var seen_dot = false;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        switch (c) {
            '+' => {},
            '-' => digits.append(pa, '-') catch oom(),
            '.' => seen_dot = true,
            '0'...'9' => {
                digits.append(pa, c) catch oom();
                if (seen_dot) scale += 1;
            },
            'e', 'E' => {
                exp = std.fmt.parseInt(i64, text[i + 1 ..], 10) catch return null;
                break;
            },
            else => return null,
        }
    }
    const n = fromText(t, digits.items, 10) orelse return null;
    const p = exp - scale;
    const ten_p = exactExpt(t, fix(10), fix(@intCast(@abs(p)))).?;
    return if (p >= 0) intOp(t, n, ten_p, .mul) else makeRational(t, n, ten_p);
}

// --- bit operations (SRFI 151, two's complement semantics) ----------------------------

pub const BitOp = enum { @"and", ior, xor };

pub fn bitOp(t: *Thread, a: Word, b: Word, comptime op: BitOp) Word {
    if (isFix(a) and isFix(b)) return switch (op) {
        .@"and" => a & b, // tags: xxx0 & xxx0, the payloads combine directly
        .ior => a | b,
        .xor => a ^ b,
    };
    var x = toManaged(a);
    defer x.deinit();
    var y = toManaged(b);
    defer y.deinit();
    var r = Managed.init(pa) catch oom();
    switch (op) {
        .@"and" => r.bitAnd(&x, &y) catch oom(),
        .ior => r.bitOr(&x, &y) catch oom(),
        .xor => r.bitXor(&x, &y) catch oom(),
    }
    return fromManaged(t, &r);
}

/// ~a = -a - 1
pub fn bitNot(t: *Thread, a: Word) Word {
    if (isFix(a)) return fix(~unfix(a));
    var x = toManaged(a);
    defer x.deinit();
    var one = Managed.initSet(pa, 1) catch oom();
    defer one.deinit();
    x.negate();
    var r = Managed.init(pa) catch oom();
    r.sub(&x, &one) catch oom();
    return fromManaged(t, &r);
}

pub fn arithmeticShift(t: *Thread, a: Word, count: i64) Word {
    if (count == 0) return a;
    if (isFix(a) and count < 0) {
        const v = unfix(a);
        return fix(if (count <= -63) (if (v >= 0) 0 else -1) else v >> @intCast(-count));
    }
    if (isFix(a) and count < 62) {
        const v = unfix(a);
        const shifted = std.math.shlExact(i64, v, @intCast(count)) catch null;
        if (shifted) |s| if (rt.fixFits(s)) return fix(s);
    }
    var x = toManaged(a);
    defer x.deinit();
    var r = Managed.init(pa) catch oom();
    if (count > 0) {
        r.shiftLeft(&x, @intCast(count)) catch oom();
    } else {
        // floor semantics for negative numbers: -((-x - 1) >> n) - 1
        if (!x.isPositive() and !x.eqlZero()) {
            var one = Managed.initSet(pa, 1) catch oom();
            defer one.deinit();
            x.negate();
            var m = Managed.init(pa) catch oom();
            defer m.deinit();
            m.sub(&x, &one) catch oom();
            r.shiftRight(&m, @intCast(-count)) catch oom();
            r.negate();
            var r2 = Managed.init(pa) catch oom();
            r2.sub(&r, &one) catch oom();
            r.deinit();
            return fromManaged(t, &r2);
        }
        r.shiftRight(&x, @intCast(-count)) catch oom();
    }
    return fromManaged(t, &r);
}

/// The limbs of |a| for a >= 0, or of ~a = -a - 1 for a < 0 (the caller deinits)
fn nonNegative(a: Word) Managed {
    var x = toManaged(a);
    if (!x.isPositive() and !x.eqlZero()) {
        var one = Managed.initSet(pa, 1) catch oom();
        defer one.deinit();
        x.negate();
        x.sub(&x, &one) catch oom();
    }
    return x;
}

pub fn bitCount(a: Word) i64 {
    if (isFix(a)) {
        const v = unfix(a);
        return @popCount(if (v < 0) ~v else v);
    }
    var x = nonNegative(a);
    defer x.deinit();
    var n: i64 = 0;
    for (x.limbs[0..x.len()]) |l| n += @popCount(l);
    return n;
}

pub fn integerLength(a: Word) i64 {
    if (isFix(a)) {
        const v = unfix(a);
        const u: u64 = @bitCast(if (v < 0) ~v else v);
        return 64 - @as(i64, @clz(u));
    }
    var x = nonNegative(a);
    defer x.deinit();
    return @intCast(x.bitCountAbs());
}

// --- exact of a flonum: the simplest rational that reads back as it ------------------

/// x (finite, >= 0) as num / den (as the JVM implementation's exactParts)
fn exactParts(x: f64) [2]Managed {
    const bits: u64 = @bitCast(x);
    var biased: i64 = @intCast((bits >> 52) & 0x7FF);
    var mantissa: u64 = bits & 0xFFFFFFFFFFFFF;
    if (biased != 0) mantissa |= @as(u64, 1) << 52 else biased = 1;
    const exp = biased - 1023 - 52;
    var num = Managed.initSet(pa, mantissa) catch oom();
    var den = Managed.initSet(pa, 1) catch oom();
    if (exp >= 0) num.shiftLeft(&num, @intCast(exp)) catch oom() else den.shiftLeft(&den, @intCast(-exp)) catch oom();
    return .{ num, den };
}

fn bigInt(v: i64) Managed {
    return Managed.initSet(pa, v) catch oom();
}

/// The simplest rational (smallest denominator) in the rounding interval of
/// f (halfway to the neighbouring doubles, both ends included on a
/// tie-to-even): (exact 0.1) is 1/10, as in the JVM implementation
pub fn floatToSimplest(t: *Thread, f: f64) ?Word {
    if (!std.math.isFinite(f)) return null;
    if (@floor(f) == f) return floatToExact(t, f);
    const negative = f < 0;
    const x = @abs(f);
    var v = exactParts(x);
    var prev = exactParts(std.math.nextAfter(f64, x, 0));
    var next = exactParts(std.math.nextAfter(f64, x, std.math.inf(f64)));
    defer for ([_]*[2]Managed{ &v, &prev, &next }) |p| {
        p[0].deinit();
        p[1].deinit();
    };
    var tmp = bigInt(0);
    defer tmp.deinit();
    // lo = (v + prev) / 2, hi = (v + next) / 2
    var loN = bigInt(0);
    var loD = bigInt(0);
    var hiN = bigInt(0);
    var hiD = bigInt(0);
    defer for ([_]*Managed{ &loN, &loD, &hiN, &hiD }) |p| p.deinit();
    loN.mul(&v[0], &prev[1]) catch oom();
    tmp.mul(&prev[0], &v[1]) catch oom();
    loN.add(&loN, &tmp) catch oom();
    loD.mul(&v[1], &prev[1]) catch oom();
    loD.shiftLeft(&loD, 1) catch oom();
    hiN.mul(&v[0], &next[1]) catch oom();
    tmp.mul(&next[0], &v[1]) catch oom();
    hiN.add(&hiN, &tmp) catch oom();
    hiD.mul(&v[1], &next[1]) catch oom();
    hiD.shiftLeft(&hiD, 1) catch oom();
    const bits: u64 = @bitCast(x);
    const closed = bits & 1 == 0;

    var terms: std.ArrayList(Managed) = .empty;
    defer {
        for (terms.items) |*m| m.deinit();
        terms.deinit(pa);
    }
    var fl = bigInt(0);
    defer fl.deinit();
    var rem = bigInt(0);
    defer rem.deinit();
    var c = bigInt(0);
    defer c.deinit();
    var one = bigInt(1);
    defer one.deinit();
    while (true) {
        fl.divFloor(&rem, &loN, &loD) catch oom();
        if (closed and rem.eqlZero()) c.copy(fl.toConst()) catch oom() else c.add(&fl, &one) catch oom();
        const cmp: std.math.Order = if (hiD.eqlZero()) .lt else blk: {
            tmp.mul(&c, &hiD) catch oom();
            break :blk tmp.order(hiN);
        };
        if (cmp == .lt or (closed and cmp == .eq)) {
            terms.append(pa, c.clone() catch oom()) catch oom();
            break;
        }
        terms.append(pa, fl.clone() catch oom()) catch oom();
        // lo' = 1 / (hi - fl), hi' = 1 / (lo - fl)
        var nLoD = bigInt(0);
        tmp.mul(&fl, &hiD) catch oom();
        nLoD.sub(&hiN, &tmp) catch oom();
        var nHiD = bigInt(0);
        tmp.mul(&fl, &loD) catch oom();
        nHiD.sub(&loN, &tmp) catch oom();
        hiN.swap(&loD); // hi' numerator = old loD
        loN.swap(&hiD); // lo' numerator = old hiD
        loD.swap(&nLoD);
        hiD.swap(&nHiD);
        nLoD.deinit();
        nHiD.deinit();
    }
    var p = terms.items[terms.items.len - 1].clone() catch oom();
    var q = bigInt(1);
    var i = terms.items.len - 1;
    while (i > 0) {
        i -= 1;
        var np = bigInt(0);
        np.mul(&terms.items[i], &p) catch oom();
        np.add(&np, &q) catch oom();
        q.deinit();
        q = p;
        p = np;
    }
    if (negative) p.negate();
    return makeRational(t, fromManaged(t, &p), fromManaged(t, &q));
}
