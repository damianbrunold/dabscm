//! The operating system layer. All use of version-sensitive `std` APIs
//! (std.Io, std.process, ...) is kept in this file.
const std = @import("std");

var io: std.Io = undefined;
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
    const builtin = @import("builtin");
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

pub fn write(bytes: []const u8) void {
    if (out_len + bytes.len > out_buf.len) {
        flush();
        if (bytes.len > out_buf.len) {
            std.Io.File.stdout().writeStreamingAll(io, bytes) catch {};
            return;
        }
    }
    @memcpy(out_buf[out_len .. out_len + bytes.len], bytes);
    out_len += bytes.len;
}

pub fn flush() void {
    if (out_len > 0) {
        std.Io.File.stdout().writeStreamingAll(io, out_buf[0..out_len]) catch {};
        out_len = 0;
    }
}

pub fn writeStderr(bytes: []const u8) void {
    flush();
    std.Io.File.stderr().writeStreamingAll(io, bytes) catch {};
}

pub fn eprint(comptime fmt: []const u8, a: anytype) void {
    flush();
    std.debug.print(fmt, a);
}

/// Read some bytes of standard input; 0 at end of file.
pub fn readStdin(buf: []u8) usize {
    flush();
    return std.Io.File.stdin().readStreaming(io, &.{buf}) catch 0;
}

pub fn exit(code: u8) noreturn {
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

pub fn readFile(path: []const u8) ?[]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, pa, .unlimited) catch null;
}

pub fn createFile(path: []const u8) ?File {
    return std.Io.Dir.cwd().createFile(io, path, .{}) catch null;
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

/// Microseconds of a monotonic clock
pub fn jiffy() i64 {
    const ts = std.Io.Clock.awake.now(io);
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
