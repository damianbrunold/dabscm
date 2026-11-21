//! Primitives: characters, strings, bytevectors, and the numeric
//! procedures that are not part of the numeric tower proper.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const chars = @import("chars.zig");
const printer = @import("printer.zig");
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

const pa = std.heap.c_allocator;

// --- characters --------------------------------------------------------------

fn charPredD(comptime f: fn (u21) bool) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            return rt.boolean(f(try P.charArg(t, 0)));
        }
    };
    return P.WD("", S.g, 1, 1);
}
fn charMapD(comptime f: fn (u21) u21) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            return rt.char(f(try P.charArg(t, 0)));
        }
    };
    return P.WD("", S.g, 1, 1);
}
pub const @"%char-alphabetic?" = charPredD(chars.isAlphabetic);
pub const @"%char-numeric?" = charPredD(chars.isDigit);
pub const @"%char-whitespace?" = charPredD(chars.isWhitespace);
pub const @"%char-upper-case?" = charPredD(chars.isUpper);
pub const @"%char-lower-case?" = charPredD(chars.isLower);
pub const @"%char-upcase" = charMapD(chars.upcase);
pub const @"%char-downcase" = charMapD(chars.downcase);
pub const @"%char-foldcase" = charMapD(chars.foldcase);

fn digitValue(t: *Thread) Err!Word {
    const d = chars.digitValue(try P.charArg(t, 0)) orelse return rt.FALSE;
    return fix(d);
}
pub const @"%digit-value" = WD("digit-value", digitValue, 1, 1);

fn charCompareD(comptime op: std.math.CompareOperator) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            for (0..t.argc) |i| _ = try P.charArg(t, i);
            for (1..t.argc) |i| if (!std.math.compare(rt.charCode(arg(t, i - 1)), op, rt.charCode(arg(t, i)))) return rt.FALSE;
            return rt.TRUE;
        }
    };
    return P.WD("", S.g, 1, any);
}
pub const @"%char<=?" = charCompareD(.lte);
pub const @"%char>?" = charCompareD(.gt);
pub const @"%char>=?" = charCompareD(.gte);

// --- strings -----------------------------------------------------------------

fn stringCompareD(comptime op: std.math.CompareOperator) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            for (0..t.argc) |i| _ = try P.stringArg(t, i);
            for (1..t.argc) |i| if (!data.stringCmp(arg(t, i - 1), arg(t, i)).compare(op)) return rt.FALSE;
            return rt.TRUE;
        }
    };
    return P.WD("", S.g, 1, any);
}
pub const @"%string<=?" = stringCompareD(.lte);
pub const @"%string>?" = stringCompareD(.gt);
pub const @"%string>=?" = stringCompareD(.gte);

fn stringCase(comptime f: fn (u21) u21) Code {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            const s0 = try P.stringArg(t, 0);
            const n = data.stringLen(s0);
            var wide = false;
            for (0..n) |i| if (f(data.stringRef(s0, i)) > 255) {
                wide = true;
            };
            t.reserve(data.stringWords(n, wide));
            const s = arg(t, 0);
            const r = data.makeString(t, n, wide);
            for (0..n) |i| data.stringSetFits(r, i, f(data.stringRef(s, i)));
            return r;
        }
    };
    return W(S.g, 1, 1);
}
pub const @"%string-upcase" = stringCase(chars.upcase);
pub const @"%string-downcase" = stringCase(chars.downcase);
pub const @"%string-foldcase" = stringCase(chars.foldcase);

fn stringToNumber(t: *Thread) Err!Word {
    const text = data.toUtf8(try P.stringArg(t, 0));
    var radix: u8 = 10;
    if (t.argc > 1) {
        const r = try P.intArg(t, "string->number: radix", 1);
        if (r != 2 and r != 8 and r != 10 and r != 16) return raise(t, "string->number: bad radix", &.{arg(t, 1)});
        radix = @intCast(r);
    }
    const lit = num.parseNumber(text, radix) orelse return rt.FALSE;
    return switch (lit) {
        .fix => |n| fix(n),
        .flo => |f| blk: {
            t.reserve(2);
            break :blk t.makeFlo(f);
        },
        .exact => num.exactFromLit(t, lit) orelse rt.FALSE,
    };
}
pub const @"%string->number" = WN("string->number", stringToNumber, 1, 2);

/// optional [start [end]] arguments from position i, for length len
fn range(t: *Thread, i: usize, len: usize) Err![2]usize {
    const start: usize = if (t.argc > i) try P.count(t, arg(t, i)) else 0;
    const end: usize = if (t.argc > i + 1) try P.count(t, arg(t, i + 1)) else len;
    if (start > end or end > len) return raise(t, "index out of range", &.{});
    return .{ start, end };
}

fn stringToUtf8(t: *Thread) Err!Word {
    const s = try P.stringArg(t, 0);
    const r = try range(t, 1, data.stringLen(s));
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    for (r[0]..r[1]) |i| data.appendCp(&buf, data.stringRef(s, i));
    t.reserve(data.bvWords(buf.items.len));
    const bv = data.makeBytevector(t, buf.items.len);
    @memcpy(data.bvBytes(bv), buf.items);
    return bv;
}
pub const @"%string->utf8" = WN("string->utf8", stringToUtf8, 1, 3);

fn utf8ToString(t: *Thread) Err!Word {
    const bv = try bvArg(t, 0);
    const r = try range(t, 1, data.bvLen(bv));
    const bytes = pa.dupe(u8, data.bvBytes(bv)[r[0]..r[1]]) catch rt.oom();
    defer pa.free(bytes);
    t.reserve(data.stringWords(bytes.len, true));
    return data.heapStringUtf8(t, bytes);
}
pub const @"%utf8->string" = WN("utf8->string", utf8ToString, 1, 3);

// --- bytevectors ---------------------------------------------------------------

pub fn bvArg(t: *Thread, i: usize) Err!Word {
    const w = arg(t, i);
    if (!data.isBytevector(w)) return P.argTypeError(t);
    return w;
}

fn byteArg(t: *Thread, i: usize) Err!u8 {
    const w = arg(t, i);
    if (!rt.isFix(w) or unfix(w) < 0 or unfix(w) > 255) return raise(t, "not a byte", &.{w});
    return @intCast(unfix(w));
}

fn bytevectorP(t: *Thread) Err!Word {
    return rt.boolean(data.isBytevector(arg(t, 0)));
}
pub const @"%bytevector?" = WD("bytevector?", bytevectorP, 1, 1);

fn makeBytevector(t: *Thread) Err!Word {
    const n = try P.count(t, arg(t, 0));
    const fill: u8 = if (t.argc > 1) try byteArg(t, 1) else 0;
    t.reserve(data.bvWords(n));
    const bv = data.makeBytevector(t, n);
    @memset(data.bvBytes(bv), fill);
    return bv;
}
pub const @"%make-bytevector" = WN("make-bytevector", makeBytevector, 1, 2);

fn bytevectorImpl(t: *Thread) Err!Word {
    for (0..t.argc) |i| _ = try byteArg(t, i);
    t.reserve(data.bvWords(t.argc));
    const bv = data.makeBytevector(t, t.argc);
    for (data.bvBytes(bv), 0..) |*b, i| b.* = @intCast(unfix(arg(t, i)));
    return bv;
}
pub const @"%bytevector" = WN("bytevector", bytevectorImpl, 0, any);

fn bytevectorLength(t: *Thread) Err!Word {
    return fix(@intCast(data.bvLen(try bvArg(t, 0))));
}
pub const @"%bytevector-length" = WD("bytevector-length", bytevectorLength, 1, 1);

fn bytevectorU8Ref(t: *Thread) Err!Word {
    const bv = try bvArg(t, 0);
    return fix(data.bvBytes(bv)[try P.index(t, arg(t, 1), data.bvLen(bv))]);
}
pub const @"%bytevector-u8-ref" = WD("bytevector-u8-ref", bytevectorU8Ref, 2, 2);

fn bytevectorU8Set(t: *Thread) Err!Word {
    const bv = try bvArg(t, 0);
    data.bvBytes(bv)[try P.index(t, arg(t, 1), data.bvLen(bv))] = try byteArg(t, 2);
    return rt.UNSPEC;
}
pub const @"%bytevector-u8-set!" = WD("bytevector-u8-set!", bytevectorU8Set, 3, 3);

fn bytevectorCopy(t: *Thread) Err!Word {
    const bv0 = try bvArg(t, 0);
    const r = try range(t, 1, data.bvLen(bv0));
    t.reserve(data.bvWords(r[1] - r[0]));
    const bv = data.makeBytevector(t, r[1] - r[0]);
    @memcpy(data.bvBytes(bv), data.bvBytes(arg(t, 0))[r[0]..r[1]]);
    return bv;
}
pub const @"%bytevector-copy" = WN("bytevector-copy", bytevectorCopy, 1, 3);

fn bytevectorCopyB(t: *Thread) Err!Word {
    const to = try bvArg(t, 0);
    const at = try P.count(t, arg(t, 1));
    const from = try bvArg(t, 2);
    const r = try range(t, 3, data.bvLen(from));
    if (at + (r[1] - r[0]) > data.bvLen(to)) return raise(t, "bytevector-copy!: out of range", &.{arg(t, 1)});
    std.mem.copyForwards(u8, data.bvBytes(to)[at .. at + r[1] - r[0]], data.bvBytes(from)[r[0]..r[1]]);
    return rt.UNSPEC;
}
pub const @"%bytevector-copy!" = WD("bytevector-copy!", bytevectorCopyB, 3, 5);

fn bytevectorAppend(t: *Thread) Err!Word {
    var n: usize = 0;
    for (0..t.argc) |i| n += data.bvLen(try bvArg(t, i));
    t.reserve(data.bvWords(n));
    const bv = data.makeBytevector(t, n);
    var k: usize = 0;
    for (0..t.argc) |i| {
        const b = data.bvBytes(arg(t, i));
        @memcpy(data.bvBytes(bv)[k .. k + b.len], b);
        k += b.len;
    }
    return bv;
}
pub const @"%bytevector-append" = WN("bytevector-append", bytevectorAppend, 0, any);

// --- transcendental functions (flonum results) -------------------------------------

fn floatFnD(comptime f: fn (f64) f64, comptime who: []const u8) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            const x = num.toF(try P.numArg(t, who ++ ": not a number", 0)).?;
            return rt.safeFlo(t, f(x));
        }
    };
    return P.WD(who, S.g, 1, 1);
}
fn fsin(x: f64) f64 {
    return @sin(x);
}
fn fcos(x: f64) f64 {
    return @cos(x);
}
fn ftan(x: f64) f64 {
    return @tan(x);
}
fn fasin(x: f64) f64 {
    return std.math.asin(x);
}
fn facos(x: f64) f64 {
    return std.math.acos(x);
}
fn flog(x: f64) f64 {
    return @log(x);
}
pub const @"%sin" = floatFnD(fsin, "sin");
pub const @"%cos" = floatFnD(fcos, "cos");
pub const @"%tan" = floatFnD(ftan, "tan");
pub const @"%asin" = floatFnD(fasin, "asin");
pub const @"%acos" = floatFnD(facos, "acos");

fn logImpl(t: *Thread) Err!Word {
    const x = num.toF(try P.numArg(t, "log: not a number", 0)).?;
    if (t.argc == 2) {
        const b = num.toF(try P.numArg(t, "log: not a number", 1)).?;
        return rt.safeFlo(t, @log(x) / @log(b));
    }
    return rt.safeFlo(t, @log(x));
}
pub const @"%log" = WD("log", logImpl, 1, 2);

fn atanImpl(t: *Thread) Err!Word {
    const y = num.toF(try P.numArg(t, "atan: not a number", 0)).?;
    if (t.argc == 2) {
        const x = num.toF(try P.numArg(t, "atan: not a number", 1)).?;
        return rt.safeFlo(t, std.math.atan2(y, x));
    }
    return rt.safeFlo(t, std.math.atan(y));
}
pub const @"%atan" = WD("atan", atanImpl, 1, 2);

fn makeE() callconv(.c) Word {
    return data.constFlonum(std.math.e);
}
pub const @"%E" = rt.ValuePrim{ .make = &makeE };

