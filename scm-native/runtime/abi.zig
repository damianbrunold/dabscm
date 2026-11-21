//! The interface between compiled Scheme code and the runtime.
//!
//! The runtime (rtmain.zig and everything it imports) is one object; every
//! library and the program are objects of their own, compiled separately
//! and cached. Compiled code imports only this file (as "rt"): the value
//! representation, the thread layout (an extern struct), inline fast paths,
//! and the runtime functions. In the runtime object, those calls are direct;
//! in compiled code, they are extern functions that the runtime exports.
const std = @import("std");
const root = @import("root");

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
pub const T_HASHTABLE: u8 = 19; // [mode] [count] [buckets] [comparator] [epoch] [flags] (scanned)
pub const T_NATIVE: u8 = 20; // [kind (raw)] [pointer (raw)]: processes, file locks
pub const T_FWD: u8 = 0xff; // forwarded during GC: the length field holds the new address / 8

pub const F_LARGE: u8 = 1; // in the large-object space
pub const F_MARK: u8 = 2; // large object reached during this collection
pub const F_PRIM: u8 = 4; // closure of a primitive
pub const F_PERM: u8 = 8; // large object that is never freed (a constant)
pub const F_ESCAPE: u8 = 32; // closure whose one parameter is only called (an escape-only receiver)

/// Mark a procedure as an escape-only receiver (compiled code)
pub inline fn markEscapeOnly(w: Word) void {
    ptr(w)[0] |= @as(Word, F_ESCAPE) << 8;
}

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
// Thread state

/// Globals the runtime itself uses; the program tells where they are.
pub const Special = enum(u8) { raise, input_port, output_port, error_port };

pub const Thread = extern struct {
    args: [*]Word,
    args_len: usize,
    argc: u64 = 0,
    self: Word = fix(0),
    val: Word = fix(0),
    stack: [*]Word,
    stack_len: usize,
    sp: usize = 0,
    hp: [*]Word,
    hlimit: [*]Word,
    heap: [*]Word,
    heap_len: usize,
    /// the top of the heap, above the nursery, holds the flonums made by
    /// arithmetic slow paths (which reserve nothing): flo_ptr up to the end
    flo_ptr: [*]Word,
    /// dynamic-wind winders and exception handlers (lists)
    winders: Word = NIL,
    handlers: Word = NIL,
    specials: [4]?*Word = .{ null, null, null, null },
    gc_count: u64 = 0,
    heap_target: usize = 0,
    large_words: usize = 0,
    // the pending error, raised by errorCode
    err_msg_ptr: [*]const u8 = "",
    err_msg_len: usize = 0,
    err_irritants: [4]Word = .{ UNSPEC, UNSPEC, UNSPEC, UNSPEC },
    err_n: usize = 0,
    err_kind: i64 = 0, // 0 error, 1 read error, 2 file error
    // the running primitive, for error messages
    prim_name_ptr: [*]const u8 = "",
    prim_name_len: usize = 0,
    exit_code: u8 = 0,
    /// set by allocations outside the nursery: a collection is due at the
    /// next poll (or reserve)
    gc_requested: u8 = 0,

    /// Make sure `n` words can be pushed.
    pub inline fn ensureStack(t: *Thread, n: usize) void {
        if (t.sp + n > t.stack_len) impl.scm_grow_stack(t, t.sp + n);
    }

    /// Make sure there is room for `n` arguments.
    pub inline fn ensureArgs(t: *Thread, n: usize) void {
        if (n > t.args_len) impl.scm_grow_args(t, n);
    }

    /// A safepoint: collect if a collection was requested
    pub inline fn poll(t: *Thread) void {
        if (t.gc_requested != 0) impl.scm_gc(t, 0);
    }

    /// Make sure `n` words can be bump-allocated without a collection.
    pub inline fn reserve(t: *Thread, n: usize) void {
        // hlimit may lie below hp: allocLarge requests a collection that way
        if (@intFromPtr(t.hp) + 8 * n > @intFromPtr(t.hlimit)) impl.scm_gc(t, n);
    }

    pub inline fn allocRaw(t: *Thread, n: usize) [*]Word {
        const q = t.hp;
        t.hp += n;
        return q;
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
        const cell = t.specials[@intFromEnum(s)] orelse return null;
        return if (cell.* == UNBOUND) null else cell.*;
    }

    pub fn errMsg(t: *const Thread) []const u8 {
        return t.err_msg_ptr[0..t.err_msg_len];
    }
    pub fn setErrMsg(t: *Thread, msg: []const u8) void {
        t.err_msg_ptr = msg.ptr;
        t.err_msg_len = msg.len;
    }
    pub fn primName(t: *const Thread) []const u8 {
        return t.prim_name_ptr[0..t.prim_name_len];
    }
};

// ---------------------------------------------------------------------------
// Modules: every library and the program

/// A compiled module, as the program lists them (in initialization order)
pub const Module = extern struct {
    init: *const fn (*Thread) callconv(.c) void,
    entry: Code,
    globals: [*]Word,
    nglobals: usize,
};

pub const ModuleList = extern struct {
    modules: [*]const Module,
    count: usize,
};

// ---------------------------------------------------------------------------
// Runtime functions. In the runtime object, root.scm_runtime is the
// runtime itself; in compiled code, they are extern.

pub const impl = if (@hasDecl(root, "scm_runtime")) root.scm_runtime else struct {
    pub extern fn scm_gc(t: *Thread, n: usize) void;
    pub extern fn scm_grow_stack(t: *Thread, need: usize) void;
    pub extern fn scm_grow_args(t: *Thread, need: usize) void;
    pub extern fn scm_not_procedure(t: *Thread, p: Word) Code;
    pub extern fn scm_fail(t: *Thread, msg: [*]const u8, len: usize, irritants: [*]const Word, n: usize) Code;
    pub extern fn scm_type_error(t: *Thread, who: [*]const u8, len: usize, irritants: [*]const Word, n: usize) Code;
    pub extern fn scm_arith_error(t: *Thread, who: [*]const u8, len: usize, a: Word, b: Word) Code;
    pub extern fn scm_vector_error(t: *Thread, who: [*]const u8, len: usize, v: Word, i: Word) Code;
    pub extern fn scm_unbound_error(t: *Thread, name: [*]const u8, len: usize) Code;
    pub extern fn scm_arity_error(t: *Thread, n: u64, at_least: bool) Code;
    pub extern fn scm_rest_list(t: *Thread, nreq: usize) Word;
    pub extern fn scm_arith(t: *Thread, a: Word, b: Word, op: u8) Word;
    pub extern fn scm_compare(a: Word, b: Word, op: u8) u8;
    pub extern fn scm_eqv(a: Word, b: Word) bool;
    pub extern fn scm_const_string(utf8: [*]const u8, len: usize) Word;
    pub extern fn scm_intern(name: [*]const u8, len: usize) Word;
    pub extern fn scm_const_pair(a: Word, d: Word) Word;
    pub extern fn scm_const_vector(items: [*]const Word, n: usize) Word;
    pub extern fn scm_const_flonum(f: f64) Word;
    pub extern fn scm_const_bytevector(bytes: [*]const u8, n: usize) Word;
    pub extern fn scm_const_number(t: *Thread, text: [*]const u8, len: usize) Word;
    pub extern fn scm_static_proc(code: Code) Word;
    pub extern fn scm_primitive(code: Code, name: [*]const u8, len: usize) Word;
    pub extern fn scm_missing_primitive(name: [*]const u8, len: usize) Word;
    pub extern fn scm_not_procedure_code(t: *Thread) callconv(.c) void;
    pub extern fn scm_error_code(t: *Thread) callconv(.c) void;
    pub extern fn scm_remember(obj: Word) void;
};

/// Prepare a call of procedure `p` and return its code.
pub inline fn enter(t: *Thread, p: Word) Code {
    t.self = p;
    if (isPtr(p) and objType(p) == T_CLOSURE) return @ptrFromInt(ptr(p)[1]);
    return impl.scm_not_procedure(t, p);
}

/// Prepare a call of the procedure in the global cell and return its code;
/// name: "<module>: <variable>", for the error if it is unbound.
pub inline fn enterCell(t: *Thread, cell: *const Word, comptime name: []const u8) Code {
    const p = cell.*;
    t.self = p;
    if (isPtr(p) and objType(p) == T_CLOSURE) return @ptrFromInt(ptr(p)[1]);
    if (p == UNBOUND) return impl.scm_unbound_error(t, name.ptr, name.len);
    return impl.scm_not_procedure(t, p);
}

/// Code of the frame on top of the stack (the return).
pub inline fn retCode(t: *Thread) Code {
    const info: *const RetInfo = @ptrFromInt(t.stack[t.sp - 1]);
    return info.code;
}

/// The write barrier: after storing val into obj (a mutation), an old obj
/// holding a young val is remembered (see the collector in rt.zig)
pub inline fn barrier(t: *const Thread, obj: Word, val: Word) void {
    if (isYoung(t, val) and !isYoung(t, obj)) impl.scm_remember(obj);
}

pub inline fn isYoung(t: *const Thread, w: Word) bool {
    return isPtr(w) and (w -% @intFromPtr(t.heap)) < t.heap_len * 8;
}

/// Use a value whose result is not needed (compiled code).
pub inline fn ignore(_: Word) void {}

pub inline fn fail(t: *Thread, comptime msg: []const u8, irritants: []const Word) Code {
    return impl.scm_fail(t, msg.ptr, msg.len, irritants.ptr, irritants.len);
}
pub inline fn typeError(t: *Thread, comptime who: []const u8, irritants: []const Word) Code {
    return impl.scm_type_error(t, who.ptr, who.len, irritants.ptr, irritants.len);
}
pub inline fn arithError(t: *Thread, comptime who: []const u8, a: Word, b: Word) Code {
    return impl.scm_arith_error(t, who.ptr, who.len, a, b);
}
pub inline fn vectorError(t: *Thread, comptime who: []const u8, v: Word, i: Word) Code {
    return impl.scm_vector_error(t, who.ptr, who.len, v, i);
}
pub inline fn unboundError(t: *Thread, comptime name: []const u8) Code {
    return impl.scm_unbound_error(t, name.ptr, name.len);
}
pub inline fn arityErrorN(t: *Thread, n: u64, at_least: bool) Code {
    return impl.scm_arity_error(t, n, at_least);
}
pub inline fn restList(t: *Thread, nreq: usize) Word {
    return impl.scm_rest_list(t, nreq);
}

// --- arithmetic fast paths ----------------------------------------------------
// null: an error (a type error or division by exact zero)

pub const Op = enum(u8) { add, sub, mul, div };
pub const Cmp = enum(u8) { lt, gt, le, ge, eq };

pub const num = struct {
    pub inline fn add(t: *Thread, a: Word, b: Word) ?Word {
        if (isFix(a | b)) {
            const r = @addWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
            if (r[1] == 0) return @bitCast(r[0]);
        }
        return slow(t, a, b, .add);
    }
    pub inline fn sub(t: *Thread, a: Word, b: Word) ?Word {
        if (isFix(a | b)) {
            const r = @subWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
            if (r[1] == 0) return @bitCast(r[0]);
        }
        return slow(t, a, b, .sub);
    }
    pub inline fn mul(t: *Thread, a: Word, b: Word) ?Word {
        if (isFix(a | b)) {
            const r = @mulWithOverflow(unfix(a), @as(i64, @bitCast(b)));
            if (r[1] == 0) return @bitCast(r[0]);
        }
        return slow(t, a, b, .mul);
    }
    pub inline fn div(t: *Thread, a: Word, b: Word) ?Word {
        if (isFix(a | b) and b != fix(0)) {
            const x = unfix(a);
            const y = unfix(b);
            if (@rem(x, y) == 0 and !(x == fix_min and y == -1)) return fix(@divTrunc(x, y));
        }
        return slow(t, a, b, .div);
    }
    inline fn slow(t: *Thread, a: Word, b: Word, op: Op) ?Word {
        const r = impl.scm_arith(t, a, b, @intFromEnum(op));
        return if (r == UNBOUND) null else r;
    }
    pub inline fn cmp(a: Word, b: Word, comptime c: Cmp) ?bool {
        if (isFix(a | b)) {
            const x: i64 = @bitCast(a);
            const y: i64 = @bitCast(b);
            return switch (c) {
                .lt => x < y,
                .gt => x > y,
                .le => x <= y,
                .ge => x >= y,
                .eq => x == y,
            };
        }
        return switch (impl.scm_compare(a, b, @intFromEnum(c))) {
            0 => false,
            1 => true,
            else => null,
        };
    }
};

// --- data ------------------------------------------------------------------------

pub const data = struct {
    pub inline fn isVector(w: Word) bool {
        return isObj(w, T_VECTOR);
    }
    pub inline fn vectorLen(w: Word) usize {
        return @intCast(hdrLen(ptr(w)[0]));
    }
    pub inline fn vref(v: Word, i: Word) ?Word {
        if (!isVector(v) or !isFix(i)) return null;
        const k: u64 = @bitCast(unfix(i));
        if (k >= vectorLen(v)) return null;
        return ptr(v)[1 + k];
    }
    pub inline fn vset(v: Word, i: Word, x: Word) bool {
        if (!isVector(v) or !isFix(i)) return false;
        const k: u64 = @bitCast(unfix(i));
        if (k >= vectorLen(v)) return false;
        ptr(v)[1 + k] = x;
        return true;
    }
    pub inline fn eqv(a: Word, b: Word) bool {
        return a == b or impl.scm_eqv(a, b);
    }
    pub fn constString(comptime utf8: []const u8) Word {
        return impl.scm_const_string(utf8.ptr, utf8.len);
    }
    pub fn intern(comptime name: []const u8) Word {
        return impl.scm_intern(name.ptr, name.len);
    }
    pub fn constPair(a: Word, d: Word) Word {
        return impl.scm_const_pair(a, d);
    }
    pub fn constVector(items: []const Word) Word {
        return impl.scm_const_vector(items.ptr, items.len);
    }
    pub fn constFlonum(f: f64) Word {
        return impl.scm_const_flonum(f);
    }
    pub fn constBytevector(bytes: []const u8) Word {
        return impl.scm_const_bytevector(bytes.ptr, bytes.len);
    }
    pub fn constNumber(t: *Thread, comptime text: []const u8) Word {
        return impl.scm_const_number(t, text.ptr, text.len);
    }
};

pub fn staticProc(code: Code) Word {
    return impl.scm_static_proc(code);
}
pub fn primitive(code: Code, comptime name: []const u8) Word {
    return impl.scm_primitive(code, name.ptr, name.len);
}
pub fn missingPrimitive(comptime name: []const u8) Word {
    return impl.scm_missing_primitive(name.ptr, name.len);
}
pub const notProcedureCode: Code = &impl.scm_not_procedure_code;
/// Raises the pending error
pub const errorCode: Code = &impl.scm_error_code;
