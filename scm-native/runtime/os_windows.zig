//! The Windows parts of the OS layer (os.zig calls these where POSIX has
//! its own): processes, the console, Ctrl+C, the local time zone, the OS
//! version. Win32 declarations of our own: Zig 0.17's std has few.
const std = @import("std");
const windows = std.os.windows;

const HANDLE = windows.HANDLE;
const BOOL = i32;
const DWORD = u32;
const WORD = u16;

const pa = std.heap.c_allocator;

const k32 = struct {
    extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) DWORD;
    extern "kernel32" fn GetProcessId(h: HANDLE) callconv(.winapi) DWORD;
    extern "kernel32" fn GetExitCodeProcess(h: HANDLE, code: *DWORD) callconv(.winapi) BOOL;
    extern "kernel32" fn WaitForSingleObject(h: HANDLE, ms: DWORD) callconv(.winapi) DWORD;
    extern "kernel32" fn OpenProcess(access: DWORD, inherit: BOOL, pid: DWORD) callconv(.winapi) ?HANDLE;
    extern "kernel32" fn TerminateProcess(h: HANDLE, code: u32) callconv(.winapi) BOOL;
    extern "kernel32" fn CloseHandle(h: HANDLE) callconv(.winapi) BOOL;
    extern "kernel32" fn CreateToolhelp32Snapshot(flags: DWORD, pid: DWORD) callconv(.winapi) HANDLE;
    extern "kernel32" fn Process32FirstW(snap: HANDLE, e: *ProcessEntry) callconv(.winapi) BOOL;
    extern "kernel32" fn Process32NextW(snap: HANDLE, e: *ProcessEntry) callconv(.winapi) BOOL;
    extern "kernel32" fn GetStdHandle(which: DWORD) callconv(.winapi) ?HANDLE;
    extern "kernel32" fn GetConsoleMode(h: HANDLE, mode: *DWORD) callconv(.winapi) BOOL;
    extern "kernel32" fn SetConsoleMode(h: HANDLE, mode: DWORD) callconv(.winapi) BOOL;
    extern "kernel32" fn GetConsoleScreenBufferInfo(h: HANDLE, info: *ScreenBufferInfo) callconv(.winapi) BOOL;
    extern "kernel32" fn SetConsoleCtrlHandler(handler: ?*const fn (DWORD) callconv(.winapi) BOOL, add: BOOL) callconv(.winapi) BOOL;
    extern "kernel32" fn FileTimeToSystemTime(ft: *const FileTime, st: *SystemTime) callconv(.winapi) BOOL;
    extern "kernel32" fn SystemTimeToFileTime(st: *const SystemTime, ft: *FileTime) callconv(.winapi) BOOL;
    extern "kernel32" fn SystemTimeToTzSpecificLocalTime(tz: ?*const anyopaque, utc: *const SystemTime, local: *SystemTime) callconv(.winapi) BOOL;
    extern "kernel32" fn GetProcessTimes(h: HANDLE, creation: *FileTime, exit: *FileTime, kernel: *FileTime, user: *FileTime) callconv(.winapi) BOOL;
    extern "kernel32" fn QueryFullProcessImageNameW(h: HANDLE, flags: DWORD, name: [*]u16, size: *DWORD) callconv(.winapi) BOOL;
    extern "ntdll" fn RtlGetVersion(info: *OsVersionInfo) callconv(.winapi) i32;
    extern "kernel32" fn SetConsoleOutputCP(cp: u32) callconv(.winapi) BOOL;
    extern "kernel32" fn SetConsoleCP(cp: u32) callconv(.winapi) BOOL;
};

const STILL_ACTIVE = 259;
const WAIT_OBJECT_0 = 0;
const INFINITE = 0xFFFFFFFF;
const PROCESS_TERMINATE = 0x0001;
const PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
const SYNCHRONIZE = 0x00100000;
const TH32CS_SNAPPROCESS = 0x2;
const STD_INPUT_HANDLE: DWORD = @bitCast(@as(i32, -10));
const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));
const STD_ERROR_HANDLE: DWORD = @bitCast(@as(i32, -12));
const ENABLE_PROCESSED_INPUT = 0x0001;
const ENABLE_LINE_INPUT = 0x0002;
const ENABLE_ECHO_INPUT = 0x0004;
const ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200;
const ENABLE_PROCESSED_OUTPUT = 0x0001;
const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

const ProcessEntry = extern struct {
    size: DWORD = @sizeOf(ProcessEntry),
    usage: DWORD = 0,
    pid: DWORD = 0,
    heap_id: usize = 0,
    module_id: DWORD = 0,
    threads: DWORD = 0,
    parent: DWORD = 0,
    priority: i32 = 0,
    flags: DWORD = 0,
    exe: [260]u16 = @splat(0),
};

const Coord = extern struct { x: i16, y: i16 };
const SmallRect = extern struct { left: i16, top: i16, right: i16, bottom: i16 };
const ScreenBufferInfo = extern struct {
    size: Coord,
    cursor: Coord,
    attributes: WORD,
    window: SmallRect,
    max_size: Coord,
};

const FileTime = extern struct { low: DWORD, high: DWORD };
const SystemTime = extern struct {
    year: WORD,
    month: WORD,
    day_of_week: WORD,
    day: WORD,
    hour: WORD,
    minute: WORD,
    second: WORD,
    ms: WORD,
};

const OsVersionInfo = extern struct {
    size: DWORD = @sizeOf(OsVersionInfo),
    major: DWORD = 0,
    minor: DWORD = 0,
    build: DWORD = 0,
    platform: DWORD = 0,
    csd: [128]u16 = @splat(0),
};

/// At startup: the console reads and writes UTF-8, as the ports do
pub fn init() void {
    _ = k32.SetConsoleOutputCP(65001);
    _ = k32.SetConsoleCP(65001);
}

// --- processes -------------------------------------------------------------------

pub fn pid() i64 {
    return k32.GetCurrentProcessId();
}

pub fn parentPid() ?i64 {
    return procParent(pid());
}

/// The exit code if the process (its handle) has ended, else null
pub fn procPoll(h: HANDLE) ?i64 {
    var code: DWORD = 0;
    if (k32.GetExitCodeProcess(h, &code) == 0) return 0;
    if (code == STILL_ACTIVE and k32.WaitForSingleObject(h, 0) != WAIT_OBJECT_0) return null;
    return code;
}

/// Wait for the process (at most timeout_ms); its exit code, or null
pub fn procWait(h: HANDLE, timeout_ms: ?u64) ?i64 {
    const ms: DWORD = if (timeout_ms) |t| @intCast(@min(t, INFINITE - 1)) else INFINITE;
    if (k32.WaitForSingleObject(h, ms) != WAIT_OBJECT_0) return null;
    var code: DWORD = 0;
    _ = k32.GetExitCodeProcess(h, &code);
    return code;
}

pub fn procId(h: HANDLE) i64 {
    return k32.GetProcessId(h);
}

/// End the process (Windows has no polite request: TerminateProcess, as the
/// JVM's Process.destroy there)
pub fn terminate(target: i64) bool {
    const h = k32.OpenProcess(PROCESS_TERMINATE, 0, @intCast(target)) orelse return false;
    defer _ = k32.CloseHandle(h);
    return k32.TerminateProcess(h, 1) != 0;
}

const Entry = struct { pid: i64, parent: i64, exe: []const u8 };

fn snapshot() []Entry {
    var list: std.ArrayList(Entry) = .empty;
    const snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == windows.INVALID_HANDLE_VALUE) return list.items;
    defer _ = k32.CloseHandle(snap);
    var e = ProcessEntry{};
    var ok = k32.Process32FirstW(snap, &e);
    while (ok != 0) : (ok = k32.Process32NextW(snap, &e)) {
        const name = std.mem.sliceTo(&e.exe, 0);
        const exe = std.unicode.utf16LeToUtf8Alloc(pa, name) catch "";
        list.append(pa, .{ .pid = e.pid, .parent = e.parent, .exe = exe }) catch break;
        e = ProcessEntry{};
    }
    return list.toOwnedSlice(pa) catch &.{};
}

pub fn listProcesses() []i64 {
    const all = snapshot();
    defer pa.free(all);
    const ids = pa.alloc(i64, all.len) catch return &.{};
    for (all, ids) |e, *i| i.* = e.pid;
    return ids;
}

pub fn procParent(p: i64) ?i64 {
    const all = snapshot();
    defer pa.free(all);
    for (all) |e| if (e.pid == p) return if (e.parent == 0) null else e.parent;
    return null;
}

pub const Info = struct { ppid: ?i64, exe: ?[]const u8, path: ?[]const u8, start_ms: ?i64, cpu_s: ?f64 };

fn fileTimeTicks(ft: FileTime) i64 {
    return @intCast((@as(u64, ft.high) << 32) | ft.low);
}

/// 100 ns ticks since 1601 to ms since 1970
fn ticksToUnixMs(ticks: i64) i64 {
    return @divTrunc(ticks - 116444736000000000, 10000);
}

pub fn procInfo(p: i64) ?Info {
    const all = snapshot();
    defer pa.free(all);
    var info: ?Info = null;
    for (all) |e| if (e.pid == p) {
        info = .{ .ppid = if (e.parent == 0) null else e.parent, .exe = e.exe, .path = null, .start_ms = null, .cpu_s = null };
    };
    var i = info orelse return null;
    if (k32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, @intCast(p))) |h| {
        defer _ = k32.CloseHandle(h);
        var c: FileTime = undefined;
        var x: FileTime = undefined;
        var kt: FileTime = undefined;
        var ut: FileTime = undefined;
        if (k32.GetProcessTimes(h, &c, &x, &kt, &ut) != 0) {
            i.start_ms = ticksToUnixMs(fileTimeTicks(c));
            i.cpu_s = @as(f64, @floatFromInt(fileTimeTicks(kt) + fileTimeTicks(ut))) / 1e7;
        }
        var buf: [1024]u16 = undefined;
        var n: DWORD = buf.len;
        if (k32.QueryFullProcessImageNameW(h, 0, &buf, &n) != 0)
            i.path = std.unicode.utf16LeToUtf8Alloc(pa, buf[0..n]) catch null;
    }
    return i;
}

// --- the console ---------------------------------------------------------------------

fn stdHandle(which: DWORD) ?HANDLE {
    const h = k32.GetStdHandle(which) orelse return null;
    if (h == windows.INVALID_HANDLE_VALUE) return null;
    return h;
}

/// fd 0, 1, 2: whether it is a console
pub fn isTerminal(fd: c_int) bool {
    const h = stdHandle(switch (fd) {
        0 => STD_INPUT_HANDLE,
        1 => STD_OUTPUT_HANDLE,
        else => STD_ERROR_HANDLE,
    }) orelse return false;
    var mode: DWORD = 0;
    return k32.GetConsoleMode(h, &mode) != 0;
}

pub fn terminalSize() ?[2]u16 {
    for ([_]DWORD{ STD_OUTPUT_HANDLE, STD_ERROR_HANDLE }) |which| {
        const h = stdHandle(which) orelse continue;
        var info: ScreenBufferInfo = undefined;
        if (k32.GetConsoleScreenBufferInfo(h, &info) == 0) continue;
        const cols = info.window.right - info.window.left + 1;
        const rows = info.window.bottom - info.window.top + 1;
        if (cols > 0 and rows > 0) return .{ @intCast(cols), @intCast(rows) };
    }
    return null;
}

var saved_in_mode: ?DWORD = null;
var saved_out_mode: ?DWORD = null;

pub fn restoreConsole() void {
    if (saved_in_mode) |m| if (stdHandle(STD_INPUT_HANDLE)) |h| {
        _ = k32.SetConsoleMode(h, m);
    };
    if (saved_out_mode) |m| if (stdHandle(STD_OUTPUT_HANDLE)) |h| {
        _ = k32.SetConsoleMode(h, m);
    };
}

fn inputMode() ?struct { h: HANDLE, mode: DWORD } {
    const h = stdHandle(STD_INPUT_HANDLE) orelse return null;
    var mode: DWORD = 0;
    if (k32.GetConsoleMode(h, &mode) == 0) return null;
    if (saved_in_mode == null) {
        saved_in_mode = mode;
        if (stdHandle(STD_OUTPUT_HANDLE)) |o| {
            var om: DWORD = 0;
            if (k32.GetConsoleMode(o, &om) != 0) saved_out_mode = om;
        }
    }
    return .{ .h = h, .mode = mode };
}

/// Raw mode: no line editing, echo or Ctrl+C processing, with VT key
/// sequences in and VT output (as the terminal escapes on POSIX), or back
pub fn terminalRaw(enable: bool) bool {
    const in = inputMode() orelse return false;
    if (!enable) {
        restoreConsole();
        return true;
    }
    const mode = (in.mode & ~@as(DWORD, ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT)) | ENABLE_VIRTUAL_TERMINAL_INPUT;
    if (k32.SetConsoleMode(in.h, mode) == 0) return false;
    if (stdHandle(STD_OUTPUT_HANDLE)) |o| {
        var om: DWORD = 0;
        if (k32.GetConsoleMode(o, &om) != 0) _ = k32.SetConsoleMode(o, om | ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
    }
    return true;
}

pub fn terminalEcho(enable: bool) bool {
    const in = inputMode() orelse return false;
    const mode = if (enable) in.mode | ENABLE_ECHO_INPUT else in.mode & ~@as(DWORD, ENABLE_ECHO_INPUT);
    return k32.SetConsoleMode(in.h, mode) != 0;
}

/// Whether input can be read within timeout_ms (the console handle is
/// signaled while it has input events)
pub fn byteReady(timeout_ms: i64) bool {
    const h = stdHandle(STD_INPUT_HANDLE) orelse return false;
    return k32.WaitForSingleObject(h, @intCast(@max(0, @min(timeout_ms, INFINITE - 1)))) == WAIT_OBJECT_0;
}

var last_size: ?[2]u16 = null;
var resizes: i64 = 0;

/// The number of window size changes seen so far (Windows has no signal:
/// compared on each call)
pub fn resizeCount() ?i64 {
    const now = terminalSize();
    if (last_size) |l| if (now) |n| if (l[0] != n[0] or l[1] != n[1]) {
        resizes += 1;
    };
    last_size = now;
    return resizes;
}

// --- Ctrl+C and closing -----------------------------------------------------------------

var shutdown_signal: std.atomic.Value(i64) = .init(0);
var shutdown_installed = false;

fn onCtrl(kind: DWORD) callconv(.winapi) BOOL {
    // Ctrl+C and Ctrl+Break as SIGINT, closing and shutdown as SIGTERM
    shutdown_signal.store(if (kind <= 1) 2 else 15, .monotonic);
    return 1;
}

pub fn shutdownSignal() i64 {
    if (!shutdown_installed) {
        _ = k32.SetConsoleCtrlHandler(&onCtrl, 1);
        shutdown_installed = true;
    }
    return shutdown_signal.load(.monotonic);
}

// --- time and version ------------------------------------------------------------------

/// The local offset from UTC (seconds) at t (seconds since the epoch), with
/// the daylight saving time in force then
pub fn localOffset(t: i64) i64 {
    const ticks: u64 = @intCast(@max(0, t * 10_000_000 + 116444736000000000));
    const ft = FileTime{ .low = @truncate(ticks), .high = @intCast(ticks >> 32) };
    var utc: SystemTime = undefined;
    var local: SystemTime = undefined;
    if (k32.FileTimeToSystemTime(&ft, &utc) == 0) return 0;
    if (k32.SystemTimeToTzSpecificLocalTime(null, &utc, &local) == 0) return 0;
    var lft: FileTime = undefined;
    if (k32.SystemTimeToFileTime(&local, &lft) == 0) return 0;
    return @divTrunc(fileTimeTicks(lft) - @as(i64, @intCast(ticks)), 10_000_000);
}

pub fn osRelease() []const u8 {
    var v = OsVersionInfo{};
    if (k32.RtlGetVersion(&v) != 0) return "";
    return std.fmt.allocPrint(pa, "{d}.{d}", .{ v.major, v.minor }) catch "";
}
