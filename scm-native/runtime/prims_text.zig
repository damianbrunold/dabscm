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
pub const @"%char-whitespace?" = charPredD(chars.isWhiteSpaceProperty);
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

const CaseMode = enum { upper, lower, fold };

/// The one-to-many mappings of SpecialCasing.txt and CaseFolding.txt that
/// the JVM implementation's UnicodeCaseMap applies (unconditional ones)
fn specialCase(cp: u21, comptime mode: CaseMode) ?[]const u21 {
    return switch (mode) {
        .upper => switch (cp) {
            0xDF => &.{ 'S', 'S' },
            0x149 => &.{ 0x2BC, 'N' },
            0x1F0 => &.{ 'J', 0x30C },
            0x390 => &.{ 0x399, 0x308, 0x301 },
            0x3B0 => &.{ 0x3A5, 0x308, 0x301 },
            0xFB00 => &.{ 'F', 'F' },
            0xFB01 => &.{ 'F', 'I' },
            0xFB02 => &.{ 'F', 'L' },
            0xFB03 => &.{ 'F', 'F', 'I' },
            0xFB04 => &.{ 'F', 'F', 'L' },
            0xFB05, 0xFB06 => &.{ 'S', 'T' },
            else => null,
        },
        .lower => switch (cp) {
            0x130 => &.{ 'i', 0x307 },
            else => null,
        },
        .fold => switch (cp) {
            0xDF, 0x1E9E => &.{ 's', 's' },
            0x130 => &.{ 'i', 0x307 },
            0xFB00 => &.{ 'f', 'f' },
            0xFB01 => &.{ 'f', 'i' },
            0xFB02 => &.{ 'f', 'l' },
            0xFB03 => &.{ 'f', 'f', 'i' },
            0xFB04 => &.{ 'f', 'f', 'l' },
            0xFB05, 0xFB06 => &.{ 's', 't' },
            else => null,
        },
    };
}

fn stringCase(comptime mode: CaseMode) Code {
    const f = switch (mode) {
        .upper => chars.upcase,
        .lower => chars.downcase,
        .fold => chars.foldcase,
    };
    const S = struct {
        fn g(t: *Thread) Err!Word {
            const s0 = try P.stringArg(t, 0);
            const n0 = data.stringLen(s0);
            var n: usize = 0;
            var wide = false;
            for (0..n0) |i| {
                const c = data.stringRef(s0, i);
                if (specialCase(c, mode)) |sp| {
                    n += sp.len;
                    for (sp) |x| if (x > 255) {
                        wide = true;
                    };
                } else {
                    n += 1;
                    if (f(c) > 255) wide = true;
                }
            }
            t.reserve(data.stringWords(n, wide));
            const s = arg(t, 0);
            const r = data.makeString(t, n, wide);
            var k: usize = 0;
            for (0..n0) |i| {
                const c = data.stringRef(s, i);
                if (specialCase(c, mode)) |sp| {
                    for (sp) |x| {
                        data.stringSetFits(r, k, x);
                        k += 1;
                    }
                } else {
                    data.stringSetFits(r, k, f(c));
                    k += 1;
                }
            }
            return r;
        }
    };
    return W(S.g, 1, 1);
}
pub const @"%string-upcase" = stringCase(.upper);
pub const @"%string-downcase" = stringCase(.lower);
pub const @"%string-foldcase" = stringCase(.fold);

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
        .exact, .complex => num.exactFromLit(t, lit) orelse rt.FALSE,
    };
}
pub const @"%string->number" = WN("string->number", stringToNumber, 1, 2);

/// optional [start [end]] arguments from position i, for length len
pub fn range(t: *Thread, i: usize, len: usize) Err![2]usize {
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
    try P.reserveObject(t, "make-bytevector", data.bvWords(n));
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
    // the same bytevector: copy away from the overlap
    const dst = data.bvBytes(to)[at .. at + r[1] - r[0]];
    const src = data.bvBytes(from)[r[0]..r[1]];
    if (@intFromPtr(dst.ptr) > @intFromPtr(src.ptr)) std.mem.copyBackwards(u8, dst, src) else std.mem.copyForwards(u8, dst, src);
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

const tower = num.tower;
const C = tower.C;

/// A function of one argument: f on a real in its domain (dom), else the
/// complex function cf (a non-real argument, or a real outside the domain)
fn floatFnD(comptime f: fn (f64) f64, comptime cf: fn (C) C, comptime dom: fn (f64) bool, comptime who: []const u8) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            const w = try P.numArg(t, who ++ ": not a number", 0);
            if (!tower.isComp(w)) {
                const x = num.toF(w).?;
                if (dom(x)) return rt.safeFlo(t, f(x));
            }
            return cf(C.of(w)).word(t);
        }
    };
    return P.WD(who, S.g, 1, 1);
}
fn anyReal(_: f64) bool {
    return true;
}
/// asin and acos are real on [-1, 1] (and NaN)
fn unitInterval(x: f64) bool {
    return !(x < -1.0 or x > 1.0);
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
pub const @"%sin" = floatFnD(fsin, C.sin, anyReal, "sin");
pub const @"%cos" = floatFnD(fcos, C.cos, anyReal, "cos");
pub const @"%tan" = floatFnD(ftan, C.tan, anyReal, "tan");
pub const @"%asin" = floatFnD(fasin, C.asin, unitInterval, "asin");
pub const @"%acos" = floatFnD(facos, C.acos, unitInterval, "acos");

/// The natural logarithm: real for a non-negative real (log 0 is -inf.0),
/// else ln|z| + i angle z (a negative real, -0.0 too: ln|x| + pi i)
pub fn logOf(w: Word) C {
    if (!tower.isComp(w)) {
        const x = num.toF(w).?;
        if (!std.math.signbit(x) or std.math.isNan(x)) return .{ .re = @log(x), .im = 0 };
        return .{ .re = @log(-x), .im = std.math.pi };
    }
    return C.log(C.of(w));
}
fn isRealLog(w: Word) bool {
    if (tower.isComp(w)) return false;
    const x = num.toF(w).?;
    return !std.math.signbit(x) or std.math.isNan(x);
}

fn logImpl(t: *Thread) Err!Word {
    const z = try P.numArg(t, "log: not a number", 0);
    if (t.argc == 2) {
        const b = try P.numArg(t, "log: not a number", 1);
        if (isRealLog(z) and isRealLog(b)) return rt.safeFlo(t, logOf(z).re / logOf(b).re);
        return C.div(logOf(z), logOf(b)).word(t);
    }
    if (isRealLog(z)) return rt.safeFlo(t, logOf(z).re);
    return logOf(z).word(t);
}
pub const @"%log" = WD("log", logImpl, 1, 2);

fn atanImpl(t: *Thread) Err!Word {
    if (t.argc == 2) {
        const yw = try P.numArg(t, "atan: not a number", 0);
        const xw = try P.numArg(t, "atan: not a number", 1);
        if (tower.isComp(yw)) return raise(t, "Failed in atan: wrong argument type", &.{yw});
        if (tower.isComp(xw)) return raise(t, "Failed in atan: wrong argument type", &.{xw});
        return rt.safeFlo(t, std.math.atan2(num.toF(yw).?, num.toF(xw).?));
    }
    const w = try P.numArg(t, "atan: not a number", 0);
    if (!tower.isComp(w)) return rt.safeFlo(t, std.math.atan(num.toF(w).?));
    return C.atan(C.of(w)).word(t);
}
pub const @"%atan" = WD("atan", atanImpl, 1, 2);

fn makeE() callconv(.c) Word {
    return data.constFlonum(std.math.e);
}
pub const @"%E" = rt.ValuePrim{ .make = &makeE };

