//! dabscm native runtime: values, thread state, GC and control.
//!
//! Calling convention (see scm-native/README.md):
//!   * every code block is `fn (*Thread) callconv(.c) void` and transfers
//!     control with `@call(.always_tail, next, .{t})`
//!   * arguments in t.args[0..argc], the callee closure in t.self, the return
//!     value in t.val
//!   * a non-tail call pushes a frame: live slots, then a pointer to a static
//!     RetInfo {code, size}
//!   * code that allocates first calls `t.reserve(n)` while every live value
//!     is in a root (args, self, val, stack, globals); after that it
//!     bump-allocates without checks, so the GC never sees Zig locals
//!   * objects of a size not known at block entry (bignums, ...) come from
//!     the large-object space (allocLarge), which never collects
const std = @import("std");
pub const os = @import("os.zig");

pub const abi = @import("abi.zig");
pub const Word = abi.Word;
pub const Code = abi.Code;
pub const RetInfo = abi.RetInfo;
pub const FALSE = abi.FALSE;
pub const TRUE = abi.TRUE;
pub const NIL = abi.NIL;
pub const UNSPEC = abi.UNSPEC;
pub const EOF = abi.EOF;
pub const UNBOUND = abi.UNBOUND;
pub const DEFAULT = abi.DEFAULT;
pub const fix_max = abi.fix_max;
pub const fix_min = abi.fix_min;
pub const fix = abi.fix;
pub const unfix = abi.unfix;
pub const isFix = abi.isFix;
pub const fixFits = abi.fixFits;
pub const isPtr = abi.isPtr;
pub const ptr = abi.ptr;
pub const tagPtr = abi.tagPtr;
pub const boolean = abi.boolean;
pub const isTrue = abi.isTrue;
pub const char = abi.char;
pub const isChar = abi.isChar;
pub const charCode = abi.charCode;
pub const T_PAIR = abi.T_PAIR;
pub const T_CLOSURE = abi.T_CLOSURE;
pub const T_STACK = abi.T_STACK;
pub const T_VECTOR = abi.T_VECTOR;
pub const T_BOX = abi.T_BOX;
pub const T_FLONUM = abi.T_FLONUM;
pub const T_STRING = abi.T_STRING;
pub const T_BUF8 = abi.T_BUF8;
pub const T_BUF32 = abi.T_BUF32;
pub const T_SYMBOL = abi.T_SYMBOL;
pub const T_VALUES = abi.T_VALUES;
pub const T_RECORD = abi.T_RECORD;
pub const T_ERROR = abi.T_ERROR;
pub const T_PORT = abi.T_PORT;
pub const T_BYTEVECTOR = abi.T_BYTEVECTOR;
pub const T_BIGNUM = abi.T_BIGNUM;
pub const T_RATNUM = abi.T_RATNUM;
pub const T_COMPNUM = abi.T_COMPNUM;
pub const T_HASHTABLE = abi.T_HASHTABLE;
pub const T_NATIVE = abi.T_NATIVE;
pub const T_FWD = abi.T_FWD;
pub const F_LARGE = abi.F_LARGE;
pub const F_MARK = abi.F_MARK;
pub const F_PRIM = abi.F_PRIM;
pub const F_PERM = abi.F_PERM;
pub const F_ESCAPE = abi.F_ESCAPE;
pub const hdr = abi.hdr;
pub const hdrType = abi.hdrType;
pub const hdrFlags = abi.hdrFlags;
pub const hdrLen = abi.hdrLen;
pub const objType = abi.objType;
pub const isObj = abi.isObj;
pub const isPair = abi.isPair;
pub const car = abi.car;
pub const cdr = abi.cdr;
pub const isFlonum = abi.isFlonum;
pub const flo = abi.flo;
pub const isProcedure = abi.isProcedure;
pub const isPrimitive = abi.isPrimitive;
pub const Thread = abi.Thread;
pub const Special = abi.Special;
pub const retCode = abi.retCode;
pub const enter = abi.enter;
pub const ignore = abi.ignore;
pub const barrier = abi.barrier;

// ---------------------------------------------------------------------------
// Static objects: constants, symbols and primitive procedures. They never
// move; those that can point into the heap are scanned at every collection.

var static_arena: std.heap.ArenaAllocator = .init(std.heap.c_allocator);
var static_scan: std.ArrayList([*]Word) = .empty;

pub fn staticAlloc(n: usize, scan: bool) [*]Word {
    const mem = static_arena.allocator().alignedAlloc(Word, .@"8", n) catch oom();
    if (scan) static_scan.append(std.heap.c_allocator, mem.ptr) catch oom();
    return mem.ptr;
}

pub fn oom() noreturn {
    os.fatal("out of memory", .{});
}

// ---------------------------------------------------------------------------
// Thread state (abi.Thread) and the large-object space

var large: std.ArrayList([*]Word) = .empty;

pub fn newThread() *Thread {
    const pa = std.heap.c_allocator;
    const heap = pa.alloc(Word, nursery_words) catch oom();
    const stack = pa.alloc(Word, 1 << 12) catch oom();
    const args = pa.alloc(Word, 256) catch oom();
    @memset(args, fix(0));
    const t = pa.create(Thread) catch oom();
    t.* = .{
        .args = args.ptr,
        .args_len = args.len,
        .stack = stack.ptr,
        .stack_len = stack.len,
        .hp = heap.ptr,
        .hlimit = nurseryEnd(heap),
        .heap = heap.ptr,
        .heap_len = heap.len,
        .flo_ptr = nurseryEnd(heap),
    };
    return t;
}

/// An object of n words (header included) that is not moved by the GC;
/// allocating it never collects, so it is safe anywhere.
pub fn allocLarge(t: *Thread, n: usize) [*]Word {
    const mem = std.heap.c_allocator.alloc(Word, n) catch oom();
    large.append(std.heap.c_allocator, mem.ptr) catch oom();
    t.large_words += n;
    large_since_major += n;
    // a major collection (which sweeps this space) at the next check
    if (large_since_major > @max(old_space.len, nursery_words)) {
        major_requested = true;
        t.hlimit = t.heap - 1;
        t.gc_requested = 1;
    }
    return mem.ptr;
}

pub fn growStackEntry(t: *Thread, need: usize) void {
    growStack(t, need);
}

pub fn growArgsEntry(t: *Thread, need: usize) void {
    growArgs(t, need);
}

pub fn gcEntry(t: *Thread, need: usize) void {
    gc(t, need);
}

/// The nursery is the heap without its top quarter (the flonum area)
fn nurseryEnd(heap: []Word) [*]Word {
    return heap.ptr + (heap.len - heap.len / 4);
}

/// A flonum made where no words were reserved (arithmetic slow paths): from
/// the flonum area, else from the large-object space; never collects.
pub fn safeFlo(t: *Thread, f: f64) Word {
    var q: [*]Word = undefined;
    if (@intFromPtr(t.flo_ptr) + 16 <= @intFromPtr(t.heap + t.heap_len)) {
        q = t.flo_ptr;
        t.flo_ptr += 2;
        q[0] = hdr(T_FLONUM, 1);
    } else {
        q = allocLarge(t, 2);
        q[0] = hdr(T_FLONUM, 1) | (@as(Word, F_LARGE) << 8);
        t.hlimit = t.heap - 1; // collect at the next check (even reserve(0))
        t.gc_requested = 1;
    }
    q[1] = @bitCast(f);
    return tagPtr(q);
}

fn growStack(t: *Thread, need: usize) void {
    var n = t.stack_len * 2;
    while (n < need) n *= 2;
    const s = std.heap.c_allocator.realloc(t.stack[0..t.stack_len], n) catch oom();
    t.stack = s.ptr;
    t.stack_len = s.len;
}

fn growArgs(t: *Thread, need: usize) void {
    var n = t.args_len * 2;
    while (n < need) n *= 2;
    const old = t.args_len;
    const a = std.heap.c_allocator.realloc(t.args[0..t.args_len], n) catch oom();
    @memset(a[old..], fix(0));
    t.args = a.ptr;
    t.args_len = a.len;
}

// ---------------------------------------------------------------------------
// Control. Helpers return the code to tail-call, so every transfer in
// generated code is a single `@call(.always_tail, ..., .{t})`.

pub fn notProcedure(t: *Thread, p: Word) Code {
    var buf: std.ArrayList(u8) = .empty;
    printer.print(&buf, p, true);
    return fail(t, std.fmt.allocPrint(std.heap.c_allocator, "{s} is not a function, cannot apply", .{buf.items}) catch oom(), &.{});
}

/// Record an error and return the code that raises it.
pub fn fail(t: *Thread, msg: []const u8, irritants: []const Word) Code {
    return failKind(t, 0, msg, irritants);
}

pub const ErrorKind = struct {
    pub const general = 0;
    pub const read = 1;
    pub const file = 2;
};

pub fn failKind(t: *Thread, kind: i64, msg: []const u8, irritants: []const Word) Code {
    t.err_kind = kind;
    if (std.mem.indexOfScalar(u8, msg, '~') != null) {
        // as the JVM implementation's SchemeError: ~s and ~a take the
        // arguments into the message, which then has no irritants
        var buf: std.ArrayList(u8) = .empty;
        var k: usize = 0;
        var i: usize = 0;
        while (i < msg.len) : (i += 1) {
            if (msg[i] == '~' and i + 1 < msg.len) {
                const d = msg[i + 1];
                if ((d == 's' or d == 'a') and k < irritants.len) {
                    @import("printer.zig").print(&buf, irritants[k], d == 's');
                    k += 1;
                    i += 1;
                    continue;
                }
                if (d == '~') {
                    buf.append(std.heap.c_allocator, '~') catch oom();
                    i += 1;
                    continue;
                }
            }
            buf.append(std.heap.c_allocator, msg[i]) catch oom();
        }
        t.setErrMsg(buf.items);
        t.err_n = 0;
        return &errorCode;
    }
    t.setErrMsg(msg);
    t.err_n = @min(irritants.len, t.err_irritants.len);
    for (0..t.err_n) |i| t.err_irritants[i] = irritants[i];
    return &errorCode;
}

pub fn arityError(t: *Thread) Code {
    return fail(t, std.fmt.allocPrint(std.heap.c_allocator, "Wrong number of arguments: {d} supplied", .{t.argc}) catch oom(), &.{});
}

/// Arity error of a procedure taking n arguments (or at least n), in the
/// JVM implementation's words
pub fn arityErrorN(t: *Thread, n: u64, at_least: bool) Code {
    const msg = if (at_least)
        std.fmt.allocPrint(std.heap.c_allocator, "Wrong number of arguments: at least {d} expected, {d} supplied", .{ n, t.argc })
    else
        std.fmt.allocPrint(std.heap.c_allocator, "Wrong number of arguments: {d} expected, {d} supplied", .{ n, t.argc });
    return fail(t, msg catch oom(), &.{});
}

/// name: "<module>: <variable>"
pub fn unboundError(t: *Thread, name: []const u8) Code {
    return fail(t, std.fmt.allocPrint(std.heap.c_allocator, "{s} is not bound", .{name}) catch oom(), &.{});
}

/// "Failed in <who>: wrong argument type", with the argument that is not
/// a number as irritant for arithmetic (as the JVM implementation)
pub fn typeError(t: *Thread, who: []const u8, irritants: []const Word) Code {
    const msg = std.fmt.allocPrint(std.heap.c_allocator, "Failed in {s}: wrong argument type", .{who}) catch oom();
    return fail(t, msg, irritants);
}

pub fn arithError(t: *Thread, who: []const u8, a: Word, b: Word) Code {
    if (!num.isNumber(a)) return typeError(t, who, &.{a});
    if (!num.isNumber(b)) return typeError(t, who, &.{b});
    return fail(t, std.fmt.allocPrint(std.heap.c_allocator, "{s}: Division by zero", .{who}) catch oom(), &.{});
}

pub fn indexError(t: *Thread, who: []const u8, i: Word) Code {
    var buf: std.ArrayList(u8) = .empty;
    printer.print(&buf, i, true);
    return fail(t, std.fmt.allocPrint(std.heap.c_allocator, "{s}: index out of range: {s}", .{ who, buf.items }) catch oom(), &.{});
}

/// vector-ref and vector-set! errors
pub fn vectorError(t: *Thread, who: []const u8, v: Word, i: Word) Code {
    if (!data.isVector(v) or !isFix(i)) return typeError(t, who, &.{});
    return indexError(t, who, i);
}

/// Raise the pending error (t.err_*) as an error object, through the
/// program's raise procedure when there is one.
pub fn errorCode(t: *Thread) callconv(.c) void {
    const n = t.err_n;
    t.reserve(data.stringWords(t.err_msg_len, true) + 3 * n + 4);
    const msg = data.heapStringUtf8(t, t.errMsg());
    var irritants = NIL;
    var i = n;
    while (i > 0) {
        i -= 1;
        irritants = t.cons(t.err_irritants[i], irritants);
    }
    const e = makeError(t, msg, irritants, t.err_kind);
    t.err_n = 0;
    t.args[0] = e;
    t.argc = 1;
    if (t.special(.raise)) |r| return @call(.always_tail, enter(t, r), .{t});
    return @call(.always_tail, raiseFatalCode, .{t});
}

/// An error object; reserve 4 words first.
pub fn makeError(t: *Thread, msg: Word, irritants: Word, kind: i64) Word {
    const q = t.allocRaw(4);
    q[0] = hdr(T_ERROR, 3);
    q[1] = msg;
    q[2] = irritants;
    q[3] = fix(kind);
    return tagPtr(q);
}

/// (%raise-fatal condition): as the JVM implementation, raise the condition
/// (as an error object) to the remaining handlers, if any; else report it
/// and exit.
pub fn raiseFatalCode(t: *Thread) callconv(.c) void {
    if (t.handlers != NIL) if (t.special(.raise)) |r| {
        if (!isObj(t.args[0], T_ERROR)) {
            var buf: std.ArrayList(u8) = .empty;
            printer.print(&buf, t.args[0], false);
            t.reserve(data.stringWords(buf.items.len, true) + 4);
            const msg = data.heapStringUtf8(t, buf.items);
            t.args[0] = makeError(t, msg, NIL, 0);
        }
        t.argc = 1;
        return @call(.always_tail, enter(t, r), .{t});
    };
    os.flush();
    var buf: std.ArrayList(u8) = .empty;
    const a = std.heap.c_allocator;
    const c = t.args[0];
    if (isObj(c, T_ERROR)) {
        printer.print(&buf, ptr(c)[1], false);
        var l = ptr(c)[2];
        while (isPair(l)) : (l = cdr(l)) {
            buf.append(a, ' ') catch oom();
            printer.print(&buf, car(l), true);
        }
    } else {
        buf.appendSlice(a, "uncaught exception: ") catch oom();
        printer.print(&buf, c, true);
    }
    buf.append(a, '\n') catch oom();
    ports.flushAll();
    os.eprint("{s}", .{buf.items});
    os.exit(1); // as the JVM implementation
}

fn haltCode(_: *Thread) callconv(.c) void {}
pub const halt_info: RetInfo = .{ .code = &haltCode, .size = 0 };

/// Run procedure `p` with the arguments already in t.args, to completion.
pub fn run(t: *Thread, p: Word, argc: u64) Word {
    t.sp = 0;
    t.ensureStack(1);
    t.pushRet(&halt_info);
    t.argc = argc;
    enter(t, p)(t);
    return t.val;
}

/// A static procedure object for code that needs no free variables.
pub fn staticProc(code: Code) Word {
    const q = staticAlloc(2, false);
    q[0] = hdr(T_CLOSURE, 1);
    q[1] = @intFromPtr(code);
    return tagPtr(q);
}

/// The procedure object of a primitive (named, for printing)
pub fn primitive(code: Code, name: []const u8) Word {
    const q = staticAlloc(3, false);
    q[0] = hdr(T_CLOSURE, 2) | (@as(Word, F_PRIM) << 8);
    q[1] = @intFromPtr(code);
    q[2] = data.intern(name);
    return tagPtr(q);
}

pub fn notProcedureCode(t: *Thread) callconv(.c) void {
    return @call(.always_tail, fail(t, "not a procedure", &.{}), .{t});
}

/// A primitive that is a value
pub const ValuePrim = struct { make: *const fn () callconv(.c) Word };

/// A procedure for a primitive the native runtime does not implement yet:
/// calling it is an error.
pub fn missingPrimitive(name: []const u8) Word {
    const q = staticAlloc(3, true);
    q[0] = hdr(T_CLOSURE, 2) | (@as(Word, F_PRIM) << 8);
    q[1] = @intFromPtr(&missingPrimitiveCode);
    q[2] = data.intern(name);
    return tagPtr(q);
}

fn missingPrimitiveCode(t: *Thread) callconv(.c) void {
    return @call(.always_tail, fail(t, "primitive not implemented in dabscm native:", &.{t.free(0)}), .{t});
}

/// The rest list of a variadic procedure: t.args[nreq..argc].
/// The caller reserves 3 * (argc - nreq) words first.
pub fn restList(t: *Thread, nreq: usize) Word {
    var l = NIL;
    var i = t.argc;
    while (i > nreq) {
        i -= 1;
        l = t.cons(t.args[i], l);
    }
    return l;
}

// ---------------------------------------------------------------------------
// Multiple values

/// t.val for a return of the values in t.args[0..argc]; reserve 1 + argc.
pub fn valuesOf(t: *Thread) Word {
    if (t.argc == 1) return t.args[0];
    const q = t.allocRaw(1 + t.argc);
    q[0] = hdr(T_VALUES, t.argc);
    @memcpy(q[1 .. 1 + t.argc], t.args[0..t.argc]);
    return tagPtr(q);
}

pub fn valuesCode(t: *Thread) callconv(.c) void {
    t.reserve(1 + t.argc);
    t.val = valuesOf(t);
    return @call(.always_tail, retCode(t), .{t});
}

/// (call-with-values producer consumer)
pub fn callWithValuesCode(t: *Thread) callconv(.c) void {
    if (t.argc != 2) return @call(.always_tail, arityError(t), .{t});
    t.ensureStack(2);
    t.push(t.args[1]);
    t.pushRet(&cwv_info);
    t.argc = 0;
    return @call(.always_tail, enter(t, t.args[0]), .{t});
}
const cwv_info: RetInfo = .{ .code = &cwvReturn, .size = 1 };
fn cwvReturn(t: *Thread) callconv(.c) void {
    const consumer = t.slot(1, 0);
    t.sp -= 2;
    const v = t.val;
    if (isObj(v, T_VALUES)) {
        const n = hdrLen(ptr(v)[0]);
        t.ensureArgs(n);
        @memcpy(t.args[0..n], ptr(v)[1 .. 1 + n]);
        t.argc = n;
    } else {
        t.args[0] = v;
        t.argc = 1;
    }
    return @call(.always_tail, enter(t, consumer), .{t});
}

// ---------------------------------------------------------------------------
// call/cc by copying the whole stack (segments come later)

pub fn callccCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, arityError(t), .{t});
    const n = t.sp;
    t.reserve(1 + n + 3);
    const s = t.allocRaw(1 + n);
    s[0] = hdr(T_STACK, n);
    @memcpy(s[1 .. 1 + n], t.stack[0..n]);
    const k = t.closure(&contCode, 1);
    k[2] = tagPtr(s);
    const f = t.args[0];
    t.args[0] = tagPtr(k);
    t.argc = 1;
    return @call(.always_tail, enter(t, f), .{t});
}

fn contCode(t: *Thread) callconv(.c) void {
    t.reserve(1 + t.argc);
    const v = valuesOf(t);
    const s = ptr(ptr(t.self)[2]);
    const n = hdrLen(s[0]);
    t.sp = 0;
    t.ensureStack(n);
    @memcpy(t.stack[0..n], s[1 .. 1 + n]);
    t.sp = n;
    t.val = v;
    return @call(.always_tail, retCode(t), .{t});
}

// ---------------------------------------------------------------------------
// Escape continuations: for receivers whose continuation is only called,
// directly, in their own code (the compiler marks them, F_ESCAPE; see
// %escape-only-receiver?). Capturing pushes a marker frame with a unique
// stamp; calling the continuation cuts the stack back to the marker and
// returns through it: no copying.

var escape_stamp: i64 = 0;

fn escapeMarkerReturn(t: *Thread) callconv(.c) void {
    t.sp -= 2;
    return @call(.always_tail, retCode(t), .{t});
}
const escape_marker: RetInfo = .{ .code = &escapeMarkerReturn, .size = 1 };

pub fn callEscapeCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, arityError(t), .{t});
    t.reserve(4);
    escape_stamp += 1;
    t.ensureStack(2);
    t.push(fix(escape_stamp));
    t.pushRet(&escape_marker);
    const k = t.closure(&escapeContCode, 2);
    k[2] = fix(@intCast(t.sp));
    k[3] = fix(escape_stamp);
    const f = t.args[0];
    t.args[0] = tagPtr(k);
    t.argc = 1;
    return @call(.always_tail, enter(t, f), .{t});
}

fn escapeContCode(t: *Thread) callconv(.c) void {
    const at: usize = @intCast(unfix(t.free(0)));
    const stamp = t.free(1);
    if (at > t.sp or at < 2 or t.stack[at - 2] != stamp or t.stack[at - 1] != @intFromPtr(&escape_marker))
        return @call(.always_tail, fail(t, "escape continuation called outside its extent", &.{}), .{t});
    t.reserve(1 + t.argc);
    t.val = valuesOf(t);
    t.sp = at;
    return @call(.always_tail, retCode(t), .{t});
}

/// (apply f arg ... list)
pub fn applyCode(t: *Thread) callconv(.c) void {
    if (t.argc < 2) return @call(.always_tail, arityError(t), .{t});
    const f = t.args[0];
    var n: usize = t.argc - 2;
    var l = t.args[t.argc - 1];
    const last = l;
    std.mem.copyForwards(Word, t.args[0..n], t.args[1 .. n + 1]);
    while (isPair(l)) : (l = cdr(l)) {
        t.ensureArgs(n + 1);
        t.args[n] = car(l);
        n += 1;
    }
    if (l != NIL) return @call(.always_tail, fail(t, "apply: last argument must be a list", &.{last}), .{t});
    t.argc = n;
    return @call(.always_tail, enter(t, f), .{t});
}

// ---------------------------------------------------------------------------
// Garbage collection: generational.
//
//   * The nursery (t.heap .. t.heap + t.heap_len, its top eighth the flonum
//     area) holds new objects; compiled code bump-allocates in it.
//   * A minor collection copies the nursery's survivors to the end of the old
//     space (promotion) and empties the nursery. Its roots are the thread's
//     roots, the module globals, the static objects, and the remembered set:
//     old objects into which a young pointer was stored (the write barrier,
//     abi.barrier, remembers them).
//   * A major collection copies everything live (nursery and old space) into
//     a new old space, Cheney style, and marks and sweeps the large-object
//     space. It runs when the old space cannot take a nursery's promotion, or
//     when the large-object space has grown (a collection request).

const nursery_words = 1 << 20; // 8 MB

var old_space: []Word = &.{};
var old_hp: usize = 0; // index of the old space's free part
var remembered: std.ArrayList([*]Word) = .empty;
var major_requested = false;
var large_since_major: usize = 0;
pub var minor_count: u64 = 0;
pub var major_count: u64 = 0;

pub const F_REMEMBERED: u8 = 16;

/// Is w an object the collector may move (in the nursery or the old space)?
pub fn isMovable(w: Word) bool {
    if (!isPtr(w)) return false;
    const a = @intFromPtr(ptr(w));
    const t = num.current_thread;
    const in_young = a >= @intFromPtr(t.heap) and a < @intFromPtr(t.heap + t.heap_len);
    const in_old = a >= @intFromPtr(old_space.ptr) and a < @intFromPtr(old_space.ptr + old_space.len);
    return in_young or in_old;
}

/// The write barrier's slow path: obj (not young) now holds a young pointer
pub fn remember(obj: Word) void {
    const q = ptr(obj);
    if (hdrFlags(q[0]) & F_REMEMBERED != 0) return;
    q[0] |= @as(Word, F_REMEMBERED) << 8;
    remembered.append(std.heap.c_allocator, q) catch oom();
}

fn gc(t: *Thread, need: usize) void {
    t.gc_count += 1;
    t.gc_requested = 0;
    const used = (@intFromPtr(t.hp) - @intFromPtr(t.heap)) / 8 + (@intFromPtr(t.flo_ptr) - @intFromPtr(nurseryEnd(t.heap[0..t.heap_len]))) / 8;
    if (major_requested or old_hp + used > old_space.len) {
        major(t);
    } else {
        minor(t);
    }
    // a request larger than the nursery: a larger nursery (it is empty now)
    if (need > nurseryCapacity(t)) {
        const pa = std.heap.c_allocator;
        pa.free(t.heap[0..t.heap_len]);
        const n = @max(nursery_words, 2 * need + need / 4);
        const heap = pa.alloc(Word, n) catch oom();
        t.heap = heap.ptr;
        t.heap_len = heap.len;
    }
    resetNursery(t);
}

fn nurseryCapacity(t: *Thread) usize {
    return t.heap_len - t.heap_len / 4;
}

fn resetNursery(t: *Thread) void {
    const heap = t.heap[0..t.heap_len];
    t.hp = heap.ptr;
    t.hlimit = nurseryEnd(heap);
    t.flo_ptr = nurseryEnd(heap);
}

fn clearRemembered() void {
    for (remembered.items) |q| q[0] &= ~(@as(Word, F_REMEMBERED) << 8);
    remembered.clearRetainingCapacity();
}

fn scanRoots(t: *Thread, g: *Gc) void {
    for (t.args[0..t.args_len]) |*w| w.* = g.copy(w.*);
    t.self = g.copy(t.self);
    t.val = g.copy(t.val);
    t.winders = g.copy(t.winders);
    t.handlers = g.copy(t.handlers);
    for (modules) |m| for (m.globals[0..m.nglobals]) |*w| {
        w.* = g.copy(w.*);
    };
    for (t.err_irritants[0..t.err_n]) |*w| w.* = g.copy(w.*);
    g.scanFrames(t.stack[0..t.sp]);
    for (static_scan.items) |q| g.scanObject(q);
}

/// SCM_NATIVE_GC_VERIFY=1: before each minor collection, look for old
/// objects that point into the nursery without being remembered (a missing
/// write barrier)
var verify: ?bool = null;

fn verifyBarriers(t: *Thread) void {
    var scan: usize = 0;
    while (scan < old_hp) {
        const q = old_space.ptr + scan;
        const len = hdrLen(q[0]);
        const ty = hdrType(q[0]);
        const first: usize = switch (ty) {
            T_PAIR, T_VECTOR, T_BOX, T_STRING, T_VALUES, T_RECORD, T_ERROR, T_RATNUM, T_COMPNUM, T_HASHTABLE => 1,
            T_CLOSURE => 2,
            else => 1 + len,
        };
        if (hdrFlags(q[0]) & F_REMEMBERED == 0) {
            var i = first;
            while (i < 1 + len) : (i += 1) if (abi.isYoung(t, q[i])) {
                os.eprint("gc verify: old object type {d} (length {d}) slot {d} points into the nursery\n", .{ ty, len, i });
                break;
            };
        }
        scan += 1 + len;
    }
}

fn minor(t: *Thread) void {
    if (verify == null) verify = os.getEnv("SCM_NATIVE_GC_VERIFY") != null;
    if (verify.?) verifyBarriers(t);
    minor_count += 1;
    var g = Gc{ .young = t.heap[0..t.heap_len], .old = &.{}, .to = old_space, .free = old_hp, .major = false };
    const promoted = old_hp;
    scanRoots(t, &g);
    for (remembered.items) |q| g.scanObject(q);
    var scan = promoted;
    while (scan < g.free) {
        const q = old_space.ptr + scan;
        g.scanObject(q);
        scan += 1 + hdrLen(q[0]);
    }
    old_hp = g.free;
    clearRemembered();
}

fn major(t: *Thread) void {
    major_count += 1;
    major_requested = false;
    large_since_major = 0;
    const pa = std.heap.c_allocator;
    // the old space for everything live: as large as both spaces (the whole
    // nursery: its flonum area too)
    const size = @max(old_space.len + t.heap_len, t.heap_target);
    const to = pa.alloc(Word, size) catch oom();
    var g = Gc{ .young = t.heap[0..t.heap_len], .old = old_space, .to = to, .free = 0, .major = true };
    scanRoots(t, &g);
    var scan: usize = 0;
    while (true) {
        if (scan < g.free) {
            const q = to.ptr + scan;
            g.scanObject(q);
            scan += 1 + hdrLen(q[0]);
        } else if (g.large_todo.pop()) |q| {
            g.scanObject(q);
        } else break;
    }
    g.large_todo.deinit(pa);
    clearRemembered();

    // sweep the large-object space
    var kept: usize = 0;
    var words: usize = 0;
    for (large.items) |q| {
        if (hdrFlags(q[0]) & (F_MARK | F_PERM) != 0) {
            q[0] &= ~(@as(Word, F_MARK) << 8);
            large.items[kept] = q;
            kept += 1;
            words += 1 + hdrLen(q[0]);
        } else {
            pa.free(q[0 .. 1 + hdrLen(q[0])]);
        }
    }
    large.items.len = kept;
    t.large_words = words;

    if (old_space.len > 0) pa.free(old_space);
    old_space = to;
    old_hp = g.free;
    // keep the old space at about three times the live data, and room for a
    // nursery's promotion
    const want = 3 * g.free + 2 * nurseryCapacity(t);
    if (want > t.heap_target) t.heap_target = want;
    if (old_space.len - old_hp < nurseryCapacity(t)) {
        // too small already: grow now (the nursery is empty: nothing moves into it)
        major_requested = false;
        resetNursery(t);
        major(t);
    }
}

/// The new location of a forwarded object (its header: T_FWD, address / 8)
inline fn forwardee(h: Word) Word {
    return tagPtr(@as([*]Word, @ptrFromInt(hdrLen(h) << 3)));
}

const Gc = struct {
    young: []Word,
    old: []Word, // empty for a minor collection
    to: []Word,
    free: usize,
    major: bool,
    large_todo: std.ArrayList([*]Word) = .empty,

    inline fn in(region: []Word, a: usize) bool {
        return a >= @intFromPtr(region.ptr) and a < @intFromPtr(region.ptr + region.len);
    }

    fn copy(g: *Gc, w: Word) Word {
        if (!isPtr(w)) return w;
        const q = ptr(w);
        const a = @intFromPtr(q);
        if (!in(g.young, a) and !(g.major and in(g.old, a))) {
            // old (in a minor collection), static or large
            if (g.major) {
                const flags = hdrFlags(q[0]);
                if (flags & F_LARGE != 0 and flags & (F_MARK | F_PERM) == 0) {
                    q[0] |= @as(Word, F_MARK) << 8;
                    g.large_todo.append(std.heap.c_allocator, q) catch oom();
                }
            }
            return w;
        }
        if (hdrType(q[0]) == T_FWD) return forwardee(q[0]);
        const n = 1 + hdrLen(q[0]);
        const dst = g.to.ptr + g.free;
        @memcpy(dst[0..n], q[0..n]);
        dst[0] &= ~(@as(Word, F_REMEMBERED) << 8);
        g.free += n;
        const nw = tagPtr(dst);
        // the new address in the header itself: an object without payload
        // (an empty vector, a record without fields) has no second word
        q[0] = hdr(T_FWD, @intFromPtr(dst) >> 3);
        return nw;
    }

    fn scanObject(g: *Gc, q: [*]Word) void {
        const len = hdrLen(q[0]);
        switch (hdrType(q[0])) {
            T_PAIR, T_VECTOR, T_BOX, T_STRING, T_VALUES, T_RECORD, T_ERROR, T_RATNUM, T_COMPNUM, T_HASHTABLE => for (q[1 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_CLOSURE => for (q[2 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_STACK => g.scanFrames(q[1 .. 1 + len]),
            T_FLONUM, T_BUF8, T_BUF32, T_SYMBOL, T_PORT, T_BYTEVECTOR, T_BIGNUM, T_NATIVE => {},
            else => unreachable,
        }
    }

    /// Walk frames from the top: [slots...][RetInfo*].
    fn scanFrames(g: *Gc, frames: []Word) void {
        var i = frames.len;
        while (i > 0) {
            const info: *const RetInfo = @ptrFromInt(frames[i - 1]);
            const n: usize = @intCast(info.size);
            for (frames[i - 1 - n .. i - 1]) |*w| w.* = g.copy(w.*);
            i -= n + 1;
        }
    }
};

// ---------------------------------------------------------------------------
// Program entry, used by rtmain.zig

/// The modules of the program, in initialization order (their globals are
/// GC roots)
var modules: []const abi.Module = &.{};
pub var command_line: []const [:0]const u8 = &.{};

pub fn start(list: abi.ModuleList, args: []const [:0]const u8) u8 {
    // SCM_NATIVE_SEGV=1: a stack trace on a crash (for debugging the runtime)
    if (os.getEnv("SCM_NATIVE_SEGV") != null) std.debug.attachSegfaultHandler();
    command_line = args;
    modules = list.modules[0..list.count];
    const t = newThread();
    num.current_thread = t;
    for (modules) |m| @memset(m.globals[0..m.nglobals], UNBOUND);
    program_specials(t);
    for (modules) |m| {
        m.init(t);
        _ = run(t, staticProc(m.entry), 0);
    }
    ports.flushAll();
    os.flush();
    if (os.getEnv("SCM_NATIVE_GC_STATS") != null)
        os.eprint("gc: {d} minor, {d} major collections; old space {d} words ({d} used), large objects {d} words\n", .{ minor_count, major_count, old_space.len, old_hp, t.large_words });
    return t.exit_code;
}

/// The program sets the cells of the specials (raise, the current ports)
extern fn scm_program_specials(t: *Thread) callconv(.c) void;
fn program_specials(t: *Thread) void {
    scm_program_specials(t);
}

pub const data = @import("data.zig");
pub const num = @import("num.zig");
pub const printer = @import("printer.zig");
pub const ports = @import("ports.zig");
/// Primitive procedures by Scheme name: rt.prims.@"%string-append"
pub const prims = @import("prims.zig");
pub const prims_ctl = @import("prims_ctl.zig");
pub const prims_text = @import("prims_text.zig");
pub const prims_io = @import("prims_io.zig");
pub const prims_num = @import("prims_num.zig");
pub const prims_fs = @import("prims_fs.zig");
pub const prims_hash = @import("prims_hash.zig");
pub const prims_string = @import("prims_string.zig");
pub const prims_format = @import("prims_format.zig");
pub const prims_bytes = @import("prims_bytes.zig");
pub const prims_sys = @import("prims_sys.zig");
pub const prims_crypto = @import("prims_crypto.zig");
pub const prims_json = @import("prims_json.zig");
pub const prims_xml = @import("prims_xml.zig");
pub const prims_image = @import("prims_image.zig");
pub const prims_module = @import("prims_module.zig");
pub const prims_net = @import("prims_net.zig");
