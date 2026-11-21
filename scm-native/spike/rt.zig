//! Phase 0 spike runtime: tagged words, explicit Scheme stack, guaranteed
//! tail calls between code blocks, precise Cheney semispace GC.
//!
//! Calling convention
//!   * every code block has the signature `fn (*Thread) callconv(.c) void`
//!     and transfers control with `@call(.always_tail, next, .{t})`
//!   * arguments in t.reg[0..argc], the callee closure in t.self
//!   * a non-tail call pushes a frame: live slots, then a pointer to a static
//!     RetInfo {code, size}; the return value is passed in t.val
//!   * a code block that allocates first calls `reserve`, while every live
//!     value is in a root (reg, self, val, stack, globals); after that it
//!     bump-allocates without checks, so the GC never sees Zig locals
const std = @import("std");

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

// Heap object header: type in the low 8 bits, payload length (words) above.
pub const T_PAIR: u8 = 1;
pub const T_CLOSURE: u8 = 2; // payload[0] = code (raw), rest scanned
pub const T_STACK: u8 = 3; // copied stack frames (scanned frame by frame)
pub const T_VECTOR: u8 = 4;
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

// ---------------------------------------------------------------------------
// Thread state

pub const NREG = 8;

pub const Thread = struct {
    reg: [NREG]Word = @splat(fix(0)),
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
    failed: bool = false,

    pub fn init(heap_words: usize, stack_words: usize, nglobals: usize) !Thread {
        const heap = try std.heap.page_allocator.alloc(Word, heap_words);
        const stack = try std.heap.page_allocator.alloc(Word, stack_words);
        const globals = try std.heap.page_allocator.alloc(Word, nglobals);
        @memset(globals, fix(0));
        return .{
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

    /// Make sure `n` words can be bump-allocated.
    pub inline fn reserve(t: *Thread, n: usize) void {
        if (@intFromPtr(t.hp + n) > @intFromPtr(t.hlimit)) gc(t, n);
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

    pub inline fn push(t: *Thread, w: Word) void {
        t.stack[t.sp] = w;
        t.sp += 1;
    }

    pub inline fn pushRet(t: *Thread, info: *const RetInfo) void {
        t.stack[t.sp] = @intFromPtr(info);
        t.sp += 1;
    }

    /// Frame slot i (0 = deepest) of a frame with `size` slots on top.
    pub inline fn slot(t: *Thread, size: usize, i: usize) Word {
        return t.stack[t.sp - 1 - size + i];
    }

    pub inline fn setSlot(t: *Thread, size: usize, i: usize, w: Word) void {
        t.stack[t.sp - 1 - size + i] = w;
    }
};

fn growStack(t: *Thread, need: usize) void {
    var n = t.stack.len * 2;
    while (n < need) n *= 2;
    t.stack = std.heap.page_allocator.realloc(t.stack, n) catch @panic("out of memory (stack)");
}

// ---------------------------------------------------------------------------
// Control helpers. They return the code to tail-call, so every transfer in
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
    return &notAProcedure;
}

fn notAProcedure(t: *Thread) callconv(.c) void {
    std.debug.print("error: not a procedure: {x}\n", .{t.self});
    t.failed = true;
}

pub fn wrongArgs(t: *Thread) callconv(.c) void {
    std.debug.print("error: wrong number of arguments: {d}\n", .{t.argc});
    t.failed = true;
}

pub fn typeError(t: *Thread) callconv(.c) void {
    std.debug.print("error: wrong type\n", .{});
    t.failed = true;
}

fn haltCode(_: *Thread) callconv(.c) void {}
pub const halt_info: RetInfo = .{ .code = &haltCode, .size = 0 };

/// Run procedure `p` with the arguments already in t.reg, to completion.
pub fn run(t: *Thread, p: Word, argc: u64) Word {
    t.sp = 0;
    t.pushRet(&halt_info);
    t.argc = argc;
    enter(t, p)(t);
    return t.val;
}

/// Static closure for a global procedure.
pub fn makeClosure(t: *Thread, code: Code, nfree: usize) Word {
    t.reserve(2 + nfree);
    const p = t.allocRaw(2 + nfree);
    p[0] = hdr(T_CLOSURE, 1 + nfree);
    p[1] = @intFromPtr(code);
    return tagPtr(p);
}

// ---------------------------------------------------------------------------
// call/cc by copying the whole stack (Phase 0; segments come later)

fn callccCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, wrongArgs, .{t});
    const n = t.sp;
    t.reserve(1 + n + 3);
    const s = t.allocRaw(1 + n);
    s[0] = hdr(T_STACK, n);
    @memcpy(s[1 .. 1 + n], t.stack[0..n]);
    const k = t.allocRaw(3);
    k[0] = hdr(T_CLOSURE, 2);
    k[1] = @intFromPtr(&contCode);
    k[2] = tagPtr(s);
    const f = t.reg[0];
    t.reg[0] = tagPtr(k);
    return @call(.always_tail, enter(t, f), .{t});
}

fn contCode(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, wrongArgs, .{t});
    const s = ptr(ptr(t.self)[2]);
    const n = hdrLen(s[0]);
    t.sp = 0;
    t.ensureStack(n);
    @memcpy(t.stack[0..n], s[1 .. 1 + n]);
    t.sp = n;
    t.val = t.reg[0];
    return @call(.always_tail, retCode(t), .{t});
}

pub fn makeCallcc(t: *Thread) Word {
    return makeClosure(t, &callccCode, 0);
}

// ---------------------------------------------------------------------------
// Cheney semispace GC

fn gc(t: *Thread, need: usize) void {
    t.gc_count += 1;
    const from = t.heap;
    // Everything allocated fits into a space of the same size.
    const to = std.heap.page_allocator.alloc(Word, @max(from.len, t.heap_target)) catch @panic("out of memory (heap)");
    var g = Gc{ .from = from, .to = to, .free = 0 };

    for (&t.reg) |*w| w.* = g.copy(w.*);
    t.self = g.copy(t.self);
    t.val = g.copy(t.val);
    for (t.globals) |*w| w.* = g.copy(w.*);
    g.scanFrames(t.stack[0..t.sp]);

    var scan: usize = 0;
    while (scan < g.free) {
        const h = to[scan];
        const len = hdrLen(h);
        switch (hdrType(h)) {
            T_PAIR, T_VECTOR => for (to[scan + 1 .. scan + 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_CLOSURE => for (to[scan + 2 .. scan + 1 + len]) |*w| {
                w.* = g.copy(w.*);
            },
            T_STACK => g.scanFrames(to[scan + 1 .. scan + 1 + len]),
            else => unreachable,
        }
        scan += 1 + len;
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
