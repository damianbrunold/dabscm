//! The operating system layer. All use of version-sensitive `std` APIs
//! (std.Io, std.process, ...) is kept in this file.
const std = @import("std");

pub var io: std.Io = undefined;
var environ: ?*std.process.Environ.Map = null;
var out_buf: [8192]u8 = undefined;
var out_len: usize = 0;

const pa = std.heap.c_allocator;

pub fn init(the_io: std.Io, env: *std.process.Environ.Map) void {
    io = the_io;
    environ = env;
}

var threaded: std.Io.Threaded = undefined;
var environ_map: std.process.Environ.Map = undefined;

/// Set up the process from the C main (as std.start does): the Io
/// implementation, the environment; returns the command line.
pub fn initProcess(argc: usize, argv: [*][*:0]u8, envp: [*:null]?[*:0]u8) []const [:0]const u8 {
    const gpa = std.heap.c_allocator;
    var env_count: usize = 0;
    while (envp[env_count] != null) : (env_count += 1) {}
    const env_block: std.process.Environ.Block = if (builtin.os.tag == .windows) .global else .{ .slice = envp[0..env_count :null] };
    const vector: std.process.Args.Vector = if (builtin.os.tag == .windows)
        std.os.windows.peb().ProcessParameters.CommandLine.slice()
    else
        @ptrCast(argv[0..argc]);
    threaded = .init(gpa, .{
        .argv0 = .init(.{ .vector = vector }),
        .environ = .{ .block = env_block },
    });
    io = threaded.io();
    environ_map = std.process.Environ.createMap(.{ .block = env_block }, gpa) catch std.process.Environ.Map.init(gpa);
    environ = &environ_map;
    const a = std.process.Args{ .vector = vector };
    return a.toSlice(pa) catch &.{};
}

// --- standard output (buffered) and error --------------------------------

/// Blocking calls (reads, waits, sleeps) tell the runtime (rt.zig sets
/// these): collections need not wait for a thread in one
pub var blocking_hooks: struct {
    begin: *const fn () void = &noHook,
    end: *const fn () void = &noHook,
} = .{};
fn noHook() void {}
/// Platform setup at startup
pub fn platformInit() void {
    if (is_windows) w32.init();
}

pub fn blockingBegin() void {
    blocking_hooks.begin();
}
pub fn blockingEnd() void {
    blocking_hooks.end();
}

/// Guards the standard output buffer (threads write to it)
var out_lock: std.Io.Mutex = .init;

pub fn write(bytes: []const u8) void {
    out_lock.lockUncancelable(io);
    defer out_lock.unlock(io);
    if (out_len + bytes.len > out_buf.len) {
        flushLocked();
        if (bytes.len > out_buf.len) {
            std.Io.File.stdout().writeStreamingAll(io, bytes) catch {};
            return;
        }
    }
    @memcpy(out_buf[out_len .. out_len + bytes.len], bytes);
    out_len += bytes.len;
}

pub fn flush() void {
    out_lock.lockUncancelable(io);
    defer out_lock.unlock(io);
    flushLocked();
}

fn flushLocked() void {
    if (out_len > 0) {
        std.Io.File.stdout().writeStreamingAll(io, out_buf[0..out_len]) catch {};
        out_len = 0;
    }
}

pub fn writeStderr(bytes: []const u8) void {
    out_lock.lockUncancelable(io);
    defer out_lock.unlock(io);
    flushLocked();
    std.Io.File.stderr().writeStreamingAll(io, bytes) catch {};
}

pub fn eprint(comptime fmt: []const u8, a: anytype) void {
    flush();
    std.debug.print(fmt, a);
}

/// Read some bytes of standard input; 0 at end of file.
pub fn readStdin(buf: []u8) usize {
    flush();
    blockingBegin();
    defer blockingEnd();
    return std.Io.File.stdin().readStreaming(io, &.{buf}) catch 0;
}

pub fn exit(code: u8) noreturn {
    for (exit_hooks.items) |h| h();
    flush();
    std.process.exit(code);
}

pub fn fatal(comptime fmt: []const u8, a: anytype) noreturn {
    flush();
    std.debug.print("fatal: " ++ fmt ++ "\n", a);
    std.process.exit(70);
}

// --- files ---------------------------------------------------------------

pub const File = std.Io.File;

/// The contents of a file, read to its end (files in /proc report size 0)
pub fn readFile(path: []const u8) ?[]u8 {
    const f = std.Io.Dir.cwd().openFile(io, path, .{}) catch return null;
    defer f.close(io);
    const size = if (f.stat(io)) |st| st.size else |_| 0;
    var list: std.ArrayList(u8) = .empty;
    list.ensureTotalCapacity(pa, @intCast(size + 1)) catch return null;
    while (true) {
        list.ensureUnusedCapacity(pa, 16384) catch return null;
        const n = f.readStreaming(io, &.{list.unusedCapacitySlice()}) catch |e| switch (e) {
            error.EndOfStream => break,
            else => return null,
        };
        if (n == 0) break;
        list.items.len += n;
    }
    return list.items;
}

pub fn createFile(path: []const u8) ?File {
    return std.Io.Dir.cwd().createFile(io, path, .{}) catch null;
}

/// A file opened for appending (created if missing) and its length: the
/// writes go after it (std.Io has no append mode or seek)
pub fn openAppend(path: []const u8) ?struct { file: File, len: u64 } {
    const f = std.Io.Dir.cwd().createFile(io, path, .{ .truncate = false }) catch return null;
    const n = f.length(io) catch 0;
    return .{ .file = f, .len = n };
}

pub fn writeFileAt(f: File, bytes: []const u8, offset: u64) bool {
    f.writePositionalAll(io, bytes, offset) catch return false;
    return true;
}

pub fn writeFile(f: File, bytes: []const u8) bool {
    f.writeStreamingAll(io, bytes) catch return false;
    return true;
}

pub fn closeFile(f: File) void {
    f.close(io);
}

pub fn fileExists(path: []const u8) bool {
    std.Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

pub fn deleteFile(path: []const u8) bool {
    std.Io.Dir.cwd().deleteFile(io, path) catch return false;
    return true;
}

// --- environment and time --------------------------------------------------

pub fn getEnv(name: []const u8) ?[]const u8 {
    const m = environ orelse return null;
    return m.get(name);
}

/// All environment variables as (name, value) pairs
pub fn envPairs() []const [2][]const u8 {
    const m = environ orelse return &.{};
    var list: std.ArrayList([2][]const u8) = .empty;
    var it = m.iterator();
    while (it.next()) |e| list.append(pa, .{ e.key_ptr.*, e.value_ptr.* }) catch break;
    return list.items;
}

/// Microseconds since the Unix epoch, as the JVM implementation's %jiffy
/// ((scheme time)'s current-second is current-jiffy / 10^6)
pub fn jiffy() i64 {
    const ts = std.Io.Clock.real.now(io);
    return @intCast(@divTrunc(ts.nanoseconds, 1000));
}

/// Seconds since the epoch
pub fn realTime() f64 {
    const ts = std.Io.Clock.real.now(io);
    return @as(f64, @floatFromInt(ts.nanoseconds)) / 1e9;
}

// --- file system ---------------------------------------------------------------

pub const EntryKind = enum { file, directory, symlink, other };

pub fn kindOf(path: []const u8, follow: bool) ?EntryKind {
    const st = std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = follow }) catch return null;
    return switch (st.kind) {
        .file => .file,
        .directory => .directory,
        .sym_link => .symlink,
        else => .other,
    };
}

pub fn fileSize(path: []const u8) ?u64 {
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return null;
    return st.size;
}

pub fn currentDirectory() []const u8 {
    return std.process.currentPathAlloc(io, pa) catch ".";
}

pub fn realPath(path: []const u8) ?[]const u8 {
    return std.Io.Dir.cwd().realPathFileAlloc(io, path, pa) catch null;
}

/// The permission bits of path (as chmod takes them), null on Windows or
/// if it does not exist
pub fn fileMode(path: []const u8) ?u32 {
    if (is_windows) return null;
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return null;
    return @intCast(st.permissions.toMode() & 0o7777);
}

/// chmod in the process; false on Windows or failure
pub fn setFileMode(path: []const u8, mode: u32) bool {
    if (is_windows) return false;
    std.Io.Dir.cwd().setFilePermissions(io, path, .fromMode(@intCast(mode)), .{}) catch return false;
    return true;
}

pub fn makeDirectory(path: []const u8) bool {
    std.Io.Dir.cwd().createDirPath(io, path) catch return false;
    return true;
}

pub fn deleteTree(path: []const u8) bool {
    std.Io.Dir.cwd().deleteTree(io, path) catch return false;
    return true;
}

pub const DirEntry = struct { name: []const u8, kind: EntryKind };

/// The entries of a directory (names allocated with the page allocator)
pub fn listDirectory(path: []const u8) ?[]DirEntry {
    var dir = std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return null;
    defer dir.close(io);
    var list: std.ArrayList(DirEntry) = .empty;
    var it = dir.iterate();
    while (it.next(io) catch null) |e| {
        const kind: EntryKind = switch (e.kind) {
            .file => .file,
            .directory => .directory,
            .sym_link => .symlink,
            else => .other,
        };
        list.append(pa, .{ .name = pa.dupe(u8, e.name) catch continue, .kind = kind }) catch break;
    }
    return list.items;
}

// --- clocks --------------------------------------------------------------------------

const builtin = @import("builtin");
pub const is_windows = builtin.os.tag == .windows;
const w32 = @import("os_windows.zig");
const is_macos = builtin.os.tag.isDarwin();
const mac = @import("os_macos.zig");

pub const ClockKind = enum { real, monotonic, process, thread };

/// Nanoseconds of a clock (since the epoch for real)
pub fn clockNs(which: ClockKind) i128 {
    switch (which) {
        .real => return std.Io.Clock.real.now(io).nanoseconds,
        .monotonic => return std.Io.Clock.awake.now(io).nanoseconds,
        .process, .thread => {
            if (is_windows) return std.Io.Clock.awake.now(io).nanoseconds;
            var ts: std.c.timespec = undefined;
            const id: std.c.clockid_t = if (which == .process) .PROCESS_CPUTIME_ID else .THREAD_CPUTIME_ID;
            if (std.c.clock_gettime(id, &ts) != 0) return 0;
            return @as(i128, ts.sec) * 1_000_000_000 + ts.nsec;
        },
    }
}

/// Cryptographically secure random bytes
pub fn randomBytes(buf: []u8) void {
    io.randomSecure(buf) catch io.random(buf);
}

pub fn sleepMs(ms: u64) void {
    blockingBegin();
    defer blockingEnd();
    io.sleep(.fromMilliseconds(@intCast(ms)), .awake) catch {};
}

// --- address space (the young space of rt.zig) ---------------------------------------

const win = struct {
    const MEM_COMMIT = 0x1000;
    const MEM_RESERVE = 0x2000;
    const MEM_DECOMMIT = 0x4000;
    const PAGE_NOACCESS = 0x01;
    const PAGE_READWRITE = 0x04;
    extern "kernel32" fn VirtualAlloc(addr: ?*anyopaque, size: usize, kind: u32, protect: u32) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn VirtualFree(addr: ?*anyopaque, size: usize, kind: u32) callconv(.winapi) i32;
};

/// Reserve n bytes of address space (committed by commit)
pub fn reserveAddressSpace(n: usize) ?[]align(std.heap.page_size_min) u8 {
    if (is_windows) {
        const p = win.VirtualAlloc(null, n, win.MEM_RESERVE, win.PAGE_NOACCESS) orelse return null;
        return @as([*]align(std.heap.page_size_min) u8, @ptrCast(@alignCast(p)))[0..n];
    }
    return std.posix.mmap(null, n, .{ .READ = true, .WRITE = true }, .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .NORESERVE = true }, -1, 0) catch null;
}

/// Make reserved memory usable (pages: page-aligned)
pub fn commit(mem: []align(std.heap.page_size_min) u8) bool {
    if (is_windows) return win.VirtualAlloc(mem.ptr, mem.len, win.MEM_COMMIT, win.PAGE_READWRITE) != null;
    return true; // mapped already, committed when touched
}

/// Give the memory back to the system (the range stays reserved)
pub fn decommit(mem: []align(std.heap.page_size_min) u8) void {
    if (is_windows) {
        _ = win.VirtualFree(mem.ptr, mem.len, win.MEM_DECOMMIT);
        return;
    }
    std.posix.madvise(mem.ptr, mem.len, std.posix.MADV.DONTNEED) catch {};
}

// --- local time zone (TZif files and POSIX TZ rules) ----------------------------------

const Rule = struct {
    std_off: i64, // seconds east of UTC
    dst_off: ?i64 = null,
    start: ?RuleDate = null,
    end: ?RuleDate = null,
};

const RuleDate = struct {
    kind: enum { month, julian1, julian0 },
    month: u8 = 0,
    week: u8 = 0,
    wday: u8 = 0,
    day: u16 = 0,
    time: i64 = 7200, // seconds after local midnight
};

const Zone = struct {
    times: []i64 = &.{},
    idx: []u8 = &.{},
    offs: []i64 = &.{},
    isdst: []bool = &.{},
    rule: ?Rule = null,
};

var zone: ?Zone = null;
var zone_lock: std.Io.Mutex = .init;

fn be32(b: []const u8) i64 {
    return @as(i32, @bitCast(std.mem.readInt(u32, b[0..4], .big)));
}
fn be64(b: []const u8) i64 {
    return @bitCast(std.mem.readInt(u64, b[0..8], .big));
}

fn parseTzif(bytes: []const u8) ?Zone {
    if (bytes.len < 44 or !std.mem.eql(u8, bytes[0..4], "TZif")) return null;
    const version = bytes[4];
    var b = bytes;
    var wide = false;
    if (version >= '2') {
        // skip the version 1 block
        const c = counts(b);
        const v1 = 44 + c[3] * 5 + c[4] * 6 + c[5] + c[2] * 8 + c[1] + c[0];
        if (b.len < v1 + 44) return null;
        b = b[v1..];
        wide = true;
    }
    const c = counts(b);
    const tsize: usize = if (wide) 8 else 4;
    var p: usize = 44;
    const need = p + c[3] * (tsize + 1) + c[4] * 6 + c[5] + c[2] * (tsize + 4) + c[1] + c[0];
    if (b.len < need) return null;
    var z = Zone{};
    z.times = pa.alloc(i64, c[3]) catch return null;
    for (z.times, 0..) |*x, i| x.* = if (wide) be64(b[p + i * 8 ..]) else be32(b[p + i * 4 ..]);
    p += c[3] * tsize;
    z.idx = pa.dupe(u8, b[p .. p + c[3]]) catch return null;
    p += c[3];
    z.offs = pa.alloc(i64, c[4]) catch return null;
    z.isdst = pa.alloc(bool, c[4]) catch return null;
    for (0..c[4]) |i| {
        z.offs[i] = be32(b[p + i * 6 ..]);
        z.isdst[i] = b[p + i * 6 + 4] != 0;
    }
    p = need;
    // the footer: \n<POSIX TZ string>\n
    if (wide and p < b.len and b[p] == '\n') {
        if (std.mem.indexOfScalarPos(u8, b, p + 1, '\n')) |e| z.rule = parseRule(b[p + 1 .. e]);
    }
    return z;
}

fn counts(b: []const u8) [6]usize {
    var c: [6]usize = undefined;
    for (0..6) |i| c[i] = @intCast(std.mem.readInt(u32, b[20 + 4 * i ..][0..4], .big));
    return c;
}

/// "CET-1CEST,M3.5.0,M10.5.0/3" and the like
fn parseRule(s: []const u8) ?Rule {
    var p: usize = 0;
    skipName(s, &p) orelse return null;
    var r = Rule{ .std_off = -(parseOffset(s, &p) orelse return null) };
    if (p >= s.len) return r;
    skipName(s, &p) orelse return r;
    r.dst_off = r.std_off + 3600;
    if (p < s.len and s[p] != ',') r.dst_off = -(parseOffset(s, &p) orelse return r);
    if (p < s.len and s[p] == ',') {
        p += 1;
        r.start = parseRuleDate(s, &p) orelse return null;
        if (p < s.len and s[p] == ',') {
            p += 1;
            r.end = parseRuleDate(s, &p) orelse return null;
        }
    }
    if (r.start == null or r.end == null) r.dst_off = null;
    return r;
}

fn skipName(s: []const u8, p: *usize) ?void {
    if (p.* < s.len and s[p.*] == '<') {
        const e = std.mem.indexOfScalarPos(u8, s, p.*, '>') orelse return null;
        p.* = e + 1;
        return;
    }
    const start = p.*;
    while (p.* < s.len and std.ascii.isAlphabetic(s[p.*])) p.* += 1;
    if (p.* - start < 3) return null;
}

/// [+-]hh[:mm[:ss]] in seconds
fn parseOffset(s: []const u8, p: *usize) ?i64 {
    var sign: i64 = 1;
    if (p.* < s.len and (s[p.*] == '+' or s[p.*] == '-')) {
        if (s[p.*] == '-') sign = -1;
        p.* += 1;
    }
    var total: i64 = 0;
    var mult: i64 = 3600;
    var any = false;
    while (mult >= 1) {
        var v: i64 = 0;
        var digits = false;
        while (p.* < s.len and std.ascii.isDigit(s[p.*])) : (p.* += 1) {
            v = v * 10 + (s[p.*] - '0');
            digits = true;
        }
        if (!digits) break;
        any = true;
        total += v * mult;
        if (p.* < s.len and s[p.*] == ':') {
            p.* += 1;
            mult = @divTrunc(mult, 60);
        } else break;
    }
    return if (any) sign * total else null;
}

fn parseRuleDate(s: []const u8, p: *usize) ?RuleDate {
    var d: RuleDate = undefined;
    if (p.* < s.len and s[p.*] == 'M') {
        p.* += 1;
        var nums: [3]u16 = .{ 0, 0, 0 };
        for (0..3) |i| {
            if (i > 0) {
                if (p.* >= s.len or s[p.*] != '.') return null;
                p.* += 1;
            }
            var any = false;
            while (p.* < s.len and std.ascii.isDigit(s[p.*])) : (p.* += 1) {
                nums[i] = nums[i] * 10 + (s[p.*] - '0');
                any = true;
            }
            if (!any) return null;
        }
        d = .{ .kind = .month, .month = @intCast(nums[0]), .week = @intCast(nums[1]), .wday = @intCast(nums[2]) };
    } else {
        var julian1 = false;
        if (p.* < s.len and s[p.*] == 'J') {
            julian1 = true;
            p.* += 1;
        }
        var n: u16 = 0;
        var any = false;
        while (p.* < s.len and std.ascii.isDigit(s[p.*])) : (p.* += 1) {
            n = n * 10 + (s[p.*] - '0');
            any = true;
        }
        if (!any) return null;
        d = .{ .kind = if (julian1) .julian1 else .julian0, .day = n };
    }
    d.time = 7200;
    if (p.* < s.len and s[p.*] == '/') {
        p.* += 1;
        d.time = parseOffset(s, p) orelse return null;
    }
    return d;
}

/// Days since 1970-01-01 of a proleptic Gregorian date (month may be out of
/// range: it is normalized)
pub fn daysFromCivil(y0: i64, m0: i64, d: i64) i64 {
    const y1 = y0 + @divFloor(m0 - 1, 12);
    const m = @mod(m0 - 1, 12) + 1;
    const y = if (m <= 2) y1 - 1 else y1;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp = if (m > 2) m - 3 else m + 9;
    const doy = @divFloor(153 * mp + 2, 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

pub const Civil = struct { year: i64, month: u8, day: u8 };

pub fn civilFromDays(z0: i64) Civil {
    const z = z0 + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const d = doy - @divFloor(153 * mp + 2, 5) + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;
    return .{ .year = era * 400 + yoe + (if (m <= 2) @as(i64, 1) else 0), .month = @intCast(m), .day = @intCast(d) };
}

fn isLeap(y: i64) bool {
    return @mod(y, 4) == 0 and (@mod(y, 100) != 0 or @mod(y, 400) == 0);
}

/// The local time (seconds since the epoch, without offset) of a rule date
fn ruleLocal(d: RuleDate, year: i64) i64 {
    const days: i64 = switch (d.kind) {
        .month => blk: {
            const first = daysFromCivil(year, d.month, 1);
            const wd1 = @mod(first + 4, 7); // 1970-01-01 was a Thursday
            var day: i64 = 1 + @mod(@as(i64, d.wday) - wd1 + 7, 7) + (@as(i64, d.week) - 1) * 7;
            const mdays = daysFromCivil(year, @as(i64, d.month) + 1, 1) - first;
            while (day > mdays) day -= 7;
            break :blk first + day - 1;
        },
        .julian1 => blk: {
            // 1..365, February 29 never counted
            var n: i64 = d.day;
            if (isLeap(year) and n >= 60) n += 1;
            break :blk daysFromCivil(year, 1, 1) + n - 1;
        },
        .julian0 => daysFromCivil(year, 1, 1) + d.day,
    };
    return days * 86400 + d.time;
}

fn ruleOffset(r: Rule, t: i64) i64 {
    const dst = r.dst_off orelse return r.std_off;
    const year = civilFromDays(@divFloor(t + r.std_off, 86400)).year;
    const start = ruleLocal(r.start.?, year) - r.std_off;
    const end = ruleLocal(r.end.?, year) - dst;
    const in_dst = if (start < end) t >= start and t < end else !(t >= end and t < start);
    return if (in_dst) dst else r.std_off;
}

fn loadZone() Zone {
    var path: []const u8 = "/etc/localtime";
    var path_buf: [512]u8 = undefined;
    if (getEnv("TZ")) |tz0| {
        const tz = if (tz0.len > 0 and tz0[0] == ':') tz0[1..] else tz0;
        if (tz.len > 0 and tz[0] == '/') {
            path = tz;
        } else if (tz.len > 0) {
            path = std.fmt.bufPrint(&path_buf, "/usr/share/zoneinfo/{s}", .{tz}) catch path;
            if (!fileExists(path)) {
                // a POSIX TZ string ("CET-1CEST,M3.5.0,M10.5.0/3", "UTC0")
                if (parseRule(tz)) |r| return .{ .rule = r };
                return .{};
            }
        }
    }
    const bytes = readFile(path) orelse return .{};
    return parseTzif(bytes) orelse .{};
}

/// The local time zone's offset from UTC in seconds at t (seconds since the epoch)
pub fn localOffset(t: i64) i64 {
    if (is_windows) return w32.localOffset(t);
    const z = blk: {
        zone_lock.lockUncancelable(io);
        defer zone_lock.unlock(io);
        if (zone == null) zone = loadZone();
        break :blk zone.?;
    };
    if (z.times.len == 0 or t >= z.times[z.times.len - 1]) {
        if (z.rule) |r| return ruleOffset(r, t);
        if (z.times.len > 0) return z.offs[z.idx[z.times.len - 1]];
        if (z.offs.len > 0) return z.offs[0];
        return 0;
    }
    if (t < z.times[0]) {
        // before the first transition: the first standard time
        for (z.offs, z.isdst) |o, d| if (!d) return o;
        return z.offs[0];
    }
    var a: usize = 0;
    var b: usize = z.times.len;
    while (a + 1 < b) {
        const m = (a + b) / 2;
        if (z.times[m] <= t) a = m else b = m;
    }
    return z.offs[z.idx[a]];
}

// --- more file system -------------------------------------------------------------------

/// Modification time in nanoseconds since the epoch
pub fn modificationTime(path: []const u8) ?i128 {
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return null;
    return st.mtime.nanoseconds;
}

pub fn setModificationTime(path: []const u8, ns: i128) bool {
    if (is_windows) return w32.setModificationTime(path, ns);
    std.Io.Dir.cwd().setTimestamps(io, path, .{ .modify_timestamp = .{ .new = .{ .nanoseconds = @intCast(ns) } } }) catch return false;
    return true;
}

/// Copy a file, replacing dst, keeping the permissions and the
/// modification time (as Java's COPY_ATTRIBUTES)
pub fn copyFile(src: []const u8, dst: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    const mtime = modificationTime(src);
    cwd.copyFile(src, cwd, dst, io, .{}) catch return false;
    if (mtime) |m| _ = setModificationTime(dst, m);
    return true;
}

pub fn rename(src: []const u8, dst: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    cwd.rename(src, cwd, dst, io) catch return false;
    return true;
}

pub fn symlink(target: []const u8, link: []const u8) bool {
    std.Io.Dir.cwd().symLink(io, target, link, .{}) catch return false;
    return true;
}

pub fn readLink(path: []const u8) ?[]const u8 {
    var buf: [4096]u8 = undefined;
    const n = std.Io.Dir.cwd().readLink(io, path, &buf) catch return null;
    return pa.dupe(u8, buf[0..n]) catch null;
}

pub fn setCurrentDirectory(path: []const u8) bool {
    std.process.setCurrentPath(io, path) catch return false;
    return true;
}

/// An exclusive lock on path (created, with its directory), or null if it
/// is held elsewhere
pub fn lockFile(path: []const u8) ?File {
    const cwd = std.Io.Dir.cwd();
    if (std.fs.path.dirname(path)) |dir| cwd.createDirPath(io, dir) catch {};
    const f = cwd.createFile(io, path, .{ .read = true, .truncate = false }) catch return null;
    const ok = f.tryLock(io, .exclusive) catch false;
    if (!ok) {
        f.close(io);
        return null;
    }
    return f;
}

pub fn unlockFile(f: File) void {
    f.unlock(io);
    f.close(io);
}

// --- processes ------------------------------------------------------------------------

pub fn pid() i64 {
    if (is_windows) return w32.pid();
    return std.c.getpid();
}

pub fn parentPid() ?i64 {
    if (is_windows) return w32.parentPid();
    return std.c.getppid();
}

pub const Proc = struct {
    child: std.process.Child,
    done: bool = false,
    code: i64 = 0,
};

pub const Spawn = struct {
    argv: []const []const u8,
    cwd: ?[]const u8 = null,
    env: []const [2][]const u8 = &.{},
    /// inherit our stdin (run-program) or give the child a closed pipe
    inherit_stdin: bool = true,
    /// stdout and stderr to this file (start-program's 'log-file)
    log_file: ?[]const u8 = null,
    capture: bool = false,
};

fn childEnv(extra: []const [2][]const u8) ?*std.process.Environ.Map {
    if (extra.len == 0) return null;
    const m = pa.create(std.process.Environ.Map) catch return null;
    m.* = if (environ) |e| e.clone(pa) catch return null else std.process.Environ.Map.init(pa);
    for (extra) |kv| m.put(kv[0], kv[1]) catch return null;
    return m;
}

pub fn spawn(s: Spawn) ?*Proc {
    var log: ?File = null;
    if (s.log_file) |lf| log = std.Io.Dir.cwd().createFile(io, lf, .{}) catch return null;
    const env_map = childEnv(s.env);
    defer if (env_map) |m| {
        m.deinit();
        pa.destroy(m);
    };
    const child = std.process.spawn(io, .{
        .argv = s.argv,
        .cwd = if (s.cwd) |c| .{ .path = c } else .inherit,
        .environ_map = env_map,
        .stdin = if (s.capture or !s.inherit_stdin) .pipe else .inherit,
        .stdout = if (s.capture) .pipe else if (log) |f| .{ .file = f } else .inherit,
        .stderr = if (s.capture) .pipe else if (log) |f| .{ .file = f } else .inherit,
    }) catch {
        if (log) |f| f.close(io);
        return null;
    };
    if (log) |f| f.close(io);
    const p = pa.create(Proc) catch return null;
    p.* = .{ .child = child };
    if (!s.capture and !s.inherit_stdin) {
        // start-program: a private stdin with nothing to read
        if (p.child.stdin) |f| f.close(io);
        p.child.stdin = null;
    }
    return p;
}

fn decodeStatus(status: c_int) i64 {
    const st: u32 = @bitCast(status);
    if (st & 0x7f == 0) return (st >> 8) & 0xff; // exited
    return 128 + @as(i64, st & 0x7f); // killed by a signal (as Java reports it)
}

/// The exit code if the process has ended (non-blocking)
pub fn procPoll(p: *Proc) ?i64 {
    if (p.done) return p.code;
    if (is_windows) {
        const c = w32.procPoll(p.child.id.?) orelse return null;
        p.done = true;
        p.code = c;
        return c;
    }
    var status: c_int = 0;
    const r = std.c.waitpid(p.child.id.?, &status, 1); // WNOHANG
    if (r == p.child.id.?) {
        p.done = true;
        p.code = decodeStatus(status);
        return p.code;
    }
    if (r < 0) {
        p.done = true;
        return p.code;
    }
    return null;
}

/// Wait for the process (at most timeout_ms); its exit code, or null on timeout
pub fn procWait(p: *Proc, timeout_ms: ?u64) ?i64 {
    if (p.done) return p.code;
    if (is_windows) {
        blockingBegin();
        defer blockingEnd();
        const c = w32.procWait(p.child.id.?, timeout_ms) orelse return null;
        p.done = true;
        p.code = c;
        return c;
    }
    if (timeout_ms == null and !is_windows) {
        var status: c_int = 0;
        blockingBegin();
        defer blockingEnd();
        while (true) {
            const r = std.c.waitpid(p.child.id.?, &status, 0);
            if (r == p.child.id.?) break;
            if (r < 0 and std.c._errno().* != @intFromEnum(std.c.E.INTR)) break;
        }
        p.done = true;
        p.code = decodeStatus(status);
        return p.code;
    }
    var waited: u64 = 0;
    while (true) {
        if (procPoll(p)) |c| return c;
        if (timeout_ms) |tm| if (waited >= tm) return null;
        sleepMs(5);
        waited += 5;
    }
}

/// Free an ended process (its handle on Windows)
pub fn procFree(p: *Proc) void {
    if (is_windows) if (p.child.id) |h| w32.closeHandle(h);
    pa.destroy(p);
}

pub fn procId(p: *Proc) i64 {
    if (is_windows) return if (p.child.id) |h| w32.procId(h) else 0;
    return p.child.id orelse 0;
}

pub const Captured = struct { code: i64, out: []u8, err: []u8 };

/// Run argv with its output captured (stdin from stdin_text, or empty)
pub fn capture(s0: Spawn, stdin_text: ?[]const u8) ?Captured {
    var s = s0;
    s.capture = true;
    const p = spawn(s) orelse return null;
    if (p.child.stdin) |f| {
        if (stdin_text) |text| f.writeStreamingAll(io, text) catch {};
        f.close(io);
        p.child.stdin = null;
    }
    var buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
    var mr: std.Io.File.MultiReader = undefined;
    mr.init(pa, io, buffer.toStreams(), &.{ p.child.stdout.?, p.child.stderr.? });
    defer mr.deinit();
    blockingBegin();
    while (mr.fill(64, .none)) |_| {} else |_| {}
    blockingEnd();
    const out = mr.toOwnedSlice(0) catch return null;
    const err = mr.toOwnedSlice(1) catch return null;
    p.child.stdout.?.close(io);
    p.child.stderr.?.close(io);
    p.child.stdout = null;
    p.child.stderr = null;
    const code = procWait(p, null) orelse 0;
    procFree(p);
    return .{ .code = code, .out = out, .err = err };
}

/// Send SIGTERM (or SIGKILL when forced) to pid; false if it does not exist
pub fn signalProcess(target: i64, force: bool) bool {
    if (is_windows) return w32.terminate(target);
    return std.c.kill(@intCast(target), if (force) .KILL else .TERM) == 0;
}

/// Kill pid and its descendants: children first, then a second, forced
/// sweep after 100 ms (as the JVM implementation's ProcessUtil.destroyTree)
pub fn killTree(root: i64, force: bool) void {
    var tree: std.ArrayList(i64) = .empty;
    defer tree.deinit(pa);
    descendants(root, &tree);
    tree.append(pa, root) catch {};
    for (tree.items) |x| _ = signalProcess(x, force);
    sleepMs(100);
    for (tree.items) |x| _ = signalProcess(x, true);
}

fn descendants(root: i64, out: *std.ArrayList(i64)) void {
    const all = listProcesses();
    defer pa.free(all);
    var frontier: std.ArrayList(i64) = .empty;
    defer frontier.deinit(pa);
    frontier.append(pa, root) catch return;
    while (frontier.pop()) |p| {
        for (all) |c| if (procParent(c)) |pp| if (pp == p) {
            out.append(pa, c) catch return;
            frontier.append(pa, c) catch return;
        };
    }
}

/// The process ids (Linux: /proc)
pub fn listProcesses() []i64 {
    if (is_windows) return w32.listProcesses();
    if (is_macos) return mac.listProcesses();
    var list: std.ArrayList(i64) = .empty;
    const entries = listDirectory("/proc") orelse return list.items;
    for (entries) |e| {
        const n = std.fmt.parseInt(i64, e.name, 10) catch continue;
        list.append(pa, n) catch break;
    }
    return list.toOwnedSlice(pa) catch &.{};
}

fn procStatFields(p: i64) ?[]const u8 {
    var buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "/proc/{d}/stat", .{p}) catch return null;
    const text = readFile(path) orelse return null;
    // after the command name in parentheses (which may contain spaces)
    const close = std.mem.lastIndexOfScalar(u8, text, ')') orelse return null;
    if (close + 2 > text.len) return null;
    return text[close + 2 ..];
}

/// field n (1-based, after the command: 1 is the state) of /proc/p/stat
fn statField(fields: []const u8, n: usize) ?[]const u8 {
    var it = std.mem.tokenizeScalar(u8, fields, ' ');
    var i: usize = 1;
    while (it.next()) |f| : (i += 1) if (i == n) return f;
    return null;
}

pub fn procParent(p: i64) ?i64 {
    if (is_windows) return w32.procParent(p);
    if (is_macos) return mac.procParent(p);
    const fields = procStatFields(p) orelse return null;
    return std.fmt.parseInt(i64, statField(fields, 2) orelse return null, 10) catch null;
}

pub const ProcInfo = struct {
    pid: i64,
    ppid: ?i64,
    command: ?[]const u8, // the executable
    cmdline: ?[]const u8, // the command line, arguments separated by spaces
    user: ?[]const u8,
    start_ms: ?i64,
    cpu_s: ?f64,
};

fn bootTime() ?i64 {
    const text = readFile("/proc/stat") orelse return null;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |l| if (std.mem.startsWith(u8, l, "btime ")) return std.fmt.parseInt(i64, std.mem.trim(u8, l[6..], " "), 10) catch null;
    return null;
}

pub fn procInfo(p: i64) ?ProcInfo {
    if (is_windows) {
        const i = w32.procInfo(p) orelse return null;
        return .{ .pid = p, .ppid = i.ppid, .command = i.path orelse i.exe, .cmdline = null, .user = i.user, .start_ms = i.start_ms, .cpu_s = i.cpu_s };
    }
    if (is_macos) {
        const i = mac.procInfo(p) orelse return null;
        return .{ .pid = p, .ppid = i.ppid, .command = i.path orelse i.name, .cmdline = i.path orelse i.name, .user = i.user, .start_ms = i.start_ms, .cpu_s = i.cpu_s };
    }
    const fields = procStatFields(p) orelse return null;
    var info = ProcInfo{ .pid = p, .ppid = null, .command = null, .cmdline = null, .user = null, .start_ms = null, .cpu_s = null };
    info.ppid = std.fmt.parseInt(i64, statField(fields, 2) orelse "", 10) catch null;
    if (info.ppid) |pp| if (pp == 0) {
        info.ppid = null;
    };
    const hz: f64 = 100; // sysconf(_SC_CLK_TCK) on Linux
    const utime = std.fmt.parseInt(i64, statField(fields, 12) orelse "", 10) catch 0;
    const stime = std.fmt.parseInt(i64, statField(fields, 13) orelse "", 10) catch 0;
    info.cpu_s = @as(f64, @floatFromInt(@divTrunc((utime + stime) * 1000, 100))) / 1000.0;
    if (bootTime()) |bt| if (std.fmt.parseInt(i64, statField(fields, 20) orelse "", 10) catch null) |st| {
        info.start_ms = bt * 1000 + @as(i64, @intFromFloat(@as(f64, @floatFromInt(st)) * 1000.0 / hz));
    };
    var buf: [64]u8 = undefined;
    if (std.fmt.bufPrint(&buf, "/proc/{d}/exe", .{p})) |path| info.command = readLink(path) else |_| {}
    if (std.fmt.bufPrint(&buf, "/proc/{d}/cmdline", .{p})) |path| {
        if (readFile(path)) |cl| if (cl.len > 0) {
            const end = if (cl[cl.len - 1] == 0) cl.len - 1 else cl.len;
            for (cl[0..end]) |*c| if (c.* == 0) {
                c.* = ' ';
            };
            info.cmdline = cl[0..end];
        };
    } else |_| {}
    if (std.fmt.bufPrint(&buf, "/proc/{d}", .{p})) |path| {
        if (std.Io.Dir.cwd().statFile(io, path, .{})) |_| {
            info.user = procUser(path);
        } else |_| {}
    } else |_| {}
    return info;
}

fn procUser(path: []const u8) ?[]const u8 {
    // the owner of /proc/<pid>, from the Uid line of its status file
    var buf: [80]u8 = undefined;
    const sp = std.fmt.bufPrint(&buf, "{s}/status", .{path}) catch return null;
    const text = readFile(sp) orelse return null;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |l| if (std.mem.startsWith(u8, l, "Uid:")) {
        var it = std.mem.tokenizeAny(u8, l[4..], " \t");
        const uid = std.fmt.parseInt(u32, it.next() orelse return null, 10) catch return null;
        return userNameOf(uid);
    };
    return null;
}

fn userNameOf(uid: u32) ?[]const u8 {
    // /etc/passwd (musl's getpwuid reads it the same way)
    const text = readFile("/etc/passwd") orelse return null;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |l| {
        var it = std.mem.splitScalar(u8, l, ':');
        const name = it.next() orelse continue;
        _ = it.next();
        const id = std.fmt.parseInt(u32, it.next() orelse continue, 10) catch continue;
        if (id == uid) return name;
    }
    return null;
}

// --- system information ------------------------------------------------------------------

pub fn hostName() ?[]const u8 {
    if (is_windows) return w32.hostName() orelse getEnv("COMPUTERNAME");
    var buf: [256]u8 = undefined;
    if (std.c.gethostname(&buf, buf.len) != 0) return null;
    const n = std.mem.indexOfScalar(u8, &buf, 0) orelse buf.len;
    return pa.dupe(u8, buf[0..n]) catch null;
}

pub fn osRelease() []const u8 {
    if (is_windows) return w32.osRelease();
    var u: std.c.utsname = undefined;
    if (std.c.uname(&u) != 0) return "";
    const r: []const u8 = std.mem.sliceTo(&u.release, 0);
    return pa.dupe(u8, r) catch "";
}

pub fn userName() []const u8 {
    if (is_macos) if (mac.userName(std.c.getuid())) |n| return n;
    if (!is_windows and !is_macos) if (userNameOf(std.c.getuid())) |n| return n;
    return getEnv("USER") orelse getEnv("USERNAME") orelse "?";
}

pub fn homeDirectory() []const u8 {
    return getEnv("HOME") orelse getEnv("USERPROFILE") orelse ".";
}

pub fn cpuCount() usize {
    return std.Thread.getCpuCount() catch 1;
}

pub fn executablePath() ?[]const u8 {
    return std.process.executablePathAlloc(io, pa) catch null;
}

/// called by exit (process-kill-on-exit, terminal modes)
var exit_hooks: std.ArrayList(*const fn () void) = .empty;

var exit_hooks_lock: std.Io.Mutex = .init;

pub fn atExit(h: *const fn () void) void {
    exit_hooks_lock.lockUncancelable(io);
    defer exit_hooks_lock.unlock(io);
    for (exit_hooks.items) |x| if (x == h) return;
    exit_hooks.append(pa, h) catch {};
}

// --- terminal -------------------------------------------------------------------------

extern "c" fn ioctl(fd: c_int, request: c_ulong, ...) c_int;

pub fn isTerminal(fd: c_int) bool {
    if (is_windows) return w32.isTerminal(fd);
    return std.c.isatty(fd) == 1;
}

/// (columns, rows) of the terminal on standard output (or /dev/tty)
pub fn terminalSize() ?[2]u16 {
    if (is_windows) return w32.terminalSize();
    var ws: std.posix.winsize = undefined;
    for ([_]c_int{ 1, 0, 2 }) |fd| {
        if (ioctl(fd, std.posix.T.IOCGWINSZ, &ws) == 0 and ws.col > 0 and ws.row > 0) return .{ ws.col, ws.row };
    }
    return null;
}

var saved_termios: ?std.posix.termios = null;

fn restoreTermios() void {
    if (saved_termios) |s| _ = std.c.tcsetattr(0, .FLUSH, &s);
}

fn currentTermios() ?std.posix.termios {
    var tio: std.posix.termios = undefined;
    if (std.c.tcgetattr(0, &tio) != 0) return null;
    if (saved_termios == null) {
        saved_termios = tio;
        atExit(&restoreTermios);
    }
    return tio;
}

/// Raw mode (stty raw -echo -isig) or back to the saved settings
pub fn terminalRaw(enable: bool) bool {
    if (is_windows) {
        atExit(&w32.restoreConsole);
        return w32.terminalRaw(enable);
    }
    if (!isTerminal(0)) return false;
    var tio = currentTermios() orelse return false;
    if (!enable) {
        restoreTermios();
        return true;
    }
    tio.iflag.IGNBRK = false;
    tio.iflag.BRKINT = false;
    tio.iflag.IGNPAR = false;
    tio.iflag.PARMRK = false;
    tio.iflag.INPCK = false;
    tio.iflag.ISTRIP = false;
    tio.iflag.INLCR = false;
    tio.iflag.IGNCR = false;
    tio.iflag.ICRNL = false;
    tio.iflag.IXON = false;
    tio.iflag.IXOFF = false;
    tio.oflag.OPOST = false;
    tio.lflag.ICANON = false;
    tio.lflag.ISIG = false;
    tio.lflag.IEXTEN = false;
    tio.lflag.ECHO = false;
    tio.lflag.ECHONL = false;
    tio.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    tio.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    return std.c.tcsetattr(0, .FLUSH, &tio) == 0;
}

pub fn terminalEcho(enable: bool) bool {
    if (is_windows) {
        atExit(&w32.restoreConsole);
        return w32.terminalEcho(enable);
    }
    if (!isTerminal(0)) return false;
    var tio = currentTermios() orelse return false;
    tio.lflag.ECHO = enable;
    return std.c.tcsetattr(0, .FLUSH, &tio) == 0;
}

/// A byte from standard input, or null at the end
pub fn readByte() ?u8 {
    var b: [1]u8 = undefined;
    blockingBegin();
    defer blockingEnd();
    if (is_windows) {
        if (w32.consoleReadByte()) |r| return r else |_| {}
        const n = std.Io.File.stdin().readStreaming(io, &.{&b}) catch return null;
        return if (n == 1) b[0] else null;
    }
    while (true) {
        const n = std.c.read(0, &b, 1);
        if (n == 1) return b[0];
        if (n < 0 and std.c._errno().* == @intFromEnum(std.c.E.INTR)) continue;
        return null;
    }
}

/// Whether a byte can be read from standard input within timeout_ms
pub fn byteReady(timeout_ms: i64) bool {
    if (is_windows) {
        blockingBegin();
        defer blockingEnd();
        return w32.byteReady(timeout_ms);
    }
    var fds = [_]std.c.pollfd{.{ .fd = 0, .events = std.c.POLL.IN, .revents = 0 }};
    blockingBegin();
    defer blockingEnd();
    return std.c.poll(&fds, 1, @intCast(@max(0, timeout_ms))) > 0 and (fds[0].revents & std.c.POLL.IN) != 0;
}

var resizes: std.atomic.Value(i64) = .init(0);
var resize_installed = false;

fn onResize(_: std.posix.SIG) callconv(.c) void {
    _ = resizes.fetchAdd(1, .monotonic);
}

/// The number of SIGWINCH signals so far (installing the handler first)
pub fn resizeCount() ?i64 {
    if (is_windows) return w32.resizeCount();
    if (!resize_installed) {
        const act = std.posix.Sigaction{
            .handler = .{ .handler = &onResize },
            .mask = std.posix.sigemptyset(),
            .flags = std.posix.SA.RESTART,
        };
        std.posix.sigaction(.WINCH, &act, null);
        resize_installed = true;
    }
    return resizes.load(.monotonic);
}

var shutdown_signal: std.atomic.Value(i64) = .init(0);
var shutdown_installed = false;

fn onShutdown(sig: std.posix.SIG) callconv(.c) void {
    shutdown_signal.store(@intFromEnum(sig), .monotonic);
}

/// The SIGINT or SIGTERM received (0 if none so far), installing the
/// handlers first; without SA_RESTART, so that a waiting poll returns
pub fn shutdownSignal() i64 {
    if (is_windows) return w32.shutdownSignal();
    if (!shutdown_installed) {
        const act = std.posix.Sigaction{
            .handler = .{ .handler = &onShutdown },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };
        std.posix.sigaction(.INT, &act, null);
        std.posix.sigaction(.TERM, &act, null);
        shutdown_installed = true;
    }
    return shutdown_signal.load(.monotonic);
}

// --- random-access files ---------------------------------------------------------------

pub const RafMode = enum { read, write, update };

pub fn openRandomAccess(path: []const u8, mode: RafMode) ?File {
    const cwd = std.Io.Dir.cwd();
    return switch (mode) {
        .read => cwd.openFile(io, path, .{}) catch null,
        .write => cwd.createFile(io, path, .{ .read = true, .truncate = true }) catch null,
        .update => cwd.createFile(io, path, .{ .read = true, .truncate = false }) catch null,
    };
}

pub fn readAt(f: File, buf: []u8, offset: u64) ?usize {
    return f.readPositionalAll(io, buf, offset) catch null;
}

pub fn writeAt(f: File, bytes: []const u8, offset: u64) bool {
    f.writePositionalAll(io, bytes, offset) catch return false;
    return true;
}

pub fn fileLength(f: File) ?u64 {
    return f.length(io) catch null;
}

pub fn setFileLength(f: File, n: u64) bool {
    f.setLength(io, n) catch return false;
    return true;
}

pub fn syncFile(f: File) bool {
    f.sync(io) catch return false;
    return true;
}
