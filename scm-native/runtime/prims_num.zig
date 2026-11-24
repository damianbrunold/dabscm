//! Primitives: numbers (the whole tower).
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const tower = @import("tower.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Code = rt.Code;
const Err = P.Err;
const W = P.W;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const any = P.any;
const fix = rt.fix;
const unfix = rt.unfix;
const isFix = rt.isFix;

const pa = std.heap.c_allocator;

fn numArg(t: *Thread, comptime who: []const u8, i: usize) Err!Word {
    const w = arg(t, i);
    if (!num.isNumber(w)) return raise(t, "Failed in " ++ who ++ ": wrong argument type", &.{w});
    return w;
}
fn realArg(t: *Thread, comptime who: []const u8, i: usize) Err!Word {
    const w = arg(t, i);
    if (!tower.isReal(w)) return raise(t, "Failed in " ++ who ++ ": wrong argument type", &.{w});
    return w;
}
fn integerArg(t: *Thread, comptime who: []const u8, i: usize) Err!Word {
    const w = arg(t, i);
    if (!num.isInteger(w)) return raise(t, "Failed in " ++ who ++ ": wrong argument type", &.{w});
    return w;
}

/// flonum results come from the flonum area (no reservation): so these
/// primitives never collect and can be called directly (WD)
inline fn flo(t: *Thread, f: f64) Word {
    return rt.safeFlo(t, f);
}

// --- arithmetic --------------------------------------------------------------

fn fold(t: *Thread, comptime op: tower.Op, comptime who: []const u8) Err!Word {
    if (t.argc == 0) return if (op == .mul) fix(1) else fix(0);
    var acc = try numArg(t, who, 0);
    if (t.argc == 1) switch (op) {
        .sub => return tower.negate(t, acc),
        .div => return divide(t, fix(1), acc),
        else => return acc,
    };
    for (1..t.argc) |i| {
        const b = try numArg(t, who, i);
        acc = switch (op) {
            .add => num.add(t, acc, b).?,
            .sub => num.sub(t, acc, b).?,
            .mul => num.mul(t, acc, b).?,
            .div => try divide(t, acc, b),
        };
    }
    return acc;
}

fn divide(t: *Thread, a: Word, b: Word) Err!Word {
    if (b == fix(0)) return raise(t, if (rt.isFlonum(a)) "/: Division by 0.0" else "/: division by zero", &.{});
    return num.div(t, a, b) orelse raise(t, "/: division by zero", &.{});
}

fn addImpl(t: *Thread) Err!Word {
    return fold(t, .add, "+");
}
fn subImpl(t: *Thread) Err!Word {
    return fold(t, .sub, "-");
}
fn mulImpl(t: *Thread) Err!Word {
    return fold(t, .mul, "*");
}
fn divImpl(t: *Thread) Err!Word {
    return fold(t, .div, "/");
}
pub const @"%+" = WD("+", addImpl, 0, any);
pub const @"%-" = WD("-", subImpl, 1, any);
pub const @"%*" = WD("*", mulImpl, 0, any);
pub const @"%/" = WD("/", divImpl, 1, any);

fn compareChain(t: *Thread, comptime c: num.Cmp, comptime who: []const u8) Err!Word {
    for (0..t.argc) |i| _ = if (c == .eq) try numArg(t, who, i) else try realArg(t, who, i);
    var result = true;
    for (1..t.argc) |i| {
        if (!(num.cmp(arg(t, i - 1), arg(t, i), c) orelse false)) result = false;
    }
    return rt.boolean(result);
}
fn ltImpl(t: *Thread) Err!Word {
    return compareChain(t, .lt, "<");
}
fn gtImpl(t: *Thread) Err!Word {
    return compareChain(t, .gt, ">");
}
fn leImpl(t: *Thread) Err!Word {
    return compareChain(t, .le, "<=");
}
fn geImpl(t: *Thread) Err!Word {
    return compareChain(t, .ge, ">=");
}
fn eqImpl(t: *Thread) Err!Word {
    return compareChain(t, .eq, "=");
}
pub const @"%<" = WD("<", ltImpl, 1, any);
pub const @"%>" = WD(">", gtImpl, 1, any);
pub const @"%<=" = WD("<=", leImpl, 1, any);
pub const @"%>=" = WD(">=", geImpl, 1, any);
pub const @"%=" = WD("=", eqImpl, 1, any);

// --- integer division ----------------------------------------------------------

fn intDivision(t: *Thread, comptime who: []const u8, comptime kind: tower.DivKind, comptime which: usize) Err!Word {
    const a = try integerArg(t, who, 0);
    const b = try integerArg(t, who, 1);
    if (num.toF(b).? == 0) return raise(t, who ++ ": division by zero", &.{});
    if (rt.isFlonum(a) or rt.isFlonum(b)) {
        const x = num.toF(a).?;
        const y = num.toF(b).?;
        if (which == 0) return flo(t, switch (kind) {
            .trunc => @trunc(x / y),
            .floor => @floor(x / y),
        });
        // the remainder exactly (fmod), not x - q * y
        var r = @rem(x, y);
        if (kind == .floor and r != 0 and (r < 0) != (y < 0)) r += y;
        return flo(t, r);
    }
    return tower.intDiv(t, a, b, kind)[which];
}
fn quotientImpl(t: *Thread) Err!Word {
    return intDivision(t, "quotient", .trunc, 0);
}
fn remainderImpl(t: *Thread) Err!Word {
    return intDivision(t, "remainder", .trunc, 1);
}
fn moduloImpl(t: *Thread) Err!Word {
    return intDivision(t, "modulo", .floor, 1);
}
pub const @"%quotient" = WD("quotient", quotientImpl, 2, 2);
pub const @"%remainder" = WD("remainder", remainderImpl, 2, 2);
pub const @"%modulo" = WD("modulo", moduloImpl, 2, 2);

// --- predicates --------------------------------------------------------------

fn numberP(t: *Thread) Err!Word {
    return rt.boolean(num.isNumber(arg(t, 0)));
}
fn realP(t: *Thread) Err!Word {
    return rt.boolean(tower.isReal(arg(t, 0)));
}
fn rationalP(t: *Thread) Err!Word {
    const w = arg(t, 0);
    return rt.boolean(tower.isExactRational(w) or (rt.isFlonum(w) and std.math.isFinite(rt.flo(w))));
}
fn integerP(t: *Thread) Err!Word {
    return rt.boolean(num.isInteger(arg(t, 0)));
}
fn exactIntegerP(t: *Thread) Err!Word {
    return rt.boolean(tower.isExactInteger(arg(t, 0)));
}
/// as the JVM implementation: #f for a non-number (and inexact? is its
/// negation)
fn exactP(t: *Thread) Err!Word {
    const w = arg(t, 0);
    return rt.boolean(num.isNumber(w) and tower.isExact(w));
}
fn inexactP(t: *Thread) Err!Word {
    const w = arg(t, 0);
    return rt.boolean(!(num.isNumber(w) and tower.isExact(w)));
}
fn zeroP(t: *Thread) Err!Word {
    return rt.boolean(tower.numEq(t, try numArg(t, "zero?", 0), fix(0)).?);
}
pub const @"%number?" = WD("number?", numberP, 1, 1);
pub const @"%complex?" = WD("complex?", numberP, 1, 1);
pub const @"%real?" = WD("real?", realP, 1, 1);
pub const @"%rational?" = WD("rational?", rationalP, 1, 1);
pub const @"%integer?" = WD("integer?", integerP, 1, 1);
pub const @"%exact-integer?" = WD("exact-integer?", exactIntegerP, 1, 1);
pub const @"%exact?" = WD("exact?", exactP, 1, 1);
pub const @"%inexact?" = WD("inexact?", inexactP, 1, 1);
pub const @"%zero?" = WD("zero?", zeroP, 1, 1);

// --- exactness ---------------------------------------------------------------

fn inexactImpl(t: *Thread) Err!Word {
    const w = try numArg(t, "inexact", 0);
    if (rt.isFlonum(w)) return w;
    if (tower.isComp(w)) {
        const re = tower.realPart(w);
        const im = tower.imagPart(w);
        return tower.makeRect(t, tower.arith(t, re, flo(t, 0), .add).?, tower.arith(t, im, flo(t, 0), .add).?);
    }
    return flo(t, num.toF(w).?);
}
fn exactImpl(t: *Thread) Err!Word {
    const w = try numArg(t, "exact", 0);
    if (rt.isFlonum(w)) return tower.floatToExact(t, rt.flo(w)) orelse raise(t, "exact: no exact representation for ~a", &.{w});
    if (tower.isComp(w)) {
        const re = tower.realPart(w);
        const im = tower.imagPart(w);
        const ere = if (rt.isFlonum(re)) tower.floatToExact(t, rt.flo(re)) orelse return raise(t, "exact: no exact representation for ~a", &.{w}) else re;
        const eim = if (rt.isFlonum(im)) tower.floatToExact(t, rt.flo(im)) orelse return raise(t, "exact: no exact representation for ~a", &.{w}) else im;
        return tower.makeRect(t, ere, eim);
    }
    return w;
}
pub const @"%inexact" = WD("inexact", inexactImpl, 1, 1);
pub const @"%exact->inexact" = WD("exact->inexact", inexactImpl, 1, 1);
pub const @"%exact" = WD("exact", exactImpl, 1, 1);
pub const @"%inexact->exact" = WD("inexact->exact", exactImpl, 1, 1);

// --- rounding ----------------------------------------------------------------

fn roundTo(t: *Thread, comptime who: []const u8, comptime mode: @TypeOf(.floor)) Err!Word {
    const w = try realArg(t, who, 0);
    if (rt.isFlonum(w)) {
        const f = rt.flo(w);
        return flo(t, switch (mode) {
            .floor => @floor(f),
            .ceiling => @ceil(f),
            .truncate => @trunc(f),
            .round => blk: {
                const r = @round(f);
                break :blk if (@abs(f - @trunc(f)) == 0.5) 2.0 * @round(f / 2.0) else r;
            },
            else => unreachable,
        });
    }
    return tower.ratRound(t, w, mode);
}
fn floorImpl(t: *Thread) Err!Word {
    return roundTo(t, "floor", .floor);
}
fn ceilingImpl(t: *Thread) Err!Word {
    return roundTo(t, "ceiling", .ceiling);
}
fn truncateImpl(t: *Thread) Err!Word {
    return roundTo(t, "truncate", .truncate);
}
fn roundImpl(t: *Thread) Err!Word {
    return roundTo(t, "round", .round);
}
pub const @"%floor" = WD("floor", floorImpl, 1, 1);
pub const @"%ceiling" = WD("ceiling", ceilingImpl, 1, 1);
pub const @"%truncate" = WD("truncate", truncateImpl, 1, 1);
pub const @"%round" = WD("round", roundImpl, 1, 1);

fn absImpl(t: *Thread) Err!Word {
    const w = try realArg(t, "abs", 0);
    return if (tower.sign(w) < 0 or (rt.isFlonum(w) and std.math.signbit(rt.flo(w)))) num.sub(t, fix(0), w).? else w;
}
pub const @"%abs" = WD("abs", absImpl, 1, 1);

fn minMax(t: *Thread, comptime is_max: bool) Err!Word {
    var acc = try realArg(t, if (is_max) "max" else "min", 0);
    var inexact = rt.isFlonum(acc);
    for (1..t.argc) |i| {
        const b = try realArg(t, if (is_max) "max" else "min", i);
        if (rt.isFlonum(b)) inexact = true;
        if (num.cmp(b, acc, if (is_max) .gt else .lt) orelse false) acc = b;
    }
    if (inexact and !rt.isFlonum(acc)) return flo(t, num.toF(acc).?);
    return acc;
}
fn minImpl(t: *Thread) Err!Word {
    return minMax(t, false);
}
fn maxImpl(t: *Thread) Err!Word {
    return minMax(t, true);
}
pub const @"%min" = WD("min", minImpl, 1, any);
pub const @"%max" = WD("max", maxImpl, 1, any);

fn numeratorImpl(t: *Thread) Err!Word {
    return tower.numerator(t, try realArg(t, "numerator", 0));
}
fn denominatorImpl(t: *Thread) Err!Word {
    return tower.denominator(t, try realArg(t, "denominator", 0));
}
pub const @"%numerator" = WD("numerator", numeratorImpl, 1, 1);
pub const @"%denominator" = WD("denominator", denominatorImpl, 1, 1);
pub const @"%rational-numerator" = WD("rational-numerator", numeratorImpl, 1, 1);
pub const @"%rational-denominator" = WD("rational-denominator", denominatorImpl, 1, 1);

fn gcdImpl(t: *Thread) Err!Word {
    var g = fix(0);
    for (0..t.argc) |i| {
        const w = try integerArg(t, "gcd", i);
        if (!tower.isExactInteger(w)) return raise(t, "gcd: not an exact integer", &.{w});
        g = tower.intGcd(t, g, w);
    }
    return g;
}
pub const @"%%gcd" = WD("%gcd", gcdImpl, 0, any);

// --- powers and roots ----------------------------------------------------------

fn sqrtImpl(t: *Thread) Err!Word {
    const w = try numArg(t, "sqrt", 0);
    if (tower.isComp(w)) {
        // the principal root, as the JVM implementation
        const a = num.toF(tower.realPart(w)).?;
        const b = num.toF(tower.imagPart(w)).?;
        const mag = @sqrt(a * a + b * b);
        const re = @sqrt((mag + a) / 2.0);
        const im = (if (b >= 0) @as(f64, 1) else -1) * @sqrt((mag - a) / 2.0);
        return tower.makeRect(t, flo(t, re), flo(t, im));
    }
    // as the JVM implementation: an exact result only for an exact integer
    // that is a square (of at most 63 bits), else a flonum or a complex
    // number with flonum parts
    if (tower.isExactInteger(w) and tower.sign(w) >= 0) {
        const r = tower.exactIntegerSqrt(t, w);
        if (r[1] == fix(0) and num.toF(r[0]).? < 9.2e18) return r[0];
    }
    const f = num.toF(w).?;
    if (f < 0) return tower.makeRect(t, flo(t, 0), flo(t, @sqrt(-f)));
    return flo(t, @sqrt(f));
}
pub const @"%sqrt" = WD("sqrt", sqrtImpl, 1, 1);

fn exactIntegerSqrtImpl(t: *Thread) Err!Word {
    const n = arg(t, 0);
    if (!tower.isExactInteger(n) or tower.sign(n) < 0) return raise(t, "exact-integer-sqrt: not a non-negative exact integer", &.{n});
    const r = tower.exactIntegerSqrt(t, n);
    t.ensureArgs(2);
    t.args[0] = r[0];
    t.args[1] = r[1];
    t.argc = 2;
    t.reserve(3);
    return rt.valuesOf(t);
}
pub const @"%exact-integer-sqrt" = WN("exact-integer-sqrt", exactIntegerSqrtImpl, 1, 1);

fn exptImpl(t: *Thread) Err!Word {
    const b = try numArg(t, "expt", 0);
    const e = try numArg(t, "expt", 1);
    if (tower.isExact(b) and tower.isExactInteger(e) and !tower.isComp(b)) {
        if (b == fix(0) and tower.sign(e) < 0) return raise(t, "expt: division by zero", &.{});
        if (tower.exactExpt(t, b, e)) |r| return r;
    }
    if (tower.isComp(b) or tower.isComp(e)) return raise(t, "expt: complex arguments not supported", &.{ b, e });
    if (e == fix(0)) return if (rt.isFlonum(b)) flo(t, 1) else fix(1);
    return flo(t, std.math.pow(f64, num.toF(b).?, num.toF(e).?));
}
pub const @"%expt" = WD("expt", exptImpl, 2, 2);

// --- complex numbers -------------------------------------------------------------

fn makeRectangular(t: *Thread) Err!Word {
    return tower.makeRect(t, try realArg(t, "make-rectangular", 0), try realArg(t, "make-rectangular", 1));
}
fn makePolar(t: *Thread) Err!Word {
    const m = num.toF(try realArg(t, "make-polar", 0)).?;
    const a = num.toF(try realArg(t, "make-polar", 1)).?;
    // always an inexact complex number, as the JVM implementation's
    // ((make-polar 1 0) is 1.0+0.0i)
    return tower.makeRect(t, flo(t, m * @cos(a)), flo(t, m * @sin(a)));
}
fn realPart(t: *Thread) Err!Word {
    return tower.realPart(try numArg(t, "real-part", 0));
}
fn imagPart(t: *Thread) Err!Word {
    return tower.imagPart(try numArg(t, "imag-part", 0));
}
fn magnitude(t: *Thread) Err!Word {
    const w = try numArg(t, "magnitude", 0);
    if (!tower.isComp(w)) return if (tower.sign(w) < 0) num.sub(t, fix(0), w).? else w;
    const re = num.toF(tower.realPart(w)).?;
    const im = num.toF(tower.imagPart(w)).?;
    return flo(t, std.math.hypot(re, im));
}
fn angle(t: *Thread) Err!Word {
    const w = try numArg(t, "angle", 0);
    const re = num.toF(tower.realPart(w)).?;
    const im = num.toF(tower.imagPart(w)).?;
    if (!tower.isComp(w) and tower.sign(w) >= 0 and !rt.isFlonum(w)) return fix(0);
    return flo(t, std.math.atan2(im, re));
}
pub const @"%make-rectangular" = WD("make-rectangular", makeRectangular, 2, 2);
pub const @"%make-polar" = WD("make-polar", makePolar, 2, 2);
pub const @"%complex-real-part" = WD("complex-real-part", realPart, 1, 1);
pub const @"%complex-imag-part" = WD("complex-imag-part", imagPart, 1, 1);
pub const @"%complex-magnitude" = WD("complex-magnitude", magnitude, 1, 1);
pub const @"%complex-angle" = WD("complex-angle", angle, 1, 1);
pub const @"%real-part" = WD("real-part", realPart, 1, 1);
pub const @"%imag-part" = WD("imag-part", imagPart, 1, 1);
pub const @"%magnitude" = WD("magnitude", magnitude, 1, 1);
pub const @"%angle" = WD("angle", angle, 1, 1);

// --- syntax ------------------------------------------------------------------

fn numberToString(t: *Thread) Err!Word {
    const w = try numArg(t, "number->string", 0);
    var radix: u8 = 10;
    if (t.argc > 1) {
        const r = arg(t, 1);
        if (!isFix(r) or (unfix(r) != 2 and unfix(r) != 8 and unfix(r) != 10 and unfix(r) != 16))
            return raise(t, "number->string: bad radix", &.{r});
        radix = @intCast(unfix(r));
    }
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    tower.format(&buf, w, radix);
    t.reserve(data.stringWords(buf.items.len, false));
    const s = data.makeString(t, buf.items.len, false);
    @memcpy(data.bytes8(s)[0..buf.items.len], buf.items);
    return s;
}
pub const @"%number->string" = WN("number->string", numberToString, 1, 2);

// --- bit operations ------------------------------------------------------------------

fn intArgOf(t: *Thread, w: Word) Err!Word {
    if (!tower.isExactInteger(w)) return P.argTypeError(t);
    return w;
}

fn bitFold(t: *Thread, comptime op: tower.BitOp) Err!Word {
    for (0..t.argc) |i| _ = try intArgOf(t, arg(t, i));
    var r: Word = fix(switch (op) {
        .@"and" => -1,
        else => 0,
    });
    for (0..t.argc) |i| {
        // a bignum result: reserve nothing, bignums live in the large-object space
        r = tower.bitOp(t, r, arg(t, i), op);
    }
    return r;
}
fn bitwiseAnd(t: *Thread) Err!Word {
    return bitFold(t, .@"and");
}
fn bitwiseIor(t: *Thread) Err!Word {
    return bitFold(t, .ior);
}
fn bitwiseXor(t: *Thread) Err!Word {
    return bitFold(t, .xor);
}
pub const @"%bitwise-and" = WD("bitwise-and", bitwiseAnd, 0, std.math.maxInt(u64));
pub const @"%bitwise-ior" = WD("bitwise-ior", bitwiseIor, 0, std.math.maxInt(u64));
pub const @"%bitwise-xor" = WD("bitwise-xor", bitwiseXor, 0, std.math.maxInt(u64));

fn bitwiseNot(t: *Thread) Err!Word {
    return tower.bitNot(t, try intArgOf(t, arg(t, 0)));
}
pub const @"%bitwise-not" = WD("bitwise-not", bitwiseNot, 1, 1);

fn arithmeticShiftImpl(t: *Thread) Err!Word {
    const a = try intArgOf(t, arg(t, 0));
    const c = arg(t, 1);
    if (!rt.isFix(c)) return raise(t, "value out of range: ~s", &.{c});
    const n = unfix(c);
    if (n > std.math.maxInt(i32)) return raise(t, "arithmetic-shift: shift count too large", &.{});
    return tower.arithmeticShift(t, a, n);
}
pub const @"%arithmetic-shift" = WD("arithmetic-shift", arithmeticShiftImpl, 2, 2);

fn bitCountImpl(t: *Thread) Err!Word {
    return fix(tower.bitCount(try intArgOf(t, arg(t, 0))));
}
fn integerLengthImpl(t: *Thread) Err!Word {
    return fix(tower.integerLength(try intArgOf(t, arg(t, 0))));
}
pub const @"%bit-count" = WD("bit-count", bitCountImpl, 1, 1);
pub const @"%integer-length" = WD("integer-length", integerLengthImpl, 1, 1);
