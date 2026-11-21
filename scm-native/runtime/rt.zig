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
const std = @import("std");
pub const os = @import("os.zig");

pub const Word = u64;
pub const Code = *const fn (*Thread) callconv(.c) void;

pub const RetInfo = extern struct {
    code: Code,
    size: u64,
};

// ---------------------------------------------------------------------------
// Value encoding
//   xxx0  fixnum (63 bit, n << 1)
//   x001  heap pointer (address + 1, objects 8-aligned)
//   x011  immediate constants
//   x101  character (code point << 3)

pub const FALSE: Word = 0b0011;
pub const TRUE: Word = 0b1011;
pub const NIL: Word = 0b10011;
pub const UNSPEC: Word = 0b11011;
pub const EOF: Word = 0b100011;
pub const UNBOUND: Word = 0b101011;
pub const DEFAULT: Word = 0b110011;

pub const fix_max: i64 = (1 << 62) - 1;
pub const fix_min: i64 = -(1 << 62);

pub inline fn fix(n: i64) Word {
    return @bitCast(n << 1);
}
pub inline fn unfix(w: Word) i64 {
    return @as(i64, @bitCast(w)) >> 1;
}
pub inline fn isFix(w: Word) bool {
    return w & 1 == 0;
}
pub inline fn isPtr(w: Word) bool {
    return w & 0b111 == 0b001;
}
pub inline fn ptr(w: Word) [*]Word {
    return @ptrFromInt(w - 1);
}
pub inline fn tagPtr(p: [*]Word) Word {
    return @intFromPtr(p) + 1;
}
pub inline fn boolean(b: bool) Word {
    return if (b) TRUE else FALSE;
}
pub inline fn isTrue(w: Word) bool {
    return w != FALSE;
}
pub inline fn char(cp: u21) Word {
    return (@as(Word, cp) << 3) | 0b101;
}
pub inline fn isChar(w: Word) bool {
    return w & 0b111 == 0b101;
}
pub inline fn charCode(w: Word) u21 {
    return @intCast(w >> 3);
}

// Heap object header: type in the low 8 bits, payload length (words) above.
pub const T_PAIR: u8 = 1;
pub const T_CLOSURE: u8 = 2; // payload[0] = code (raw), rest scanned
pub const T_STACK: u8 = 3; // copied stack frames, scanned frame by frame
pub const T_VECTOR: u8 = 4;
pub const T_BOX: u8 = 5;
pub const T_FLONUM: u8 = 6; // raw f64
pub const T_STRING: u8 = 7; // [char count (fixnum)] [buffer]
pub const T_BUF8: u8 = 8; // raw Latin-1 characters
pub const T_BUF32: u8 = 9; // raw code points (u32)
pub const T_SYMBOL: u8 = 10; // [byte length (raw)] [UTF-8 bytes (raw)], static
pub const T_FWD: u8 = 0xff; // forwarded during GC, payload[0] = new pointer

pub inline fn hdr(ty: u8, len: u64) Word {
    return (len << 8) | ty;
}
pub inline fn hdrType(h: Word) u8 {
    return @truncate(h);
}
pub inline fn hdrLen(h: Word) u64 {
    return h >> 8;
}
pub inline fn objType(w: Word) u8 {
    return hdrType(ptr(w)[0]);
}
pub inline fn isObj(w: Word, ty: u8) bool {
    return isPtr(w) and objType(w) == ty;
}
pub inline fn isPair(w: Word) bool {
    return isObj(w, T_PAIR);
}
pub inline fn car(w: Word) Word {
    return ptr(w)[1];
}
pub inline fn cdr(w: Word) Word {
    return ptr(w)[2];
}
pub inline fn isFlonum(w: Word) bool {
    return isObj(w, T_FLONUM);
}
pub inline fn flo(w: Word) f64 {
    return @bitCast(ptr(w)[1]);
}
pub inline fn isProcedure(w: Word) bool {
    return isObj(w, T_CLOSURE);
}

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
// Thread state

pub const Thread = struct {
    args: []Word,
    argc: u64 = 0,
    self: Word = fix(0),
    val: Word = fix(0),
    stack: []Word,
    sp: usize = 0,
    hp: [*]Word,
    hlimit: [*]Word,
    heap: []Word,
    globals: []Word,
    gc_count: u64 = 0,
    heap_target: usize = 0,
    // the pending error, reported by errorCode
    err_msg: []const u8 = "",
    err_irritants: [3]Word = .{ UNSPEC, UNSPEC, UNSPEC },
    err_n: usize = 0,
    exit_code: u8 = 0,

    pub fn init(nglobals: usize) Thread {
        const pa = std.heap.page_allocator;
        const heap = pa.alloc(Word, 1 << 20) catch oom();
        const stack = pa.alloc(Word, 1 << 12) catch oom();
        const args = pa.alloc(Word, 256) catch oom();
        const globals = pa.alloc(Word, nglobals) catch oom();
        @memset(args, fix(0));
        @memset(globals, UNBOUND);
        return .{
            .args = args,
            .stack = stack,
            .hp = heap.ptr,
            .hlimit = heap.ptr + heap.len,
            .heap = heap,
            .globals = globals,
        };
    }

    /// Make sure `n` words can be pushed.
    pub inline fn ensureStack(t: *Thread, n: usize) void {
        if (t.sp + n > t.stack.len) growStack(t, t.sp + n);
    }

    /// Make sure there is room for `n` arguments.
    pub inline fn ensureArgs(t: *Thread, n: usize) void {
        if (n > t.args.len) growArgs(t, n);
    }

    /// Make sure `n` words can be bump-allocated without a collection.
    pub inline fn reserve(t: *Thread, n: usize) void {
        if (n > (@intFromPtr(t.hlimit) - @intFromPtr(t.hp)) / 8) gc(t, n);
    }

    pub inline fn allocRaw(t: *Thread, n: usize) [*]Word {
        const p = t.hp;
        t.hp += n;
        return p;
    }

    pub inline fn cons(t: *Thread, a: Word, d: Word) Word {
        const p = t.allocRaw(3);
        p[0] = hdr(T_PAIR, 2);
        p[1] = a;
        p[2] = d;
        return tagPtr(p);
    }

    pub inline fn box(t: *Thread, v: Word) Word {
        const p = t.allocRaw(2);
        p[0] = hdr(T_BOX, 1);
        p[1] = v;
        return tagPtr(p);
    }

    pub inline fn makeFlo(t: *Thread, f: f64) Word {
        const p = t.allocRaw(2);
        p[0] = hdr(T_FLONUM, 1);
        p[1] = @bitCast(f);
        return tagPtr(p);
    }

    /// A closure with `n` free variables, filled in by the caller.
    pub inline fn closure(t: *Thread, code: Code, n: usize) [*]Word {
        const p = t.allocRaw(2 + n);
        p[0] = hdr(T_CLOSURE, 1 + n);
        p[1] = @intFromPtr(code);
        return p;
    }

    pub inline fn push(t: *Thread, w: Word) void {
        t.stack[t.sp] = w;
        t.sp += 1;
    }

    pub inline fn pushRet(t: *Thread, info: *const RetInfo) void {
        t.stack[t.sp] = @intFromPtr(info);
        t.sp += 1;
    }

    /// Slot i (0 = deepest) of the frame with `size` slots on top.
    pub inline fn slot(t: *Thread, size: usize, i: usize) Word {
        return t.stack[t.sp - 1 - size + i];
    }

    /// Free variable i of the running closure.
    pub inline fn free(t: *Thread, i: usize) Word {
        return ptr(t.self)[2 + i];
    }
};

fn growStack(t: *Thread, need: usize) void {
    var n = t.stack.len * 2;
    while (n < need) n *= 2;
    t.stack = std.heap.page_allocator.realloc(t.stack, n) catch oom();
}

fn growArgs(t: *Thread, need: usize) void {
    var n = t.args.len * 2;
    while (n < need) n *= 2;
    const old = t.args.len;
    t.args = std.heap.page_allocator.realloc(t.args, n) catch oom();
    @memset(t.args[old..], fix(0));
}

// ---------------------------------------------------------------------------
// Control. Helpers return the code to tail-call, so every transfer in
// generated code is a single `@call(.always_tail, ..., .{t})`.

/// Code of the frame on top of the stack (the return).
pub inline fn retCode(t: *Thread) Code {
    const info: *const RetInfo = @ptrFromInt(t.stack[t.sp - 1]);
    return info.code;
}

/// Prepare a call of procedure `p` and return its code.
pub inline fn enter(t: *Thread, p: Word) Code {
    t.self = p;
    if (isPtr(p) and objType(p) == T_CLOSURE) return @ptrFromInt(ptr(p)[1]);
    return fail(t, "not a procedure", &.{p});
}

/// Prepare a call of the procedure in global i and return its code.
pub inline fn enterGlobal(t: *Thread, i: usize) Code {
    const p = t.globals[i];
    t.self = p;
    if (isPtr(p) and objType(p) == T_CLOSURE) return @ptrFromInt(ptr(p)[1]);
    if (p == UNBOUND) return unboundError(t, global_names[i]);
    return fail(t, "not a procedure", &.{p});
}

/// Use a value whose result is not needed (generated code).
pub inline fn ignore(_: Word) void {}

/// Record an error and return the code that reports it.
pub fn fail(t: *Thread, msg: []const u8, irritants: []const Word) Code {
    t.err_msg = msg;
    t.err_n = @min(irritants.len, t.err_irritants.len);
    for (0..t.err_n) |i| t.err_irritants[i] = irritants[i];
    return &errorCode;
}

pub fn arityError(t: *Thread) Code {
    return fail(t, "wrong number of arguments", &.{ t.self, fix(@intCast(t.argc)) });
}

pub fn unboundError(t: *Thread, name: []const u8) Code {
    t.err_msg = name;
    t.err_n = 0;
    return &unboundCode;
}

fn unboundCode(t: *Thread) callconv(.c) void {
    os.flush();
    os.eprint("error: unbound variable: {s}\n", .{t.err_msg});
    os.exit(1);
}

/// Phase 1: errors are fatal. Phase 2 raises them to Scheme handlers.
pub fn errorCode(t: *Thread) callconv(.c) void {
    os.flush();
    var buf: std.ArrayList(u8) = .empty;
    buf.appendSlice(std.heap.page_allocator, "error: ") catch oom();
    buf.appendSlice(std.heap.page_allocator, t.err_msg) catch oom();
    for (t.err_irritants[0..t.err_n]) |w| {
        buf.append(std.heap.page_allocator, ' ') catch oom();
        printer.print(&buf, w, true);
    }
    buf.append(std.heap.page_allocator, '\n') catch oom();
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
    const p = staticAlloc(2, false);
    p[0] = hdr(T_CLOSURE, 1);
    p[1] = @intFromPtr(code);
    return tagPtr(p);
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
    return @call(.always_tail, enter(t, f), .{t});
}

fn contCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, fail(t, "multiple values are not supported yet", &.{}), .{t});
    const s = ptr(ptr(t.self)[2]);
    const n = hdrLen(s[0]);
    t.sp = 0;
    t.ensureStack(n);
    @memcpy(t.stack[0..n], s[1 .. 1 + n]);
    t.sp = n;
    t.val = t.args[0];
    return @call(.always_tail, retCode(t), .{t});
}

/// (apply f arg ... list)
pub fn applyCode(t: *Thread) callconv(.c) void {
    if (t.argc < 2) return @call(.always_tail, arityError(t), .{t});
    const f = t.args[0];
    var n: usize = t.argc - 2;
    var l = t.args[t.argc - 1];
    std.mem.copyForwards(Word, t.args[0..n], t.args[1 .. n + 1]);
    while (isPair(l)) : (l = cdr(l)) {
        t.ensureArgs(n + 1);
        t.args[n] = car(l);
        n += 1;
    }
    if (l != NIL) return @call(.always_tail, fail(t, "apply: not a proper list", &.{t.args[t.argc - 1]}), .{t});
    t.argc = n;
    return @call(.always_tail, enter(t, f), .{t});
}

// ---------------------------------------------------------------------------
// Cheney semispace GC

fn gc(t: *Thread, need: usize) void {
    t.gc_count += 1;
    const from = t.heap;
    // Everything allocated fits into a space of the same size.
    const to = std.heap.page_allocator.alloc(Word, @max(from.len, t.heap_target)) catch oom();
    var g = Gc{ .from = from, .to = to, .free = 0 };

    for (t.args) |*w| w.* = g.copy(w.*);
    t.self = g.copy(t.self);
    t.val = g.copy(t.val);
    for (t.globals) |*w| w.* = g.copy(w.*);
    for (t.err_irritants[0..t.err_n]) |*w| w.* = g.copy(w.*);
    g.scanFrames(t.stack[0..t.sp]);
    for (static_scan.items) |p| g.scanObject(p);

    var scan: usize = 0;
    while (scan < g.free) {
        const p = to.ptr + scan;
        g.scanObject(p);
        scan += 1 + hdrLen(p[0]);
    }

    std.heap.page_allocator.free(from);
    t.heap = to;
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

    fn copy(g: *Gc, w: Word) Word {
        if (!isPtr(w)) return w;
        const p = ptr(w);
        const a = @intFromPtr(p);
        if (a < @intFromPtr(g.from.ptr) or a >= @intFromPtr(g.from.ptr + g.from.len)) return w; // static
        if (hdrType(p[0]) == T_FWD) return p[1];
        const n = 1 + hdrLen(p[0]);
        const q = g.to.ptr + g.free;
        @memcpy(q[0..n], p[0..n]);
        g.free += n;
        const nw = tagPtr(q);
        p[0] = hdr(T_FWD, hdrLen(p[0]));
        p[1] = nw;
        return nw;
    }

    fn scanObject(g: *Gc, p: [*]Word) void {
        const len = hdrLen(p[0]);
        switch (hdrType(p[0])) {
            T_PAIR, T_VECTOR, T_BOX, T_STRING => for (p[1 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_CLOSURE => for (p[2 .. 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_STACK => g.scanFrames(p[1 .. 1 + len]),
            T_FLONUM, T_BUF8, T_BUF32, T_SYMBOL => {},
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
// Program entry, used by main.zig

pub const Program = struct {
    names: []const []const u8,
    init: *const fn (*Thread) void,
    entry: Code,
};

/// Names of the globals, for error messages
var global_names: []const []const u8 = &.{};

pub fn start(prog: Program) u8 {
    global_names = prog.names;
    const t = std.heap.page_allocator.create(Thread) catch oom();
    t.* = Thread.init(prog.names.len);
    prog.init(t);
    _ = run(t, staticProc(prog.entry), 0);
    os.flush();
    return t.exit_code;
}

pub const data = @import("data.zig");
pub const num = @import("num.zig");
pub const printer = @import("printer.zig");
/// Primitive procedures by Scheme name: rt.prims.@"%string-append"
pub const prims = @import("prims.zig");
