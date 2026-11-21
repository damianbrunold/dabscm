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
pub inline fn fixFits(n: i64) bool {
    return n >= fix_min and n <= fix_max;
}
pub inline fn isPtr(w: Word) bool {
    return w & 0b111 == 0b001;
}
pub inline fn ptr(w: Word) [*]Word {
    return @ptrFromInt(w - 1);
}
pub inline fn tagPtr(q: [*]Word) Word {
    return @intFromPtr(q) + 1;
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

// Heap object header: type (8 bits), flags (8 bits), payload length in words.
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
pub const T_VALUES: u8 = 11; // multiple values (scanned)
pub const T_RECORD: u8 = 12; // [type] [fields...] (scanned)
pub const T_ERROR: u8 = 13; // [message] [irritants] [kind (fixnum)]
pub const T_PORT: u8 = 14; // [*Port (raw)]
pub const T_BYTEVECTOR: u8 = 15; // [byte length (raw)] [bytes (raw)]
pub const T_BIGNUM: u8 = 16; // [sign and limb count (raw)] [limbs (raw)]
pub const T_RATNUM: u8 = 17; // [numerator] [denominator] (scanned)
pub const T_COMPNUM: u8 = 18; // [real] [imaginary] (scanned)
pub const T_FWD: u8 = 0xff; // forwarded during GC, payload[0] = new pointer

pub const F_LARGE: u8 = 1; // in the large-object space
pub const F_MARK: u8 = 2; // large object reached during this collection
pub const F_PRIM: u8 = 4; // closure of a primitive
pub const F_PERM: u8 = 8; // large object that is never freed (a constant)

pub inline fn hdr(ty: u8, len: u64) Word {
    return (len << 16) | ty;
}
pub inline fn hdrType(h: Word) u8 {
    return @truncate(h);
}
pub inline fn hdrFlags(h: Word) u8 {
    return @truncate(h >> 8);
}
pub inline fn hdrLen(h: Word) u64 {
    return h >> 16;
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
pub inline fn isPrimitive(w: Word) bool {
    return isProcedure(w) and hdrFlags(ptr(w)[0]) & F_PRIM != 0;
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

/// Globals the runtime itself uses; the program tells where they are.
pub const Special = enum { raise, input_port, output_port, error_port };

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
    /// dynamic-wind winders and exception handlers (lists)
    winders: Word = NIL,
    handlers: Word = NIL,
    specials: [4]?usize = .{ null, null, null, null },
    gc_count: u64 = 0,
    heap_target: usize = 0,
    large: std.ArrayList([*]Word) = .empty,
    large_words: usize = 0,
    // the pending error, reported by errorCode
    err_msg: []const u8 = "",
    err_irritants: [4]Word = .{ UNSPEC, UNSPEC, UNSPEC, UNSPEC },
    err_n: usize = 0,
    err_kind: i64 = 0, // 0 error, 1 read error, 2 file error
    prim_name: []const u8 = "", // the running primitive, for error messages
    exit_code: u8 = 0,

    pub fn init(nglobals: usize) Thread {
        const pa = std.heap.page_allocator;
        const heap = pa.alloc(Word, 1 << 20) catch oom();
        const stack = pa.alloc(Word, 1 << 12) catch oom();
        const args = pa.alloc(Word, 256) catch oom();
        const globals = pa.alloc(Word, @max(nglobals, 1)) catch oom();
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
        // hlimit may lie below hp: allocLarge requests a collection that way
        if (@intFromPtr(t.hp) + 8 * n > @intFromPtr(t.hlimit)) gc(t, n);
    }

    pub inline fn allocRaw(t: *Thread, n: usize) [*]Word {
        const q = t.hp;
        t.hp += n;
        return q;
    }

    /// An object of n words (header included) that is not moved by the GC;
    /// allocating it never collects, so it is safe anywhere.
    pub fn allocLarge(t: *Thread, n: usize) [*]Word {
        const mem = std.heap.page_allocator.alloc(Word, n) catch oom();
        t.large.append(std.heap.page_allocator, mem.ptr) catch oom();
        t.large_words += n;
        // the collection happens at the next reserve
        if (t.large_words > t.heap.len) t.hlimit = t.hp;
        return mem.ptr;
    }

    pub inline fn cons(t: *Thread, a: Word, d: Word) Word {
        const q = t.allocRaw(3);
        q[0] = hdr(T_PAIR, 2);
        q[1] = a;
        q[2] = d;
        return tagPtr(q);
    }

    pub inline fn box(t: *Thread, v: Word) Word {
        const q = t.allocRaw(2);
        q[0] = hdr(T_BOX, 1);
        q[1] = v;
        return tagPtr(q);
    }

    pub inline fn makeFlo(t: *Thread, f: f64) Word {
        const q = t.allocRaw(2);
        q[0] = hdr(T_FLONUM, 1);
        q[1] = @bitCast(f);
        return tagPtr(q);
    }

    /// A closure with `n` free variables, filled in by the caller.
    pub inline fn closure(t: *Thread, code: Code, n: usize) [*]Word {
        const q = t.allocRaw(2 + n);
        q[0] = hdr(T_CLOSURE, 1 + n);
        q[1] = @intFromPtr(code);
        return q;
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

    pub fn special(t: *Thread, s: Special) ?Word {
        const i = t.specials[@intFromEnum(s)] orelse return null;
        const w = t.globals[i];
        return if (w == UNBOUND) null else w;
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
    return notProcedure(t, p);
}

fn notProcedure(t: *Thread, p: Word) Code {
    var buf: std.ArrayList(u8) = .empty;
    printer.print(&buf, p, true);
    return fail(t, std.fmt.allocPrint(std.heap.page_allocator, "{s} is not a function, cannot apply", .{buf.items}) catch oom(), &.{});
}

/// Prepare a call of the procedure in global i and return its code.
pub inline fn enterGlobal(t: *Thread, i: usize) Code {
    const p = t.globals[i];
    t.self = p;
    if (isPtr(p) and objType(p) == T_CLOSURE) return @ptrFromInt(ptr(p)[1]);
    if (p == UNBOUND) return unboundError(t, global_names[i]);
    return notProcedure(t, p);
}

/// Use a value whose result is not needed (generated code).
pub inline fn ignore(_: Word) void {}

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
    t.err_msg = msg;
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
    t.reserve(data.stringWords(t.err_msg.len, true) + 3 * n + 4);
    const msg = data.heapStringUtf8(t, t.err_msg);
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

/// The value of (%primitive "name"): primitives are code, or values made at
/// startup (ports, constants).
pub fn primitive(comptime x: anytype, name: []const u8) Word {
    if (@TypeOf(x) == Code) {
        const q = staticAlloc(3, false);
        q[0] = hdr(T_CLOSURE, 2) | (@as(Word, F_PRIM) << 8);
        q[1] = @intFromPtr(x);
        q[2] = data.intern(name);
        return tagPtr(q);
    }
    return x.make();
}

/// The code of a primitive called directly
pub fn primCode(comptime x: anytype) Code {
    if (@TypeOf(x) == Code) return x;
    return &notAProcedureCode;
}

fn notAProcedureCode(t: *Thread) callconv(.c) void {
    return @call(.always_tail, fail(t, "not a procedure", &.{}), .{t});
}

/// A primitive that is a value
pub const ValuePrim = struct { make: *const fn () Word };

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
    const from = t.heap;
    // Everything allocated fits into a space of the same size.
    const to = std.heap.page_allocator.alloc(Word, @max(from.len, t.heap_target)) catch oom();
    var g = Gc{ .from = from, .to = to, .free = 0 };

    for (t.args) |*w| w.* = g.copy(w.*);
    t.self = g.copy(t.self);
    t.val = g.copy(t.val);
    t.winders = g.copy(t.winders);
    t.handlers = g.copy(t.handlers);
    for (t.globals) |*w| w.* = g.copy(w.*);
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
    for (t.large.items) |q| {
        if (hdrFlags(q[0]) & (F_MARK | F_PERM) != 0) {
            q[0] &= ~(@as(Word, F_MARK) << 8);
            t.large.items[kept] = q;
            kept += 1;
            words += 1 + hdrLen(q[0]);
        } else {
            std.heap.page_allocator.free(q[0 .. 1 + hdrLen(q[0])]);
        }
    }
    t.large.items.len = kept;
    t.large_words = words;
    g.large_todo.deinit(std.heap.page_allocator);

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
// Program entry, used by main.zig

pub const Program = struct {
    names: []const []const u8,
    init: *const fn (*Thread) void,
    entry: Code,
};

/// Names of the globals, for error messages
var global_names: []const []const u8 = &.{};
pub var command_line: []const [:0]const u8 = &.{};

pub fn start(prog: Program, args: []const [:0]const u8) u8 {
    global_names = prog.names;
    command_line = args;
    const t = std.heap.page_allocator.create(Thread) catch oom();
    t.* = Thread.init(prog.names.len);
    num.current_thread = t;
    prog.init(t);
    _ = run(t, staticProc(prog.entry), 0);
    ports.flushAll();
    os.flush();
    return t.exit_code;
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
