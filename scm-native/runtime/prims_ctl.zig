//! Primitives: control (dynamic-wind and handler state, multiple values,
//! errors, parameters), records, list utilities, process context.
const std = @import("std");
const builtin = @import("builtin");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const ports = @import("ports.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Code = rt.Code;
const Err = P.Err;
const W = P.W;
const WN = P.WN;
const arg = P.arg;
const raise = P.raise;
const any = P.any;
const fix = rt.fix;
const unfix = rt.unfix;

const pa = std.heap.page_allocator;

// --- dynamic state -----------------------------------------------------------

fn windersGet(t: *Thread) Err!Word {
    return t.winders;
}
fn windersSet(t: *Thread) Err!Word {
    t.winders = arg(t, 0);
    return rt.UNSPEC;
}
fn handlersGet(t: *Thread) Err!Word {
    return t.handlers;
}
fn handlersSet(t: *Thread) Err!Word {
    t.handlers = arg(t, 0);
    return rt.UNSPEC;
}
pub const @"%%winders-get" = WN("%winders-get", windersGet, 0, 0);
pub const @"%%winders-set!" = WN("%winders-set!", windersSet, 1, 1);
pub const @"%%exception-handlers-get" = WN("%exception-handlers-get", handlersGet, 0, 0);
pub const @"%%exception-handlers-set!" = WN("%exception-handlers-set!", handlersSet, 1, 1);

pub const @"%%call-with-escape-continuation" = &rt.callccCode;
fn escapeOnly(_: *Thread) Err!Word {
    return rt.FALSE;
}
pub const @"%%escape-only-receiver?" = WN("%escape-only-receiver?", escapeOnly, 1, 1);

pub const @"%values" = &rt.valuesCode;
pub const @"%call-with-values" = &rt.callWithValuesCode;

// --- errors ------------------------------------------------------------------

fn makeErrorObject(t: *Thread) Err!Word {
    t.reserve(4);
    if (!data.isString(arg(t, 0))) return raise(t, "%make-error-object: message is not a string", &.{arg(t, 0)});
    return rt.makeError(t, arg(t, 0), arg(t, 1), 0);
}
pub const @"%%make-error-object" = WN("%make-error-object", makeErrorObject, 2, 2);
pub const @"%%raise-fatal" = &rt.raiseFatalCode;

fn errorObjectP(t: *Thread) Err!Word {
    return rt.boolean(rt.isObj(arg(t, 0), rt.T_ERROR));
}
pub const @"%error-object?" = WN("error-object?", errorObjectP, 1, 1);

fn errArg(t: *Thread) Err!Word {
    const e = arg(t, 0);
    if (!rt.isObj(e, rt.T_ERROR)) return raise(t, "not an error object", &.{e});
    return e;
}
fn errorObjectMessage(t: *Thread) Err!Word {
    return rt.ptr(try errArg(t))[1];
}
fn errorObjectIrritants(t: *Thread) Err!Word {
    return rt.ptr(try errArg(t))[2];
}
fn readErrorP(t: *Thread) Err!Word {
    const e = arg(t, 0);
    return rt.boolean(rt.isObj(e, rt.T_ERROR) and rt.ptr(e)[3] == fix(rt.ErrorKind.read));
}
fn fileErrorP(t: *Thread) Err!Word {
    const e = arg(t, 0);
    return rt.boolean(rt.isObj(e, rt.T_ERROR) and rt.ptr(e)[3] == fix(rt.ErrorKind.file));
}
pub const @"%error-object-message" = WN("error-object-message", errorObjectMessage, 1, 1);
pub const @"%error-object-irritants" = WN("error-object-irritants", errorObjectIrritants, 1, 1);
pub const @"%read-error?" = WN("read-error?", readErrorP, 1, 1);
pub const @"%file-error?" = WN("file-error?", fileErrorP, 1, 1);

// --- parameters: a procedure over a box ----------------------------------------

fn makeParameter(t: *Thread) Err!Word {
    t.reserve(2 + 3);
    const b = t.box(arg(t, 0));
    const c = t.closure(&parameterCode, 1);
    c[2] = b;
    return rt.tagPtr(c);
}
fn parameterCode(t: *Thread) callconv(.c) void {
    const b = rt.ptr(t.free(0));
    switch (t.argc) {
        0 => t.val = b[1],
        1 => {
            b[1] = t.args[0];
            t.val = rt.UNSPEC;
        },
        else => return @call(.always_tail, rt.arityError(t), .{t}),
    }
    return @call(.always_tail, rt.retCode(t), .{t});
}
pub const @"%%make-parameter" = WN("%make-parameter", makeParameter, 1, 1);

// --- records -------------------------------------------------------------------

fn makeRecordImpl(t: *Thread) Err!Word {
    const n = try P.count(t, arg(t, 0));
    t.reserve(1 + n);
    return data.makeRecord(t, n);
}
fn recordP(t: *Thread) Err!Word {
    return rt.boolean(data.isRecord(arg(t, 0)));
}
fn recordRef(t: *Thread) Err!Word {
    const r = arg(t, 0);
    if (!data.isRecord(r)) return raise(t, "record-ref: not a record", &.{r});
    return data.recordSlots(r)[try P.index(t, arg(t, 1), data.recordSize(r))];
}
fn recordSet(t: *Thread) Err!Word {
    const r = arg(t, 0);
    if (!data.isRecord(r)) return raise(t, "record-set!: not a record", &.{r});
    data.recordSlots(r)[try P.index(t, arg(t, 1), data.recordSize(r))] = arg(t, 2);
    return rt.UNSPEC;
}
pub const @"%make-record" = WN("make-record", makeRecordImpl, 1, 1);
pub const @"%record?" = WN("record?", recordP, 1, 1);
pub const @"%record-ref" = WN("record-ref", recordRef, 2, 2);
pub const @"%record-set!" = WN("record-set!", recordSet, 3, 3);

inline fn isInstance(x: Word, ty: Word) bool {
    return data.isRecord(x) and data.recordSize(x) > 0 and data.recordSlots(x)[0] == ty;
}

/// (%record-procedure kind type arg extra): a specialized procedure, as
/// in the JVM implementation. Free variables: constructor [type indexes
/// size], predicate [type], accessor/modifier [type index tag].
fn recordProcedure(t: *Thread) Err!Word {
    t.reserve(2 + 3);
    const kind = data.symbolName(arg(t, 0));
    const c = if (std.mem.eql(u8, kind, "constructor"))
        t.closure(&recordConstructorCode, 3)
    else if (std.mem.eql(u8, kind, "predicate"))
        t.closure(&recordPredicateCode, 3)
    else if (std.mem.eql(u8, kind, "accessor"))
        t.closure(&recordAccessorCode, 3)
    else if (std.mem.eql(u8, kind, "modifier"))
        t.closure(&recordModifierCode, 3)
    else
        return raise(t, "%record-procedure: unknown kind", &.{arg(t, 0)});
    c[2] = arg(t, 1);
    c[3] = arg(t, 2);
    c[4] = arg(t, 3);
    return rt.tagPtr(c);
}
pub const @"%%record-procedure" = WN("%record-procedure", recordProcedure, 4, 4);

fn recordConstructorCode(t: *Thread) callconv(.c) void {
    const indexes = t.free(1);
    const n = data.vectorLen(indexes);
    if (t.argc != n) {
        // irritants: the type and the arguments, as the JVM implementation
        t.reserve(3 * t.argc);
        const args = rt.restList(t, 0);
        return @call(.always_tail, rt.fail(t, "wrong number of arguments to constructor", &.{ t.free(0), args }), .{t});
    }
    const size: usize = @intCast(unfix(t.free(2)));
    t.reserve(1 + size);
    const r = data.makeRecord(t, size);
    const slots = data.recordSlots(r);
    slots[0] = t.free(0);
    for (data.vectorItems(t.free(1)), 0..) |ix, i| slots[@intCast(unfix(ix))] = t.args[i];
    t.val = r;
    return @call(.always_tail, rt.retCode(t), .{t});
}

fn recordPredicateCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, rt.arityError(t), .{t});
    t.val = rt.boolean(isInstance(t.args[0], t.free(0)));
    return @call(.always_tail, rt.retCode(t), .{t});
}

fn recordAccessorCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, rt.arityError(t), .{t});
    const x = t.args[0];
    if (!isInstance(x, t.free(0))) return @call(.always_tail, rt.fail(t, "accessor applied to bad value", &.{ t.free(0), t.free(2), x }), .{t});
    t.val = data.recordSlots(x)[@intCast(unfix(t.free(1)))];
    return @call(.always_tail, rt.retCode(t), .{t});
}

fn recordModifierCode(t: *Thread) callconv(.c) void {
    if (t.argc != 2) return @call(.always_tail, rt.arityError(t), .{t});
    const x = t.args[0];
    if (!isInstance(x, t.free(0))) return @call(.always_tail, rt.fail(t, "modifier applied to bad value", &.{ t.free(0), t.free(2), x }), .{t});
    data.recordSlots(x)[@intCast(unfix(t.free(1)))] = t.args[1];
    t.val = rt.UNSPEC;
    return @call(.always_tail, rt.retCode(t), .{t});
}

// --- procedures ------------------------------------------------------------------

fn lambdaP(t: *Thread) Err!Word {
    return rt.boolean(rt.isProcedure(arg(t, 0)) and !rt.isPrimitive(arg(t, 0)));
}
fn primitiveP(t: *Thread) Err!Word {
    return rt.boolean(rt.isPrimitive(arg(t, 0)));
}
pub const @"%lambda?" = WN("lambda?", lambdaP, 1, 1);
pub const @"%primitive?" = WN("primitive?", primitiveP, 1, 1);

var gensym_counter: u64 = 0;
fn gensymImpl(t: *Thread) Err!Word {
    gensym_counter += 1;
    var prefix: []const u8 = "g";
    if (t.argc > 0) {
        const a = arg(t, 0);
        if (data.isSymbol(a)) prefix = data.symbolName(a) else if (data.isString(a)) prefix = data.toUtf8(a);
    }
    const name = std.fmt.allocPrint(pa, "{s}{d}", .{ prefix, gensym_counter }) catch rt.oom();
    return data.intern(name);
}
pub const @"%gensym" = WN("gensym", gensymImpl, 0, 1);

// --- lists -----------------------------------------------------------------------

fn cxr(comptime path: []const u8) Code {
    const S = struct {
        fn f(t: *Thread) Err!Word {
            var x = arg(t, 0);
            comptime var i = path.len;
            inline while (i > 0) {
                i -= 1;
                if (!rt.isPair(x)) return P.typeError(t, "c" ++ path ++ "r");
                x = if (path[i] == 'a') rt.car(x) else rt.cdr(x);
            }
            return x;
        }
    };
    return W(S.f, 1, 1);
}
pub const @"%caar" = cxr("aa");
pub const @"%cadr" = cxr("ad");
pub const @"%cdar" = cxr("da");
pub const @"%cddr" = cxr("dd");
pub const @"%caaar" = cxr("aaa");
pub const @"%caadr" = cxr("aad");
pub const @"%cadar" = cxr("ada");
pub const @"%caddr" = cxr("add");
pub const @"%cdaar" = cxr("daa");
pub const @"%cdadr" = cxr("dad");
pub const @"%cddar" = cxr("dda");
pub const @"%cdddr" = cxr("ddd");
pub const @"%caaaar" = cxr("aaaa");
pub const @"%caaadr" = cxr("aaad");
pub const @"%caadar" = cxr("aada");
pub const @"%caaddr" = cxr("aadd");
pub const @"%cadaar" = cxr("adaa");
pub const @"%cadadr" = cxr("adad");
pub const @"%caddar" = cxr("adda");
pub const @"%cadddr" = cxr("addd");
pub const @"%cdaaar" = cxr("daaa");
pub const @"%cdaadr" = cxr("daad");
pub const @"%cdadar" = cxr("dada");
pub const @"%cdaddr" = cxr("dadd");
pub const @"%cddaar" = cxr("ddaa");
pub const @"%cddadr" = cxr("ddad");
pub const @"%cdddar" = cxr("ddda");
pub const @"%cddddr" = cxr("dddd");
pub const @"%first" = cxr("a");
pub const @"%second" = cxr("ad");

fn listRef(t: *Thread) Err!Word {
    var x = arg(t, 0);
    var k = try P.count(t, arg(t, 1));
    while (k > 0) : (k -= 1) {
        if (!rt.isPair(x)) return raise(t, "list-ref: index out of range", &.{arg(t, 1)});
        x = rt.cdr(x);
    }
    if (!rt.isPair(x)) return raise(t, "list-ref: index out of range", &.{arg(t, 1)});
    return rt.car(x);
}
pub const @"%list-ref" = WN("list-ref", listRef, 2, 2);

fn mem(comptime eq: fn (Word, Word) bool) Code {
    const S = struct {
        fn f(t: *Thread) Err!Word {
            var l = arg(t, 1);
            while (rt.isPair(l)) : (l = rt.cdr(l)) if (eq(arg(t, 0), rt.car(l))) return l;
            return rt.FALSE;
        }
    };
    return W(S.f, 2, 2);
}
fn ass(comptime eq: fn (Word, Word) bool) Code {
    const S = struct {
        fn f(t: *Thread) Err!Word {
            var l = arg(t, 1);
            while (rt.isPair(l)) : (l = rt.cdr(l)) {
                const e = rt.car(l);
                if (!rt.isPair(e)) return raise(t, "assoc list element is not a pair", &.{e});
                if (eq(arg(t, 0), rt.car(e))) return e;
            }
            return rt.FALSE;
        }
    };
    return W(S.f, 2, 2);
}
fn eqFn(a: Word, b: Word) bool {
    return a == b;
}
pub const @"%memq" = mem(eqFn);
pub const @"%memv" = mem(data.eqv);
pub const @"%member" = mem(data.equal);
pub const @"%assq" = ass(eqFn);
pub const @"%assv" = ass(data.eqv);
pub const @"%assoc" = ass(data.equal);

fn eofObject(_: *Thread) Err!Word {
    return rt.EOF;
}
fn eofObjectP(t: *Thread) Err!Word {
    return rt.boolean(arg(t, 0) == rt.EOF);
}
pub const @"%eof-object" = WN("eof-object", eofObject, 0, 0);
pub const @"%eof-object?" = WN("eof-object?", eofObjectP, 1, 1);

// --- process context ---------------------------------------------------------------

fn commandLine(t: *Thread) Err!Word {
    var total: usize = 0;
    for (rt.command_line) |a| total += data.stringWords(a.len, true) + 3;
    t.reserve(total);
    var l = rt.NIL;
    var i = rt.command_line.len;
    while (i > 0) {
        i -= 1;
        l = t.cons(data.heapStringUtf8(t, rt.command_line[i]), l);
    }
    return l;
}
pub const @"%command-line" = WN("command-line", commandLine, 0, 0);

fn getEnv(t: *Thread) Err!Word {
    const name = data.toUtf8(try P.stringArg(t, 0));
    const v = rt.os.getEnv(name) orelse return rt.FALSE;
    t.reserve(data.stringWords(v.len, true));
    return data.heapStringUtf8(t, v);
}
pub const @"%get-environment-variable" = WN("get-environment-variable", getEnv, 1, 1);

fn getEnvs(t: *Thread) Err!Word {
    const pairs = rt.os.envPairs();
    var total: usize = 0;
    for (pairs) |kv| total += data.stringWords(kv[0].len, true) + data.stringWords(kv[1].len, true) + 6;
    t.reserve(total);
    var l = rt.NIL;
    for (pairs) |kv| {
        const k = data.heapStringUtf8(t, kv[0]);
        const v = data.heapStringUtf8(t, kv[1]);
        l = t.cons(t.cons(k, v), l);
    }
    return l;
}
pub const @"%get-environment-variables" = WN("get-environment-variables", getEnvs, 0, 0);

fn exitCode(w: Word) u8 {
    if (w == rt.FALSE) return 1;
    if (rt.isFix(w)) return @truncate(@as(u64, @bitCast(unfix(w))));
    return 0;
}
fn exitImpl(t: *Thread) Err!Word {
    ports.flushAll();
    rt.os.exit(if (t.argc > 0) exitCode(arg(t, 0)) else t.exit_code);
}
pub const @"%exit" = WN("exit", exitImpl, 0, 1);
fn setExitCode(t: *Thread) Err!Word {
    t.exit_code = exitCode(arg(t, 0));
    return rt.UNSPEC;
}
pub const @"%set-exit-code!" = WN("set-exit-code!", setExitCode, 1, 1);

fn jiffy(_: *Thread) Err!Word {
    return fix(rt.os.jiffy());
}
pub const @"%current-jiffy" = WN("current-jiffy", jiffy, 0, 0);
pub const @"%%jiffy" = WN("%jiffy", jiffy, 0, 0);

fn currentSourceLocation(_: *Thread) Err!Word {
    return rt.FALSE;
}
pub const @"%current-source-location" = WN("current-source-location", currentSourceLocation, 0, 0);

fn features(t: *Thread) Err!Word {
    const os_features: []const []const u8 = switch (builtin.os.tag) {
        .windows => &.{"windows"},
        .macos => &.{ "darwin", "unix" },
        else => &.{ "gnu-linux", "unix" },
    };
    const arch: []const u8 = if (builtin.cpu.arch == .aarch64) "arm64" else "x86-64";
    const base = [_][]const u8{ "r7rs", "scm", "dabscm-native", "exact-closed", "ieee-float" };
    const srfis = [_][]const u8{ "srfi-1", "srfi-2", "srfi-8", "srfi-9", "srfi-13", "srfi-14", "srfi-18", "srfi-19", "srfi-26", "srfi-27", "srfi-28", "srfi-39", "srfi-64", "srfi-69", "srfi-95", "srfi-98", "srfi-111", "srfi-125", "srfi-128", "srfi-132", "srfi-133", "srfi-151", "srfi-158", "srfi-194", "srfi-271" };
    t.reserve(3 * 48);
    var l = rt.NIL;
    var j = srfis.len;
    while (j > 0) {
        j -= 1;
        l = t.cons(data.intern(srfis[j]), l);
    }
    l = t.cons(data.intern("little-endian"), l);
    l = t.cons(data.intern(arch), l);
    var i = os_features.len;
    while (i > 0) {
        i -= 1;
        l = t.cons(data.intern(os_features[i]), l);
    }
    i = base.len;
    while (i > 0) {
        i -= 1;
        l = t.cons(data.intern(base[i]), l);
    }
    return l;
}
pub const @"%%features-list" = WN("%features-list", features, 0, 0);
pub const @"%features" = WN("features", features, 0, 0);
