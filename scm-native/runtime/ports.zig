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
    /// guards output (threads may write to one port)
    lock: std.Io.Mutex = .init,
    /// text file output: the encoding the buffered UTF-8 is written in, a
    /// DEFLATE stream (written when the port is closed, or at exit), and
    /// for appending the offset of the next write
    enc: Encoding = .utf8,
    deflate: bool = false,
    offset: ?u64 = null,
    /// UTF-16 output: the byte order mark is written
    started: bool = false,
    /// the collection epoch in which a major collection last reached the
    /// port object (see sweep); pinned: a native structure uses the port
    /// (a zip entry being written), so it stays
    seen: u32 = 0,
    pinned: bool = false,
    /// made since the last collection: its port object is in a nursery,
    /// which every collection copies whole, so a minor one can free it too
    young: bool = true,

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
        p.lock.lockUncancelable(os.io);
        defer p.lock.unlock(os.io);
        if (std.mem.lastIndexOfScalar(u8, bytes, '\n')) |i| p.column = bytes.len - i - 1 else p.column += bytes.len;
        switch (p.kind) {
            .stdout => os.write(bytes),
            .stderr => os.writeStderr(bytes),
            else => {
                p.out.appendSlice(pa, bytes) catch rt.oom();
                if (p.kind == .file_out and p.out.items.len >= 65536) p.flushLocked();
                if (p.kind == .net_out and p.out.items.len >= 8192) p.flushLocked();
            },
        }
    }

    pub fn flush(p: *Port) void {
        p.lock.lockUncancelable(os.io);
        defer p.lock.unlock(os.io);
        p.flushLocked();
    }

    fn flushLocked(p: *Port) void {
        switch (p.kind) {
            .stdout => os.flush(),
            .file_out => if (p.file != null and !p.deflate) {
                p.writeEncoded(p.out.items);
                p.out.clearRetainingCapacity();
            },
            .net_out => if (p.conn) |c| {
                _ = c.writeAll(p.out.items);
                p.out.clearRetainingCapacity();
            },
            else => {},
        }
    }

    /// The buffered UTF-8 text in the port's encoding, to its file
    fn writeEncoded(p: *Port, utf8: []const u8) void {
        if (p.enc == .utf8) return p.writeRaw(utf8);
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(pa);
        if (p.enc == .utf16 and !p.started) buf.appendSlice(pa, &.{ 0xfe, 0xff }) catch rt.oom();
        p.started = true;
        encode(&buf, utf8, p.enc);
        p.writeRaw(buf.items);
    }

    fn writeRaw(p: *Port, bytes: []const u8) void {
        const f = p.file orelse return;
        if (p.offset) |o| {
            _ = os.writeFileAt(f, bytes, o);
            p.offset = o + bytes.len;
        } else _ = os.writeFile(f, bytes);
    }

    /// A DEFLATE port: its text, encoded and compressed (as Java's
    /// DeflaterOutputStream with a raw Deflater), once
    fn finishDeflate(p: *Port) void {
        if (!p.deflate or p.file == null) return;
        p.deflate = false;
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(pa);
        if (p.enc == .utf8) buf.appendSlice(pa, p.out.items) catch rt.oom() else {
            if (p.enc == .utf16) buf.appendSlice(pa, &.{ 0xfe, 0xff }) catch rt.oom();
            encode(&buf, p.out.items, p.enc);
        }
        p.out.clearRetainingCapacity();
        const z = @import("compress.zig").compress(buf.items, .raw, -1) catch rt.oom();
        defer if (z.len > 0) pa.free(z);
        p.writeRaw(z);
    }

    pub fn close(p: *Port) void {
        if (!p.open) return;
        if (p.deflate) {
            p.lock.lockUncancelable(os.io);
            p.finishDeflate();
            p.lock.unlock(os.io);
        }
        p.flush();
        if (p.file) |f| os.closeFile(f);
        p.file = null;
        p.open = false;
        // the buffers: a file input port holds the whole (inflated) file;
        // the port object itself stays (it is not collected), so without
        // this every file read kept its contents. A string output port
        // keeps its text (get-output-string)
        if (p.isInput() and p.kind != .stdin) {
            p.in.clearAndFree(pa);
            p.pos = 0;
            p.eof = true;
        }
        if (p.kind == .file_out or p.kind == .net_out) p.out.clearAndFree(pa);
    }
};

// --- encodings of text files ---------------------------------------------

pub const Encoding = enum { utf8, latin1, utf16, utf16be, utf16le };

/// An encoding name as the JVM implementation's (Encoding.java), with
/// whether it asks for a UTF-8 byte order mark
pub fn parseEncoding(name: []const u8) ?struct { enc: Encoding, bom: bool } {
    var low: [16]u8 = undefined;
    if (name.len > low.len) return null;
    const n = std.ascii.lowerString(&low, name);
    const eq = struct {
        fn f(a: []const u8, names: []const []const u8) bool {
            for (names) |x| if (std.mem.eql(u8, a, x)) return true;
            return false;
        }
    }.f;
    if (eq(n, &.{ "utf8", "utf-8" })) return .{ .enc = .utf8, .bom = false };
    if (eq(n, &.{ "utf8bom", "utf-8-bom" })) return .{ .enc = .utf8, .bom = true };
    if (eq(n, &.{ "latin-1", "iso-8859-1", "iso88591" })) return .{ .enc = .latin1, .bom = false };
    if (eq(n, &.{ "utf-16", "utf16" })) return .{ .enc = .utf16, .bom = false };
    if (eq(n, &.{ "utf-16-be", "utf-16be", "utf16-be", "utf16be" })) return .{ .enc = .utf16be, .bom = false };
    if (eq(n, &.{ "utf-16-le", "utf-16le", "utf16-le", "utf16le" })) return .{ .enc = .utf16le, .bom = false };
    return null;
}

/// UTF-8 text in enc (not utf8): Latin-1 writes ? for a character above
/// U+00FF, as Java's encoder; UTF-16 big endian unless utf16le
fn encode(out: *std.ArrayList(u8), utf8: []const u8, enc: Encoding) void {
    const data = @import("data.zig");
    var i: usize = 0;
    while (i < utf8.len) {
        const d = data.utf8Next(utf8, i);
        i += d.len;
        const cp: u32 = d.cp;
        switch (enc) {
            .latin1 => out.append(pa, if (cp <= 0xff) @intCast(cp) else '?') catch rt.oom(),
            else => {
                const le = enc == .utf16le;
                if (cp >= 0x10000) {
                    const v = cp - 0x10000;
                    unit(out, @intCast(0xd800 + (v >> 10)), le);
                    unit(out, @intCast(0xdc00 + (v & 0x3ff)), le);
                } else unit(out, @intCast(cp), le);
            },
        }
    }
}

fn unit(out: *std.ArrayList(u8), u: u16, le: bool) void {
    const b = if (le) [2]u8{ @truncate(u), @truncate(u >> 8) } else [2]u8{ @truncate(u >> 8), @truncate(u) };
    out.appendSlice(pa, &b) catch rt.oom();
}

/// The bytes of a text file in enc as UTF-8 (owned by pa): Latin-1 bytes
/// as characters, UTF-16 with its byte order mark (else big endian) for
/// utf16, unpaired surrogates as U+FFFD; utf8 without a byte order mark
/// when strip_bom (as Java's reader of a file that is not deflated)
pub fn decodeText(bytes: []u8, enc: Encoding, strip_bom: bool) []u8 {
    switch (enc) {
        .utf8 => {
            if (strip_bom and bytes.len >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf) {
                const rest = pa.dupe(u8, bytes[3..]) catch rt.oom();
                pa.free(bytes);
                return rest;
            }
            return bytes;
        },
        .latin1 => {
            var out: std.ArrayList(u8) = .empty;
            out.ensureTotalCapacity(pa, bytes.len) catch rt.oom();
            for (bytes) |b| appendCp(&out, b);
            pa.free(bytes);
            return out.toOwnedSlice(pa) catch rt.oom();
        },
        else => {
            var le = enc == .utf16le;
            var i: usize = 0;
            if (enc == .utf16 and bytes.len >= 2) {
                if (bytes[0] == 0xfe and bytes[1] == 0xff) {
                    i = 2;
                } else if (bytes[0] == 0xff and bytes[1] == 0xfe) {
                    i = 2;
                    le = true;
                }
            }
            var out: std.ArrayList(u8) = .empty;
            while (i + 1 < bytes.len) : (i += 2) {
                const u: u32 = if (le) @as(u32, bytes[i]) | (@as(u32, bytes[i + 1]) << 8) else (@as(u32, bytes[i]) << 8) | bytes[i + 1];
                if (u >= 0xd800 and u < 0xdc00 and i + 3 < bytes.len) {
                    const v: u32 = if (le) @as(u32, bytes[i + 2]) | (@as(u32, bytes[i + 3]) << 8) else (@as(u32, bytes[i + 2]) << 8) | bytes[i + 3];
                    if (v >= 0xdc00 and v < 0xe000) {
                        appendCp(&out, 0x10000 + ((u - 0xd800) << 10) + (v - 0xdc00));
                        i += 2;
                        continue;
                    }
                }
                appendCp(&out, if (u >= 0xd800 and u < 0xe000) 0xfffd else u);
            }
            if (i < bytes.len) appendCp(&out, 0xfffd); // an odd last byte
            pa.free(bytes);
            return out.toOwnedSlice(pa) catch rt.oom();
        },
    }
}

fn appendCp(out: *std.ArrayList(u8), cp: u32) void {
    var b: [4]u8 = undefined;
    const n = std.unicode.utf8Encode(@intCast(cp), &b) catch 0;
    out.appendSlice(pa, b[0..n]) catch rt.oom();
}

/// File output ports, flushed at exit
var file_ports: std.ArrayList(*Port) = .empty;
var file_ports_lock: std.Io.Mutex = .init;

pub fn flushAll() void {
    file_ports_lock.lockUncancelable(os.io);
    defer file_ports_lock.unlock(os.io);
    // only at exit: DEFLATE ports are finished
    for (file_ports.items) |p| {
        if (p.deflate) {
            p.lock.lockUncancelable(os.io);
            p.finishDeflate();
            p.lock.unlock(os.io);
        }
        p.flush();
    }
    stdout_port.flush();
}

var stdin_port: Port = .{ .kind = .stdin, .binary = false };
var stdout_port: Port = .{ .kind = .stdout, .binary = false };
var stderr_port: Port = .{ .kind = .stderr, .binary = false };

/// Every port made by newPort (for the statistics and the collector)
var all_ports: std.ArrayList(*Port) = .empty;
var all_ports_lock: std.Io.Mutex = .init;

/// The current collection epoch: a major collection marks every port
/// object it reaches with it (rt.zig, scanObject), then sweep frees the
/// others. Ports are native memory the copying collector does not see; a
/// program that makes string ports in a loop (a server) otherwise kept
/// every one with its buffer.
pub var epoch: u32 = 1;

pub fn markSeen(p: *Port) void {
    p.seen = epoch;
}

/// After a collection (every thread stopped): the ports no object refers
/// to any more are freed, after a minor collection only those made since
/// the last one; a file output port is flushed and closed first, as at
/// exit.
pub fn sweep(major: bool) void {
    all_ports_lock.lockUncancelable(os.io);
    defer all_ports_lock.unlock(os.io);
    var kept: usize = 0;
    for (all_ports.items) |p| {
        if (p.seen == epoch or p.pinned or !(major or p.young)) {
            p.young = false;
            all_ports.items[kept] = p;
            kept += 1;
            continue;
        }
        p.close();
        if (p.kind == .file_out) {
            file_ports_lock.lockUncancelable(os.io);
            defer file_ports_lock.unlock(os.io);
            for (file_ports.items, 0..) |q, i| if (q == p) {
                _ = file_ports.swapRemove(i);
                break;
            };
        }
        p.in.deinit(pa);
        p.out.deinit(pa);
        pa.destroy(p);
    }
    all_ports.items.len = kept;
    epoch +%= 1;
    if (epoch == 0) epoch = 1;
}

/// The number of ports and the bytes their buffers hold (allocated)
pub fn stats() struct { count: usize, bytes: usize } {
    all_ports_lock.lockUncancelable(os.io);
    defer all_ports_lock.unlock(os.io);
    var b: usize = 0;
    for (all_ports.items) |p| b += p.in.capacity + p.out.capacity;
    return .{ .count = all_ports.items.len, .bytes = b };
}

pub fn newPort(kind: Kind, binary: bool) *Port {
    const p = pa.create(Port) catch rt.oom();
    p.* = .{ .kind = kind, .binary = binary };
    {
        all_ports_lock.lockUncancelable(os.io);
        defer all_ports_lock.unlock(os.io);
        all_ports.append(pa, p) catch rt.oom();
    }
    if (kind == .file_out) {
        file_ports_lock.lockUncancelable(os.io);
        defer file_ports_lock.unlock(os.io);
        file_ports.append(pa, p) catch rt.oom();
    }
    return p;
}

/// The port object for p; reserve 2 words first.
pub fn wrap(t: *Thread, p: *Port) Word {
    const q = t.allocRaw(2);
    q[0] = rt.hdr(rt.T_PORT, 1);
    q[1] = @intFromPtr(p);
    return rt.tagPtr(q);
}

/// A static port object (never collected): its port is pinned, as the
/// collector does not scan static objects (see sweep)
pub fn staticWrap(p: *Port) Word {
    p.pinned = true;
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
