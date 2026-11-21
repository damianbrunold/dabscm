//! The operating system layer. All use of version-sensitive `std` APIs
//! (std.Io, std.process, ...) is kept in this file.
const std = @import("std");

var io: std.Io = undefined;
var out_buf: [8192]u8 = undefined;
var out_len: usize = 0;

pub fn init(the_io: std.Io) void {
    io = the_io;
}

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

pub fn eprint(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn exit(code: u8) noreturn {
    flush();
    std.process.exit(code);
}

pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    flush();
    std.debug.print("fatal: " ++ fmt ++ "\n", args);
    std.process.exit(70);
}
