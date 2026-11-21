//! Primitive procedures, in the standard calling convention. Each `pub const`
//! named like the Scheme procedure is its code; the compiler refers to them as
//! rt.prims.@"%name" (scm-native/compiler/scm-native-primitives.sld lists them).
//!
//! A primitive that allocates calls t.reserve first and reads its arguments
//! from t.args after that (a collection moves objects).
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const printer = @import("printer.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Code = rt.Code;
const fix = rt.fix;
const unfix = rt.unfix;

pub const Err = error{Scheme};
const any = std.math.maxInt(u64);

/// Record an error for the primitive's caller.
fn raise(t: *Thread, msg: []const u8, irritants: []const Word) Err {
    _ = rt.fail(t, msg, irritants);
    return error.Scheme;
}

/// Standard-convention code for f, with an arity check.
fn W(comptime f: fn (*Thread) Err!Word, comptime min: u64, comptime max: u64) Code {
    const S = struct {
        fn code(t: *Thread) callconv(.c) void {
            if (t.argc < min or t.argc > max) return @call(.always_tail, rt.arityError(t), .{t});
            t.val = f(t) catch return @call(.always_tail, rt.errorCode, .{t});
            return @call(.always_tail, rt.retCode(t), .{t});
        }
    };
    return &S.code;
}

inline fn arg(t: *Thread, i: usize) Word {
    return t.args[i];
}

fn checkPair(t: *Thread, who: []const u8, w: Word) Err!Word {
    if (!rt.isPair(w)) return raise(t, who, &.{w});
    return w;
}

fn index(t: *Thread, w: Word, len: usize) Err!usize {
    if (!rt.isFix(w) or unfix(w) < 0 or unfix(w) >= len) return raise(t, "index out of range", &.{w});
    return @intCast(unfix(w));
}

fn count(t: *Thread, w: Word) Err!usize {
    if (!rt.isFix(w) or unfix(w) < 0) return raise(t, "not a valid length", &.{w});
    return @intCast(unfix(w));
}

fn listLength(l: Word) ?usize {
    var n: usize = 0;
    var x = l;
    while (rt.isPair(x)) : (x = rt.cdr(x)) n += 1;
    return if (x == rt.NIL) n else null;
}

// --- control ---------------------------------------------------------------

pub const @"%call-with-current-continuation" = &rt.callccCode;
pub const @"%call/cc" = &rt.callccCode;
pub const @"%apply" = &rt.applyCode;

fn errorImpl(t: *Thread) Err!Word {
    const msg = arg(t, 0);
    var buf: std.ArrayList(u8) = .empty;
    printer.print(&buf, msg, false);
    t.err_msg = buf.items;
    t.err_n = @min(t.argc - 1, t.err_irritants.len);
    for (0..t.err_n) |i| t.err_irritants[i] = arg(t, i + 1);
    return error.Scheme;
}
pub const @"%error" = W(errorImpl, 1, any);

fn exitImpl(t: *Thread) Err!Word {
    var code: u8 = 0;
    if (t.argc > 0) {
        const c = arg(t, 0);
        code = if (c == rt.FALSE) 1 else if (rt.isFix(c)) @truncate(@as(u64, @bitCast(unfix(c)))) else 0;
    }
    rt.os.exit(code);
}
pub const @"%exit" = W(exitImpl, 0, 1);

fn procedureP(t: *Thread) Err!Word {
    return rt.boolean(rt.isProcedure(arg(t, 0)));
}
pub const @"%procedure?" = W(procedureP, 1, 1);

// --- pairs and lists -------------------------------------------------------

fn consImpl(t: *Thread) Err!Word {
    t.reserve(3);
    return t.cons(arg(t, 0), arg(t, 1));
}
pub const @"%cons" = W(consImpl, 2, 2);

fn carImpl(t: *Thread) Err!Word {
    return rt.car(try checkPair(t, "car: not a pair", arg(t, 0)));
}
pub const @"%car" = W(carImpl, 1, 1);

fn cdrImpl(t: *Thread) Err!Word {
    return rt.cdr(try checkPair(t, "cdr: not a pair", arg(t, 0)));
}
pub const @"%cdr" = W(cdrImpl, 1, 1);

fn setCarImpl(t: *Thread) Err!Word {
    rt.ptr(try checkPair(t, "set-car!: not a pair", arg(t, 0)))[1] = arg(t, 1);
    return rt.UNSPEC;
}
pub const @"%set-car!" = W(setCarImpl, 2, 2);

fn setCdrImpl(t: *Thread) Err!Word {
    rt.ptr(try checkPair(t, "set-cdr!: not a pair", arg(t, 0)))[2] = arg(t, 1);
    return rt.UNSPEC;
}
pub const @"%set-cdr!" = W(setCdrImpl, 2, 2);

fn pairP(t: *Thread) Err!Word {
    return rt.boolean(rt.isPair(arg(t, 0)));
}
pub const @"%pair?" = W(pairP, 1, 1);

fn nullP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.NIL);
}
pub const @"%null?" = W(nullP, 1, 1);

fn listP(t: *Thread) Err!Word {
    return rt.boolean(listLength(arg(t, 0)) != null);
}
pub const @"%list?" = W(listP, 1, 1);

fn listImpl(t: *Thread) Err!Word {
    t.reserve(3 * t.argc);
    return rt.restList(t, 0);
}
pub const @"%list" = W(listImpl, 0, any);

fn lengthImpl(t: *Thread) Err!Word {
    const n = listLength(arg(t, 0)) orelse return raise(t, "length: not a proper list", &.{arg(t, 0)});
    return fix(@intCast(n));
}
pub const @"%length" = W(lengthImpl, 1, 1);

fn reverseImpl(t: *Thread) Err!Word {
    const n = listLength(arg(t, 0)) orelse return raise(t, "reverse: not a proper list", &.{arg(t, 0)});
    t.reserve(3 * n);
    var r = rt.NIL;
    var x = arg(t, 0);
    while (x != rt.NIL) : (x = rt.cdr(x)) r = t.cons(rt.car(x), r);
    return r;
}
pub const @"%reverse" = W(reverseImpl, 1, 1);

fn appendImpl(t: *Thread) Err!Word {
    if (t.argc == 0) return rt.NIL;
    var total: usize = 0;
    for (0..t.argc - 1) |i| total += listLength(arg(t, i)) orelse return raise(t, "append: not a proper list", &.{arg(t, i)});
    t.reserve(3 * total);
    var result = arg(t, t.argc - 1);
    var i = t.argc - 1;
    while (i > 0) {
        i -= 1;
        // copy list i in front of result, keeping its order
        const n = listLength(arg(t, i)).?;
        const start = t.hp;
        var x = arg(t, i);
        var j: usize = 0;
        while (j < n) : (j += 1) {
            const p = t.allocRaw(3);
            p[0] = rt.hdr(rt.T_PAIR, 2);
            p[1] = rt.car(x);
            p[2] = if (j + 1 < n) rt.tagPtr(p + 3) else result;
            x = rt.cdr(x);
        }
        if (n > 0) result = rt.tagPtr(start);
    }
    return result;
}
pub const @"%append" = W(appendImpl, 0, any);

// --- equivalence -----------------------------------------------------------

fn eqP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == arg(t, 1));
}
pub const @"%eq?" = W(eqP, 2, 2);

fn eqvP(t: *Thread) Err!Word {
    return rt.boolean(data.eqv(arg(t, 0), arg(t, 1)));
}
pub const @"%eqv?" = W(eqvP, 2, 2);

fn equalP(t: *Thread) Err!Word {
    return rt.boolean(data.equal(arg(t, 0), arg(t, 1)));
}
pub const @"%equal?" = W(equalP, 2, 2);

fn notImpl(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.FALSE);
}
pub const @"%not" = W(notImpl, 1, 1);

fn booleanP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.TRUE or arg(t, 0) == rt.FALSE);
}
pub const @"%boolean?" = W(booleanP, 1, 1);

// --- numbers ---------------------------------------------------------------

fn numArg(t: *Thread, who: []const u8, i: usize) Err!Word {
    const w = arg(t, i);
    if (!num.isNumber(w)) return raise(t, who, &.{w});
    return w;
}

fn foldArith(t: *Thread, comptime op: enum { add, sub, mul, div }, comptime who: []const u8) Err!Word {
    t.reserve(2 * (t.argc + 1));
    if (t.argc == 0) return if (op == .mul) fix(1) else fix(0);
    var acc = try numArg(t, who ++ ": not a number", 0);
    if (t.argc == 1) {
        switch (op) {
            .sub => return num.sub(t, fix(0), acc) orelse raise(t, who ++ ": integer overflow (no bignums yet)", &.{acc}),
            .div => return num.div(t, fix(1), acc) orelse raise(t, who ++ ": result not representable yet", &.{acc}),
            else => return acc,
        }
    }
    for (1..t.argc) |i| {
        const b = try numArg(t, who ++ ": not a number", i);
        acc = switch (op) {
            .add => num.add(t, acc, b),
            .sub => num.sub(t, acc, b),
            .mul => num.mul(t, acc, b),
            .div => num.div(t, acc, b),
        } orelse return raise(t, who ++ ": integer overflow or result not representable yet", &.{ acc, b });
    }
    return acc;
}

fn addImpl(t: *Thread) Err!Word {
    return foldArith(t, .add, "+");
}
fn subImpl(t: *Thread) Err!Word {
    return foldArith(t, .sub, "-");
}
fn mulImpl(t: *Thread) Err!Word {
    return foldArith(t, .mul, "*");
}
fn divImpl(t: *Thread) Err!Word {
    return foldArith(t, .div, "/");
}
pub const @"%+" = W(addImpl, 0, any);
pub const @"%-" = W(subImpl, 1, any);
pub const @"%*" = W(mulImpl, 0, any);
pub const @"%/" = W(divImpl, 1, any);

fn compareChain(t: *Thread, comptime c: num.Cmp, comptime who: []const u8) Err!Word {
    for (0..t.argc) |i| _ = try numArg(t, who ++ ": not a number", i);
    for (1..t.argc) |i| if (!num.cmp(arg(t, i - 1), arg(t, i), c).?) return rt.FALSE;
    return rt.TRUE;
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
fn numEqImpl(t: *Thread) Err!Word {
    return compareChain(t, .eq, "=");
}
pub const @"%<" = W(ltImpl, 1, any);
pub const @"%>" = W(gtImpl, 1, any);
pub const @"%<=" = W(leImpl, 1, any);
pub const @"%>=" = W(geImpl, 1, any);
pub const @"%=" = W(numEqImpl, 1, any);

fn intArg(t: *Thread, who: []const u8, i: usize) Err!i64 {
    const w = arg(t, i);
    if (!rt.isFix(w)) return raise(t, who, &.{w});
    return unfix(w);
}

fn quotientImpl(t: *Thread) Err!Word {
    const x = try intArg(t, "quotient: not an integer", 0);
    const y = try intArg(t, "quotient: not an integer", 1);
    if (y == 0) return raise(t, "quotient: division by zero", &.{});
    return fix(@divTrunc(x, y));
}
pub const @"%quotient" = W(quotientImpl, 2, 2);

fn remainderImpl(t: *Thread) Err!Word {
    const x = try intArg(t, "remainder: not an integer", 0);
    const y = try intArg(t, "remainder: not an integer", 1);
    if (y == 0) return raise(t, "remainder: division by zero", &.{});
    return fix(@rem(x, y));
}
pub const @"%remainder" = W(remainderImpl, 2, 2);

fn moduloImpl(t: *Thread) Err!Word {
    const x = try intArg(t, "modulo: not an integer", 0);
    const y = try intArg(t, "modulo: not an integer", 1);
    if (y == 0) return raise(t, "modulo: division by zero", &.{});
    return fix(@mod(x, y));
}
pub const @"%modulo" = W(moduloImpl, 2, 2);

fn numberP(t: *Thread) Err!Word {
    return rt.boolean(num.isNumber(arg(t, 0)));
}
pub const @"%number?" = W(numberP, 1, 1);

fn integerP(t: *Thread) Err!Word {
    return rt.boolean(num.isInteger(arg(t, 0)));
}
pub const @"%integer?" = W(integerP, 1, 1);

fn exactP(t: *Thread) Err!Word {
    _ = try numArg(t, "exact?: not a number", 0);
    return rt.boolean(rt.isFix(arg(t, 0)));
}
pub const @"%exact?" = W(exactP, 1, 1);

fn inexactP(t: *Thread) Err!Word {
    _ = try numArg(t, "inexact?: not a number", 0);
    return rt.boolean(rt.isFlonum(arg(t, 0)));
}
pub const @"%inexact?" = W(inexactP, 1, 1);

fn zeroP(t: *Thread) Err!Word {
    const w = try numArg(t, "zero?: not a number", 0);
    return rt.boolean(num.toF(w).? == 0);
}
pub const @"%zero?" = W(zeroP, 1, 1);

fn inexactImpl(t: *Thread) Err!Word {
    t.reserve(2);
    const w = try numArg(t, "inexact: not a number", 0);
    if (rt.isFlonum(w)) return w;
    return t.makeFlo(num.toF(w).?);
}
pub const @"%inexact" = W(inexactImpl, 1, 1);
pub const @"%exact->inexact" = @"%inexact";

fn exactImpl(t: *Thread) Err!Word {
    const w = try numArg(t, "exact: not a number", 0);
    if (rt.isFix(w)) return w;
    const f = rt.flo(w);
    if (!num.isInteger(w) or f < -4.6e18 or f > 4.6e18) return raise(t, "exact: not representable yet", &.{w});
    return fix(@intFromFloat(f));
}
pub const @"%exact" = W(exactImpl, 1, 1);
pub const @"%inexact->exact" = @"%exact";

fn floatFn(t: *Thread, comptime who: []const u8, comptime f: fn (f64) f64) Err!Word {
    t.reserve(2);
    const w = try numArg(t, who ++ ": not a number", 0);
    if (rt.isFix(w) and !std.mem.eql(u8, who, "sqrt")) return w; // floor etc. of an integer
    const r = f(num.toF(w).?);
    if (std.mem.eql(u8, who, "sqrt") and rt.isFix(w) and @floor(r) == r and r * r == num.toF(w).?) return fix(@intFromFloat(r));
    return t.makeFlo(r);
}
fn fSqrt(x: f64) f64 {
    return @sqrt(x);
}
fn fFloor(x: f64) f64 {
    return @floor(x);
}
fn fCeil(x: f64) f64 {
    return @ceil(x);
}
fn fTrunc(x: f64) f64 {
    return @trunc(x);
}
fn fRound(x: f64) f64 {
    // round to even, as R7RS requires
    const r = @round(x);
    if (@abs(x - @trunc(x)) == 0.5) return 2.0 * @round(x / 2.0);
    return r;
}
fn sqrtImpl(t: *Thread) Err!Word {
    return floatFn(t, "sqrt", fSqrt);
}
fn floorImpl(t: *Thread) Err!Word {
    return floatFn(t, "floor", fFloor);
}
fn ceilingImpl(t: *Thread) Err!Word {
    return floatFn(t, "ceiling", fCeil);
}
fn truncateImpl(t: *Thread) Err!Word {
    return floatFn(t, "truncate", fTrunc);
}
fn roundImpl(t: *Thread) Err!Word {
    return floatFn(t, "round", fRound);
}
pub const @"%sqrt" = W(sqrtImpl, 1, 1);
pub const @"%floor" = W(floorImpl, 1, 1);
pub const @"%ceiling" = W(ceilingImpl, 1, 1);
pub const @"%truncate" = W(truncateImpl, 1, 1);
pub const @"%round" = W(roundImpl, 1, 1);

fn absImpl(t: *Thread) Err!Word {
    t.reserve(2);
    const w = try numArg(t, "abs: not a number", 0);
    if (rt.isFix(w)) return if (unfix(w) < 0) fix(-unfix(w)) else w;
    return t.makeFlo(@abs(rt.flo(w)));
}
pub const @"%abs" = W(absImpl, 1, 1);

fn minMax(t: *Thread, comptime is_max: bool) Err!Word {
    t.reserve(2);
    var acc = try numArg(t, "min/max: not a number", 0);
    var inexact_seen = rt.isFlonum(acc);
    for (1..t.argc) |i| {
        const b = try numArg(t, "min/max: not a number", i);
        if (rt.isFlonum(b)) inexact_seen = true;
        const take = if (is_max) num.cmp(b, acc, .gt).? else num.cmp(b, acc, .lt).?;
        if (take) acc = b;
    }
    if (inexact_seen and rt.isFix(acc)) return t.makeFlo(num.toF(acc).?);
    return acc;
}
fn minImpl(t: *Thread) Err!Word {
    return minMax(t, false);
}
fn maxImpl(t: *Thread) Err!Word {
    return minMax(t, true);
}
pub const @"%min" = W(minImpl, 1, any);
pub const @"%max" = W(maxImpl, 1, any);

fn numberToString(t: *Thread) Err!Word {
    const w = try numArg(t, "number->string: not a number", 0);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.heap.page_allocator);
    printer.print(&buf, w, false);
    t.reserve(data.stringWords(buf.items.len, false));
    const s = data.makeString(t, buf.items.len, false);
    @memcpy(data.bytes8(s)[0..buf.items.len], buf.items);
    return s;
}
pub const @"%number->string" = W(numberToString, 1, 1);

// --- characters ------------------------------------------------------------

fn charP(t: *Thread) Err!Word {
    return rt.boolean(rt.isChar(arg(t, 0)));
}
pub const @"%char?" = W(charP, 1, 1);

fn charArg(t: *Thread, i: usize) Err!u21 {
    const w = arg(t, i);
    if (!rt.isChar(w)) return raise(t, "not a character", &.{w});
    return rt.charCode(w);
}

fn charToInteger(t: *Thread) Err!Word {
    return fix(try charArg(t, 0));
}
pub const @"%char->integer" = W(charToInteger, 1, 1);

fn integerToChar(t: *Thread) Err!Word {
    const n = try intArg(t, "integer->char: not an integer", 0);
    if (n < 0 or n > 0x10FFFF or (n >= 0xD800 and n <= 0xDFFF)) return raise(t, "integer->char: not a code point", &.{arg(t, 0)});
    return rt.char(@intCast(n));
}
pub const @"%integer->char" = W(integerToChar, 1, 1);

fn charEq(t: *Thread) Err!Word {
    for (1..t.argc) |i| if (try charArg(t, i - 1) != try charArg(t, i)) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%char=?" = W(charEq, 1, any);

fn charLt(t: *Thread) Err!Word {
    for (1..t.argc) |i| if (!(try charArg(t, i - 1) < try charArg(t, i))) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%char<?" = W(charLt, 1, any);

// --- strings ---------------------------------------------------------------

fn stringArg(t: *Thread, i: usize) Err!Word {
    const w = arg(t, i);
    if (!data.isString(w)) return raise(t, "not a string", &.{w});
    return w;
}

fn stringP(t: *Thread) Err!Word {
    return rt.boolean(data.isString(arg(t, 0)));
}
pub const @"%string?" = W(stringP, 1, 1);

fn stringLength(t: *Thread) Err!Word {
    return fix(@intCast(data.stringLen(try stringArg(t, 0))));
}
pub const @"%string-length" = W(stringLength, 1, 1);

fn stringRef(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    const i = try index(t, arg(t, 1), data.stringLen(s));
    return rt.char(data.stringRef(s, i));
}
pub const @"%string-ref" = W(stringRef, 2, 2);

fn stringSet(t: *Thread) Err!Word {
    const s0 = try stringArg(t, 0);
    const i = try index(t, arg(t, 1), data.stringLen(s0));
    const cp = try charArg(t, 2);
    if (cp > 255 and !data.isWide(s0)) {
        t.reserve(1 + data.bufWords(data.stringLen(s0), true));
        data.widen(t, arg(t, 0));
    }
    data.stringSetFits(arg(t, 0), i, cp);
    return rt.UNSPEC;
}
pub const @"%string-set!" = W(stringSet, 3, 3);

fn makeStringImpl(t: *Thread) Err!Word {
    const n = try count(t, arg(t, 0));
    const fill: u21 = if (t.argc > 1) try charArg(t, 1) else ' ';
    t.reserve(data.stringWords(n, fill > 255));
    const s = data.makeString(t, n, fill > 255);
    for (0..n) |i| data.stringSetFits(s, i, fill);
    return s;
}
pub const @"%make-string" = W(makeStringImpl, 1, 2);

/// A new string with the characters of `chars` (any iterator of code points).
fn copyChars(t: *Thread, src: Word, from: usize, to: usize) Word {
    // caller reserved stringWords(to - from, isWide(src)); src re-read by caller
    const n = to - from;
    const wide = data.isWide(src);
    const s = data.makeString(t, n, wide);
    for (0..n) |i| data.stringSetFits(s, i, data.stringRef(src, from + i));
    return s;
}

fn substringImpl(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    const len = data.stringLen(s);
    const from: usize = if (t.argc > 1) try count(t, arg(t, 1)) else 0;
    const to: usize = if (t.argc > 2) try count(t, arg(t, 2)) else len;
    if (from > to or to > len) return raise(t, "substring: index out of range", &.{ arg(t, 1), arg(t, 2) });
    t.reserve(data.stringWords(to - from, data.isWide(s)));
    return copyChars(t, arg(t, 0), from, to);
}
pub const @"%substring" = W(substringImpl, 2, 3);
pub const @"%string-copy" = W(substringImpl, 1, 3);

fn stringAppend(t: *Thread) Err!Word {
    var n: usize = 0;
    var wide = false;
    for (0..t.argc) |i| {
        const s = try stringArg(t, i);
        n += data.stringLen(s);
        if (data.isWide(s)) wide = true;
    }
    t.reserve(data.stringWords(n, wide));
    const r = data.makeString(t, n, wide);
    var k: usize = 0;
    for (0..t.argc) |i| {
        const s = arg(t, i);
        for (0..data.stringLen(s)) |j| {
            data.stringSetFits(r, k, data.stringRef(s, j));
            k += 1;
        }
    }
    return r;
}
pub const @"%string-append" = W(stringAppend, 0, any);

fn stringEqImpl(t: *Thread) Err!Word {
    for (0..t.argc) |i| _ = try stringArg(t, i);
    for (1..t.argc) |i| if (!data.stringEq(arg(t, i - 1), arg(t, i))) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%string=?" = W(stringEqImpl, 1, any);

fn stringLtImpl(t: *Thread) Err!Word {
    for (0..t.argc) |i| _ = try stringArg(t, i);
    for (1..t.argc) |i| if (data.stringCmp(arg(t, i - 1), arg(t, i)) != .lt) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%string<?" = W(stringLtImpl, 1, any);

fn stringToList(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    const n = data.stringLen(s);
    t.reserve(3 * n);
    var l = rt.NIL;
    var i = n;
    while (i > 0) {
        i -= 1;
        l = t.cons(rt.char(data.stringRef(arg(t, 0), i)), l);
    }
    return l;
}
pub const @"%string->list" = W(stringToList, 1, 1);

fn listToString(t: *Thread) Err!Word {
    const n = listLength(arg(t, 0)) orelse return raise(t, "list->string: not a proper list", &.{arg(t, 0)});
    var wide = false;
    var x = arg(t, 0);
    while (x != rt.NIL) : (x = rt.cdr(x)) {
        const c = rt.car(x);
        if (!rt.isChar(c)) return raise(t, "list->string: not a character", &.{c});
        if (rt.charCode(c) > 255) wide = true;
    }
    t.reserve(data.stringWords(n, wide));
    const s = data.makeString(t, n, wide);
    x = arg(t, 0);
    var i: usize = 0;
    while (x != rt.NIL) : (x = rt.cdr(x)) {
        data.stringSetFits(s, i, rt.charCode(rt.car(x)));
        i += 1;
    }
    return s;
}
pub const @"%list->string" = W(listToString, 1, 1);

fn stringImpl(t: *Thread) Err!Word {
    var wide = false;
    for (0..t.argc) |i| if (try charArg(t, i) > 255) {
        wide = true;
    };
    t.reserve(data.stringWords(t.argc, wide));
    const s = data.makeString(t, t.argc, wide);
    for (0..t.argc) |i| data.stringSetFits(s, i, rt.charCode(arg(t, i)));
    return s;
}
pub const @"%string" = W(stringImpl, 0, any);

// --- symbols ---------------------------------------------------------------

fn symbolP(t: *Thread) Err!Word {
    return rt.boolean(data.isSymbol(arg(t, 0)));
}
pub const @"%symbol?" = W(symbolP, 1, 1);

fn stringToSymbol(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.heap.page_allocator);
    data.appendUtf8(&buf, s);
    return data.intern(buf.items);
}
pub const @"%string->symbol" = W(stringToSymbol, 1, 1);

fn symbolToString(t: *Thread) Err!Word {
    const w = arg(t, 0);
    if (!data.isSymbol(w)) return raise(t, "symbol->string: not a symbol", &.{w});
    // the name is UTF-8; count code points first
    const name = data.symbolName(w);
    var n: usize = 0;
    var wide = false;
    var it = std.unicode.Utf8View.initUnchecked(name).iterator();
    while (it.nextCodepoint()) |cp| {
        n += 1;
        if (cp > 255) wide = true;
    }
    t.reserve(data.stringWords(n, wide));
    const s = data.makeString(t, n, wide);
    it = std.unicode.Utf8View.initUnchecked(data.symbolName(arg(t, 0))).iterator();
    var i: usize = 0;
    while (it.nextCodepoint()) |cp| : (i += 1) data.stringSetFits(s, i, cp);
    return s;
}
pub const @"%symbol->string" = W(symbolToString, 1, 1);

// --- vectors ---------------------------------------------------------------

fn vectorArg(t: *Thread, i: usize) Err!Word {
    const w = arg(t, i);
    if (!data.isVector(w)) return raise(t, "not a vector", &.{w});
    return w;
}

fn vectorP(t: *Thread) Err!Word {
    return rt.boolean(data.isVector(arg(t, 0)));
}
pub const @"%vector?" = W(vectorP, 1, 1);

fn makeVectorImpl(t: *Thread) Err!Word {
    const n = try count(t, arg(t, 0));
    t.reserve(1 + n);
    return data.makeVector(t, n, if (t.argc > 1) arg(t, 1) else fix(0));
}
pub const @"%make-vector" = W(makeVectorImpl, 1, 2);

fn vectorImpl(t: *Thread) Err!Word {
    t.reserve(1 + t.argc);
    const v = data.makeVector(t, t.argc, fix(0));
    @memcpy(data.vectorItems(v), t.args[0..t.argc]);
    return v;
}
pub const @"%vector" = W(vectorImpl, 0, any);

fn vectorRef(t: *Thread) Err!Word {
    const v = try vectorArg(t, 0);
    return data.vectorItems(v)[try index(t, arg(t, 1), data.vectorLen(v))];
}
pub const @"%vector-ref" = W(vectorRef, 2, 2);

fn vectorSet(t: *Thread) Err!Word {
    const v = try vectorArg(t, 0);
    data.vectorItems(v)[try index(t, arg(t, 1), data.vectorLen(v))] = arg(t, 2);
    return rt.UNSPEC;
}
pub const @"%vector-set!" = W(vectorSet, 3, 3);

fn vectorLength(t: *Thread) Err!Word {
    return fix(@intCast(data.vectorLen(try vectorArg(t, 0))));
}
pub const @"%vector-length" = W(vectorLength, 1, 1);

fn vectorFill(t: *Thread) Err!Word {
    @memset(data.vectorItems(try vectorArg(t, 0)), arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%vector-fill!" = W(vectorFill, 2, 2);

fn vectorToList(t: *Thread) Err!Word {
    const n = data.vectorLen(try vectorArg(t, 0));
    t.reserve(3 * n);
    var l = rt.NIL;
    var i = n;
    while (i > 0) {
        i -= 1;
        l = t.cons(data.vectorItems(arg(t, 0))[i], l);
    }
    return l;
}
pub const @"%vector->list" = W(vectorToList, 1, 1);

fn listToVector(t: *Thread) Err!Word {
    const n = listLength(arg(t, 0)) orelse return raise(t, "list->vector: not a proper list", &.{arg(t, 0)});
    t.reserve(1 + n);
    const v = data.makeVector(t, n, fix(0));
    var x = arg(t, 0);
    for (data.vectorItems(v)) |*w| {
        w.* = rt.car(x);
        x = rt.cdr(x);
    }
    return v;
}
pub const @"%list->vector" = W(listToVector, 1, 1);

// --- output (Phase 1: stdout only; the port argument is ignored) -----------

fn out(w: Word, write: bool) void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.heap.page_allocator);
    printer.print(&buf, w, write);
    rt.os.write(buf.items);
}

fn displayImpl(t: *Thread) Err!Word {
    out(arg(t, 0), false);
    return rt.UNSPEC;
}
pub const @"%display" = W(displayImpl, 1, 2);

fn writeImpl(t: *Thread) Err!Word {
    out(arg(t, 0), true);
    return rt.UNSPEC;
}
pub const @"%write" = W(writeImpl, 1, 2);

fn newlineImpl(_: *Thread) Err!Word {
    rt.os.write("\n");
    return rt.UNSPEC;
}
pub const @"%newline" = W(newlineImpl, 0, 1);

fn writeChar(t: *Thread) Err!Word {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.heap.page_allocator);
    data.appendCp(&buf, try charArg(t, 0));
    rt.os.write(buf.items);
    return rt.UNSPEC;
}
pub const @"%write-char" = W(writeChar, 1, 2);

fn writeString(t: *Thread) Err!Word {
    out(try stringArg(t, 0), false);
    return rt.UNSPEC;
}
pub const @"%write-string" = W(writeString, 1, 2);
