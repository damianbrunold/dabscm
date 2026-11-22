//! Ports. A port object is [hdr T_PORT] [*Port]; the Port lives outside the
//! GC heap. Textual ports read and write UTF-8.
const std = @import("std");
const rt = @import("rt.zig");
const os = @import("os.zig");
const Word = rt.Word;
const Thread = rt.Thread;

const pa = std.heap.c_allocator;

pub const Kind = enum { string_in, bytes_in, file_in, stdin, generator, net_in, string_out, bytes_out, file_out, stdout, stderr, net_out };

/// An endless binary input port's source: fills buf
pub const Generator = *const fn (state: *anyopaque, buf: []u8) void;

pub const Port = struct {
    kind: Kind,
    binary: bool,
    open: bool = true,
    /// input: the bytes read so far (all of them for string and file ports)
    in: std.ArrayList(u8) = .empty,
    pos: usize = 0,
    eof: bool = false,
    /// output
    out: std.ArrayList(u8) = .empty,
    file: ?os.File = null,
    /// output column, for fresh-line
    column: usize = 0,
    /// for port-position: the file name, "{string}" for string ports
    name: []const u8 = "{string}",
    /// generator ports: the source, its state, and the bytes consumed
    /// before the buffer (in)
    gen: ?Generator = null,
    gen_state: ?*anyopaque = null,
    gen_base: u64 = 0,
    /// what the port is for (chacha20-port?, secure-random-port?)
    tag: u8 = 0,
    /// socket ports: the connection
    conn: ?*@import("net.zig").Conn = null,

    /// The number of bytes read from a generator port
    pub fn consumed(p: *const Port) u64 {
        return p.gen_base + p.pos;
    }

    pub fn isInput(p: *const Port) bool {
        return switch (p.kind) {
            .string_in, .bytes_in, .file_in, .stdin, .generator, .net_in => true,
            else => false,
        };
    }

    // --- input -------------------------------------------------------------

    /// Make sure byte pos is available; false at end of input
    fn fill(p: *Port, n: usize) bool {
        if (p.kind == .generator) {
            if (p.pos > 0 and p.pos == p.in.items.len) {
                p.gen_base += p.pos;
                p.in.clearRetainingCapacity();
                p.pos = 0;
            }
            if (p.pos + n > p.in.items.len) {
                const more = @max(64, p.pos + n - p.in.items.len);
                const buf = p.in.addManyAsSlice(pa, more) catch rt.oom();
                p.gen.?(p.gen_state.?, buf);
            }
            return true;
        }
        if (p.kind == .net_in) {
            // a socket: the bytes consumed are dropped
            if (p.pos > 0 and p.pos == p.in.items.len) {
                p.in.clearRetainingCapacity();
                p.pos = 0;
            }
            while (p.pos + n > p.in.items.len) {
                if (p.eof) return false;
                var buf: [8192]u8 = undefined;
                const got = p.conn.?.portRead(&buf);
                if (got == 0) {
                    p.eof = true;
                    return false;
                }
                p.in.appendSlice(pa, buf[0..got]) catch rt.oom();
            }
            return true;
        }
        while (p.pos + n > p.in.items.len) {
            if (p.kind != .stdin or p.eof) return false;
            var buf: [4096]u8 = undefined;
            const got = os.readStdin(&buf);
            if (got == 0) {
                p.eof = true;
                return false;
            }
            p.in.appendSlice(pa, buf[0..got]) catch rt.oom();
        }
        return true;
    }

    pub fn peekByte(p: *Port) ?u8 {
        if (!p.fill(1)) return null;
        return p.in.items[p.pos];
    }

    pub fn readByte(p: *Port) ?u8 {
        const b = p.peekByte() orelse return null;
        p.pos += 1;
        return b;
    }

    /// The next character and its length in bytes
    fn decode(p: *Port) ?struct { cp: u21, len: usize } {
        if (!p.fill(1)) return null;
        const b0 = p.in.items[p.pos];
        const len = std.unicode.utf8ByteSequenceLength(b0) catch 1;
        _ = p.fill(len); // as much of the sequence as there is
        const d = @import("data.zig").utf8Next(p.in.items, p.pos);
        return .{ .cp = d.cp, .len = d.len };
    }

    pub fn peekChar(p: *Port) ?u21 {
        const d = p.decode() orelse return null;
        return d.cp;
    }

    pub fn readChar(p: *Port) ?u21 {
        const d = p.decode() orelse return null;
        p.pos += d.len;
        return d.cp;
    }

    // --- output ------------------------------------------------------------

    pub fn write(p: *Port, bytes: []const u8) void {
        if (bytes.len == 0) return;
        if (std.mem.lastIndexOfScalar(u8, bytes, '\n')) |i| p.column = bytes.len - i - 1 else p.column += bytes.len;
        switch (p.kind) {
            .stdout => os.write(bytes),
            .stderr => os.writeStderr(bytes),
            else => {
                p.out.appendSlice(pa, bytes) catch rt.oom();
                if (p.kind == .file_out and p.out.items.len >= 65536) p.flush();
                if (p.kind == .net_out and p.out.items.len >= 8192) p.flush();
            },
        }
    }

    pub fn flush(p: *Port) void {
        switch (p.kind) {
            .stdout => os.flush(),
            .file_out => if (p.file) |f| {
                _ = os.writeFile(f, p.out.items);
                p.out.clearRetainingCapacity();
            },
            .net_out => if (p.conn) |c| {
                _ = c.writeAll(p.out.items);
                p.out.clearRetainingCapacity();
            },
            else => {},
        }
    }

    pub fn close(p: *Port) void {
        if (!p.open) return;
        p.flush();
        if (p.file) |f| os.closeFile(f);
        p.file = null;
        p.open = false;
    }
};

/// File output ports, flushed at exit
var file_ports: std.ArrayList(*Port) = .empty;

pub fn flushAll() void {
    for (file_ports.items) |p| p.flush();
    stdout_port.flush();
}

var stdin_port: Port = .{ .kind = .stdin, .binary = false };
var stdout_port: Port = .{ .kind = .stdout, .binary = false };
var stderr_port: Port = .{ .kind = .stderr, .binary = false };

pub fn newPort(kind: Kind, binary: bool) *Port {
    const p = pa.create(Port) catch rt.oom();
    p.* = .{ .kind = kind, .binary = binary };
    if (kind == .file_out) file_ports.append(pa, p) catch rt.oom();
    return p;
}

/// The port object for p; reserve 2 words first.
pub fn wrap(t: *Thread, p: *Port) Word {
    const q = t.allocRaw(2);
    q[0] = rt.hdr(rt.T_PORT, 1);
    q[1] = @intFromPtr(p);
    return rt.tagPtr(q);
}

pub fn staticWrap(p: *Port) Word {
    const q = rt.staticAlloc(2, false);
    q[0] = rt.hdr(rt.T_PORT, 1);
    q[1] = @intFromPtr(p);
    return rt.tagPtr(q);
}

pub fn get(w: Word) ?*Port {
    if (!rt.isObj(w, rt.T_PORT)) return null;
    return @ptrFromInt(rt.ptr(w)[1]);
}

var stdin_obj: Word = 0;
var stdout_obj: Word = 0;
var stderr_obj: Word = 0;

pub fn stdinObject() Word {
    if (stdin_obj == 0) stdin_obj = staticWrap(&stdin_port);
    return stdin_obj;
}
pub fn stdoutObject() Word {
    if (stdout_obj == 0) stdout_obj = staticWrap(&stdout_port);
    return stdout_obj;
}
pub fn stderrObject() Word {
    if (stderr_obj == 0) stderr_obj = staticWrap(&stderr_port);
    return stderr_obj;
}

/// The current port: the value of the program's *output-port* (or input,
/// error) global, else the standard one.
pub fn current(t: *Thread, which: rt.Special) *Port {
    if (t.special(which)) |w| if (get(w)) |p| return p;
    return switch (which) {
        .input_port => &stdin_port,
        .error_port => &stderr_port,
        else => &stdout_port,
    };
}
