//! Phase 0 spike: hand-written code in the shape the compiler would emit.
//!
//!   (define (fib n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
//!   (define (tak x y z) (if (not (< y x)) z
//!     (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y))))
//!   (define (ctak x y z) (call/cc (lambda (k) (ctak-aux k x y z))))
//!   (define (ctak-aux k x y z)
//!     (if (not (< y x)) (k z)
//!         (call/cc (lambda (k)
//!           (ctak-aux k
//!             (call/cc (lambda (k) (ctak-aux k (- x 1) y z)))
//!             (call/cc (lambda (k) (ctak-aux k (- y 1) z x)))
//!             (call/cc (lambda (k) (ctak-aux k (- z 1) x y))))))))
//!   (define (mk n) (if (= n 0) '() (cons n (mk (- n 1)))))      ; deep recursion
//!   (define (sum l acc) (if (null? l) acc (sum (cdr l) (+ acc (car l)))))
const std = @import("std");
const rt = @import("rt.zig");
const Thread = rt.Thread;
const Word = rt.Word;
const RetInfo = rt.RetInfo;
const fix = rt.fix;

const G_FIB = 0;
const G_TAK = 1;
const G_CTAK = 2;
const G_CTAK_AUX = 3;
const G_CALLCC = 4;
const G_MK = 5;
const G_SUM = 6;
const NGLOBALS = 7;

// Fixnum fast paths; the slow paths (bignum, flonum) are out of scope here.
inline fn add(a: Word, b: Word) Word {
    const r = @addWithOverflow(a, b);
    if (r[1] != 0 or !rt.isFix(a | b)) @panic("generic + not in spike");
    return r[0];
}
inline fn sub(a: Word, b: Word) Word {
    const r = @subWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
    if (r[1] != 0 or !rt.isFix(a | b)) @panic("generic - not in spike");
    return @bitCast(r[0]);
}
inline fn lt(a: Word, b: Word) bool {
    if (!rt.isFix(a | b)) @panic("generic < not in spike");
    return @as(i64, @bitCast(a)) < @as(i64, @bitCast(b));
}

inline fn callGlobal(t: *Thread, g: usize) rt.Code {
    return rt.enter(t, t.globals[g]);
}

// --- fib -------------------------------------------------------------------

fn fib(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, rt.wrongArgs, .{t});
    const n = t.reg[0];
    if (lt(n, fix(2))) {
        t.val = n;
        return @call(.always_tail, rt.retCode(t), .{t});
    }
    t.ensureStack(2);
    t.push(n);
    t.pushRet(&fib_k1);
    t.reg[0] = sub(n, fix(1));
    return @call(.always_tail, callGlobal(t, G_FIB), .{t});
}
const fib_k1: RetInfo = .{ .code = &fibK1, .size = 1 };
fn fibK1(t: *Thread) callconv(.c) void {
    const n = t.slot(1, 0);
    t.setSlot(1, 0, t.val);
    t.stack[t.sp - 1] = @intFromPtr(&fib_k2);
    t.reg[0] = sub(n, fix(2));
    t.argc = 1;
    return @call(.always_tail, callGlobal(t, G_FIB), .{t});
}
const fib_k2: RetInfo = .{ .code = &fibK2, .size = 1 };
fn fibK2(t: *Thread) callconv(.c) void {
    const a = t.slot(1, 0);
    t.sp -= 2;
    t.val = add(a, t.val);
    return @call(.always_tail, rt.retCode(t), .{t});
}

// --- tak -------------------------------------------------------------------

fn tak(t: *Thread) callconv(.c) void {
    if (t.argc != 3) return @call(.always_tail, rt.wrongArgs, .{t});
    const x = t.reg[0];
    const y = t.reg[1];
    const z = t.reg[2];
    if (!lt(y, x)) {
        t.val = z;
        return @call(.always_tail, rt.retCode(t), .{t});
    }
    t.ensureStack(6);
    t.push(x);
    t.push(y);
    t.push(z);
    t.pushRet(&tak_k1);
    t.reg[0] = sub(x, fix(1));
    return @call(.always_tail, callGlobal(t, G_TAK), .{t});
}
const tak_k1: RetInfo = .{ .code = &takK1, .size = 3 };
fn takK1(t: *Thread) callconv(.c) void {
    // frame [x y z] -> [x y z v1]
    const x = t.slot(3, 0);
    const y = t.slot(3, 1);
    const z = t.slot(3, 2);
    t.stack[t.sp - 1] = t.val;
    t.pushRet(&tak_k2);
    t.reg[0] = sub(y, fix(1));
    t.reg[1] = z;
    t.reg[2] = x;
    t.argc = 3;
    return @call(.always_tail, callGlobal(t, G_TAK), .{t});
}
const tak_k2: RetInfo = .{ .code = &takK2, .size = 4 };
fn takK2(t: *Thread) callconv(.c) void {
    // frame [x y z v1] -> [x y z v1 v2]
    const x = t.slot(4, 0);
    const y = t.slot(4, 1);
    const z = t.slot(4, 2);
    t.stack[t.sp - 1] = t.val;
    t.pushRet(&tak_k3);
    t.reg[0] = sub(z, fix(1));
    t.reg[1] = x;
    t.reg[2] = y;
    t.argc = 3;
    return @call(.always_tail, callGlobal(t, G_TAK), .{t});
}
const tak_k3: RetInfo = .{ .code = &takK3, .size = 5 };
fn takK3(t: *Thread) callconv(.c) void {
    t.reg[0] = t.slot(5, 3);
    t.reg[1] = t.slot(5, 4);
    t.reg[2] = t.val;
    t.argc = 3;
    t.sp -= 6;
    return @call(.always_tail, callGlobal(t, G_TAK), .{t});
}

// --- ctak ------------------------------------------------------------------

/// Allocate (lambda (k) ...) closing over x y z, then (call/cc it).
inline fn callccWith(t: *Thread, code: rt.Code, x: Word, y: Word, z: Word) rt.Code {
    // reserve() may collect: x y z are in reg[0..3] by convention of callers.
    const p = t.allocRaw(5);
    p[0] = rt.hdr(rt.T_CLOSURE, 4);
    p[1] = @intFromPtr(code);
    p[2] = x;
    p[3] = y;
    p[4] = z;
    t.reg[0] = rt.tagPtr(p);
    t.argc = 1;
    return callGlobal(t, G_CALLCC);
}

inline fn freeVar(t: *Thread, i: usize) Word {
    return rt.ptr(t.self)[2 + i];
}

fn ctak(t: *Thread) callconv(.c) void {
    if (t.argc != 3) return @call(.always_tail, rt.wrongArgs, .{t});
    t.reserve(5);
    return @call(.always_tail, callccWith(t, &ctakL1, t.reg[0], t.reg[1], t.reg[2]), .{t});
}
fn ctakL1(t: *Thread) callconv(.c) void {
    // (lambda (k) (ctak-aux k x y z))
    t.reg[1] = freeVar(t, 0);
    t.reg[2] = freeVar(t, 1);
    t.reg[3] = freeVar(t, 2);
    t.argc = 4;
    return @call(.always_tail, callGlobal(t, G_CTAK_AUX), .{t});
}

fn ctakAux(t: *Thread) callconv(.c) void {
    if (t.argc != 4) return @call(.always_tail, rt.wrongArgs, .{t});
    const k = t.reg[0];
    const x = t.reg[1];
    const y = t.reg[2];
    const z = t.reg[3];
    if (!lt(y, x)) {
        t.reg[0] = z;
        t.argc = 1;
        return @call(.always_tail, rt.enter(t, k), .{t});
    }
    // Live values must be re-read from the roots after a possible collection.
    t.reserve(5);
    return @call(.always_tail, callccWith(t, &ctakL2, t.reg[1], t.reg[2], t.reg[3]), .{t});
}
fn ctakL2(t: *Thread) callconv(.c) void {
    // (lambda (k) (ctak-aux k (call/cc L3) (call/cc L4) (call/cc L5)))
    const k = t.reg[0];
    const x = freeVar(t, 0);
    const y = freeVar(t, 1);
    const z = freeVar(t, 2);
    t.ensureStack(7);
    t.push(k);
    t.push(x);
    t.push(y);
    t.push(z);
    t.pushRet(&ctak_k1);
    t.reserve(5); // roots: frame holds x y z
    return @call(.always_tail, callccWith(t, &ctakL3, t.slot(4, 1), t.slot(4, 2), t.slot(4, 3)), .{t});
}
const ctak_k1: RetInfo = .{ .code = &ctakK1, .size = 4 };
fn ctakK1(t: *Thread) callconv(.c) void {
    t.ensureStack(1);
    t.stack[t.sp - 1] = t.val; // [k x y z v1]
    t.pushRet(&ctak_k2);
    t.reserve(5);
    return @call(.always_tail, callccWith(t, &ctakL4, t.slot(5, 1), t.slot(5, 2), t.slot(5, 3)), .{t});
}
const ctak_k2: RetInfo = .{ .code = &ctakK2, .size = 5 };
fn ctakK2(t: *Thread) callconv(.c) void {
    t.stack[t.sp - 1] = t.val; // [k x y z v1 v2]
    t.ensureStack(1);
    t.pushRet(&ctak_k3);
    t.reserve(5);
    return @call(.always_tail, callccWith(t, &ctakL5, t.slot(6, 1), t.slot(6, 2), t.slot(6, 3)), .{t});
}
const ctak_k3: RetInfo = .{ .code = &ctakK3, .size = 6 };
fn ctakK3(t: *Thread) callconv(.c) void {
    t.reg[0] = t.slot(6, 0);
    t.reg[1] = t.slot(6, 4);
    t.reg[2] = t.slot(6, 5);
    t.reg[3] = t.val;
    t.argc = 4;
    t.sp -= 7;
    return @call(.always_tail, callGlobal(t, G_CTAK_AUX), .{t});
}
fn ctakL3(t: *Thread) callconv(.c) void {
    // (lambda (k) (ctak-aux k (- x 1) y z))
    t.reg[1] = sub(freeVar(t, 0), fix(1));
    t.reg[2] = freeVar(t, 1);
    t.reg[3] = freeVar(t, 2);
    t.argc = 4;
    return @call(.always_tail, callGlobal(t, G_CTAK_AUX), .{t});
}
fn ctakL4(t: *Thread) callconv(.c) void {
    // (lambda (k) (ctak-aux k (- y 1) z x))
    t.reg[1] = sub(freeVar(t, 1), fix(1));
    t.reg[2] = freeVar(t, 2);
    t.reg[3] = freeVar(t, 0);
    t.argc = 4;
    return @call(.always_tail, callGlobal(t, G_CTAK_AUX), .{t});
}
fn ctakL5(t: *Thread) callconv(.c) void {
    // (lambda (k) (ctak-aux k (- z 1) x y))
    t.reg[1] = sub(freeVar(t, 2), fix(1));
    t.reg[2] = freeVar(t, 0);
    t.reg[3] = freeVar(t, 1);
    t.argc = 4;
    return @call(.always_tail, callGlobal(t, G_CTAK_AUX), .{t});
}

// --- mk / sum: deep recursion, allocation, GC --------------------------------

fn mk(t: *Thread) callconv(.c) void {
    if (t.argc != 1) return @call(.always_tail, rt.wrongArgs, .{t});
    const n = t.reg[0];
    if (n == fix(0)) {
        t.val = rt.NIL;
        return @call(.always_tail, rt.retCode(t), .{t});
    }
    t.ensureStack(2);
    t.push(n);
    t.pushRet(&mk_k1);
    t.reg[0] = sub(n, fix(1));
    return @call(.always_tail, callGlobal(t, G_MK), .{t});
}
const mk_k1: RetInfo = .{ .code = &mkK1, .size = 1 };
fn mkK1(t: *Thread) callconv(.c) void {
    t.reserve(3); // roots: n in the frame, the list in t.val
    const n = t.slot(1, 0);
    t.sp -= 2;
    t.val = t.cons(n, t.val);
    return @call(.always_tail, rt.retCode(t), .{t});
}

fn sum(t: *Thread) callconv(.c) void {
    // compiled as a loop: a self tail call becomes a jump
    if (t.argc != 2) return @call(.always_tail, rt.wrongArgs, .{t});
    var l = t.reg[0];
    var acc = t.reg[1];
    while (l != rt.NIL) {
        if (!rt.isPtr(l) or rt.objType(l) != rt.T_PAIR) return @call(.always_tail, rt.typeError, .{t});
        const p = rt.ptr(l);
        acc = add(acc, p[1]);
        l = p[2];
    }
    t.val = acc;
    return @call(.always_tail, rt.retCode(t), .{t});
}

// ---------------------------------------------------------------------------

fn bench(io: std.Io, name: []const u8, t: *Thread, g: usize, args: []const i64, reps: usize) void {
    const t0 = std.Io.Clock.awake.now(io);
    var r: Word = 0;
    for (0..reps) |_| {
        for (args, 0..) |a, i| t.reg[i] = fix(a);
        r = rt.run(t, t.globals[g], args.len);
        if (t.failed) return;
    }
    const t1 = std.Io.Clock.awake.now(io);
    const ms = @as(f64, @floatFromInt(t1.nanoseconds - t0.nanoseconds)) / 1e6;
    std.debug.print("{s:<24} result {d:<10} {d:>9.2} ms total, {d:>8.3} ms/run  (gc {d})\n", .{ name, rt.unfix(r), ms, ms / @as(f64, @floatFromInt(reps)), t.gc_count });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var thread = try Thread.init(1 << 20, 1 << 10, NGLOBALS);
    const t = &thread;
    t.globals[G_FIB] = rt.makeClosure(t, &fib, 0);
    t.globals[G_TAK] = rt.makeClosure(t, &tak, 0);
    t.globals[G_CTAK] = rt.makeClosure(t, &ctak, 0);
    t.globals[G_CTAK_AUX] = rt.makeClosure(t, &ctakAux, 0);
    t.globals[G_CALLCC] = rt.makeCallcc(t);
    t.globals[G_MK] = rt.makeClosure(t, &mk, 0);
    t.globals[G_SUM] = rt.makeClosure(t, &sum, 0);

    bench(io, "fib 30", t, G_FIB, &.{30}, 5);
    bench(io, "tak 18 12 6", t, G_TAK, &.{ 18, 12, 6 }, 200);
    bench(io, "ctak 18 12 6", t, G_CTAK, &.{ 18, 12, 6 }, 20);

    // mk 1e6 (1e6 frames deep, 1e6 pairs), then sum the list
    const t0 = std.Io.Clock.awake.now(io);
    var total: i64 = 0;
    for (0..20) |_| {
        t.reg[0] = fix(1_000_000);
        const l = rt.run(t, t.globals[G_MK], 1);
        t.reg[0] = l;
        t.reg[1] = fix(0);
        total += rt.unfix(rt.run(t, t.globals[G_SUM], 2));
    }
    const t1 = std.Io.Clock.awake.now(io);
    const ms = @as(f64, @floatFromInt(t1.nanoseconds - t0.nanoseconds)) / 1e6;
    std.debug.print("{s:<24} result {d:<10} {d:>9.2} ms total, {d:>8.3} ms/run  (gc {d}, stack {d} words)\n", .{ "mk+sum 1e6", total, ms, ms / 20.0, t.gc_count, t.stack.len });
}
