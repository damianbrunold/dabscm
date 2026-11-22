//! The macOS parts of the OS layer (os.zig calls these where Linux reads
//! /proc): processes through libproc, user names through getpwuid.
const std = @import("std");

const pa = std.heap.c_allocator;

extern "c" fn proc_listallpids(buf: ?*anyopaque, size: c_int) c_int;
extern "c" fn proc_pidinfo(pid: c_int, flavor: c_int, arg: u64, buf: *anyopaque, size: c_int) c_int;
extern "c" fn proc_pidpath(pid: c_int, buf: [*]u8, size: u32) c_int;
extern "c" fn getpwuid(uid: u32) ?*const Passwd;

const Passwd = extern struct {
    name: ?[*:0]const u8,
    passwd: ?[*:0]const u8,
    uid: u32,
    gid: u32,
    // (further fields not used)
};

const PROC_PIDTASKINFO = 4;
const PROC_PIDTBSDINFO = 3;

const BsdInfo = extern struct {
    flags: u32,
    status: u32,
    xstatus: u32,
    pid: u32,
    ppid: u32,
    uid: u32,
    gid: u32,
    ruid: u32,
    rgid: u32,
    svuid: u32,
    svgid: u32,
    rfu: u32,
    comm: [16]u8,
    name: [32]u8,
    nfiles: u32,
    pgid: u32,
    pjobc: u32,
    tdev: u32,
    tpgid: u32,
    nice: i32,
    start_sec: u64,
    start_usec: u64,
};

const TaskInfo = extern struct {
    virtual_size: u64,
    resident_size: u64,
    total_user: u64, // ns
    total_system: u64, // ns
    threads_user: u64,
    threads_system: u64,
    policy: i32,
    faults: i32,
    pageins: i32,
    cow_faults: i32,
    messages_sent: i32,
    messages_received: i32,
    syscalls_mach: i32,
    syscalls_unix: i32,
    csw: i32,
    threadnum: i32,
    numrunning: i32,
    priority: i32,
};

pub fn listProcesses() []i64 {
    const n = proc_listallpids(null, 0);
    if (n <= 0) return &.{};
    const buf = pa.alloc(c_int, @as(usize, @intCast(n)) + 64) catch return &.{};
    defer pa.free(buf);
    const got = proc_listallpids(buf.ptr, @intCast(buf.len * @sizeOf(c_int)));
    if (got <= 0) return &.{};
    const ids = pa.alloc(i64, @intCast(got)) catch return &.{};
    for (buf[0..@intCast(got)], ids) |p, *i| i.* = p;
    return ids;
}

fn bsdInfo(p: i64) ?BsdInfo {
    var info: BsdInfo = undefined;
    if (proc_pidinfo(@intCast(p), PROC_PIDTBSDINFO, 0, &info, @sizeOf(BsdInfo)) != @sizeOf(BsdInfo)) return null;
    return info;
}

pub fn procParent(p: i64) ?i64 {
    const i = bsdInfo(p) orelse return null;
    return if (i.ppid == 0) null else i.ppid;
}

pub const Info = struct { ppid: ?i64, path: ?[]const u8, name: ?[]const u8, user: ?[]const u8, start_ms: ?i64, cpu_s: ?f64 };

pub fn procInfo(p: i64) ?Info {
    const b = bsdInfo(p) orelse return null;
    var info = Info{
        .ppid = if (b.ppid == 0) null else b.ppid,
        .path = null,
        .name = pa.dupe(u8, std.mem.sliceTo(&b.comm, 0)) catch null,
        .user = userName(b.uid),
        .start_ms = @intCast(b.start_sec * 1000 + b.start_usec / 1000),
        .cpu_s = null,
    };
    var t: TaskInfo = undefined;
    if (proc_pidinfo(@intCast(p), PROC_PIDTASKINFO, 0, &t, @sizeOf(TaskInfo)) == @sizeOf(TaskInfo))
        info.cpu_s = @as(f64, @floatFromInt(t.total_user + t.total_system)) / 1e9;
    var buf: [4096]u8 = undefined;
    const n = proc_pidpath(@intCast(p), &buf, buf.len);
    if (n > 0) info.path = pa.dupe(u8, buf[0..@intCast(n)]) catch null;
    return info;
}

pub fn userName(uid: u32) ?[]const u8 {
    const pw = getpwuid(uid) orelse return null;
    const name = pw.name orelse return null;
    return pa.dupe(u8, std.mem.span(name)) catch null;
}
