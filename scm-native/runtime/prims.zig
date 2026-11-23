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
pub const any = std.math.maxInt(u64);

/// Record an error for the primitive's caller.
pub fn raise(t: *Thread, msg: []const u8, irritants: []const Word) Err {
    _ = rt.fail(t, msg, irritants);
    return error.Scheme;
}

/// Standard-convention code for f, with an arity check.
pub fn W(comptime f: fn (*Thread) Err!Word, comptime min: u64, comptime max: u64) Code {
    return WN("", f, min, max);
}

/// W for the primitive called name (for error messages)
pub fn WN(comptime name: []const u8, comptime f: fn (*Thread) Err!Word, comptime min: u64, comptime max: u64) Code {
    const S = struct {
        fn code(t: *Thread) callconv(.c) void {
            t.prim_name_ptr = name.ptr;
            t.prim_name_len = name.len;
            if (t.argc < min or t.argc > max) return @call(.always_tail, rt.arityErrorN(t, if (t.argc < min) min else max, min != max and t.argc < min), .{t});
            t.val = f(t) catch return @call(.always_tail, rt.errorCode, .{t});
            data.scratchReset();
            return @call(.always_tail, rt.retCode(t), .{t});
        }
    };
    return &S.code;
}

/// A primitive that never collects and never calls Scheme: besides its code,
/// compiled code can call it directly (scmd_<name>), as a Zig function that
/// takes its arguments in t.args and returns its value (UNBOUND on an error,
/// which is then pending in the thread).
pub const Direct = *const fn (*Thread) callconv(.c) Word;
pub const Prim = struct { code: Code, direct: Direct };

pub fn WD(comptime name: []const u8, comptime f: fn (*Thread) Err!Word, comptime min: u64, comptime max: u64) Prim {
    const S = struct {
        fn direct(t: *Thread) callconv(.c) Word {
            t.prim_name_ptr = name.ptr;
            t.prim_name_len = name.len;
            if (t.argc < min or t.argc > max) {
                _ = rt.arityErrorN(t, if (t.argc < min) min else max, min != max and t.argc < min);
                return rt.UNBOUND;
            }
            const v = f(t) catch return rt.UNBOUND;
            data.scratchReset();
            return v;
        }
    };
    return .{ .code = WN(name, f, min, max), .direct = &S.direct };
}

pub inline fn arg(t: *Thread, i: usize) Word {
    return t.args[i];
}

pub fn checkPair(t: *Thread, who: []const u8, w: Word) Err!Word {
    if (!rt.isPair(w)) return typeError(t, who);
    return w;
}

/// "Failed in <who>: wrong argument type", as the JVM implementation
pub fn typeError(t: *Thread, who: []const u8) Err {
    _ = rt.typeError(t, who, &.{});
    return error.Scheme;
}

/// typeError for the running primitive
pub fn argTypeError(t: *Thread) Err {
    return typeError(t, t.primName());
}

pub fn index(t: *Thread, w: Word, len: usize) Err!usize {
    if (!rt.isFix(w) or unfix(w) < 0 or unfix(w) >= len) return raise(t, "index out of range", &.{w});
    return @intCast(unfix(w));
}

pub fn count(t: *Thread, w: Word) Err!usize {
    if (!rt.isFix(w) or unfix(w) < 0) return raise(t, "not a valid length", &.{w});
    return @intCast(unfix(w));
}

pub fn numArg(t: *Thread, who: []const u8, i: usize) Err!Word {
    const w = arg(t, i);
    if (!num.isNumber(w)) return raise(t, who, &.{w});
    return w;
}

pub fn intArg(t: *Thread, who: []const u8, i: usize) Err!i64 {
    const w = arg(t, i);
    if (!rt.isFix(w)) return raise(t, who, &.{w});
    return unfix(w);
}

/// The length of a proper list; null for an improper or circular one
pub fn listLength(l: Word) ?usize {
    var n: usize = 0;
    var fast = l;
    var slow = l;
    while (rt.isPair(fast)) {
        fast = rt.cdr(fast);
        n += 1;
        if (!rt.isPair(fast)) break;
        fast = rt.cdr(fast);
        n += 1;
        slow = rt.cdr(slow);
        if (fast == slow) return null;
    }
    return if (fast == rt.NIL) n else null;
}

// --- control ---------------------------------------------------------------

pub const @"%call-with-current-continuation" = &rt.callccCode;
pub const @"%call/cc" = &rt.callccCode;
pub const @"%apply" = &rt.applyCode;

fn errorImpl(t: *Thread) Err!Word {
    const msg = arg(t, 0);
    var buf: std.ArrayList(u8) = .empty;
    printer.print(&buf, msg, false);
    t.setErrMsg(buf.items);
    t.err_n = @min(t.argc - 1, t.err_irritants.len);
    for (0..t.err_n) |i| t.err_irritants[i] = arg(t, i + 1);
    return error.Scheme;
}
pub const @"%error" = WN("error", errorImpl, 1, any);



fn procedureP(t: *Thread) Err!Word {
    return rt.boolean(rt.isProcedure(arg(t, 0)));
}
pub const @"%procedure?" = WD("procedure?", procedureP, 1, 1);

// --- pairs and lists -------------------------------------------------------

fn consImpl(t: *Thread) Err!Word {
    t.reserve(3);
    return t.cons(arg(t, 0), arg(t, 1));
}
pub const @"%cons" = WN("cons", consImpl, 2, 2);

fn carImpl(t: *Thread) Err!Word {
    return rt.car(try checkPair(t, "car", arg(t, 0)));
}
pub const @"%car" = WD("car", carImpl, 1, 1);

fn cdrImpl(t: *Thread) Err!Word {
    return rt.cdr(try checkPair(t, "cdr", arg(t, 0)));
}
pub const @"%cdr" = WD("cdr", cdrImpl, 1, 1);

fn setCarImpl(t: *Thread) Err!Word {
    rt.ptr(try checkPair(t, "set-car!", arg(t, 0)))[1] = arg(t, 1);
    rt.barrier(t, arg(t, 0), arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%set-car!" = WD("set-car!", setCarImpl, 2, 2);

fn setCdrImpl(t: *Thread) Err!Word {
    rt.ptr(try checkPair(t, "set-cdr!", arg(t, 0)))[2] = arg(t, 1);
    rt.barrier(t, arg(t, 0), arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%set-cdr!" = WD("set-cdr!", setCdrImpl, 2, 2);

fn pairP(t: *Thread) Err!Word {
    return rt.boolean(rt.isPair(arg(t, 0)));
}
pub const @"%pair?" = WD("pair?", pairP, 1, 1);

fn nullP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.NIL);
}
pub const @"%null?" = WD("null?", nullP, 1, 1);

fn listP(t: *Thread) Err!Word {
    return rt.boolean(listLength(arg(t, 0)) != null);
}
pub const @"%list?" = WD("list?", listP, 1, 1);

fn listImpl(t: *Thread) Err!Word {
    t.reserve(3 * t.argc);
    return rt.restList(t, 0);
}
pub const @"%list" = WN("list", listImpl, 0, any);

fn lengthImpl(t: *Thread) Err!Word {
    const n = listLength(arg(t, 0)) orelse return typeError(t, "length");
    return fix(@intCast(n));
}
pub const @"%length" = WD("length", lengthImpl, 1, 1);

fn reverseImpl(t: *Thread) Err!Word {
    const n = listLength(arg(t, 0)) orelse return typeError(t, "reverse");
    t.reserve(3 * n);
    var r = rt.NIL;
    var x = arg(t, 0);
    while (x != rt.NIL) : (x = rt.cdr(x)) r = t.cons(rt.car(x), r);
    return r;
}
pub const @"%reverse" = WN("reverse", reverseImpl, 1, 1);

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
pub const @"%append" = WN("append", appendImpl, 0, any);

// --- equivalence -----------------------------------------------------------

fn eqP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == arg(t, 1));
}
pub const @"%eq?" = WD("eq?", eqP, 2, 2);

fn eqvP(t: *Thread) Err!Word {
    return rt.boolean(data.eqv(arg(t, 0), arg(t, 1)));
}
pub const @"%eqv?" = WD("eqv?", eqvP, 2, 2);

fn equalP(t: *Thread) Err!Word {
    return rt.boolean(data.equal(arg(t, 0), arg(t, 1)));
}
pub const @"%equal?" = WD("equal?", equalP, 2, 2);

fn notImpl(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.FALSE);
}
pub const @"%not" = WD("not", notImpl, 1, 1);

fn booleanP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.TRUE or arg(t, 0) == rt.FALSE);
}
pub const @"%boolean?" = WD("boolean?", booleanP, 1, 1);

// --- characters ------------------------------------------------------------

fn charP(t: *Thread) Err!Word {
    return rt.boolean(rt.isChar(arg(t, 0)));
}
pub const @"%char?" = WD("char?", charP, 1, 1);

pub fn charArg(t: *Thread, i: usize) Err!u21 {
    const w = arg(t, i);
    if (!rt.isChar(w)) return argTypeError(t);
    return rt.charCode(w);
}

fn charToInteger(t: *Thread) Err!Word {
    return fix(try charArg(t, 0));
}
pub const @"%char->integer" = WD("char->integer", charToInteger, 1, 1);

fn integerToChar(t: *Thread) Err!Word {
    const n = try intArg(t, "integer->char: not an integer", 0);
    if (n < 0 or n > 0x10FFFF or (n >= 0xD800 and n <= 0xDFFF)) return raise(t, "integer->char: not a code point", &.{arg(t, 0)});
    return rt.char(@intCast(n));
}
pub const @"%integer->char" = WD("integer->char", integerToChar, 1, 1);

fn charEq(t: *Thread) Err!Word {
    for (1..t.argc) |i| if (try charArg(t, i - 1) != try charArg(t, i)) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%char=?" = WD("char=?", charEq, 1, any);

fn charLt(t: *Thread) Err!Word {
    for (1..t.argc) |i| if (!(try charArg(t, i - 1) < try charArg(t, i))) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%char<?" = WD("char<?", charLt, 1, any);

// --- strings ---------------------------------------------------------------

pub fn stringArg(t: *Thread, i: usize) Err!Word {
    const w = arg(t, i);
    if (!data.isString(w)) return argTypeError(t);
    return w;
}

fn stringP(t: *Thread) Err!Word {
    return rt.boolean(data.isString(arg(t, 0)));
}
pub const @"%string?" = WD("string?", stringP, 1, 1);

fn stringLength(t: *Thread) Err!Word {
    return fix(@intCast(data.stringLen(try stringArg(t, 0))));
}
pub const @"%string-length" = WD("string-length", stringLength, 1, 1);

fn stringRef(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    const i = try index(t, arg(t, 1), data.stringLen(s));
    return rt.char(data.stringRef(s, i));
}
pub const @"%string-ref" = WD("string-ref", stringRef, 2, 2);

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
pub const @"%string-set!" = WN("string-set!", stringSet, 3, 3);

fn makeStringImpl(t: *Thread) Err!Word {
    const n = try count(t, arg(t, 0));
    const fill: u21 = if (t.argc > 1) try charArg(t, 1) else ' ';
    t.reserve(data.stringWords(n, fill > 255));
    const s = data.makeString(t, n, fill > 255);
    for (0..n) |i| data.stringSetFits(s, i, fill);
    return s;
}
pub const @"%make-string" = WN("make-string", makeStringImpl, 1, 2);

/// A new string with the characters of `chars` (any iterator of code points).
fn copyChars(t: *Thread, src: Word, from: usize, to: usize) Word {
    // caller reserved stringWords(to - from, isWide(src)); src re-read by caller
    const n = to - from;
    const wide = data.isWide(src);
    const s = data.makeString(t, n, wide);
    for (0..n) |i| data.stringSetFits(s, i, data.stringRef(src, from + i));
    return s;
}

/// A substring index; negative ones count from the end (as the JVM
/// implementation)
fn stringIndex(t: *Thread, w: Word, len: usize) Err!usize {
    if (!rt.isFix(w)) return argTypeError(t);
    const i = unfix(w);
    const k = if (i < 0) @as(i64, @intCast(len)) + i else i;
    if (k < 0) return raise(t, "substring: index out of range", &.{w});
    return @intCast(k);
}

fn substringImpl(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    const len = data.stringLen(s);
    const from: usize = if (t.argc > 1) try stringIndex(t, arg(t, 1), len) else 0;
    const to: usize = if (t.argc > 2) try stringIndex(t, arg(t, 2), len) else len;
    if (from > to or to > len) return raise(t, "substring: index out of range", &.{ arg(t, 1), arg(t, 2) });
    t.reserve(data.stringWords(to - from, data.isWide(s)));
    return copyChars(t, arg(t, 0), from, to);
}
pub const @"%substring" = WN("substring", substringImpl, 1, 3);
pub const @"%string-copy" = WN("string-copy", substringImpl, 1, 3);

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
pub const @"%string-append" = WN("string-append", stringAppend, 0, any);

fn stringEqImpl(t: *Thread) Err!Word {
    for (0..t.argc) |i| _ = try stringArg(t, i);
    for (1..t.argc) |i| if (!data.stringEq(arg(t, i - 1), arg(t, i))) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%string=?" = WD("string=?", stringEqImpl, 1, any);

fn stringLtImpl(t: *Thread) Err!Word {
    for (0..t.argc) |i| _ = try stringArg(t, i);
    for (1..t.argc) |i| if (data.stringCmp(arg(t, i - 1), arg(t, i)) != .lt) return rt.FALSE;
    return rt.TRUE;
}
pub const @"%string<?" = WD("string<?", stringLtImpl, 1, any);

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
pub const @"%string->list" = WN("string->list", stringToList, 1, 1);

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
pub const @"%list->string" = WN("list->string", listToString, 1, 1);

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
pub const @"%string" = WN("string", stringImpl, 0, any);

// --- symbols ---------------------------------------------------------------

fn symbolP(t: *Thread) Err!Word {
    return rt.boolean(data.isSymbol(arg(t, 0)));
}
pub const @"%symbol?" = WD("symbol?", symbolP, 1, 1);

fn stringToSymbol(t: *Thread) Err!Word {
    const s = try stringArg(t, 0);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.heap.c_allocator);
    data.appendUtf8(&buf, s);
    return data.intern(buf.items);
}
pub const @"%string->symbol" = WD("string->symbol", stringToSymbol, 1, 1);

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
pub const @"%symbol->string" = WN("symbol->string", symbolToString, 1, 1);

// --- vectors ---------------------------------------------------------------

pub fn vectorArg(t: *Thread, i: usize) Err!Word {
    const w = arg(t, i);
    if (!data.isVector(w)) return argTypeError(t);
    return w;
}

fn vectorP(t: *Thread) Err!Word {
    return rt.boolean(data.isVector(arg(t, 0)));
}
pub const @"%vector?" = WD("vector?", vectorP, 1, 1);

fn makeVectorImpl(t: *Thread) Err!Word {
    const n = try count(t, arg(t, 0));
    t.reserve(1 + n);
    return data.makeVector(t, n, if (t.argc > 1) arg(t, 1) else fix(0));
}
pub const @"%make-vector" = WN("make-vector", makeVectorImpl, 1, 2);

fn vectorImpl(t: *Thread) Err!Word {
    t.reserve(1 + t.argc);
    const v = data.makeVector(t, t.argc, fix(0));
    @memcpy(data.vectorItems(v), t.args[0..t.argc]);
    return v;
}
pub const @"%vector" = WN("vector", vectorImpl, 0, any);

fn vectorIndex(t: *Thread, who: []const u8, v: Word) Err!usize {
    const i = arg(t, 1);
    if (!rt.isFix(i) or unfix(i) < 0 or unfix(i) >= data.vectorLen(v)) {
        _ = rt.indexError(t, who, i);
        return error.Scheme;
    }
    return @intCast(unfix(i));
}

// (vector-ref v k [default]): as the JVM implementation, default for k out
// of range (the open-coded two-argument calls do not get here)
fn vectorRef(t: *Thread) Err!Word {
    const v = try vectorArg(t, 0);
    if (t.argc == 3) {
        const i = arg(t, 1);
        if (rt.isFix(i) and (unfix(i) < 0 or unfix(i) >= data.vectorLen(v))) return arg(t, 2);
    }
    return data.vectorItems(v)[try vectorIndex(t, "vector-ref", v)];
}
pub const @"%vector-ref" = WD("vector-ref", vectorRef, 2, 3);

fn vectorSet(t: *Thread) Err!Word {
    const v = try vectorArg(t, 0);
    data.vectorItems(v)[try vectorIndex(t, "vector-set!", v)] = arg(t, 2);
    rt.barrier(t, v, arg(t, 2));
    return rt.UNSPEC;
}
pub const @"%vector-set!" = WD("vector-set!", vectorSet, 3, 3);

fn vectorLength(t: *Thread) Err!Word {
    return fix(@intCast(data.vectorLen(try vectorArg(t, 0))));
}
pub const @"%vector-length" = WD("vector-length", vectorLength, 1, 1);

fn vectorFill(t: *Thread) Err!Word {
    @memset(data.vectorItems(try vectorArg(t, 0)), arg(t, 1));
    rt.barrier(t, arg(t, 0), arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%vector-fill!" = WD("vector-fill!", vectorFill, 2, 2);

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
pub const @"%vector->list" = WN("vector->list", vectorToList, 1, 1);

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
pub const @"%list->vector" = WN("list->vector", listToVector, 1, 1);

