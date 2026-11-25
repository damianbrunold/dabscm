//! Primitives: time ((scheme time) helpers, (scm datetime) timestamps),
//! the rest of the file system ((scm fs)), processes and system
//! information ((scm system)), property lists. As in the JVM
//! implementation; the operating system calls are in os.zig.
const std = @import("std");
const builtin = @import("builtin");
const rt = @import("rt.zig");
const data = @import("data.zig");
const os = @import("os.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;
const unfix = rt.unfix;

const pa = std.heap.c_allocator;

fn str(t: *Thread, utf8: []const u8) Word {
    t.reserve(data.stringWords(utf8.len, true));
    return data.heapStringUtf8(t, utf8);
}

fn textArg(t: *Thread, i: usize) Err![]const u8 {
    return data.toUtf8(try P.stringArg(t, i));
}

fn intArg(t: *Thread, i: usize) Err!i64 {
    const w = arg(t, i);
    if (!rt.isFix(w)) return raise(t, "value out of range: ~s", &.{w});
    return unfix(w);
}

fn pair(t: *Thread, a: i64, b: i64) Word {
    t.reserve(3);
    return t.cons(fix(a), fix(b));
}

// --- native objects (processes, file locks) ----------------------------------------------

pub const NativeKind = enum(u64) { process = 1, file_lock = 2, zip_in = 3, zip_out = 4, json_reader = 5, json_object = 6, xml_reader = 7, random_access = 8, macro_standin = 9, socket = 10, listener = 11, thread_ctl = 12, mutex_ctl = 13, cond_ctl = 14 };

/// The record of a native object: its pointer (null once released) and
/// its kind. A native heap object holds [kind, record, slots...]; the
/// collector marks the record when it reaches the object, and the records
/// it did not reach are finalized after the collection (sweepNatives), as
/// ports are: their memory and handles are freed, sockets and files closed
pub const Native = struct {
    ptr: ?*anyopaque,
    kind: NativeKind,
    /// what this object keeps alive: a JSON object's parser
    owner: ?*anyopaque = null,
    seen: u32 = 0,
    young: bool = true,
};

var natives: std.ArrayList(*Native) = .empty;
var natives_lock: std.Io.Mutex = .init;

fn wrapNative(t: *Thread, kind: NativeKind, p: *anyopaque) Word {
    t.reserve(3);
    return allocNative(t, kind, p);
}

pub const wrapNativeOf = wrapNative;

/// A native object; reserve 3 words first
pub fn allocNative(t: *Thread, kind: NativeKind, p: *anyopaque) Word {
    return allocNativeSlots(t, kind, p, null, 0);
}

/// A native object with slots, words the collector scans (a socket's
/// ports), #f at first; reserve 3 + slots words first
pub fn allocNativeSlots(t: *Thread, kind: NativeKind, p: *anyopaque, owner: ?*anyopaque, slots: usize) Word {
    const rec = pa.create(Native) catch rt.oom();
    rec.* = .{ .ptr = p, .kind = kind, .owner = owner };
    {
        natives_lock.lockUncancelable(os.io);
        defer natives_lock.unlock(os.io);
        natives.append(pa, rec) catch rt.oom();
    }
    const q = t.allocRaw(3 + slots);
    q[0] = rt.hdr(rt.T_NATIVE, 2 + slots);
    q[1] = @intFromEnum(kind);
    q[2] = @intFromPtr(rec);
    for (q[3 .. 3 + slots]) |*w| w.* = rt.FALSE;
    return rt.tagPtr(q);
}

/// The record of a native object w (not a macro stand-in)
pub fn nativeRecord(w: Word) *Native {
    return @ptrFromInt(rt.ptr(w)[2]);
}

/// The object's pointer; null if w is not of this kind or was released
pub fn nativeOf(w: Word, kind: NativeKind) ?*anyopaque {
    if (!rt.isObj(w, rt.T_NATIVE) or rt.ptr(w)[1] != @intFromEnum(kind) or kind == .macro_standin) return null;
    return nativeRecord(w).ptr;
}

/// The collector reached the native object q
pub fn markNative(q: [*]Word) void {
    if (q[1] == @intFromEnum(NativeKind.macro_standin)) return;
    const rec: *Native = @ptrFromInt(q[2]);
    rec.seen = @import("ports.zig").epoch;
}

/// The number of native objects, for the statistics
pub fn nativeCount() usize {
    return natives.items.len;
}

/// After a collection (every thread stopped), before the ports' sweep: the
/// native objects not reached are finalized, after a minor collection only
/// those made since the last one
pub fn sweepNatives(major: bool) void {
    natives_lock.lockUncancelable(os.io);
    defer natives_lock.unlock(os.io);
    const epoch = @import("ports.zig").epoch;
    var kept: usize = 0;
    for (natives.items) |rec| {
        if (rec.seen == epoch or !(major or rec.young)) {
            rec.young = false;
            natives.items[kept] = rec;
            kept += 1;
            continue;
        }
        finalize(rec);
        pa.destroy(rec);
    }
    natives.items.len = kept;
}

/// Free what a native object no longer reachable holds. Nothing here may
/// block: a socket is closed without flushing, as the JVM's cleaner does
fn finalize(rec: *Native) void {
    const p = rec.ptr orelse return releaseOwner(rec);
    rec.ptr = null;
    switch (rec.kind) {
        .process => {
            const proc: *os.Proc = @ptrCast(@alignCast(p));
            // a running process stays (it may still be waited for by
            // process-kill-on-exit); an ended one is reaped and freed
            if (os.procPoll(proc) == null) return;
            tracked_lock.lockUncancelable(os.io);
            defer tracked_lock.unlock(os.io);
            for (tracked.items, 0..) |q, i| if (q == proc) {
                _ = tracked.swapRemove(i);
                break;
            };
            os.procFree(proc);
        },
        .file_lock => {
            const f: *os.File = @ptrCast(@alignCast(p));
            os.unlockFile(f.*);
            pa.destroy(f);
        },
        .zip_in => {
            const z: *ZipIn = @ptrCast(@alignCast(p));
            pa.free(z.reader.bytes);
            pa.free(z.reader.entries);
            pa.destroy(z);
        },
        .zip_out => {
            const z: *ZipOut = @ptrCast(@alignCast(p));
            if (z.port) |port| port.pinned = false;
            if (z.writer.pending) |pend| pa.free(pend.name);
            for (z.writer.central.items) |c| pa.free(c.name);
            z.writer.central.deinit(pa);
            z.writer.out.deinit(pa);
            if (z.path) |path| pa.free(path);
            pa.destroy(z);
        },
        .json_reader => @import("prims_json.zig").releaseParser(p),
        .json_object => releaseOwner(rec),
        .xml_reader => @import("prims_xml.zig").freeReader(p),
        .random_access => {
            const r: *Raf = @ptrCast(@alignCast(p));
            if (r.open) os.closeFile(r.file);
            pa.destroy(r);
        },
        .macro_standin => {},
        .socket => @import("prims_net.zig").freeSocket(p),
        .listener => @import("net.zig").freeListener(@ptrCast(@alignCast(p))),
        .thread_ctl, .mutex_ctl, .cond_ctl => @import("prims_thread.zig").freeCtl(rec.kind, p),
    }
}

// glibc's mallinfo (Zig links against a glibc older than mallinfo2): int
// fields, enough for tests
const Mallinfo = extern struct { arena: c_int, ordblks: c_int, smblks: c_int, hblks: c_int, hblkhd: c_int, usmblks: c_int, fsmblks: c_int, uordblks: c_int, fordblks: c_int, keepcost: c_int };
extern "c" fn mallinfo() Mallinfo;

fn mallocInUse() usize {
    if (builtin.os.tag != .linux or builtin.abi != .gnu) return 0;
    const m = mallinfo();
    return @as(usize, @intCast(@as(u32, @bitCast(m.uordblks)))) + @as(usize, @intCast(@as(u32, @bitCast(m.hblkhd))));
}

/// (%gc-collect [full]), native only (soak tests): a collection now, a
/// major one unless full is #f
fn gcCollect(t: *Thread) Err!Word {
    rt.collectNow(t, !(t.argc > 0 and arg(t, 0) == rt.FALSE));
    return rt.UNSPEC;
}
pub const @"%gc-collect" = WN("gc-collect", gcCollect, 0, 1);

/// (%gc-statistics), native only (soak tests): an alist of the collector's
/// numbers: minor and major collections, live-words (the old space's
/// used words and the large objects'), ports, port-bytes (their
/// buffers), native-objects, threads
fn gcStatistics(t: *Thread) Err!Word {
    const g = rt.gcNumbers();
    const port_stats = @import("ports.zig").stats();
    const items = [_]struct { []const u8, usize }{
        .{ "minor", g.minor },
        .{ "major", g.major },
        .{ "live-words", g.old_used + g.large },
        .{ "ports", port_stats.count },
        .{ "port-bytes", port_stats.bytes },
        .{ "native-objects", natives.items.len },
        .{ "threads", g.threads },
        // the C allocator's bytes in use (glibc only; 0 elsewhere)
        .{ "malloc-bytes", mallocInUse() },
    };
    var syms: [items.len]Word = undefined;
    for (items, 0..) |it, i| syms[i] = data.intern(it[0]);
    t.reserve(6 * items.len);
    var l = rt.NIL;
    var i = items.len;
    while (i > 0) {
        i -= 1;
        l = t.cons(t.cons(syms[i], fix(@intCast(items[i][1]))), l);
    }
    return l;
}
pub const @"%gc-statistics" = WN("gc-statistics", gcStatistics, 0, 0);

fn releaseOwner(rec: *Native) void {
    if (rec.kind == .json_object) if (rec.owner) |o| @import("prims_json.zig").releaseParser(o);
    rec.owner = null;
}

pub fn nativeName(w: Word) []const u8 {
    return switch (rt.ptr(w)[1]) {
        1 => "#<process>",
        2 => "#<file-lock>",
        3 => "#<input-zip>",
        4 => "#<output-zip>",
        5 => "#<json-reader>",
        6 => blk: {
            // as the JVM implementation: the object as JSON text
            var b: std.ArrayList(u8) = .empty;
            const json = @import("prims_json.zig");
            const o = nativeRecord(w).ptr orelse break :blk "#<json-object>";
            json.objectText(@ptrCast(@alignCast(o)), &b);
            break :blk b.items;
        },
        7 => "#<xml-reader>",
        8 => "#<random-access-file>",
        9 => "#<macro>",
        10 => "#<socket>",
        11 => "#<tcp-listener>",
        12, 13, 14 => "#<synchronization>",
        else => "#<native>",
    };
}

// --- clocks ---------------------------------------------------------------------------------

fn secNs(t: *Thread, ns: i128) Word {
    return pair(t, @intCast(@divFloor(ns, 1_000_000_000)), @intCast(@mod(ns, 1_000_000_000)));
}

fn currentNanosecond(t: *Thread) Err!Word {
    return secNs(t, os.clockNs(.real));
}
fn monotonicNanosecond(t: *Thread) Err!Word {
    return secNs(t, os.clockNs(.monotonic));
}
fn processNanosecond(t: *Thread) Err!Word {
    return secNs(t, os.clockNs(.process));
}
fn threadNanosecond(t: *Thread) Err!Word {
    return secNs(t, os.clockNs(.thread));
}
pub const @"%%current-nanosecond" = WN("%current-nanosecond", currentNanosecond, 0, 0);
pub const @"%%monotonic-nanosecond" = WN("%monotonic-nanosecond", monotonicNanosecond, 0, 0);
pub const @"%%process-nanosecond" = WN("%process-nanosecond", processNanosecond, 0, 0);
pub const @"%%thread-nanosecond" = WN("%thread-nanosecond", threadNanosecond, 0, 0);

fn nowMs() i64 {
    return @intCast(@divFloor(os.clockNs(.real), 1_000_000));
}

fn localTzOffset(t: *Thread) Err!Word {
    const secs = if (t.argc > 0) try intArg(t, 0) else @divFloor(nowMs(), 1000);
    return fix(os.localOffset(secs));
}
pub const @"%%local-tz-offset" = WD("%local-tz-offset", localTzOffset, 0, 1);

fn timestamp(_: *Thread) Err!Word {
    return fix(nowMs());
}
pub const @"%timestamp" = WD("timestamp", timestamp, 0, 0);

// --- timestamp->string (java.text.SimpleDateFormat patterns, local time) ------------------

const month_names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
const day_names = [_][]const u8{ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };

fn pad(out: *std.ArrayList(u8), v: i64, width: usize) void {
    var buf: [24]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{@abs(v)}) catch "";
    if (v < 0) out.append(pa, '-') catch rt.oom();
    var k = s.len;
    while (k < width) : (k += 1) out.append(pa, '0') catch rt.oom();
    out.appendSlice(pa, s) catch rt.oom();
}

fn formatTime(out: *std.ArrayList(u8), ms: i64, pattern: []const u8) void {
    const local_ms = ms + os.localOffset(@divFloor(ms, 1000)) * 1000;
    const days = @divFloor(local_ms, 86_400_000);
    const in_day = @mod(local_ms, 86_400_000);
    const c = os.civilFromDays(days);
    const hour = @divFloor(in_day, 3_600_000);
    const minute = @mod(@divFloor(in_day, 60_000), 60);
    const second = @mod(@divFloor(in_day, 1000), 60);
    const milli = @mod(in_day, 1000);
    const wday: usize = @intCast(@mod(days + 4, 7));
    const off = @divFloor(local_ms - ms, 60_000);
    var i: usize = 0;
    while (i < pattern.len) {
        const ch = pattern[i];
        if (ch == '\'') {
            // quoted text; '' is a quote
            if (i + 1 < pattern.len and pattern[i + 1] == '\'') {
                out.append(pa, '\'') catch rt.oom();
                i += 2;
                continue;
            }
            i += 1;
            while (i < pattern.len) {
                if (pattern[i] == '\'') {
                    if (i + 1 < pattern.len and pattern[i + 1] == '\'') {
                        out.append(pa, '\'') catch rt.oom();
                        i += 2;
                        continue;
                    }
                    i += 1;
                    break;
                }
                out.append(pa, pattern[i]) catch rt.oom();
                i += 1;
            }
            continue;
        }
        if (!std.ascii.isAlphabetic(ch)) {
            out.append(pa, ch) catch rt.oom();
            i += 1;
            continue;
        }
        var n: usize = 0;
        while (i + n < pattern.len and pattern[i + n] == ch) n += 1;
        i += n;
        switch (ch) {
            'y', 'Y', 'u' => if (n == 2) pad(out, @mod(c.year, 100), 2) else pad(out, c.year, n),
            'M', 'L' => if (n >= 4)
                out.appendSlice(pa, month_names[c.month - 1]) catch rt.oom()
            else if (n == 3)
                out.appendSlice(pa, month_names[c.month - 1][0..3]) catch rt.oom()
            else
                pad(out, c.month, n),
            'd' => pad(out, c.day, n),
            'D' => pad(out, days - os.daysFromCivil(c.year, 1, 1) + 1, n),
            'E' => out.appendSlice(pa, if (n >= 4) day_names[wday] else day_names[wday][0..3]) catch rt.oom(),
            'H' => pad(out, hour, n),
            'k' => pad(out, if (hour == 0) 24 else hour, n),
            'K' => pad(out, @mod(hour, 12), n),
            'h' => pad(out, if (@mod(hour, 12) == 0) 12 else @mod(hour, 12), n),
            'm' => pad(out, minute, n),
            's' => pad(out, second, n),
            'S' => pad(out, milli, n),
            'a' => out.appendSlice(pa, if (hour < 12) "AM" else "PM") catch rt.oom(),
            'Z' => {
                out.append(pa, if (off < 0) '-' else '+') catch rt.oom();
                pad(out, @divTrunc(@as(i64, @intCast(@abs(off))), 60), 2);
                pad(out, @mod(@as(i64, @intCast(@abs(off))), 60), 2);
            },
            'X' => {
                if (off == 0) {
                    out.append(pa, 'Z') catch rt.oom();
                } else {
                    out.append(pa, if (off < 0) '-' else '+') catch rt.oom();
                    pad(out, @divTrunc(@as(i64, @intCast(@abs(off))), 60), 2);
                    if (n >= 2) {
                        if (n >= 3) out.append(pa, ':') catch rt.oom();
                        pad(out, @mod(@as(i64, @intCast(@abs(off))), 60), 2);
                    }
                }
            },
            else => for (0..n) |_| out.append(pa, ch) catch rt.oom(),
        }
    }
}

fn timestampToString(t: *Thread) Err!Word {
    const ms = try intArg(t, 0);
    var fmt: []const u8 = "isodatetime";
    if (t.argc > 1) {
        const f = arg(t, 1);
        fmt = if (data.isSymbol(f)) data.symbolName(f) else try textArg(t, 1);
    }
    const eql = std.mem.eql;
    const pattern = if (eql(u8, fmt, "isodatetime"))
        "yyyyMMdd-HHmmss"
    else if (eql(u8, fmt, "isodatetime2"))
        "yyyyMMdd HHmmss"
    else if (eql(u8, fmt, "isodate"))
        "yyyyMMdd"
    else if (eql(u8, fmt, "isodate-hours"))
        "yyyyMMddHH"
    else if (eql(u8, fmt, "datetime"))
        "dd.MM.yyyy HH:mm:ss"
    else if (eql(u8, fmt, "date"))
        "dd.MM.yyyy"
    else
        fmt;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(pa);
    formatTime(&out, ms, pattern);
    return str(t, out.items);
}
pub const @"%timestamp->string" = WN("timestamp->string", timestampToString, 1, 2);

/// Parse s with abutting numeric fields of the given widths, as
/// SimpleDateFormat: every field but the last takes exactly its width, the
/// last all following digits; trailing text is ignored. Values are lenient
/// (they roll over).
fn parseFields(s: []const u8, comptime widths: []const usize, out: []i64) bool {
    var p: usize = 0;
    for (widths, 0..) |w, k| {
        const last = k + 1 == widths.len;
        var v: i64 = 0;
        var n: usize = 0;
        while (p < s.len and std.ascii.isDigit(s[p]) and (last or n < w)) : (p += 1) {
            v = v * 10 + (s[p] - '0');
            n += 1;
        }
        if (n == 0 or (!last and n < w)) return false;
        out[k] = v;
    }
    return true;
}

/// Seconds since the epoch of a UTC date and time (lenient)
fn utcSeconds(f: []const i64) i64 {
    const days = os.daysFromCivil(f[0], f[1], 1) + f[2] - 1;
    var secs = days * 86400;
    if (f.len > 3) secs += f[3] * 3600;
    if (f.len > 4) secs += f[4] * 60;
    if (f.len > 5) secs += f[5];
    return secs;
}

fn stringToDateDays(t: *Thread) Err!Word {
    const s0 = try textArg(t, 0);
    const s = if (s0.len > 8) s0[0..8] else s0;
    var f: [3]i64 = undefined;
    if (!parseFields(s, &.{ 4, 2, 2 }, &f)) return rt.FALSE;
    return fix(@divTrunc(utcSeconds(&f), 86400) + 25569);
}
pub const @"%string->date-days" = WN("string->date-days", stringToDateDays, 1, 1);

fn stringToDateSeconds(t: *Thread) Err!Word {
    const s = try textArg(t, 0);
    var f: [6]i64 = .{ 0, 0, 0, 0, 0, 0 };
    if (parseFields(s, &.{ 4, 2, 2, 2, 2, 2 }, &f)) return fix(utcSeconds(f[0..6]));
    if (parseFields(s, &.{ 4, 2, 2, 2, 2 }, &f)) return fix(utcSeconds(f[0..5]));
    if (parseFields(s, &.{ 4, 2, 2, 2 }, &f)) return fix(utcSeconds(f[0..4]));
    if (parseFields(s, &.{ 4, 2, 2 }, &f)) return fix(utcSeconds(f[0..3]));
    return rt.FALSE;
}
pub const @"%string->date-seconds" = WN("string->date-seconds", stringToDateSeconds, 1, 1);

// --- file system ------------------------------------------------------------------------

fn fileModificationDate(t: *Thread) Err!Word {
    const ns = os.modificationTime(try textArg(t, 0)) orelse return fix(0);
    return fix(@intCast(@divTrunc(@divTrunc(ns, 1_000_000), 1000)));
}
fn fileModificationTimestamp(t: *Thread) Err!Word {
    const ns = os.modificationTime(try textArg(t, 0)) orelse return fix(0);
    return fix(@intCast(@divTrunc(ns, 1_000_000)));
}
pub const @"%file-modification-date" = WN("file-modification-date", fileModificationDate, 1, 1);
pub const @"%file-modification-timestamp" = WN("file-modification-timestamp", fileModificationTimestamp, 1, 1);

fn setFileModificationTime(t: *Thread) Err!Word {
    const path = try textArg(t, 0);
    const ms = try intArg(t, 1);
    return if (os.setModificationTime(path, @as(i128, ms) * 1_000_000)) rt.UNSPEC else rt.FALSE;
}
pub const @"%set-file-modification-time!" = WN("set-file-modification-time!", setFileModificationTime, 2, 2);

fn copyFile(t: *Thread) Err!Word {
    return if (os.copyFile(try textArg(t, 0), try textArg(t, 1))) rt.UNSPEC else rt.FALSE;
}
pub const @"%copy-file" = WN("copy-file", copyFile, 2, 2);

/// files first, then the subdirectories (as the JVM implementation)
fn copyTree(src: []const u8, dst: []const u8) bool {
    if (os.kindOf(src, true) != .directory) return true;
    if (!os.fileExists(dst) and !os.makeDirectory(dst)) return false;
    const entries = os.listDirectory(src) orelse return false;
    for (entries) |e| {
        const s = std.fs.path.join(pa, &.{ src, e.name }) catch rt.oom();
        if (os.kindOf(s, true) == .directory) continue;
        if (!os.copyFile(s, std.fs.path.join(pa, &.{ dst, e.name }) catch rt.oom())) return false;
    }
    for (entries) |e| {
        const s = std.fs.path.join(pa, &.{ src, e.name }) catch rt.oom();
        if (os.kindOf(s, true) != .directory) continue;
        if (!copyTree(s, std.fs.path.join(pa, &.{ dst, e.name }) catch rt.oom())) return false;
    }
    return true;
}

fn copyDirectory(t: *Thread) Err!Word {
    return if (copyTree(try textArg(t, 0), try textArg(t, 1))) rt.UNSPEC else rt.FALSE;
}
pub const @"%copy-directory" = WN("copy-directory", copyDirectory, 2, 2);

fn moveFile(t: *Thread) Err!Word {
    return if (os.rename(try textArg(t, 0), try textArg(t, 1))) rt.UNSPEC else rt.FALSE;
}
pub const @"%move-file" = WN("move-file", moveFile, 2, 2);
pub const @"%move-directory" = WN("move-directory", moveFile, 2, 2);

fn makeSymlink(t: *Thread) Err!Word {
    return if (os.symlink(try textArg(t, 0), try textArg(t, 1))) rt.UNSPEC else rt.FALSE;
}
pub const @"%make-symlink" = WN("make-symlink", makeSymlink, 2, 2);

fn readSymlink(t: *Thread) Err!Word {
    const target = os.readLink(try textArg(t, 0)) orelse return rt.FALSE;
    return str(t, target);
}
pub const @"%read-symlink" = WN("read-symlink", readSymlink, 1, 1);

fn setCurrentDirectory(t: *Thread) Err!Word {
    const p = try textArg(t, 0);
    if (os.kindOf(p, true) != .directory) return rt.FALSE;
    if (!os.setCurrentDirectory(p)) return rt.FALSE;
    return str(t, os.currentDirectory());
}
pub const @"%set-current-directory!" = WN("set-current-directory!", setCurrentDirectory, 1, 1);

/// Lexically normalized path: . and .. resolved, separators collapsed
fn normalize(path: []const u8) []const u8 {
    return std.fs.path.resolve(pa, &.{path}) catch path;
}

/// The path from dir to path (both absolute and normalized)
fn relativeTo(dir: []const u8, path: []const u8) []const u8 {
    const rel = std.fs.path.relative(pa, "/", null, dir, path) catch return path;
    return if (rel.len == 0) "." else rel;
}

/// (normalized-path p): canonical (symbolic links resolved where the file
/// exists); relative paths stay relative to the current directory
fn normalizedPath(t: *Thread) Err!Word {
    const p = try textArg(t, 0);
    const cwd = os.currentDirectory();
    // on Windows a rooted path without a drive is on the current drive
    const abs = if (builtin.os.tag == .windows)
        normalize(@import("prims_fs.zig").windowsAbsolute(p))
    else if (std.fs.path.isAbsolute(p)) normalize(p) else normalize(std.fs.path.join(pa, &.{ cwd, p }) catch rt.oom());
    const canonical = os.realPath(abs) orelse canonicalPrefix(abs);
    if (std.fs.path.isAbsolute(p)) return str(t, canonical);
    const wd = os.realPath(cwd) orelse cwd;
    return str(t, relativeTo(wd, canonical));
}
pub const @"%normalized-path" = WN("normalized-path", normalizedPath, 1, 1);

/// For a path that does not exist: its longest existing prefix resolved,
/// the rest appended (as File.getCanonicalPath)
fn canonicalPrefix(abs: []const u8) []const u8 {
    var cut = abs.len;
    while (std.mem.lastIndexOfAny(u8, abs[0..cut], if (builtin.os.tag == .windows) "/\\" else "/")) |i| {
        // the root (/, C:\) stays
        if (i == 0 or (builtin.os.tag == .windows and i <= 2)) break;
        if (os.realPath(abs[0..i])) |r| return std.fs.path.join(pa, &.{ r, abs[i + 1 ..] }) catch abs;
        cut = i;
    }
    return abs;
}

fn fileLock(t: *Thread) Err!Word {
    const f = os.lockFile(try textArg(t, 0)) orelse return rt.FALSE;
    const box = pa.create(os.File) catch rt.oom();
    box.* = f;
    return wrapNative(t, .file_lock, box);
}
pub const @"%file-lock" = WN("file-lock", fileLock, 1, 1);

fn fileUnlock(t: *Thread) Err!Word {
    const w = arg(t, 0);
    if (!rt.isObj(w, rt.T_NATIVE) or rt.ptr(w)[1] != @intFromEnum(NativeKind.file_lock)) return rt.FALSE;
    const p = nativeOf(w, .file_lock) orelse return rt.TRUE; // already released
    const f: *os.File = @ptrCast(@alignCast(p));
    os.unlockFile(f.*);
    pa.destroy(f);
    nativeRecord(w).ptr = null;
    return rt.TRUE;
}
pub const @"%file-unlock" = WN("file-unlock", fileUnlock, 1, 1);

fn specialFolderDocuments(t: *Thread) Err!Word {
    if (os.getEnv("USERPROFILE")) |u| return str(t, std.fs.path.join(pa, &.{ u, "Documents" }) catch rt.oom());
    if (os.getEnv("XDG_DOCUMENTS_DIR")) |x| return str(t, x);
    return str(t, os.homeDirectory());
}
pub const @"%special-folder-documents" = WN("special-folder-documents", specialFolderDocuments, 0, 0);

fn specialFolderApplicationData(t: *Thread) Err!Word {
    if (os.getEnv("APPDATA")) |a| return str(t, a);
    if (os.getEnv("XDG_CONFIG_HOME")) |x| return str(t, x);
    return str(t, std.fs.path.join(pa, &.{ os.homeDirectory(), ".config" }) catch rt.oom());
}
pub const @"%special-folder-application-data" = WN("special-folder-application-data", specialFolderApplicationData, 0, 0);

fn which(t: *Thread) Err!Word {
    const name = try textArg(t, 0);
    const path = os.getEnv("PATH") orelse return rt.FALSE;
    // On Windows a name without an extension is resolved as cmd.exe does
    // (and the JVM implementation): each PATHEXT extension in order, so
    // "git" finds git.exe (and not an extension-less file before it)
    var candidates: std.ArrayList([]const u8) = .empty;
    defer candidates.deinit(pa);
    const slash = if (std.mem.lastIndexOfAny(u8, name, "/\\")) |i| i + 1 else 0;
    const has_ext = std.mem.indexOfScalar(u8, name[slash..], '.') != null;
    if (!os.is_windows or has_ext) {
        candidates.append(pa, name) catch rt.oom();
    } else {
        const pathext = if (os.getEnv("PATHEXT")) |v| (if (v.len > 0) v else ".COM;.EXE;.BAT;.CMD") else ".COM;.EXE;.BAT;.CMD";
        var exts = std.mem.splitScalar(u8, pathext, ';');
        while (exts.next()) |e0| {
            const e = std.mem.trim(u8, e0, " \t");
            if (e.len > 0) candidates.append(pa, std.mem.concat(data.scratch(), u8, &.{ name, e }) catch rt.oom()) catch rt.oom();
        }
    }
    var it = std.mem.splitScalar(u8, path, if (os.is_windows) ';' else ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        for (candidates.items) |c| {
            const full = std.fs.path.join(data.scratch(), &.{ dir, c }) catch rt.oom();
            if (os.kindOf(full, true) == .file) return str(t, full);
        }
    }
    return rt.FALSE;
}
pub const @"%which" = WN("which", which, 1, 1);

// --- property lists ------------------------------------------------------------------------

/// The value of name in a property list of (key value) lists or bare keys
fn findProperty(lst0: Word, name: Word, comptime rest: bool) ?Word {
    var lst = lst0;
    while (rt.isPair(lst)) : (lst = rt.cdr(lst)) {
        const e = rt.car(lst);
        if (rt.isPair(e)) {
            if (data.eqv(rt.car(e), name)) {
                if (rest) return rt.cdr(e);
                return if (rt.isPair(rt.cdr(e))) rt.car(rt.cdr(e)) else null;
            }
        } else if (data.eqv(e, name)) return e;
    }
    return null;
}

fn getProperty(t: *Thread) Err!Word {
    const r = findProperty(arg(t, 0), arg(t, 1), false) orelse rt.FALSE;
    if (r == rt.FALSE and t.argc == 3) return arg(t, 2);
    return r;
}
fn getPropertyList(t: *Thread) Err!Word {
    if (findProperty(arg(t, 0), arg(t, 1), true)) |r| return r;
    return if (t.argc == 3) arg(t, 2) else rt.FALSE;
}
pub const @"%get-property" = WD("get-property", getProperty, 2, 3);
pub const @"%get-property-list" = WD("get-property-list", getPropertyList, 2, 3);

// --- processes ---------------------------------------------------------------------------

const Options = struct {
    spawn: os.Spawn,
    stdin_text: ?[]const u8 = null,

    /// The strings are copies, freed after the spawn (the child has its own)
    fn deinit(o: *Options) void {
        for (o.spawn.argv) |a| pa.free(a);
        pa.free(o.spawn.argv);
        if (o.spawn.cwd) |c| pa.free(c);
        if (o.spawn.log_file) |f| pa.free(f);
        if (o.spawn.stdin_file) |f| pa.free(f);
        if (o.spawn.stdout_file) |f| pa.free(f);
        if (o.spawn.stderr_file) |f| pa.free(f);
        for (o.spawn.env) |kv| {
            pa.free(kv[0]);
            pa.free(kv[1]);
        }
        pa.free(o.spawn.env);
        if (o.stdin_text) |x| pa.free(x);
        o.* = .{ .spawn = .{ .argv = &.{} } };
    }
};

/// The command line and options of run-program, run-program/capture and
/// start-program
fn programArgs(t: *Thread) Err!Options {
    var argv: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (argv.items) |a| pa.free(a);
        argv.deinit(pa);
    }
    var l = arg(t, 0);
    if (!rt.isPair(l)) return P.argTypeError(t);
    while (rt.isPair(l)) : (l = rt.cdr(l)) {
        const x = rt.car(l);
        if (!data.isString(x)) return P.argTypeError(t);
        argv.append(pa, data.toUtf8Owned(x)) catch rt.oom();
    }
    var o = Options{ .spawn = .{ .argv = argv.toOwnedSlice(pa) catch rt.oom() } };
    errdefer o.deinit();
    if (t.argc > 1) {
        const opts = arg(t, 1);
        if (findProperty(opts, data.intern("work-dir"), false)) |w| if (w != rt.FALSE) {
            if (!data.isString(w)) return P.argTypeError(t);
            o.spawn.cwd = data.toUtf8Owned(w);
        };
        if (findProperty(opts, data.intern("stdin"), false)) |s| if (s != rt.FALSE) {
            if (!data.isString(s)) return P.argTypeError(t);
            o.stdin_text = data.toUtf8Owned(s);
        };
        if (findProperty(opts, data.intern("log-file"), false)) |f| if (f != rt.FALSE) {
            if (!data.isString(f)) return P.argTypeError(t);
            o.spawn.log_file = data.toUtf8Owned(f);
        };
        if (findProperty(opts, data.intern("stdin-file"), false)) |f| if (f != rt.FALSE) {
            if (!data.isString(f)) return P.argTypeError(t);
            o.spawn.stdin_file = data.toUtf8Owned(f);
        };
        if (findProperty(opts, data.intern("stdout"), false)) |f| if (f != rt.FALSE) {
            if (!data.isString(f)) return P.argTypeError(t);
            o.spawn.stdout_file = data.toUtf8Owned(f);
        };
        if (findProperty(opts, data.intern("stderr"), false)) |f| if (f != rt.FALSE) {
            if (f == data.intern("stdout")) {
                o.spawn.stderr_to_stdout = true;
            } else {
                if (!data.isString(f)) return P.argTypeError(t);
                o.spawn.stderr_file = data.toUtf8Owned(f);
            }
        };
        if (findProperty(opts, data.intern("append"), false)) |f| o.spawn.append = f != rt.FALSE;
        if (findProperty(opts, data.intern("new-group"), false)) |f| o.spawn.new_group = f != rt.FALSE;
        if (findProperty(opts, data.intern("env"), false)) |env| {
            var pairs: std.ArrayList([2][]const u8) = .empty;
            errdefer {
                for (pairs.items) |kv| {
                    pa.free(kv[0]);
                    pa.free(kv[1]);
                }
                pairs.deinit(pa);
            }
            var e = env;
            while (rt.isPair(e)) : (e = rt.cdr(e)) {
                const kv = rt.car(e);
                if (!rt.isPair(kv) or !data.isString(rt.car(kv))) return P.argTypeError(t);
                const v = if (rt.isPair(rt.cdr(kv))) rt.car(rt.cdr(kv)) else rt.cdr(kv);
                if (!data.isString(v)) return P.argTypeError(t);
                pairs.append(pa, .{ data.toUtf8Owned(rt.car(kv)), data.toUtf8Owned(v) }) catch rt.oom();
            }
            o.spawn.env = pairs.toOwnedSlice(pa) catch rt.oom();
        }
    }
    return o;
}

fn runProgram(t: *Thread) Err!Word {
    var o = try programArgs(t);
    defer o.deinit();
    o.spawn.stdin_text = o.stdin_text;
    o.spawn.new_group = false;
    os.flush();
    const p = os.spawn(o.spawn) orelse return rt.FALSE;
    const code = os.procWait(p, null);
    os.procJoinFeeder(p, true);
    os.procFree(p);
    return fix(code orelse return rt.FALSE);
}
pub const @"%run-program" = WN("run-program", runProgram, 1, 2);

fn runProgramCapture(t: *Thread) Err!Word {
    var o = try programArgs(t);
    defer o.deinit();
    o.spawn.new_group = false;
    os.flush();
    const r = os.capture(o.spawn, o.stdin_text) orelse return rt.FALSE;
    defer pa.free(r.out);
    defer pa.free(r.err);
    t.reserve(9 + data.stringWords(r.out.len, true) + data.stringWords(r.err.len, true));
    const out = data.heapStringUtf8(t, r.out);
    const err = data.heapStringUtf8(t, r.err);
    return t.cons(fix(r.code), t.cons(out, t.cons(err, rt.NIL)));
}
pub const @"%run-program/capture" = WN("run-program/capture", runProgramCapture, 1, 2);

fn startProgram(t: *Thread) Err!Word {
    var o = try programArgs(t);
    defer o.deinit();
    o.spawn.inherit_stdin = false;
    o.spawn.stdin_text = o.stdin_text;
    os.flush();
    const p = os.spawn(o.spawn) orelse return raise(t, "start-program: cannot start ~a", &.{rt.car(arg(t, 0))});
    os.procJoinFeeder(p, false);
    return wrapNative(t, .process, p);
}
pub const @"%start-program" = WN("start-program", startProgram, 1, 2);

fn procArg(t: *Thread) Err!*os.Proc {
    const p = nativeOf(arg(t, 0), .process) orelse return P.argTypeError(t);
    return @ptrCast(@alignCast(p));
}

fn processAliveP(t: *Thread) Err!Word {
    return rt.boolean(os.procPoll(try procArg(t)) == null);
}
pub const @"%process-alive?" = WN("process-alive?", processAliveP, 1, 1);

fn processPid(t: *Thread) Err!Word {
    return fix(os.procId(try procArg(t)));
}
pub const @"%process-pid" = WN("process-pid", processPid, 1, 1);

fn processWait(t: *Thread) Err!Word {
    const p = try procArg(t);
    const timeout: ?u64 = if (t.argc > 1) @intCast(@max(0, try intArg(t, 1))) else null;
    return fix(os.procWait(p, timeout) orelse return rt.FALSE);
}
pub const @"%process-wait" = WN("process-wait", processWait, 1, 2);

fn processKill(t: *Thread) Err!Word {
    const p = try procArg(t);
    const force = t.argc > 1 and arg(t, 1) != rt.FALSE;
    if (os.procPoll(p) != null) return rt.TRUE;
    os.killTree(os.procId(p), force);
    return rt.TRUE;
}
pub const @"%process-kill" = WN("process-kill", processKill, 1, 2);

var tracked: std.ArrayList(*os.Proc) = .empty;
var tracked_lock: std.Io.Mutex = .init;

fn killTracked() void {
    tracked_lock.lockUncancelable(os.io);
    defer tracked_lock.unlock(os.io);
    for (tracked.items) |p| if (os.procPoll(p) == null) os.killTree(os.procId(p), true);
}

fn processKillOnExit(t: *Thread) Err!Word {
    const p = try procArg(t);
    tracked_lock.lockUncancelable(os.io);
    defer tracked_lock.unlock(os.io);
    var i: usize = 0;
    while (i < tracked.items.len) {
        if (os.procPoll(tracked.items[i]) != null) {
            _ = tracked.swapRemove(i);
        } else i += 1;
    }
    tracked.append(pa, p) catch rt.oom();
    os.atExit(&killTracked);
    return rt.TRUE;
}
pub const @"%process-kill-on-exit" = WN("process-kill-on-exit", processKillOnExit, 1, 1);

fn currentPid(_: *Thread) Err!Word {
    return fix(os.pid());
}
fn parentPid(_: *Thread) Err!Word {
    return if (os.parentPid()) |p| fix(p) else rt.FALSE;
}
pub const @"%current-pid" = WD("current-pid", currentPid, 0, 0);
pub const @"%parent-pid" = WD("parent-pid", parentPid, 0, 0);

fn kill(t: *Thread) Err!Word {
    const target = try intArg(t, 0);
    const force = t.argc > 1 and arg(t, 1) != rt.FALSE;
    return rt.boolean(os.signalProcess(target, force));
}
pub const @"%kill" = WN("kill", kill, 1, 2);

/// The JVM's ProcessHandle.Info: command is the executable, the command
/// line when available
fn infoWords(i: os.ProcInfo) usize {
    const cmd = i.cmdline orelse i.command orelse "";
    const user = i.user orelse "";
    return 6 * 3 + 6 * 3 + data.stringWords(cmd.len, true) + data.stringWords(user.len, true) + 4;
}

fn infoList(t: *Thread, i: os.ProcInfo) Word {
    const cmd: Word = if (i.cmdline orelse i.command) |c| data.heapStringUtf8(t, c) else rt.FALSE;
    const user: Word = if (i.user) |u| data.heapStringUtf8(t, u) else rt.FALSE;
    const start: Word = if (i.start_ms) |s| fix(s) else rt.FALSE;
    const cpu: Word = if (i.cpu_s) |c| rt.safeFlo(t, c) else rt.FALSE;
    var l = rt.NIL;
    l = t.cons(t.cons(data.intern("cpu-time"), cpu), l);
    l = t.cons(t.cons(data.intern("start-time"), start), l);
    l = t.cons(t.cons(data.intern("user"), user), l);
    l = t.cons(t.cons(data.intern("command"), cmd), l);
    l = t.cons(t.cons(data.intern("ppid"), if (i.ppid) |pp| fix(pp) else rt.FALSE), l);
    l = t.cons(t.cons(data.intern("pid"), fix(i.pid)), l);
    return l;
}

fn ps(t: *Thread) Err!Word {
    const pids = os.listProcesses();
    var infos: std.ArrayList(os.ProcInfo) = .empty;
    defer infos.deinit(pa);
    var words: usize = 0;
    for (pids) |p| if (os.procInfo(p)) |i| {
        infos.append(pa, i) catch rt.oom();
        words += infoWords(i) + 3;
    };
    t.reserve(words);
    var l = rt.NIL;
    for (infos.items) |i| l = t.cons(infoList(t, i), l);
    return l;
}
pub const @"%ps" = WN("ps", ps, 0, 0);

fn psInfo(t: *Thread) Err!Word {
    const i = os.procInfo(try intArg(t, 0)) orelse return rt.FALSE;
    t.reserve(infoWords(i));
    return infoList(t, i);
}
pub const @"%ps-info" = WN("ps-info", psInfo, 1, 1);

fn matches(i: os.ProcInfo, pattern: []const u8, full: bool) bool {
    const hay = (if (full) i.cmdline orelse i.command else i.command) orelse return false;
    return std.mem.indexOf(u8, hay, pattern) != null;
}

fn pgrep(t: *Thread) Err!Word {
    const pattern = try textArg(t, 0);
    const full = t.argc > 1 and arg(t, 1) != rt.FALSE;
    var found: std.ArrayList(i64) = .empty;
    defer found.deinit(pa);
    for (os.listProcesses()) |p| if (os.procInfo(p)) |i| if (matches(i, pattern, full)) found.append(pa, p) catch rt.oom();
    t.reserve(3 * found.items.len);
    var l = rt.NIL;
    for (found.items) |p| l = t.cons(fix(p), l);
    return l;
}
pub const @"%pgrep" = WN("pgrep", pgrep, 1, 2);

fn pkill(t: *Thread) Err!Word {
    const pattern = try textArg(t, 0);
    const force = t.argc > 1 and arg(t, 1) != rt.FALSE;
    const full = t.argc > 2 and arg(t, 2) != rt.FALSE;
    const self = os.pid();
    var n: i64 = 0;
    for (os.listProcesses()) |p| {
        if (p == self) continue;
        const i = os.procInfo(p) orelse continue;
        if (matches(i, pattern, full) and os.signalProcess(p, force)) n += 1;
    }
    return fix(n);
}
pub const @"%pkill" = WN("pkill", pkill, 1, 3);

// --- system information --------------------------------------------------------------------

fn sysMachineName(t: *Thread) Err!Word {
    return str(t, os.hostName() orelse return rt.FALSE);
}
pub const @"%sys-machine-name" = WN("sys-machine-name", sysMachineName, 0, 0);

fn sysNumCpuCores(_: *Thread) Err!Word {
    return fix(@intCast(os.cpuCount()));
}
pub const @"%sys-num-cpu-cores" = WD("sys-num-cpu-cores", sysNumCpuCores, 0, 0);

fn sysOsVersion(t: *Thread) Err!Word {
    const name = switch (builtin.os.tag) {
        .windows => "windows",
        .linux => "linux",
        else => "unknown",
    };
    const release = os.osRelease();
    t.reserve(data.stringWords(release.len, true) + 6);
    const v = data.heapStringUtf8(t, release);
    return t.cons(data.intern(name), t.cons(v, rt.NIL));
}
pub const @"%sys-os-version" = WN("sys-os-version", sysOsVersion, 0, 0);

/// A native program has no interpreter of its own: scm on the PATH
fn sysScmCommand(t: *Thread) Err!Word {
    t.reserve(data.stringWords(3, false) + 3);
    return t.cons(data.heapStringUtf8(t, "scm"), rt.NIL);
}
pub const @"%sys-scm-command" = WN("sys-scm-command", sysScmCommand, 0, 0);

fn sysScmTechnology(_: *Thread) Err!Word {
    return data.intern("native");
}
pub const @"%sys-scm-technology" = WD("sys-scm-technology", sysScmTechnology, 0, 0);

extern fn scm_program_version() callconv(.c) [*:0]const u8;

fn sysScmVersion(t: *Thread) Err!Word {
    return str(t, std.mem.span(scm_program_version()));
}
pub const @"%sys-scm-version" = WN("sys-scm-version", sysScmVersion, 0, 0);

fn sysUserName(t: *Thread) Err!Word {
    return str(t, os.userName());
}
pub const @"%sys-user-name" = WN("sys-user-name", sysUserName, 0, 0);

// --- terminal ((scm terminal)) ------------------------------------------------------------

fn terminalP(t: *Thread) Err!Word {
    if (t.argc == 1) {
        const w = arg(t, 0);
        if (!data.isSymbol(w)) return P.argTypeError(t);
        const n = data.symbolName(w);
        if (std.mem.eql(u8, n, "input")) return rt.boolean(os.isTerminal(0));
        if (std.mem.eql(u8, n, "output")) return rt.boolean(os.isTerminal(1));
        return raise(t, "terminal?: expected 'input or 'output, got ~s", &.{w});
    }
    // as Java's System.console(): both are terminals
    return rt.boolean(os.isTerminal(0) and os.isTerminal(1));
}
pub const @"%terminal?" = WN("terminal?", terminalP, 0, 1);

fn terminalSize(t: *Thread) Err!Word {
    const s = os.terminalSize() orelse return rt.FALSE;
    return pair(t, s[0], s[1]);
}
pub const @"%terminal-size" = WN("terminal-size", terminalSize, 0, 0);

fn terminalRaw(t: *Thread) Err!Word {
    var keep_output = false;
    if (t.argc > 1) {
        if (arg(t, 1) != data.intern("keep-output")) return P.argTypeError(t);
        keep_output = true;
    }
    os.flush();
    return rt.boolean(os.terminalRaw(arg(t, 0) != rt.FALSE, keep_output));
}
pub const @"%terminal-raw!" = WN("terminal-raw!", terminalRaw, 1, 2);

const interrupt_modes = [_][]const u8{ "default", "ignore", "record" };

/// (set-interrupt-handler! mode): what Ctrl+C does: 'default, 'ignore,
/// 'record (take-interrupt! tells); the mode before
fn setInterruptHandler(t: *Thread) Err!Word {
    const m = arg(t, 0);
    for (interrupt_modes, 0..) |name, i| if (m == data.intern(name)) {
        const before = os.setInterruptMode(@intCast(i));
        return data.intern(interrupt_modes[before]);
    };
    return P.argTypeError(t);
}
pub const @"%set-interrupt-handler!" = WN("set-interrupt-handler!", setInterruptHandler, 1, 1);

fn takeInterrupt(t: *Thread) Err!Word {
    _ = t;
    return rt.boolean(os.takeInterrupt());
}
pub const @"%take-interrupt!" = WN("take-interrupt!", takeInterrupt, 0, 0);

fn consoleEcho(t: *Thread) Err!Word {
    return rt.boolean(os.terminalEcho(arg(t, 0) != rt.FALSE));
}
pub const @"%console-echo!" = WN("console-echo!", consoleEcho, 1, 1);

fn terminalReadByte(_: *Thread) Err!Word {
    os.flush();
    return if (os.readByte()) |b| fix(b) else rt.EOF;
}
pub const @"%terminal-read-byte" = WN("terminal-read-byte", terminalReadByte, 0, 0);

fn terminalByteReadyP(t: *Thread) Err!Word {
    const timeout: i64 = if (t.argc > 0) try intArg(t, 0) else 0;
    os.flush();
    return rt.boolean(os.byteReady(timeout));
}
pub const @"%terminal-byte-ready?" = WN("terminal-byte-ready?", terminalByteReadyP, 0, 1);

fn terminalEnableAnsi(_: *Thread) Err!Word {
    return rt.TRUE;
}
pub const @"%terminal-enable-ansi!" = WD("terminal-enable-ansi!", terminalEnableAnsi, 0, 0);

fn terminalResizeCount(_: *Thread) Err!Word {
    return if (os.resizeCount()) |n| fix(n) else rt.FALSE;
}
pub const @"%terminal-resize-count" = WD("terminal-resize-count", terminalResizeCount, 0, 0);

/// (console-read-password [prompt]): a line read without echo
fn consoleReadPassword(t: *Thread) Err!Word {
    if (t.argc == 1) {
        const p = arg(t, 0);
        if (!data.isString(p)) return raise(t, "console-read-password: expected string prompt, got ~s", &.{p});
        os.write(data.toUtf8(p));
    }
    os.flush();
    const tty = os.isTerminal(0);
    if (tty) _ = os.terminalEcho(false);
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(pa);
    var eof = true;
    while (os.readByte()) |b| {
        eof = false;
        if (b == '\n') break;
        if (b != '\r') line.append(pa, b) catch rt.oom();
    }
    if (tty) {
        _ = os.terminalEcho(true);
        os.write("\n");
        os.flush();
    }
    if (eof and line.items.len == 0) return rt.EOF;
    return str(t, line.items);
}
pub const @"%console-read-password" = WN("console-read-password", consoleReadPassword, 0, 1);

// --- zip archives ((scm zip)) ------------------------------------------------------------

const zip = @import("zip.zig");
const ports = @import("ports.zig");

const ZipIn = struct { reader: zip.Reader };

const ZipOut = struct {
    writer: zip.Writer = .{},
    path: ?[]const u8 = null, // null: a bytevector zip
    port: ?*ports.Port = null, // of the entry being written
    closed: bool = false,

    /// end the entry being written through a port
    fn finishPending(z: *ZipOut) zip.Error!void {
        const pend = z.writer.pending orelse return;
        const p = z.port.?;
        z.writer.pending = null;
        z.port = null;
        p.pinned = false;
        // add copies the name
        defer pa.free(pend.name);
        try z.writer.add(pend.name, p.out.items, pend.ms, pend.method);
        p.out.clearAndFree(pa);
        p.open = false;
    }
};

fn zipError(t: *Thread, who: []const u8, e: zip.Error) Err {
    const m = switch (e) {
        error.BadZip => "zip END header not found",
        error.BadData => @import("compress.zig").last_error,
        error.NotFound => "entry not found",
        error.OutOfMemory => rt.oom(),
    };
    return raise(t, std.fmt.allocPrint(pa, "{s} failed: {s}", .{ who, m }) catch rt.oom(), &.{});
}

fn openInputZipFile(t: *Thread) Err!Word {
    const path = try textArg(t, 0);
    const bytes = os.readFile(path) orelse
        return raise(t, std.fmt.allocPrint(pa, "open-input-zip-file failed: {s} (No such file or directory)", .{path}) catch rt.oom(), &.{});
    const r = zip.open(bytes) catch |e| return zipError(t, "open-input-zip-file", e);
    const z = pa.create(ZipIn) catch rt.oom();
    z.* = .{ .reader = r };
    return wrapNative(t, .zip_in, z);
}
pub const @"%open-input-zip-file" = WN("open-input-zip-file", openInputZipFile, 1, 1);

fn zipIn(t: *Thread) Err!*ZipIn {
    const p = nativeOf(arg(t, 0), .zip_in) orelse return P.argTypeError(t);
    return @ptrCast(@alignCast(p));
}

fn zipOut(t: *Thread) Err!*ZipOut {
    const p = nativeOf(arg(t, 0), .zip_out) orelse return P.argTypeError(t);
    return @ptrCast(@alignCast(p));
}

fn zipEntryNames(t: *Thread) Err!Word {
    const z = try zipIn(t);
    var words: usize = 0;
    for (z.reader.entries) |e| words += 3 + data.stringWords(e.name.len, true);
    t.reserve(words);
    var l = rt.NIL;
    var i = z.reader.entries.len;
    while (i > 0) {
        i -= 1;
        l = t.cons(data.heapStringUtf8(t, z.reader.entries[i].name), l);
    }
    return l;
}
pub const @"%zip-entry-names" = WN("zip-entry-names", zipEntryNames, 1, 1);

fn entryArg(t: *Thread, z: *ZipIn, who: []const u8) Err!*const zip.Entry {
    const name = try textArg(t, 1);
    return z.reader.find(name) orelse raise(t, std.fmt.allocPrint(pa, "{s}: entry not found, ~a", .{who}) catch rt.oom(), &.{arg(t, 1)});
}

fn zipEntrySize(t: *Thread) Err!Word {
    const z = try zipIn(t);
    const e = try entryArg(t, z, "zip-entry-size");
    return fix(@intCast(e.usize));
}
pub const @"%zip-entry-size" = WN("zip-entry-size", zipEntrySize, 2, 2);

fn zipReadEntryBytevector(t: *Thread) Err!Word {
    const z = try zipIn(t);
    const e = try entryArg(t, z, "zip-read-entry-bytevector");
    const bytes = z.reader.read(e) catch |err| return zipError(t, "zip-read-entry-bytevector", err);
    defer pa.free(bytes);
    t.reserve(data.bvWords(bytes.len));
    const bv = data.makeBytevector(t, bytes.len);
    @memcpy(data.bvBytes(bv), bytes);
    return bv;
}
pub const @"%zip-read-entry-bytevector" = WN("zip-read-entry-bytevector", zipReadEntryBytevector, 2, 2);

fn zipExtractEntry(t: *Thread) Err!Word {
    const z = try zipIn(t);
    const e = try entryArg(t, z, "zip-extract-entry");
    const path = try textArg(t, 2);
    const max: i64 = if (t.argc > 3) try intArg(t, 3) else std.math.maxInt(i64);
    const bytes = z.reader.read(e) catch |err| return zipError(t, "zip-extract-entry", err);
    defer pa.free(bytes);
    if (bytes.len > max)
        return raise(t, std.fmt.allocPrint(pa, "zip-extract-entry: entry ~a is larger than {d} bytes", .{max}) catch rt.oom(), &.{arg(t, 1)});
    const f = os.createFile(path) orelse return raise(t, "zip-extract-entry failed: ~a", &.{arg(t, 2)});
    defer os.closeFile(f);
    if (!os.writeFile(f, bytes)) return raise(t, "zip-extract-entry failed: ~a", &.{arg(t, 2)});
    return fix(@intCast(bytes.len));
}
pub const @"%zip-extract-entry" = WN("zip-extract-entry", zipExtractEntry, 3, 4);

fn closeInputZip(t: *Thread) Err!Word {
    _ = try zipIn(t);
    return rt.UNSPEC;
}
pub const @"%close-input-zip" = WN("close-input-zip", closeInputZip, 1, 1);

fn openOutputZip(t: *Thread, path: ?[]const u8) Word {
    const z = pa.create(ZipOut) catch rt.oom();
    z.* = .{ .path = path };
    return wrapNative(t, .zip_out, z);
}

fn openOutputZipFile(t: *Thread) Err!Word {
    const path = data.toUtf8Owned(try P.stringArg(t, 0)); // kept: written at close
    // fail now, as the JVM's FileOutputStream, if the file cannot be created
    const f = os.createFile(path) orelse
        return raise(t, std.fmt.allocPrint(pa, "open-output-zip-file failed: {s} (No such file or directory)", .{path}) catch rt.oom(), &.{});
    os.closeFile(f);
    return openOutputZip(t, path);
}
pub const @"%open-output-zip-file" = WN("open-output-zip-file", openOutputZipFile, 1, 1);

fn openOutputZipBytevector(t: *Thread) Err!Word {
    return openOutputZip(t, null);
}
pub const @"%open-output-zip-bytevector" = WN("open-output-zip-bytevector", openOutputZipBytevector, 0, 0);

fn entryTime(t: *Thread, i: usize) Err!i64 {
    return if (t.argc > i) (try intArg(t, i)) * 1000 else nowMs();
}

fn addPortEntry(t: *Thread, binary: bool) Err!Word {
    const z = try zipOut(t);
    const name = try textArg(t, 1);
    const ms = try entryTime(t, 2);
    z.finishPending() catch |e| return zipError(t, if (binary) "zip-add-binary-entry" else "zip-add-text-entry", e);
    const p = ports.newPort(if (binary) .bytes_out else .string_out, binary);
    z.port = p;
    p.pinned = true; // the zip writer reads it at the next entry or close
    z.writer.pending = .{ .name = pa.dupe(u8, name) catch rt.oom(), .ms = ms, .method = 8 };
    t.reserve(2);
    return ports.wrap(t, p);
}
fn zipAddTextEntry(t: *Thread) Err!Word {
    return addPortEntry(t, false);
}
fn zipAddBinaryEntry(t: *Thread) Err!Word {
    return addPortEntry(t, true);
}
pub const @"%zip-add-text-entry" = WN("zip-add-text-entry", zipAddTextEntry, 2, 3);
pub const @"%zip-add-binary-entry" = WN("zip-add-binary-entry", zipAddBinaryEntry, 2, 3);

fn zipAddStoredEntry(t: *Thread) Err!Word {
    const z = try zipOut(t);
    const name = try textArg(t, 1);
    const bv = arg(t, 2);
    if (!data.isBytevector(bv)) return P.argTypeError(t);
    const ms = try entryTime(t, 3);
    z.finishPending() catch |e| return zipError(t, "zip-add-stored-entry", e);
    z.writer.add(name, data.bvBytes(bv), ms, 0) catch |e| return zipError(t, "zip-add-stored-entry", e);
    return rt.UNSPEC;
}
pub const @"%zip-add-stored-entry" = WN("zip-add-stored-entry", zipAddStoredEntry, 3, 4);

fn zipAddFileEntry(t: *Thread) Err!Word {
    const z = try zipOut(t);
    const name = try textArg(t, 1);
    const path = try textArg(t, 2);
    const deflate = t.argc > 3 and arg(t, 3) != rt.FALSE;
    const bytes = os.readFile(path) orelse
        return raise(t, std.fmt.allocPrint(pa, "zip-add-file-entry: io failure: {s}", .{path}) catch rt.oom(), &.{});
    defer pa.free(bytes);
    const ms: i64 = if (os.modificationTime(path)) |ns| @intCast(@divTrunc(ns, 1_000_000)) else nowMs();
    z.finishPending() catch |e| return zipError(t, "zip-add-file-entry", e);
    z.writer.add(name, bytes, ms, if (deflate) 8 else 0) catch |e| return zipError(t, "zip-add-file-entry", e);
    return rt.UNSPEC;
}
pub const @"%zip-add-file-entry" = WN("zip-add-file-entry", zipAddFileEntry, 3, 4);

fn closeOutputZip(t: *Thread) Err!Word {
    const z = try zipOut(t);
    if (z.closed) return rt.UNSPEC;
    z.finishPending() catch |e| return zipError(t, "close-output-zip", e);
    const bytes = z.writer.finish() catch |e| return zipError(t, "close-output-zip", e);
    z.closed = true;
    if (z.path) |path| {
        const f = os.createFile(path) orelse return raise(t, std.fmt.allocPrint(pa, "close-output-zip failed: {s}", .{path}) catch rt.oom(), &.{});
        defer os.closeFile(f);
        if (!os.writeFile(f, bytes)) return raise(t, std.fmt.allocPrint(pa, "close-output-zip failed: {s}", .{path}) catch rt.oom(), &.{});
    }
    return rt.UNSPEC;
}
pub const @"%close-output-zip" = WN("close-output-zip", closeOutputZip, 1, 1);

fn getOutputZipBytevector(t: *Thread) Err!Word {
    const z = try zipOut(t);
    if (z.path != null) return raise(t, "get-output-zip-bytevector: not a bytevector zip port", &.{});
    const bytes = z.writer.out.items;
    t.reserve(data.bvWords(bytes.len));
    const bv = data.makeBytevector(t, bytes.len);
    @memcpy(data.bvBytes(bv), z.writer.out.items);
    return bv;
}
pub const @"%get-output-zip-bytevector" = WN("get-output-zip-bytevector", getOutputZipBytevector, 1, 1);

// --- random-access files ((scm random-access)) -------------------------------------------

const Raf = struct { file: os.File, open: bool = true };

fn openRandomAccessFile(t: *Thread) Err!Word {
    const path = try textArg(t, 0);
    const m = arg(t, 1);
    const mode_name = if (data.isSymbol(m)) data.symbolName(m) else try textArg(t, 1);
    const mode: os.RafMode = if (std.mem.eql(u8, mode_name, "read")) .read else if (std.mem.eql(u8, mode_name, "write")) .write else if (std.mem.eql(u8, mode_name, "update")) .update else return raise(t, "open-random-access-file: bad mode, ~a (expected read, write, or update)", &.{m});
    if (mode == .read and !os.fileExists(path)) {
        // the JVM's irritant is a Java string: a symbol
        _ = rt.failKind(t, rt.ErrorKind.file, "open-random-access-file: file not found", &.{data.intern(path)});
        return error.Scheme;
    }
    const f = os.openRandomAccess(path, mode) orelse
        return raise(t, std.fmt.allocPrint(pa, "open-random-access-file: io failure: {s}", .{path}) catch rt.oom(), &.{});
    const r = pa.create(Raf) catch rt.oom();
    r.* = .{ .file = f };
    return wrapNative(t, .random_access, r);
}
pub const @"%open-random-access-file" = WN("open-random-access-file", openRandomAccessFile, 2, 2);

fn rafArg(t: *Thread, who: []const u8) Err!*Raf {
    const p = nativeOf(arg(t, 0), .random_access) orelse
        return raise(t, std.fmt.allocPrint(pa, "{s}: random-access file handle expected, got ~s", .{who}) catch rt.oom(), &.{arg(t, 0)});
    const r: *Raf = @ptrCast(@alignCast(p));
    if (!r.open) return raise(t, std.fmt.allocPrint(pa, "{s}: random-access file is closed", .{who}) catch rt.oom(), &.{});
    return r;
}

fn randomAccessFileP(t: *Thread) Err!Word {
    return rt.boolean(nativeOf(arg(t, 0), .random_access) != null);
}
pub const @"%random-access-file?" = WN("random-access-file?", randomAccessFileP, 1, 1);

fn rafRead(t: *Thread) Err!Word {
    const r = try rafArg(t, "random-access-file-read");
    const offset = try intArg(t, 1);
    const count = try intArg(t, 2);
    if (offset < 0) return raise(t, "random-access-file-read: negative offset, ~s", &.{arg(t, 1)});
    const size = os.fileLength(r.file) orelse 0;
    const n: usize = if (count <= 0 or @as(u64, @intCast(offset)) >= size) 0 else @intCast(@min(@as(u64, @intCast(count)), size - @as(u64, @intCast(offset))));
    const buf = pa.alloc(u8, n) catch rt.oom();
    defer pa.free(buf);
    const got = if (n > 0) os.readAt(r.file, buf, @intCast(offset)) orelse return raise(t, "random-access-file-read: io failure", &.{}) else 0;
    t.reserve(data.bvWords(got));
    const bv = data.makeBytevector(t, got);
    @memcpy(data.bvBytes(bv), buf[0..got]);
    return bv;
}
pub const @"%random-access-file-read" = WN("random-access-file-read", rafRead, 3, 3);

fn rafWrite(t: *Thread) Err!Word {
    const r = try rafArg(t, "random-access-file-write!");
    const offset = try intArg(t, 1);
    const bv = arg(t, 2);
    if (!data.isBytevector(bv)) return P.argTypeError(t);
    const len = data.bvLen(bv);
    const start: i64 = if (t.argc > 3) try intArg(t, 3) else 0;
    const end: i64 = if (t.argc > 4) try intArg(t, 4) else @intCast(len);
    if (offset < 0) return raise(t, "random-access-file-write!: negative offset, ~s", &.{arg(t, 1)});
    if (start < 0 or end > len or start > end)
        return raise(t, "random-access-file-write!: bad start/end (~s ~s) for bytevector of length ~s", &.{ fix(start), fix(end), fix(@intCast(len)) });
    const bytes = data.bvBytes(bv)[@intCast(start)..@intCast(end)];
    if (bytes.len > 0 and !os.writeAt(r.file, bytes, @intCast(offset))) return raise(t, "random-access-file-write!: io failure", &.{});
    return fix(@intCast(bytes.len));
}
pub const @"%random-access-file-write!" = WN("random-access-file-write!", rafWrite, 3, 5);

fn rafSize(t: *Thread) Err!Word {
    const r = try rafArg(t, "random-access-file-size");
    return fix(@intCast(os.fileLength(r.file) orelse return raise(t, "random-access-file-size: io failure", &.{})));
}
pub const @"%random-access-file-size" = WN("random-access-file-size", rafSize, 1, 1);

fn rafTruncate(t: *Thread) Err!Word {
    const r = try rafArg(t, "random-access-file-truncate!");
    const size = try intArg(t, 1);
    if (size < 0) return raise(t, "random-access-file-truncate!: negative size, ~s", &.{arg(t, 1)});
    if (!os.setFileLength(r.file, @intCast(size))) return raise(t, "random-access-file-truncate!: io failure", &.{});
    return rt.UNSPEC;
}
pub const @"%random-access-file-truncate!" = WN("random-access-file-truncate!", rafTruncate, 2, 2);

fn rafFlush(t: *Thread) Err!Word {
    const r = try rafArg(t, "random-access-file-flush");
    _ = os.syncFile(r.file);
    return rt.UNSPEC;
}
pub const @"%random-access-file-flush" = WN("random-access-file-flush", rafFlush, 1, 1);

fn closeRandomAccessFile(t: *Thread) Err!Word {
    const p = nativeOf(arg(t, 0), .random_access) orelse
        return raise(t, "close-random-access-file: random-access file handle expected, got ~s", &.{arg(t, 0)});
    const r: *Raf = @ptrCast(@alignCast(p));
    if (r.open) {
        r.open = false;
        os.closeFile(r.file);
    }
    return rt.UNSPEC;
}
pub const @"%close-random-access-file" = WN("close-random-access-file", closeRandomAccessFile, 1, 1);

fn makeNil() callconv(.c) Word {
    return rt.NIL;
}
pub const @"%nil" = rt.ValuePrim{ .make = &makeNil };
