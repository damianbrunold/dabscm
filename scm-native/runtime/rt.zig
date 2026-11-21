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
pub const T_FWD = abi.T_FWD;
pub const F_LARGE = abi.F_LARGE;
pub const F_MARK = abi.F_MARK;
pub const F_PRIM = abi.F_PRIM;
pub const F_PERM = abi.F_PERM;
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

// ---------------------------------------------------------------------------
// Static objects: constants, symbols and primitive procedures. They never
// move; those that can point into the heap are scanned at every collection.

var static_arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
var static_scan: std.ArrayList([*]Word) = .empty;

pub fn staticAlloc(n: usize, scan: bool) [*]Word {
    const mem = static_arena.allocator().alignedAlloc(Word, .@"8", n) catch oom();
    if (scan) static_scan.append(std.heap.page_allocator, mem.ptr) catch oom();
    return mem.ptr;
}

pub fn oom() noreturn {
    os.fatal("out of memory", .{});
}

// ---------------------------------------------------------------------------
// Thread state (abi.Thread) and the large-object space

var large: std.ArrayList([*]Word) = .empty;

pub fn newThread() *Thread {
    const pa = std.heap.page_allocator;
    const heap = pa.alloc(Word, 1 << 20) catch oom();
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
        .hlimit = heap.ptr + heap.len,
        .heap = heap.ptr,
        .heap_len = heap.len,
    };
    return t;
}

/// An object of n words (header included) that is not moved by the GC;
/// allocating it never collects, so it is safe anywhere.
pub fn allocLarge(t: *Thread, n: usize) [*]Word {
    const mem = std.heap.page_allocator.alloc(Word, n) catch oom();
    large.append(std.heap.page_allocator, mem.ptr) catch oom();
    t.large_words += n;
    // the collection happens at the next reserve
    if (t.large_words > t.heap_len) t.hlimit = t.hp;
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

fn growStack(t: *Thread, need: usize) void {
    var n = t.stack_len * 2;
    while (n < need) n *= 2;
    const s = std.heap.page_allocator.realloc(t.stack[0..t.stack_len], n) catch oom();
    t.stack = s.ptr;
    t.stack_len = s.len;
}

fn growArgs(t: *Thread, need: usize) void {
    var n = t.args_len * 2;
    while (n < need) n *= 2;
    const old = t.args_len;
    const a = std.heap.page_allocator.realloc(t.args[0..t.args_len], n) catch oom();
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
    return fail(t, std.fmt.allocPrint(std.heap.page_allocator, "{s} is not a function, cannot apply", .{buf.items}) catch oom(), &.{});
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
    t.setErrMsg(msg);
    t.err_n = @min(irritants.len, t.err_irritants.len);
    for (0..t.err_n) |i| t.err_irritants[i] = irritants[i];
    return &errorCode;
}

pub fn arityError(t: *Thread) Code {
    return fail(t, std.fmt.allocPrint(std.heap.page_allocator, "Wrong number of arguments: {d} supplied", .{t.argc}) catch oom(), &.{});
}

/// Arity error of a procedure taking n arguments (or at least n), in the
/// JVM implementation's words
pub fn arityErrorN(t: *Thread, n: u64, at_least: bool) Code {
    const msg = if (at_least)
        std.fmt.allocPrint(std.heap.page_allocator, "Wrong number of arguments: at least {d} expected, {d} supplied", .{ n, t.argc })
    else
        std.fmt.allocPrint(std.heap.page_allocator, "Wrong number of arguments: {d} expected, {d} supplied", .{ n, t.argc });
    return fail(t, msg catch oom(), &.{});
}

/// name: "<module>: <variable>"
pub fn unboundError(t: *Thread, name: []const u8) Code {
    return fail(t, std.fmt.allocPrint(std.heap.page_allocator, "{s} is not bound", .{name}) catch oom(), &.{});
}

/// "Failed in <who>: wrong argument type", with the argument that is not
/// a number as irritant for arithmetic (as the JVM implementation)
pub fn typeError(t: *Thread, who: []const u8, irritants: []const Word) Code {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, "Failed in {s}: wrong argument type", .{who}) catch oom();
    return fail(t, msg, irritants);
}

pub fn arithError(t: *Thread, who: []const u8, a: Word, b: Word) Code {
    if (!num.isNumber(a)) return typeError(t, who, &.{a});
    if (!num.isNumber(b)) return typeError(t, who, &.{b});
    return fail(t, std.fmt.allocPrint(std.heap.page_allocator, "{s}: Division by zero", .{who}) catch oom(), &.{});
}

pub fn indexError(t: *Thread, who: []const u8, i: Word) Code {
    var buf: std.ArrayList(u8) = .empty;
    printer.print(&buf, i, true);
    return fail(t, std.fmt.allocPrint(std.heap.page_allocator, "{s}: index out of range: {s}", .{ who, buf.items }) catch oom(), &.{});
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
    const a = std.heap.page_allocator;
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
// Garbage collection: Cheney semispace copying for the heap, mark and sweep
// for the large-object space.

fn gc(t: *Thread, need: usize) void {
    t.gc_count += 1;
    const from = t.heap[0..t.heap_len];
    // Everything allocated fits into a space of the same size.
    const to = std.heap.page_allocator.alloc(Word, @max(from.len, t.heap_target)) catch oom();
    var g = Gc{ .from = from, .to = to, .free = 0 };

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
            std.heap.page_allocator.free(q[0 .. 1 + hdrLen(q[0])]);
        }
    }
    large.items.len = kept;
    t.large_words = words;
    g.large_todo.deinit(std.heap.page_allocator);

    std.heap.page_allocator.free(from);
    t.heap = to.ptr;
    t.heap_len = to.len;
    t.hp = to.ptr + g.free;
    t.hlimit = to.ptr + to.len;
    // Keep at least half of the space free after a collection: if not,
    // collect again right away into a space twice as large.
    if ((g.free + need) * 2 > to.len) {
        t.heap_target = 2 * (g.free + need) + to.len;
        gc(t, need);
    }
}

const Gc = struct {
    from: []Word,
    to: []Word,
    free: usize,
    large_todo: std.ArrayList([*]Word) = .empty,

    fn copy(g: *Gc, w: Word) Word {
        if (!isPtr(w)) return w;
        const q = ptr(w);
        const a = @intFromPtr(q);
        if (a < @intFromPtr(g.from.ptr) or a >= @intFromPtr(g.from.ptr + g.from.len)) {
            // static or large
            const flags = hdrFlags(q[0]);
            if (flags & F_LARGE != 0 and flags & (F_MARK | F_PERM) == 0) {
                q[0] |= @as(Word, F_MARK) << 8;
                g.large_todo.append(std.heap.page_allocator, q) catch oom();
            }
            return w;
        }
        if (hdrType(q[0]) == T_FWD) return q[1];
        const n = 1 + hdrLen(q[0]);
        const dst = g.to.ptr + g.free;
        @memcpy(dst[0..n], q[0..n]);
        g.free += n;
        const nw = tagPtr(dst);
        q[0] = hdr(T_FWD, hdrLen(q[0]));
        q[1] = nw;
        return nw;
    }

    fn scanObject(g: *Gc, q: [*]Word) void {
        const len = hdrLen(q[0]);
        switch (hdrType(q[0])) {
            T_PAIR, T_VECTOR, T_BOX, T_STRING, T_VALUES, T_RECORD, T_ERROR, T_RATNUM, T_COMPNUM => for (q[1 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_CLOSURE => for (q[2 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_STACK => g.scanFrames(q[1 .. 1 + len]),
            T_FLONUM, T_BUF8, T_BUF32, T_SYMBOL, T_PORT, T_BYTEVECTOR, T_BIGNUM => {},
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
