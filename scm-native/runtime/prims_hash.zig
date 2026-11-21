//! Primitives: hash tables (SRFI 69/125 underneath), as the JVM
//! implementation's SchemeHashTable: eq, eqv or equal keys.
//!
//! A table is a heap object [hdr T_HASHTABLE] [mode] [count] [buckets]
//! [comparator] [epoch] [flags]: buckets is a vector of chains (lists of
//! (key . value) entries). Identity hashes of objects the collector moves
//! change at collections: a table holding such keys (flag 1) rehashes when
//! it is used after a collection (epoch: the collection count).
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const tower = @import("tower.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Code = rt.Code;
const Err = P.Err;
const W = P.W;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;
const unfix = rt.unfix;
const ptr = rt.ptr;

pub const Mode = enum(i64) { eq = 0, eqv = 1, equal = 2 };

const F_MOVABLE: i64 = 1;

const SLOTS = 6;
inline fn slots(h: Word) [*]Word {
    return ptr(h) + 1;
}
inline fn mode(h: Word) Mode {
    return @enumFromInt(unfix(slots(h)[0]));
}
inline fn count(h: Word) usize {
    return @intCast(unfix(slots(h)[1]));
}
inline fn buckets(h: Word) Word {
    return slots(h)[2];
}

pub inline fn isTable(w: Word) bool {
    return rt.isObj(w, rt.T_HASHTABLE);
}

fn tableArg(t: *Thread) Err!Word {
    const h = arg(t, 0);
    if (!isTable(h) or isDict(h)) return raise(t, "not a hash table", &.{h});
    return h;
}

// --- hashing -------------------------------------------------------------------

inline fn mix(x: u64) u64 {
    var z = x +% 0x9e3779b97f4a7c15;
    z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
    return z ^ (z >> 31);
}

fn hashBytes(b: []const u8) u64 {
    return std.hash.Wyhash.hash(0, b);
}

fn hash(w: Word, m: Mode, movable: *bool, depth: u32) u64 {
    if (!rt.isPtr(w)) return mix(w);
    const ty = rt.objType(w);
    if (m != .eq) switch (ty) {
        rt.T_FLONUM => return mix(rt.ptr(w)[1]),
        rt.T_BIGNUM => {
            const n: usize = @intCast(ptr(w)[1] >> 1);
            const b: [*]const u8 = @ptrCast(ptr(w) + 1);
            return hashBytes(b[0 .. 8 * (1 + n)]);
        },
        rt.T_RATNUM, rt.T_COMPNUM => return mix(hash(ptr(w)[1], m, movable, depth +% 1) ^ (hash(ptr(w)[2], m, movable, depth +% 1) *% 31)),
        else => {},
    };
    if (m == .equal and depth < 8) switch (ty) {
        rt.T_STRING => {
            var h: u64 = 0;
            for (0..data.stringLen(w)) |i| h = h *% 31 +% data.stringRef(w, i);
            return mix(h);
        },
        rt.T_BYTEVECTOR => return hashBytes(data.bvBytes(w)),
        rt.T_PAIR => return mix(hash(rt.car(w), m, movable, depth + 1) *% 31 ^ hash(rt.cdr(w), m, movable, depth + 1)),
        rt.T_VECTOR => {
            var h: u64 = data.vectorLen(w);
            for (data.vectorItems(w)[0..@min(8, data.vectorLen(w))]) |x| h = h *% 31 ^ hash(x, m, movable, depth + 1);
            return mix(h);
        },
        else => {},
    };
    if (m == .equal and depth >= 8) return 0;
    // identity
    if (rt.isMovable(w)) movable.* = true;
    return mix(w);
}

fn same(a: Word, b: Word, m: Mode) bool {
    return switch (m) {
        .eq => a == b,
        .eqv => data.eqv(a, b),
        .equal => data.equal(a, b),
    };
}

/// Rehash a table whose identity hashes may have changed
fn refresh(t: *Thread, h: Word) void {
    const s = slots(h);
    if (unfix(s[5]) & F_MOVABLE == 0 or s[4] == fix(@intCast(t.gc_count))) return;
    rehashInto(t, h, buckets(h));
}

/// Move all entries of h into the (cleared) bucket vector nb, reusing the
/// chain cells (no allocation)
fn rehashInto(t: *Thread, h: Word, nb: Word) void {
    const s = slots(h);
    const old = buckets(h);
    const m = mode(h);
    var cells = rt.NIL;
    // collect the chain cells of the old buckets into one list
    for (data.vectorItems(old)) |*b| {
        var c = b.*;
        while (c != rt.NIL) {
            const next = rt.cdr(c);
            ptr(c)[2] = cells;
            cells = c;
            c = next;
        }
        b.* = rt.NIL;
    }
    const n = data.vectorLen(nb);
    var movable = false;
    var c = cells;
    while (c != rt.NIL) {
        const next = rt.cdr(c);
        const i = hash(rt.car(rt.car(c)), m, &movable, 0) & (n - 1);
        ptr(c)[2] = data.vectorItems(nb)[i];
        data.vectorItems(nb)[i] = c;
        rt.barrier(t, nb, c);
        c = next;
    }
    s[2] = nb;
    rt.barrier(t, h, nb);
    s[4] = fix(@intCast(t.gc_count));
    s[5] = fix((unfix(s[5]) & ~F_MOVABLE) | (if (movable) F_MOVABLE else 0));
}

/// The entry (key . value) for key, or null
fn find(t: *Thread, h: Word, key: Word) ?Word {
    refresh(t, h);
    const m = mode(h);
    var movable = false;
    const b = buckets(h);
    const i = hash(key, m, &movable, 0) & (data.vectorLen(b) - 1);
    var c = data.vectorItems(b)[i];
    while (c != rt.NIL) : (c = rt.cdr(c)) {
        const e = rt.car(c);
        if (same(rt.car(e), key, m)) return e;
    }
    return null;
}

// --- construction --------------------------------------------------------------

fn newTable(t: *Thread, m: Mode, nbuckets: usize) Word {
    // reserve 1 + SLOTS + 1 + nbuckets first
    const b = data.makeVector(t, nbuckets, rt.NIL);
    const q = t.allocRaw(1 + SLOTS);
    q[0] = rt.hdr(rt.T_HASHTABLE, SLOTS);
    q[1] = fix(@intFromEnum(m));
    q[2] = fix(0);
    q[3] = b;
    q[4] = rt.FALSE;
    q[5] = fix(@intCast(t.gc_count));
    q[6] = fix(0);
    return rt.tagPtr(q);
}

/// The mode for an equivalence procedure (a primitive's name)
fn modeOf(w: Word) Mode {
    if (rt.isPrimitive(w)) {
        const name = data.symbolName(ptr(w)[2]);
        if (std.mem.eql(u8, name, "eq?")) return .eq;
        if (std.mem.eql(u8, name, "eqv?") or std.mem.eql(u8, name, "=")) return .eqv;
    }
    return .equal;
}

fn makeHashTable(t: *Thread) Err!Word {
    t.reserve(1 + SLOTS + 1 + 16);
    return newTable(t, if (t.argc > 0) modeOf(arg(t, 0)) else .equal, 16);
}
pub const @"%make-hash-table" = WN("make-hash-table", makeHashTable, 0, 2);

fn hashTableP(t: *Thread) Err!Word {
    return rt.boolean(isTable(arg(t, 0)) and !isDict(arg(t, 0)));
}
pub const @"%hash-table?" = WD("hash-table?", hashTableP, 1, 1);

fn hashTableSet(t: *Thread) Err!Word {
    const h0 = try tableArg(t);
    if (find(t, h0, arg(t, 1))) |e| {
        ptr(e)[2] = arg(t, 2);
        rt.barrier(t, e, arg(t, 2));
        return rt.UNSPEC;
    }
    const nb = data.vectorLen(buckets(h0));
    const grow = count(h0) + 1 > 2 * nb;
    t.reserve(6 + if (grow) 1 + 2 * nb else 0);
    // re-read: the reservation may have collected
    const h = arg(t, 0);
    const key = arg(t, 1);
    if (grow) {
        const v = data.makeVector(t, 2 * nb, rt.NIL);
        rehashInto(t, h, v);
    }
    refresh(t, h);
    const s = slots(h);
    var movable = false;
    const b = buckets(h);
    const i = hash(key, mode(h), &movable, 0) & (data.vectorLen(b) - 1);
    const e = t.cons(key, arg(t, 2));
    const cell = t.cons(e, data.vectorItems(b)[i]);
    data.vectorItems(b)[i] = cell;
    rt.barrier(t, b, cell);
    s[1] = fix(@intCast(count(h) + 1));
    if (movable) s[5] = fix(unfix(s[5]) | F_MOVABLE);
    return rt.UNSPEC;
}
pub const @"%hash-table-set!" = WN("hash-table-set!", hashTableSet, 3, 3);

/// (hash-table-ref table key [thunk]): calls thunk when the key is missing
fn hashTableRefCode(t: *Thread) callconv(.c) void {
    if (t.argc < 2 or t.argc > 3) return @call(.always_tail, rt.arityErrorN(t, 2, true), .{t});
    const h = t.args[0];
    if (!isTable(h)) return @call(.always_tail, rt.fail(t, "hash-table-ref: not a hash table", &.{h}), .{t});
    if (find(t, h, t.args[1])) |e| {
        t.val = rt.cdr(e);
        return @call(.always_tail, rt.retCode(t), .{t});
    }
    if (t.argc == 3 and rt.isProcedure(t.args[2])) {
        const thunk = t.args[2];
        t.argc = 0;
        return @call(.always_tail, rt.enter(t, thunk), .{t});
    }
    return @call(.always_tail, rt.fail(t, "hash-table-ref: key not found in hash table", &.{}), .{t});
}
pub const @"%hash-table-ref" = &hashTableRefCode;

fn hashTableRefDefault(t: *Thread) Err!Word {
    const h = try tableArg(t);
    return if (find(t, h, arg(t, 1))) |e| rt.cdr(e) else arg(t, 2);
}
pub const @"%hash-table-ref/default" = WD("hash-table-ref/default", hashTableRefDefault, 3, 3);

fn hashTableExists(t: *Thread) Err!Word {
    const h = try tableArg(t);
    return rt.boolean(find(t, h, arg(t, 1)) != null);
}
pub const @"%hash-table-exists?" = WD("hash-table-exists?", hashTableExists, 2, 2);

fn hashTableDelete(t: *Thread) Err!Word {
    const h = try tableArg(t);
    refresh(t, h);
    const m = mode(h);
    var movable = false;
    const b = buckets(h);
    const i = hash(arg(t, 1), m, &movable, 0) & (data.vectorLen(b) - 1);
    var prev = rt.NIL;
    var c = data.vectorItems(b)[i];
    while (c != rt.NIL) : (c = rt.cdr(c)) {
        if (same(rt.car(rt.car(c)), arg(t, 1), m)) {
            if (prev == rt.NIL) {
                data.vectorItems(b)[i] = rt.cdr(c);
                rt.barrier(t, b, rt.cdr(c));
            } else {
                ptr(prev)[2] = rt.cdr(c);
                rt.barrier(t, prev, rt.cdr(c));
            }
            slots(h)[1] = fix(@intCast(count(h) - 1));
            return rt.UNSPEC;
        }
        prev = c;
    }
    return rt.UNSPEC;
}
pub const @"%hash-table-delete!" = WD("hash-table-delete!", hashTableDelete, 2, 2);

fn hashTableSize(t: *Thread) Err!Word {
    return fix(@intCast(count(try tableArg(t))));
}
pub const @"%hash-table-size" = WD("hash-table-size", hashTableSize, 1, 1);

fn hashTableClear(t: *Thread) Err!Word {
    const h = try tableArg(t);
    @memset(data.vectorItems(buckets(h)), rt.NIL);
    slots(h)[1] = fix(0);
    return rt.UNSPEC;
}
pub const @"%hash-table-clear!" = WD("hash-table-clear!", hashTableClear, 1, 1);

/// keys, values or (key . value) entries as a list (new pairs)
fn listOf(t: *Thread, comptime what: enum { keys, values, alist }) Err!Word {
    const n = count(try tableArg(t));
    t.reserve(if (what == .alist) 6 * n else 3 * n);
    const h = arg(t, 0);
    var l = rt.NIL;
    for (data.vectorItems(buckets(h))) |b| {
        var c = b;
        while (c != rt.NIL) : (c = rt.cdr(c)) {
            const e = rt.car(c);
            l = t.cons(switch (what) {
                .keys => rt.car(e),
                .values => rt.cdr(e),
                .alist => t.cons(rt.car(e), rt.cdr(e)),
            }, l);
        }
    }
    return l;
}
fn hashTableKeys(t: *Thread) Err!Word {
    return listOf(t, .keys);
}
fn hashTableValues(t: *Thread) Err!Word {
    return listOf(t, .values);
}
fn hashTableToAlist(t: *Thread) Err!Word {
    return listOf(t, .alist);
}
pub const @"%hash-table-keys" = WN("hash-table-keys", hashTableKeys, 1, 1);
pub const @"%hash-table-values" = WN("hash-table-values", hashTableValues, 1, 1);
pub const @"%hash-table->alist" = WN("hash-table->alist", hashTableToAlist, 1, 1);

fn hashTableCopy(t: *Thread) Err!Word {
    const h0 = try tableArg(t);
    const n = count(h0);
    const nb = data.vectorLen(buckets(h0));
    t.reserve(1 + SLOTS + 1 + nb + 6 * n);
    const h = arg(t, 0);
    const c = newTable(t, mode(h), nb);
    const cs = slots(c);
    const hs = slots(h);
    for (data.vectorItems(buckets(h)), 0..) |b, i| {
        var chain = rt.NIL;
        var x = b;
        while (x != rt.NIL) : (x = rt.cdr(x)) {
            const e = rt.car(x);
            chain = t.cons(t.cons(rt.car(e), rt.cdr(e)), chain);
        }
        data.vectorItems(cs[2])[i] = chain;
    }
    cs[1] = hs[1];
    cs[3] = hs[3];
    cs[4] = hs[4];
    cs[5] = hs[5];
    return c;
}
pub const @"%hash-table-copy" = WN("hash-table-copy", hashTableCopy, 1, 2);

fn comparatorGet(t: *Thread) Err!Word {
    return slots(try tableArg(t))[3];
}
fn comparatorSet(t: *Thread) Err!Word {
    const h = try tableArg(t);
    slots(h)[3] = arg(t, 1);
    rt.barrier(t, h, arg(t, 1));
    return rt.UNSPEC;
}
pub const @"%%hash-table-comparator" = WD("%hash-table-comparator", comparatorGet, 1, 1);
pub const @"%%hash-table-set-comparator!" = WD("%hash-table-set-comparator!", comparatorSet, 2, 2);

// --- dicts ((scm dict)) ---------------------------------------------------------------
//
// A dict is a hash table in equal mode with string keys (symbol keys are
// converted to their names), flagged F_DICT, that keeps the insertion
// order as the JVM implementation's LinkedHashMap: the comparator slot
// holds its (key . value) entries, newest first. Entries are never removed
// one by one (there is no dict-remove), only all at once by dict-clear.

const F_DICT: i64 = 2;

pub inline fn isDict(w: Word) bool {
    return isTable(w) and (unfix(slots(w)[5]) & F_DICT) != 0;
}

fn dictArg(t: *Thread) Err!Word {
    const d = arg(t, 0);
    if (!isDict(d)) return P.argTypeError(t);
    return d;
}

/// replace argument i (a string or symbol) by a fresh string: the key
fn dictKey(t: *Thread, who: []const u8, i: usize) Err!void {
    const k = arg(t, i);
    if (data.isSymbol(k)) {
        const name = data.symbolName(k);
        t.reserve(data.stringWords(name.len, true));
        t.args[i] = data.heapStringUtf8(t, data.symbolName(arg(t, i)));
    } else if (data.isString(k)) {
        const n = data.stringLen(k);
        var wide = false;
        for (0..n) |j| if (data.stringRef(k, j) > 255) {
            wide = true;
            break;
        };
        t.reserve(data.stringWords(n, wide));
        const s = data.makeString(t, n, wide);
        const src = arg(t, i);
        for (0..n) |j| data.stringSetFits(s, j, data.stringRef(src, j));
        t.args[i] = s;
    } else {
        return raise(t, std.fmt.allocPrint(std.heap.c_allocator, "{s}: Key must be string or symbol", .{who}) catch rt.oom(), &.{});
    }
}

fn makeDict(t: *Thread) Err!Word {
    t.reserve(1 + SLOTS + 1 + 16);
    const d = newTable(t, .equal, 16);
    slots(d)[3] = rt.NIL;
    slots(d)[5] = fix(F_DICT);
    return d;
}
pub const @"%make-dict" = WN("make-dict", makeDict, 0, 0);

fn dictGet(t: *Thread) Err!Word {
    _ = try dictArg(t);
    try dictKey(t, "dict-get", 1);
    if (find(t, arg(t, 0), arg(t, 1))) |e| return rt.cdr(e);
    if (t.argc == 3) return arg(t, 2);
    const key = data.toUtf8(arg(t, 1));
    return raise(t, std.fmt.allocPrint(std.heap.c_allocator, "dict-get: Key {s} not found", .{key}) catch rt.oom(), &.{});
}
pub const @"%dict-get" = WN("dict-get", dictGet, 2, 3);

fn dictContains(t: *Thread) Err!Word {
    _ = try dictArg(t);
    try dictKey(t, "dict-contains", 1);
    return rt.boolean(find(t, arg(t, 0), arg(t, 1)) != null);
}
pub const @"%dict-contains" = WN("dict-contains", dictContains, 2, 2);

fn dictPut(t: *Thread) Err!Word {
    _ = try dictArg(t);
    try dictKey(t, "dict-put", 1);
    if (find(t, arg(t, 0), arg(t, 1))) |e| {
        ptr(e)[2] = arg(t, 2);
        rt.barrier(t, e, arg(t, 2));
        return rt.UNSPEC;
    }
    const nb = data.vectorLen(buckets(arg(t, 0)));
    const grow = count(arg(t, 0)) + 1 > 2 * nb;
    t.reserve(9 + if (grow) 1 + 2 * nb else 0);
    const d = arg(t, 0);
    const key = arg(t, 1);
    if (grow) {
        const v = data.makeVector(t, 2 * nb, rt.NIL);
        rehashInto(t, d, v);
    }
    const s = slots(d);
    var movable = false;
    const b = buckets(d);
    const i = hash(key, .equal, &movable, 0) & (data.vectorLen(b) - 1);
    const e = t.cons(key, arg(t, 2));
    const cell = t.cons(e, data.vectorItems(b)[i]);
    data.vectorItems(b)[i] = cell;
    rt.barrier(t, b, cell);
    const order = t.cons(e, s[3]);
    s[3] = order;
    rt.barrier(t, d, order);
    s[1] = fix(@intCast(count(d) + 1));
    return rt.UNSPEC;
}
pub const @"%dict-put" = WN("dict-put", dictPut, 3, 3);

fn dictClear(t: *Thread) Err!Word {
    const d = try dictArg(t);
    @memset(data.vectorItems(buckets(d)), rt.NIL);
    slots(d)[1] = fix(0);
    slots(d)[3] = rt.NIL;
    return rt.UNSPEC;
}
pub const @"%dict-clear" = WD("dict-clear", dictClear, 1, 1);

fn dictSize(t: *Thread) Err!Word {
    return fix(@intCast(count(try dictArg(t))));
}
pub const @"%dict-size" = WD("dict-size", dictSize, 1, 1);

/// keys (fresh strings), values or (key . value) entries, in insertion order
fn dictList(t: *Thread, comptime what: enum { keys, values, entries }) Err!Word {
    const d0 = try dictArg(t);
    var words: usize = 3 * count(d0);
    if (what != .values) {
        var o = slots(d0)[3];
        while (o != rt.NIL) : (o = rt.cdr(o)) words += 3 + data.stringWords(data.stringLen(rt.car(rt.car(o))), true);
    }
    t.reserve(words);
    var l = rt.NIL;
    var o = slots(arg(t, 0))[3];
    while (o != rt.NIL) : (o = rt.cdr(o)) {
        const e = rt.car(o);
        const item = switch (what) {
            .values => rt.cdr(e),
            else => blk: {
                const k = rt.car(e);
                const n = data.stringLen(k);
                var wide = false;
                for (0..n) |j| if (data.stringRef(k, j) > 255) {
                    wide = true;
                    break;
                };
                const s = data.makeString(t, n, wide);
                for (0..n) |j| data.stringSetFits(s, j, data.stringRef(k, j));
                break :blk if (what == .keys) s else t.cons(s, rt.cdr(e));
            },
        };
        l = t.cons(item, l);
    }
    return l;
}
fn dictKeys(t: *Thread) Err!Word {
    return dictList(t, .keys);
}
fn dictValues(t: *Thread) Err!Word {
    return dictList(t, .values);
}
fn dictEntries(t: *Thread) Err!Word {
    return dictList(t, .entries);
}
pub const @"%dict-keys" = WN("dict-keys", dictKeys, 1, 1);
pub const @"%dict-values" = WN("dict-values", dictValues, 1, 1);
pub const @"%dict-entries" = WN("dict-entries", dictEntries, 1, 1);
