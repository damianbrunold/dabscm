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
    lockHeap();
    defer unlockHeap();
    const mem = static_arena.allocator().alignedAlloc(Word, .@"8", n) catch oom();
    if (scan) static_scan.append(std.heap.c_allocator, mem.ptr) catch oom();
    return mem.ptr;
}

/// Guards the shared parts of the heap that threads change outside
/// collections: the static objects, the large-object space, the
/// remembered set
var heap_lock: std.Io.Mutex = .init;

pub fn lockHeap() void {
    heap_lock.lockUncancelable(os.io);
}
pub fn unlockHeap() void {
    heap_lock.unlock(os.io);
}

pub fn oom() noreturn {
    os.fatal("out of memory", .{});
}

// ---------------------------------------------------------------------------
// Thread state (abi.Thread) and the large-object space

var large: std.ArrayList([*]Word) = .empty;
var large_words: usize = 0;

// The young space: one reserved range of address space from which every
// thread's nursery is taken, so that "young" is one range check for all
// threads (abi.isYoung, the write barrier): a thread may store a pointer
// into another thread's nursery (through a global, say).
const young_reserve: usize = 1 << 36; // 64 GB of address space, committed when used
var young_space: []align(std.heap.page_size_min) u8 = &.{};
var young_top: usize = 0;
var young_free: std.ArrayList([]Word) = .empty; // nurseries of ended threads

fn initYoung() void {
    young_space = os.reserveAddressSpace(young_reserve) orelse oom();
}

/// A nursery of at least n words (under the world lock)
fn allocNursery(n: usize) []Word {
    for (young_free.items, 0..) |h, i| if (h.len >= n) {
        _ = young_free.swapRemove(i);
        if (!os.commit(pageBytes(h))) oom();
        return h;
    };
    const bytes = std.mem.alignForward(usize, n * 8, std.heap.page_size_min);
    if (young_top + bytes > young_space.len) oom();
    const h: [*]Word = @ptrCast(@alignCast(young_space.ptr + young_top));
    young_top += bytes;
    if (!os.commit(pageBytes(h[0 .. bytes / 8]))) oom();
    return h[0 .. bytes / 8];
}

fn pageBytes(h: []Word) []align(std.heap.page_size_min) u8 {
    const p: [*]align(std.heap.page_size_min) u8 = @ptrCast(@alignCast(h.ptr));
    return p[0 .. h.len * 8];
}

/// Give a nursery back (its memory to the system, its range for reuse)
fn freeNursery(h: []Word) void {
    os.decommit(pageBytes(h));
    young_free.append(std.heap.c_allocator, h) catch oom();
}

/// A new thread's state (its nursery, stack and argument registers); under
/// the world lock, or before other threads exist
pub fn newThread() *Thread {
    const pa = std.heap.c_allocator;
    const heap = allocNursery(nursery_words);
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
        .young_base = @intFromPtr(young_space.ptr),
        .young_bytes = young_space.len,
    };
    if (stress) |st| stressNursery(t, st);
    return t;
}

/// An object of n words (header included) that is not moved by the GC;
/// allocating it never collects, so it is safe anywhere.
pub fn allocLarge(t: *Thread, n: usize) [*]Word {
    const mem = std.heap.c_allocator.alloc(Word, n) catch oom();
    lockHeap();
    large.append(std.heap.c_allocator, mem.ptr) catch oom();
    large_words += n;
    large_since_major += n;
    const due = large_since_major > @max(old_space.len, nursery_words);
    if (due) major_requested = true;
    unlockHeap();
    // a major collection (which sweeps this space) at the next check
    if (due) {
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

/// A collection now (a major one if full), for %gc-collect
pub fn collectNow(t: *Thread, full: bool) void {
    if (full) major_requested = true;
    gc(t, 0);
}

/// The collector's numbers, for %gc-statistics: the collections, the old
/// space's used words, the large objects' words, the live threads
pub fn gcNumbers() struct { minor: usize, major: usize, old_used: usize, large: usize, threads: usize } {
    var live: usize = 0;
    for (threads.items) |o| if (o.ended == 0) {
        live += 1;
    };
    return .{ .minor = minor_count, .major = major_count, .old_used = old_hp, .large = large_words, .threads = live };
}

/// SCM_NATIVE_GC_STATS=1: the collector's numbers, at exit (the end of the
/// program, or exit)
pub fn printGcStats() void {
    if (os.getEnv("SCM_NATIVE_GC_STATS") == null) return;
    var live: usize = 0;
    var nursery: usize = 0;
    var stacks: usize = 0;
    var ended: usize = 0;
    var ended_stacks: usize = 0;
    for (threads.items) |o| if (o.ended == 0) {
        live += 1;
        nursery += o.heap_len;
        stacks += o.stack_len + o.args_len;
    } else {
        ended += 1;
        ended_stacks += o.stack_len + o.heap_len;
    };
    const ps = ports.stats();
    os.eprint("gc: {d} minor, {d} major collections; old space {d} MB ({d} MB used), large objects {d} MB, {d} threads ({d} MB nurseries, {d} MB stacks and argument arrays), {d} ended threads not yet freed ({d} MB), {d} ports ({d} MB buffers), {d} native objects\n", .{ minor_count, major_count, old_space.len / 131072, old_hp / 131072, large_words / 131072, live, nursery / 131072, stacks / 131072, ended, ended_stacks / 131072, ps.count, ps.bytes / 1048576, prims_sys.nativeCount() });
}

/// The entry of module i (by its index in the initialization order), as
/// a procedure of no arguments, with its constants set up: the program
/// calls it at the import that brings the module in (see scm_program_eager)
pub fn moduleEntry(t: *Thread, i: usize) ?Word {
    if (i >= modules.len) return null;
    const m = modules[i];
    m.init(t);
    return staticProc(m.entry);
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

threadlocal var escape_stamp: i64 = 0;

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

/// Is w an object the collector may move (in a nursery or the old space)?
pub fn isMovable(w: Word) bool {
    if (!isPtr(w)) return false;
    const a = @intFromPtr(ptr(w));
    const in_young = a -% @intFromPtr(young_space.ptr) < young_space.len;
    const in_old = a >= @intFromPtr(old_space.ptr) and a < @intFromPtr(old_space.ptr + old_space.len);
    return in_young or in_old;
}

/// The write barrier's slow path: obj (not young) now holds a young pointer
pub fn remember(obj: Word) void {
    const q = ptr(obj);
    if (hdrFlags(q[0]) & F_REMEMBERED != 0) return;
    lockHeap();
    defer unlockHeap();
    if (hdrFlags(q[0]) & F_REMEMBERED != 0) return;
    q[0] |= @as(Word, F_REMEMBERED) << 8;
    remembered.append(std.heap.c_allocator, q) catch oom();
}

// ---------------------------------------------------------------------------
// Threads and collections. Every thread has its own nursery, stack and
// registers (abi.Thread); the old space, the large objects, the static
// objects and the globals are shared. A collection stops the world: the
// thread that needs one asks every other thread to stop (gc_requested, and
// a lowered allocation limit for reserve), waits until each has stopped at
// a safepoint or is in a blocking call (t.safe: it does not touch the heap
// meanwhile), and collects all nurseries at once.

var world_lock: std.Io.Mutex = .init;
var world_cond: std.Io.Condition = .init;
/// every thread that has not ended, and the ended ones until the next
/// collection (their nurseries may hold live objects)
var threads: std.ArrayList(*Thread) = .empty;
var stopping = false; // a collection is under way
var stopped: usize = 0; // threads stopped at a safepoint or in a blocking call
var heap_target: usize = 0;
var ended_count: usize = 0; // ended threads not yet freed

pub fn lockWorld() void {
    world_lock.lockUncancelable(os.io);
}
pub fn unlockWorld() void {
    world_lock.unlock(os.io);
}
fn waitWorld() void {
    world_cond.waitUncancelable(os.io, &world_lock);
}
fn wakeWorld() void {
    world_cond.broadcast(os.io);
}

/// The number of threads that have not ended (the program's included)
pub fn threadCount() usize {
    lockWorld();
    defer unlockWorld();
    var n: usize = 0;
    for (threads.items) |o| if (o.ended == 0) {
        n += 1;
    };
    return n;
}

/// Add a new thread (newThread), as in a blocking call: it joins the world
/// with blockingEnd, on its own OS thread. Under the world lock.
pub fn registerThreadLocked(t: *Thread) void {
    // ended threads keep their nurseries until a collection: ask for one
    // (at the creator's next safepoint) when several are waiting
    if (ended_count >= 8) @atomicStore(u8, &num.current_thread.gc_requested, 1, .monotonic);
    t.safe = 1;
    stopped += 1;
    threads.append(std.heap.c_allocator, t) catch oom();
}

/// The running thread ends: from now on it counts as stopped, and the next
/// collection frees its state
pub fn threadEnded(t: *Thread) void {
    lockWorld();
    defer unlockWorld();
    t.sp = 0;
    t.argc = 0;
    t.self = FALSE;
    t.val = FALSE;
    t.winders = NIL;
    t.handlers = NIL;
    t.params = NIL;
    t.thread_obj = FALSE;
    t.err_n = 0;
    t.ended = 1;
    t.safe = 1;
    stopped += 1;
    ended_count += 1;
    wakeWorld();
}

/// Enter a blocking call (a read, a sleep, a wait): until blockingEnd, the
/// thread must not touch the heap (its Words may move), and collections
/// need not wait for it. Calls nest.
pub fn blockingBegin(t: *Thread) void {
    if (t.safe > 0) {
        t.safe += 1;
        return;
    }
    lockWorld();
    defer unlockWorld();
    t.safe = 1;
    stopped += 1;
    wakeWorld();
}

pub fn blockingEnd(t: *Thread) void {
    if (t.safe > 1) {
        t.safe -= 1;
        return;
    }
    lockWorld();
    defer unlockWorld();
    while (stopping) waitWorld();
    t.safe = 0;
    stopped -= 1;
}

/// The same for the running thread (for code that has no Thread at hand)
pub fn blockingBeginCurrent() void {
    blockingBegin(num.current_thread);
}
pub fn blockingEndCurrent() void {
    blockingEnd(num.current_thread);
}

fn nurseryRoom(t: *Thread) usize {
    const lim = t.limit();
    const hp = @intFromPtr(t.hp);
    return if (lim > hp) (lim - hp) / 8 else 0;
}

/// A safepoint at a procedure entry (abi.Thread.attention)
pub fn attention(t: *Thread) ?Code {
    gc(t, 0);
    if (@atomicLoad(u8, &t.terminate_requested, .monotonic) != 0) return &terminatedCode;
    return null;
}

/// thread-terminate!: the thread ends here (prims_thread.zig takes it from the
/// return of its run)
fn terminatedCode(t: *Thread) callconv(.c) void {
    t.val = UNSPEC;
}

fn gc(t: *Thread, need: usize) void {
    lockWorld();
    while (stopping) {
        // another thread collects: stop here until it is done
        stopped += 1;
        wakeWorld();
        while (stopping) waitWorld();
        stopped -= 1;
        if (t.gc_requested == 0 and nurseryRoom(t) >= need) {
            unlockWorld();
            return;
        }
    }
    if (@atomicLoad(u8, &t.terminate_requested, .monotonic) != 0 and need == 0) {
        // the thread is to end: no collection needed
        @atomicStore(u8, &t.gc_requested, 0, .monotonic);
        unlockWorld();
        return;
    }
    stopping = true;
    for (threads.items) |o| if (o != t and o.ended == 0) {
        @atomicStore(u8, &o.gc_requested, 1, .monotonic);
        @atomicStore([*]Word, &o.hlimit, o.heap, .monotonic);
    };
    while (stopped < threads.items.len - 1) waitWorld();
    collect(t, need);
    stopping = false;
    wakeWorld();
    unlockWorld();
}

fn collect(t: *Thread, need: usize) void {
    t.gc_count += 1;
    var used: usize = 0;
    for (threads.items) |o| used += nurseryUsed(o);
    const stress_major = if (stress) |st| (minor_count + major_count + 1) % st.major == 0 else false;
    if (major_requested or stress_major or old_hp + used > old_space.len) {
        major(t);
    } else {
        minor(t);
    }
    // every nursery is empty now; ended threads go
    var kept: usize = 0;
    for (threads.items) |o| {
        if (o.ended != 0) {
            stopped -= 1;
            ended_count -= 1;
            freeThread(o);
            continue;
        }
        resetNursery(o);
        o.gc_requested = 0;
        threads.items[kept] = o;
        kept += 1;
    }
    threads.items.len = kept;
    // a request larger than the nursery: a larger nursery (it is empty now)
    if (need > nurseryCapacity(t)) {
        freeNursery(t.heap[0..t.heap_len]);
        const heap = allocNursery(@max(nursery_words, 2 * need + need / 4));
        t.heap = heap.ptr;
        t.heap_len = heap.len;
        resetNursery(t);
    }
    // stress mode: allocation goes on above the poisoned part, unless the
    // request does not fit there
    if (stress) |st| if (@intFromPtr(t.hp) + 8 * need > @intFromPtr(nurseryEnd(t.heap[0..t.heap_len]))) {
        t.hp = t.heap;
        t.stress_young = @intFromPtr(t.hp);
        t.hlimit = @ptrFromInt(@min(@intFromPtr(nurseryEnd(t.heap[0..t.heap_len])), @intFromPtr(t.hp) + 8 * st.words));
    };
}

/// The words a nursery holds (the bump area and the flonum area)
fn nurseryUsed(o: *Thread) usize {
    return (@intFromPtr(o.hp) - @intFromPtr(o.heap)) / 8 + (@intFromPtr(o.flo_ptr) - @intFromPtr(nurseryEnd(o.heap[0..o.heap_len]))) / 8;
}

fn freeThread(o: *Thread) void {
    const pa = std.heap.c_allocator;
    freeNursery(o.heap[0..o.heap_len]);
    pa.free(o.stack[0..o.stack_len]);
    pa.free(o.args[0..o.args_len]);
    pa.destroy(o);
}

fn nurseryCapacity(t: *Thread) usize {
    return t.heap_len - t.heap_len / 4;
}

fn resetNursery(t: *Thread) void {
    const heap = t.heap[0..t.heap_len];
    if (stress) |st| return stressNursery(t, st);
    t.hp = heap.ptr;
    t.hlimit = nurseryEnd(heap);
    t.flo_ptr = nurseryEnd(heap);
}

// ---------------------------------------------------------------------------
// GC stress mode, for finding objects the collector does not know about (a
// heap pointer in a runtime local across an allocation, a missing root):
//
//   SCM_NATIVE_GC_STRESS=words[,major]
//
// A collection after every `words` words allocated (0: at every allocation
// check that allocates), and every `major`th collection a major one (default
// 100; 1: all). After a collection the memory of the dead nursery objects and
// flonums is poisoned, and allocation goes on above it rather than at the
// nursery's start, so that a stale pointer finds poison instead of a new
// object: the collector stops the program with a message when it reaches
// one, and a primitive reading one sees no valid type. The old space a major
// collection leaves is poisoned before it is freed.

const Stress = struct { words: usize, major: usize };
var stress: ?Stress = null;

/// Poison, as a header: type 0xee (no type), length 0xdeaddeaddead
pub const poison_word: Word = 0xdead_dead_dead_deee;
const poison_type: u8 = 0xee;

fn initStress() void {
    const v = os.getEnv("SCM_NATIVE_GC_STRESS") orelse return;
    var it = std.mem.splitScalar(u8, v, ',');
    const words = std.fmt.parseInt(usize, std.mem.trim(u8, it.first(), " "), 10) catch 0;
    var every: usize = 100;
    if (it.next()) |m| every = @max(1, std.fmt.parseInt(usize, std.mem.trim(u8, m, " "), 10) catch 100);
    stress = .{ .words = words, .major = every };
}

fn poison(from: usize, to: usize) void {
    if (to <= from) return;
    const q: [*]Word = @ptrFromInt(from);
    @memset(q[0 .. (to - from) / 8], poison_word);
}

/// Poison the objects from..to of a nursery, each with a header that keeps
/// its type and whether it was copied (forwarded) or garbage, for the
/// message when a stale pointer reaches it; the rest plain poison when the
/// objects cannot be walked
fn poisonObjects(from: usize, to: usize) void {
    var a = from;
    while (a < to) {
        const q: [*]Word = @ptrFromInt(a);
        const h = q[0];
        var ty = hdrType(h);
        var len = hdrLen(h);
        var moved: Word = 0;
        if (ty == T_FWD) {
            const nq = ptr(forwardee(h));
            ty = hdrType(nq[0]);
            len = hdrLen(nq[0]);
            moved = 1;
        }
        if (ty == 0 or ty > T_NATIVE or a + 8 * (1 + len) > to) return poison(a, to);
        q[0] = (poison_word & ~@as(Word, 0xffffff)) | (moved << 16) | (@as(Word, ty) << 8) | poison_type;
        @memset(q[1 .. 1 + len], poison_word);
        a += 8 * (1 + len);
    }
}

fn stressNursery(t: *Thread, st: Stress) void {
    const heap = t.heap[0..t.heap_len];
    const lo = @intFromPtr(heap.ptr);
    const mid = @intFromPtr(nurseryEnd(heap));
    const top = @intFromPtr(heap.ptr + heap.len);
    // marks outside this nursery: a new or replaced nursery
    if (t.stress_young < lo or t.stress_young > mid) t.stress_young = lo;
    if (t.stress_flo < mid or t.stress_flo > top) t.stress_flo = mid;
    const hp = @intFromPtr(t.hp);
    const fp = @intFromPtr(t.flo_ptr);
    if (hp >= lo and hp <= mid) poisonObjects(t.stress_young, hp) else poison(lo, mid);
    if (fp >= mid and fp <= top) poison(t.stress_flo, fp) else poison(mid, top);
    // go on above the poisoned part while a quarter of the nursery is left
    // (a collection with a larger request finds room: it made the nursery
    // large enough for it, and an empty one has it)
    if (hp < lo or hp + (mid - lo) / 4 > mid) t.hp = heap.ptr;
    if (fp < mid or fp + (top - mid) / 2 > top) t.flo_ptr = nurseryEnd(heap);
    t.stress_young = @intFromPtr(t.hp);
    t.stress_flo = @intFromPtr(t.flo_ptr);
    t.hlimit = @ptrFromInt(@min(mid, @intFromPtr(t.hp) + 8 * st.words));
}

fn deadObject(g: *const Gc, q: [*]Word) noreturn {
    os.eprint("gc stress: a pointer to a dead object ({x}): an object the collector did not know about was used after a collection\n", .{@intFromPtr(q)});
    if (q[0] != poison_word)
        os.eprint("  the dead object: type {d}, {s}\n", .{ (q[0] >> 8) & 0xff, if ((q[0] >> 16) & 0xff != 0) "copied by that collection (a stale pointer to a live object)" else "garbage at that collection (an object only the runtime held)" });
    if (g.cur) |c| {
        const len = hdrLen(c[0]);
        os.eprint("  found in an object of type {d}, length {d}:", .{ hdrType(c[0]), len });
        for (c[1 .. 1 + @min(len, 8)]) |w| os.eprint(" {x}", .{w});
        os.eprint("\n", .{});
    } else os.eprint("  found in a root\n", .{});
    @panic("gc stress: a pointer to a dead object");
}

fn badHeader(q: [*]Word) noreturn {
    os.eprint("gc: object {x} has a header of no type ({x})\n", .{ @intFromPtr(q), q[0] });
    @panic("gc: object without a valid header");
}

fn clearRemembered() void {
    for (remembered.items) |q| q[0] &= ~(@as(Word, F_REMEMBERED) << 8);
    remembered.clearRetainingCapacity();
}

/// Print forms of record types ((%set-record-printer! type parts)): an
/// alist of (type . parts), a GC root
pub var record_printers: Word = NIL;

fn scanThread(o: *Thread, g: *Gc) void {
    for (o.args[0..o.args_len]) |*w| w.* = g.copy(w.*);
    o.self = g.copy(o.self);
    o.val = g.copy(o.val);
    o.winders = g.copy(o.winders);
    o.handlers = g.copy(o.handlers);
    o.params = g.copy(o.params);
    o.thread_obj = g.copy(o.thread_obj);
    for (o.err_irritants[0..o.err_n]) |*w| w.* = g.copy(w.*);
    g.scanFrames(o.stack[0..o.sp]);
}

fn scanRoots(g: *Gc) void {
    record_printers = g.copy(record_printers);
    for (threads.items) |o| if (o.ended == 0) scanThread(o, g);
    for (modules) |m| for (m.globals[0..m.nglobals]) |*w| {
        w.* = g.copy(w.*);
    };
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
            T_NATIVE => 3,
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

fn youngWords() []Word {
    const q: [*]Word = @ptrCast(@alignCast(young_space.ptr));
    return q[0 .. young_space.len / 8];
}

fn minor(t: *Thread) void {
    if (verify == null) verify = os.getEnv("SCM_NATIVE_GC_VERIFY") != null;
    if (verify.?) verifyBarriers(t);
    minor_count += 1;
    var g = Gc{ .young = youngWords(), .old = &.{}, .to = old_space, .free = old_hp, .major = false };
    const promoted = old_hp;
    scanRoots(&g);
    for (remembered.items) |q| g.scanObject(q);
    var scan = promoted;
    while (scan < g.free) {
        const q = old_space.ptr + scan;
        g.scanObject(q);
        scan += 1 + hdrLen(q[0]);
    }
    old_hp = g.free;
    clearRemembered();
    // the new native and port objects not reached: what they hold goes
    prims_sys.sweepNatives(false);
    ports.sweep(false);
}

fn major(t: *Thread) void {
    major_count += 1;
    major_requested = false;
    large_since_major = 0;
    const pa = std.heap.c_allocator;
    // the old space for everything live: as large as both spaces (the whole
    // nurseries: their flonum areas too)
    var nurseries: usize = 0;
    for (threads.items) |o| nurseries += nurseryUsed(o);
    const size = @max(old_hp + nurseries + nursery_words, heap_target);
    const to = pa.alloc(Word, size) catch oom();
    if (os.getEnv("SCM_NATIVE_GC_STATS") != null)
        os.eprint("gc: major {d}: old space {x} ({d} MB) -> {x} ({d} MB)\n", .{ major_count, @intFromPtr(old_space.ptr), old_space.len / 131072, @intFromPtr(to.ptr), size / 131072 });
    var g = Gc{ .young = youngWords(), .old = old_space, .to = to, .free = 0, .major = true };
    scanRoots(&g);
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
    large_words = words;

    if (old_space.len > 0) {
        if (stress != null) @memset(old_space[0..old_hp], poison_word);
        pa.free(old_space);
    }
    old_space = to;
    old_hp = g.free;
    // the native and port objects not reached: what they hold goes
    prims_sys.sweepNatives(true);
    ports.sweep(true);
    // keep the old space at one and a half times the live data, and room
    // for the nurseries' promotion; recomputed at every major collection,
    // so that it shrinks again after a peak. A major collection copies the
    // live data into a new space while the old one still exists, so the
    // memory peaks at about the old space plus the live data: about 2.5
    // times the live data (it was 4 times with three times the live data,
    // more than a JVM with large data such as loaded grouper releases)
    var capacity: usize = 0;
    for (threads.items) |o| if (o.ended == 0) {
        capacity += nurseryCapacity(o);
    };
    heap_target = g.free + g.free / 2 + 2 * capacity;
    if (old_space.len - old_hp < capacity) {
        // too small already: grow now (the nurseries are empty: nothing
        // moves into them)
        major_requested = false;
        for (threads.items) |o| resetNursery(o);
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
    /// the object being scanned (null: a root), for the stress mode's message
    cur: ?[*]Word = null,

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
        if (hdrType(q[0]) == poison_type) deadObject(g, q);
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
        g.cur = q;
        defer g.cur = null;
        const len = hdrLen(q[0]);
        switch (hdrType(q[0])) {
            T_PAIR, T_VECTOR, T_BOX, T_STRING, T_VALUES, T_RECORD, T_ERROR, T_RATNUM, T_COMPNUM, T_HASHTABLE => for (q[1 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_CLOSURE => for (q[2 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_STACK => g.scanFrames(q[1 .. 1 + len]),
            T_PORT => ports.markSeen(@ptrFromInt(q[1])),
            // [kind, record, slots...]: the slots hold objects (a socket's ports)
            T_NATIVE => {
                prims_sys.markNative(q);
                for (q[3 .. 1 + len]) |*w| w.* = g.copy(w.*);
            },
            T_FLONUM, T_BUF8, T_BUF32, T_SYMBOL, T_BYTEVECTOR, T_BIGNUM => {},
            else => badHeader(q),
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

pub fn start(list: abi.ModuleList, eager: usize, args: []const [:0]const u8) u8 {
    // SCM_NATIVE_SEGV=1: a stack trace on a crash (for debugging the runtime)
    if (os.getEnv("SCM_NATIVE_SEGV") != null) std.debug.attachSegfaultHandler();
    command_line = args;
    modules = list.modules[0..list.count];
    initYoung();
    initStress();
    os.platformInit();
    os.blocking_hooks = .{ .begin = &blockingBeginCurrent, .end = &blockingEndCurrent };
    const t = newThread();
    threads.append(std.heap.c_allocator, t) catch oom();
    num.current_thread = t;
    for (modules) |m| @memset(m.globals[0..m.nglobals], UNBOUND);
    program_specials(t);
    // the program (the last module) returns its last form's value: an
    // integer is the exit code unless set-exit-code! set one, as for a
    // script on the JVM implementation
    for (modules[0..@min(eager, modules.len - 1)]) |m| {
        m.init(t);
        _ = run(t, staticProc(m.entry), 0);
    }
    const program = modules[modules.len - 1];
    program.init(t);
    const result = run(t, staticProc(program.entry), 0);
    if (t.exit_code == 0 and isFix(result))
        t.exit_code = @truncate(@as(u64, @bitCast(unfix(result))));
    ports.flushAll();
    os.flush();
    printGcStats();
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
pub const threads_prims = @import("prims_thread.zig");
