//! SRFI 18 threads, mutexes and condition variables, as the JVM and C#
//! implementations' primitives (their semantics and messages): every
//! thread is an OS thread with its own abi.Thread (nursery, stack,
//! registers); globals are shared; parameters are per thread (prims_ctl).
//!
//! The objects are records (scanned by the collector) whose type is a
//! static marker, with their native part (locks, the OS thread) in slot 1
//! as a fixnum address:
//!   thread:  [marker] [ctl] [thunk] [name] [specific] [result] [exception] [state] [flags]
//!   mutex:   [marker] [ctl] [name] [specific]
//!   condvar: [marker] [ctl] [name] [specific]
//!   thread exception (join timeout, abandoned mutex, terminated thread,
//!   uncaught exception): [marker] [kind] [reason]
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const os = @import("os.zig");
const tower = @import("tower.zig");
const num = @import("num.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Code = rt.Code;
const Err = P.Err;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const Io = std.Io;

const pa = std.heap.c_allocator;

// --- the markers ------------------------------------------------------------

var thread_marker: Word = 0;
var mutex_marker: Word = 0;
var condvar_marker: Word = 0;
var texc_marker: Word = 0;

fn marker(name: []const u8) Word {
    const q = rt.staticAlloc(2, false);
    q[0] = rt.hdr(rt.T_RECORD, 1);
    q[1] = data.intern(name);
    return rt.tagPtr(q);
}

fn markers() void {
    if (thread_marker != 0) return;
    rt.lockWorld();
    defer rt.unlockWorld();
    if (thread_marker != 0) return;
    mutex_marker = marker("mutex");
    condvar_marker = marker("condition-variable");
    texc_marker = marker("thread-exception");
    @atomicStore(Word, &thread_marker, marker("thread"), .release);
}

fn isKind(w: Word, m: Word) bool {
    return m != 0 and data.isRecord(w) and data.recordSize(w) >= 2 and data.recordSlots(w)[0] == m;
}

fn ctlOf(comptime T: type, w: Word) *T {
    return @ptrFromInt(@as(usize, @intCast(rt.unfix(data.recordSlots(w)[1]))));
}

fn slot(w: Word, i: usize) Word {
    return data.recordSlots(w)[i];
}

fn setSlot(t: *Thread, w: Word, i: usize, v: Word) void {
    data.recordSlots(w)[i] = v;
    rt.barrier(t, w, v);
}

// --- time -------------------------------------------------------------------

/// A timeout argument: milliseconds, null for none (#f or absent)
fn timeoutArg(t: *Thread, who: []const u8, i: usize) Err!?i64 {
    if (t.argc <= i or arg(t, i) == rt.FALSE) return null;
    const w = arg(t, i);
    if (!num.isNumber(w)) return raise(t, msg("{s}: invalid timeout ~s", .{who}), &.{w});
    const s = tower.toFloat(w);
    if (!(s > 0)) return 0;
    return @intFromFloat(@min(s * 1000.0, 1e15));
}

fn msg(comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(pa, fmt, args) catch rt.oom();
}

fn timeout(ms: ?i64) Io.Timeout {
    const m = ms orelse return .none;
    return .{ .duration = .{ .raw = .fromMilliseconds(m), .clock = .awake } };
}

// --- threads ----------------------------------------------------------------

const State = struct {
    const new = 0;
    const started = 1;
    const done = 2;
};
const Flag = struct {
    const terminated = 1;
    const exception = 2;
};

const ThreadCtl = struct {
    lock: Io.Mutex = .init,
    cond: Io.Condition = .init,
    done: bool = false,
    /// the running thread's state (null before it starts and after it ends)
    t: ?*Thread = null,
    /// the mutexes it holds (abandoned when it ends)
    held: std.ArrayList(*MutexCtl) = .empty,
};

fn newThreadObject(t: *Thread, thunk_i: ?usize, name: Word, state: i64) Word {
    t.reserve(1 + 9);
    const ctl = pa.create(ThreadCtl) catch rt.oom();
    ctl.* = .{};
    const r = data.makeRecord(t, 9);
    const s = data.recordSlots(r);
    s[0] = thread_marker;
    s[1] = rt.fix(@intCast(@intFromPtr(ctl)));
    s[2] = if (thunk_i) |i| arg(t, i) else rt.FALSE;
    s[3] = name;
    s[4] = rt.NIL;
    s[5] = rt.UNSPEC;
    s[6] = rt.FALSE;
    s[7] = rt.fix(state);
    s[8] = rt.fix(0);
    return r;
}

/// The running thread's object (made for the program's thread, named
/// primordial, when first asked for)
pub fn currentThreadObject(t: *Thread) Word {
    markers();
    if (t.thread_obj == rt.FALSE) {
        const r = newThreadObject(t, null, data.intern("primordial"), State.started);
        ctlOf(ThreadCtl, r).t = t;
        t.thread_obj = r;
        t.ctl = ctlOf(ThreadCtl, r);
    }
    return t.thread_obj;
}

fn threadArg(t: *Thread, i: usize) Err!Word {
    const w = arg(t, i);
    if (!isKind(w, thread_marker)) return P.argTypeError(t);
    return w;
}

fn currentThread(t: *Thread) Err!Word {
    return currentThreadObject(t);
}
pub const @"%current-thread" = WN("current-thread", currentThread, 0, 0);

fn threadP(t: *Thread) Err!Word {
    return rt.boolean(isKind(arg(t, 0), thread_marker));
}
pub const @"%thread?" = WN("thread?", threadP, 1, 1);

fn makeThread(t: *Thread) Err!Word {
    markers();
    if (!rt.isProcedure(arg(t, 0))) return P.argTypeError(t);
    return newThreadObject(t, 0, if (t.argc > 1) arg(t, 1) else rt.FALSE, State.new);
}
pub const @"%make-thread" = WN("make-thread", makeThread, 1, 2);

fn threadName(t: *Thread) Err!Word {
    return slot(try threadArg(t, 0), 3);
}
pub const @"%thread-name" = WN("thread-name", threadName, 1, 1);

fn threadSpecific(t: *Thread) Err!Word {
    return slot(try threadArg(t, 0), 4);
}
pub const @"%thread-specific" = WN("thread-specific", threadSpecific, 1, 1);

fn threadSpecificSet(t: *Thread) Err!Word {
    setSlot(t, try threadArg(t, 0), 4, arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%thread-specific-set!" = WN("thread-specific-set!", threadSpecificSet, 2, 2);

/// The handler at the bottom of a thread's handler list: an uncaught
/// exception ends the thread (thread-join! raises it, wrapped)
fn uncaughtHandlerCode(t: *Thread) callconv(.c) void {
    const r = t.thread_obj;
    const e = if (t.argc > 0) t.args[0] else rt.UNSPEC;
    setSlot(t, r, 6, e);
    data.recordSlots(r)[8] = rt.fix(rt.unfix(slot(r, 8)) | Flag.exception);
    // returning ends the run (threadMain)
}
var uncaught_handler: Word = 0;

fn threadStart(t: *Thread) Err!Word {
    const r0 = try threadArg(t, 0);
    if (rt.unfix(slot(r0, 7)) != State.new) return raise(t, "thread-start!: thread already started", &.{});
    if (uncaught_handler == 0) {
        rt.lockWorld();
        if (uncaught_handler == 0) uncaught_handler = rt.primitive(&uncaughtHandlerCode, "uncaught-exception-handler");
        rt.unlockWorld();
    }
    const r = arg(t, 0);
    data.recordSlots(r)[7] = rt.fix(State.started);
    const ctl = ctlOf(ThreadCtl, r);
    rt.lockWorld();
    const nt = rt.newThread();
    // the program's special cells (raise, the current ports): errors of
    // primitives in the thread go to its handlers, as Scheme raises do
    nt.specials = t.specials;
    nt.thread_obj = r;
    nt.ctl = ctl;
    ctl.t = nt;
    rt.registerThreadLocked(nt);
    rt.unlockWorld();
    const th = std.Thread.spawn(.{ .stack_size = 8 << 20 }, threadMain, .{nt}) catch {
        return raise(t, "thread-start!: cannot create a thread", &.{});
    };
    th.detach();
    return arg(t, 0);
}
pub const @"%thread-start!" = WN("thread-start!", threadStart, 1, 1);

fn threadMain(t: *Thread) void {
    num.current_thread = t;
    rt.blockingEnd(t); // join the world (after a collection under way)
    t.reserve(3);
    t.handlers = t.cons(uncaught_handler, rt.NIL);
    const thunk = slot(t.thread_obj, 2);
    const result = rt.run(t, thunk, 0);
    const r = t.thread_obj;
    const ctl: *ThreadCtl = @ptrCast(@alignCast(t.ctl.?));
    var flags = rt.unfix(slot(r, 8));
    if (@atomicLoad(u8, &t.terminate_requested, .monotonic) != 0 and flags & Flag.exception == 0) {
        // as on the JVM: the thread ended with the error "thread terminated"
        const text = "thread terminated";
        t.reserve(data.stringWords(text.len, true) + 4);
        const e = rt.makeError(t, data.heapStringUtf8(t, text), rt.NIL, 0);
        setSlot(t, t.thread_obj, 6, e);
        flags |= Flag.terminated | Flag.exception;
    }
    if (flags & (Flag.exception | Flag.terminated) == 0) setSlot(t, t.thread_obj, 5, result);
    data.recordSlots(t.thread_obj)[8] = rt.fix(flags);
    data.recordSlots(t.thread_obj)[7] = rt.fix(State.done);
    // abandon the mutexes it still holds (lock order: a mutex, then its
    // owner's ctl: take the list first)
    ctl.lock.lockUncancelable(os.io);
    const held = ctl.held.toOwnedSlice(pa) catch rt.oom();
    ctl.lock.unlock(os.io);
    defer pa.free(held);
    for (held) |m| {
        m.lock.lockUncancelable(os.io);
        if (m.owner == ctl) {
            m.locked = false;
            m.owner = null;
            m.owner_obj = null;
            m.abandoned = true;
            m.cond.signal(os.io);
        }
        m.lock.unlock(os.io);
    }
    ctl.lock.lockUncancelable(os.io);
    ctl.done = true;
    ctl.t = null;
    ctl.cond.broadcast(os.io);
    ctl.lock.unlock(os.io);
    rt.threadEnded(t);
}

fn threadException(t: *Thread, comptime kind_name: []const u8, kind: i64, reason: Word) Err {
    markers();
    // reason may move: keep it in an argument register over the allocation
    t.ensureArgs(t.argc + 1);
    t.args[t.argc] = reason;
    t.reserve(1 + 3);
    const e = data.makeRecord(t, 3);
    const s = data.recordSlots(e);
    s[0] = texc_marker;
    s[1] = rt.fix(kind);
    s[2] = t.args[t.argc];
    return raise(t, kind_name, &.{e});
}

const Kind = struct {
    const join_timeout = 0;
    const abandoned_mutex = 1;
    const terminated_thread = 2;
    const uncaught = 3;
};

fn threadJoin(t: *Thread) Err!Word {
    _ = try threadArg(t, 0);
    const ms = try timeoutArg(t, "thread-join!", 1);
    const ctl = ctlOf(ThreadCtl, arg(t, 0));
    var completed = true;
    if (rt.unfix(slot(arg(t, 0), 7)) == State.new) {
        // a thread never started does not complete (as on the JVM)
        completed = false;
    } else if (rt.unfix(slot(arg(t, 0), 7)) == State.done and !ctl.done) {
        // terminated before it started
        completed = true;
    } else {
        rt.blockingBegin(t);
        ctl.lock.lockUncancelable(os.io);
        const to = timeout(ms).toDeadline(os.io);
        while (!ctl.done) {
            ctl.cond.waitTimeout(os.io, &ctl.lock, to) catch {
                completed = ctl.done;
                break;
            };
        }
        ctl.lock.unlock(os.io);
        rt.blockingEnd(t);
    }
    const r = arg(t, 0);
    if (!completed) {
        if (t.argc >= 3) return arg(t, 2);
        return threadException(t, "join-timeout-exception", Kind.join_timeout, rt.UNSPEC);
    }
    const flags = rt.unfix(slot(r, 8));
    if (flags & Flag.exception != 0) return threadException(t, "uncaught-exception", Kind.uncaught, slot(r, 6));
    if (flags & Flag.terminated != 0) return threadException(t, "terminated-thread-exception", Kind.terminated_thread, rt.UNSPEC);
    return slot(r, 5);
}
pub const @"%thread-join!" = WN("thread-join!", threadJoin, 1, 3);

fn threadTerminate(t: *Thread) Err!Word {
    const r = try threadArg(t, 0);
    const ctl = ctlOf(ThreadCtl, r);
    data.recordSlots(r)[8] = rt.fix(rt.unfix(slot(r, 8)) | Flag.terminated);
    if (r == t.thread_obj) {
        @atomicStore(u8, &t.terminate_requested, 1, .monotonic);
        return raise(t, "thread terminated", &.{});
    }
    rt.lockWorld();
    if (ctl.t) |o| {
        @atomicStore(u8, &o.terminate_requested, 1, .monotonic);
        @atomicStore(u8, &o.gc_requested, 1, .monotonic);
        @atomicStore([*]Word, &o.hlimit, o.heap, .monotonic);
    } else if (rt.unfix(slot(r, 7)) == State.new) {
        data.recordSlots(r)[7] = rt.fix(State.done);
        ctl.done = true;
    }
    rt.unlockWorld();
    return rt.NIL;
}
pub const @"%thread-terminate!" = WN("thread-terminate!", threadTerminate, 1, 1);

fn threadYield(t: *Thread) Err!Word {
    rt.blockingBegin(t);
    std.Thread.yield() catch {};
    rt.blockingEnd(t);
    return rt.NIL;
}
pub const @"%thread-yield!" = WN("thread-yield!", threadYield, 0, 0);

fn threadSleep(t: *Thread) Err!Word {
    const w = arg(t, 0);
    if (!num.isNumber(w)) return raise(t, "thread-sleep!: expected time object or number, got ~s", &.{w});
    const s = tower.toFloat(w);
    if (s > 0) {
        rt.blockingBegin(t);
        os.sleepMs(@intFromFloat(@min(s * 1000.0, 1e12)));
        rt.blockingEnd(t);
    }
    return rt.NIL;
}
pub const @"%thread-sleep!" = WN("thread-sleep!", threadSleep, 1, 1);

// --- mutexes -----------------------------------------------------------------

const MutexCtl = struct {
    lock: Io.Mutex = .init,
    cond: Io.Condition = .init,
    locked: bool = false,
    abandoned: bool = false,
    owner: ?*ThreadCtl = null,
    /// the owner's thread object is read under the world's stop: the owner
    /// thread keeps it as a root (t.thread_obj); mutex-state reads it there
    owner_obj: ?*Thread = null,
};

fn mutexArg(t: *Thread, i: usize) Err!*MutexCtl {
    const w = arg(t, i);
    if (!isKind(w, mutex_marker)) return P.argTypeError(t);
    return ctlOf(MutexCtl, w);
}

fn makeSync(t: *Thread, comptime T: type, m: Word) Word {
    markers();
    t.reserve(1 + 4);
    const ctl = pa.create(T) catch rt.oom();
    ctl.* = .{};
    const r = data.makeRecord(t, 4);
    const s = data.recordSlots(r);
    s[0] = if (m == 0) mutex_marker else m;
    s[1] = rt.fix(@intCast(@intFromPtr(ctl)));
    s[2] = if (t.argc > 0) arg(t, 0) else rt.FALSE;
    s[3] = rt.NIL;
    return r;
}

fn makeMutex(t: *Thread) Err!Word {
    markers();
    return makeSync(t, MutexCtl, mutex_marker);
}
pub const @"%make-mutex" = WN("make-mutex", makeMutex, 0, 1);

fn mutexP(t: *Thread) Err!Word {
    return rt.boolean(isKind(arg(t, 0), mutex_marker));
}
pub const @"%mutex?" = WN("mutex?", mutexP, 1, 1);

fn syncName(t: *Thread) Err!Word {
    const w = arg(t, 0);
    if (!isKind(w, mutex_marker) and !isKind(w, condvar_marker)) return P.argTypeError(t);
    return slot(w, 2);
}
fn syncSpecific(t: *Thread) Err!Word {
    const w = arg(t, 0);
    if (!isKind(w, mutex_marker) and !isKind(w, condvar_marker)) return P.argTypeError(t);
    return slot(w, 3);
}
fn syncSpecificSet(t: *Thread) Err!Word {
    const w = arg(t, 0);
    if (!isKind(w, mutex_marker) and !isKind(w, condvar_marker)) return P.argTypeError(t);
    setSlot(t, w, 3, arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%mutex-name" = WN("mutex-name", syncName, 1, 1);
pub const @"%mutex-specific" = WN("mutex-specific", syncSpecific, 1, 1);
pub const @"%mutex-specific-set!" = WN("mutex-specific-set!", syncSpecificSet, 2, 2);

fn takeMutex(t: *Thread, m: *MutexCtl) bool {
    const self: *ThreadCtl = @ptrCast(@alignCast(currentCtl(t)));
    m.locked = true;
    m.owner = self;
    m.owner_obj = t;
    self.lock.lockUncancelable(os.io);
    self.held.append(pa, m) catch rt.oom();
    self.lock.unlock(os.io);
    const was = m.abandoned;
    m.abandoned = false;
    return was;
}

fn currentCtl(t: *Thread) *anyopaque {
    if (t.ctl == null) _ = currentThreadObject(t);
    return t.ctl.?;
}

fn releaseMutex(m: *MutexCtl) void {
    m.lock.lockUncancelable(os.io);
    if (m.owner) |o| {
        o.lock.lockUncancelable(os.io);
        for (o.held.items, 0..) |h, i| if (h == m) {
            _ = o.held.swapRemove(i);
            break;
        };
        o.lock.unlock(os.io);
    }
    m.locked = false;
    m.owner = null;
    m.owner_obj = null;
    // each waiter waits for the mutex to be free; one of them takes it
    m.cond.signal(os.io);
    m.lock.unlock(os.io);
}

fn mutexLock(t: *Thread) Err!Word {
    const m = try mutexArg(t, 0);
    const ms = try timeoutArg(t, "mutex-lock!", 1);
    _ = currentCtl(t);
    m.lock.lockUncancelable(os.io);
    if (!m.locked) {
        const was = takeMutex(t, m);
        m.lock.unlock(os.io);
        if (was) return threadException(t, "abandoned-mutex-exception", Kind.abandoned_mutex, rt.UNSPEC);
        return rt.TRUE;
    }
    if (ms != null and ms.? == 0) {
        m.lock.unlock(os.io);
        return rt.FALSE;
    }
    m.lock.unlock(os.io);
    rt.blockingBegin(t);
    m.lock.lockUncancelable(os.io);
    const to = timeout(ms).toDeadline(os.io);
    var got = true;
    while (m.locked) {
        m.cond.waitTimeout(os.io, &m.lock, to) catch {
            if (m.locked) {
                got = false;
                break;
            }
        };
    }
    var was = false;
    if (got) was = takeMutex(t, m) else if (!m.locked) m.cond.signal(os.io);
    m.lock.unlock(os.io);
    rt.blockingEnd(t);
    if (!got) return rt.FALSE;
    if (was) return threadException(t, "abandoned-mutex-exception", Kind.abandoned_mutex, rt.UNSPEC);
    return rt.TRUE;
}
pub const @"%mutex-lock!" = WN("mutex-lock!", mutexLock, 1, 3);

fn mutexUnlock(t: *Thread) Err!Word {
    const m = try mutexArg(t, 0);
    if (t.argc < 2) {
        releaseMutex(m);
        return rt.TRUE;
    }
    const cvw = arg(t, 1);
    if (!isKind(cvw, condvar_marker)) return P.argTypeError(t);
    const cv = ctlOf(CondCtl, cvw);
    const ms = try timeoutArg(t, "mutex-unlock!", 2);
    // SRFI 18: unlocking and starting to wait are one atomic step: the
    // condition variable's lock is taken before the mutex is released
    rt.blockingBegin(t);
    cv.lock.lockUncancelable(os.io);
    releaseMutex(m);
    var signaled = true;
    cv.cond.waitTimeout(os.io, &cv.lock, timeout(ms)) catch {
        signaled = false;
    };
    cv.lock.unlock(os.io);
    rt.blockingEnd(t);
    return rt.boolean(signaled);
}
pub const @"%mutex-unlock!" = WN("mutex-unlock!", mutexUnlock, 1, 3);

fn mutexState(t: *Thread) Err!Word {
    const m = try mutexArg(t, 0);
    m.lock.lockUncancelable(os.io);
    defer m.lock.unlock(os.io);
    if (m.abandoned) return data.intern("abandoned");
    if (m.locked) if (m.owner_obj) |o| return o.thread_obj;
    if (m.locked) return data.intern("not-owned");
    return data.intern("not-abandoned");
}
pub const @"%mutex-state" = WN("mutex-state", mutexState, 1, 1);

// --- condition variables -------------------------------------------------------

/// As the JVM's monitor: a signal wakes one waiter, a broadcast all
const CondCtl = struct {
    lock: Io.Mutex = .init,
    cond: Io.Condition = .init,
};

fn condArg(t: *Thread, i: usize) Err!*CondCtl {
    const w = arg(t, i);
    if (!isKind(w, condvar_marker)) return P.argTypeError(t);
    return ctlOf(CondCtl, w);
}

fn makeCondvar(t: *Thread) Err!Word {
    markers();
    return makeSync(t, CondCtl, condvar_marker);
}
pub const @"%make-condition-variable" = WN("make-condition-variable", makeCondvar, 0, 1);

fn condvarP(t: *Thread) Err!Word {
    return rt.boolean(isKind(arg(t, 0), condvar_marker));
}
pub const @"%condition-variable?" = WN("condition-variable?", condvarP, 1, 1);
pub const @"%condition-variable-name" = WN("condition-variable-name", syncName, 1, 1);
pub const @"%condition-variable-specific" = WN("condition-variable-specific", syncSpecific, 1, 1);
pub const @"%condition-variable-specific-set!" = WN("condition-variable-specific-set!", syncSpecificSet, 2, 2);

fn condSignal(t: *Thread) Err!Word {
    const cv = try condArg(t, 0);
    cv.lock.lockUncancelable(os.io);
    cv.cond.signal(os.io);
    cv.lock.unlock(os.io);
    return rt.NIL;
}
pub const @"%condition-variable-signal!" = WN("condition-variable-signal!", condSignal, 1, 1);

fn condBroadcast(t: *Thread) Err!Word {
    const cv = try condArg(t, 0);
    cv.lock.lockUncancelable(os.io);
    cv.cond.broadcast(os.io);
    cv.lock.unlock(os.io);
    return rt.NIL;
}
pub const @"%condition-variable-broadcast!" = WN("condition-variable-broadcast!", condBroadcast, 1, 1);

// --- thread exceptions -----------------------------------------------------------

/// The thread exception of obj: an error object raised for one (its first
/// irritant), or the object itself
fn threadExceptionOf(w: Word) ?Word {
    if (isKind(w, texc_marker)) return w;
    if (rt.isObj(w, rt.T_ERROR)) {
        const irritants = rt.ptr(w)[2];
        if (rt.isPair(irritants) and isKind(rt.car(irritants), texc_marker)) return rt.car(irritants);
    }
    return null;
}

fn isException(w: Word, kind: i64) bool {
    const e = threadExceptionOf(w) orelse return false;
    return rt.unfix(slot(e, 1)) == kind;
}

fn joinTimeoutP(t: *Thread) Err!Word {
    return rt.boolean(isException(arg(t, 0), Kind.join_timeout));
}
fn abandonedP(t: *Thread) Err!Word {
    return rt.boolean(isException(arg(t, 0), Kind.abandoned_mutex));
}
fn terminatedP(t: *Thread) Err!Word {
    return rt.boolean(isException(arg(t, 0), Kind.terminated_thread));
}
fn uncaughtP(t: *Thread) Err!Word {
    return rt.boolean(isException(arg(t, 0), Kind.uncaught));
}
fn uncaughtReason(t: *Thread) Err!Word {
    if (threadExceptionOf(arg(t, 0))) |e| if (rt.unfix(slot(e, 1)) == Kind.uncaught) return slot(e, 2);
    return raise(t, "uncaught-exception-reason: expected uncaught exception, got ~s", &.{arg(t, 0)});
}
pub const @"%join-timeout-exception?" = WN("join-timeout-exception?", joinTimeoutP, 1, 1);
pub const @"%abandoned-mutex-exception?" = WN("abandoned-mutex-exception?", abandonedP, 1, 1);
pub const @"%terminated-thread-exception?" = WN("terminated-thread-exception?", terminatedP, 1, 1);
pub const @"%uncaught-exception?" = WN("uncaught-exception?", uncaughtP, 1, 1);
pub const @"%uncaught-exception-reason" = WN("uncaught-exception-reason", uncaughtReason, 1, 1);

// --- printing ------------------------------------------------------------------

/// The printed form of a thread object, mutex, condition variable or
/// thread exception, as the JVM implementation's; null for other records
pub fn printForm(buf: *std.ArrayList(u8), w: Word) bool {
    if (thread_marker == 0) return false;
    const printer = @import("printer.zig");
    const s = data.recordSlots(w);
    if (s.len == 0) return false;
    const what: []const u8 = if (s[0] == thread_marker) "thread" else if (s[0] == mutex_marker) "mutex" else if (s[0] == condvar_marker) "condition-variable" else if (s[0] == texc_marker) {
        const names = [_][]const u8{ "#<join-timeout-exception>", "#<abandoned-mutex-exception>", "#<terminated-thread-exception>", "#<uncaught-exception>" };
        buf.appendSlice(pa, names[@intCast(rt.unfix(s[1]))]) catch rt.oom();
        return true;
    } else return false;
    const name = if (s[0] == thread_marker) s[3] else s[2];
    buf.appendSlice(pa, "#<") catch rt.oom();
    buf.appendSlice(pa, what) catch rt.oom();
    if (name != rt.FALSE) {
        buf.append(pa, ' ') catch rt.oom();
        printer.print(buf, name, false);
    }
    buf.append(pa, '>') catch rt.oom();
    return true;
}
