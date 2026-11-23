//! (scm net sockets): TCP sockets and listeners, TLS (net.zig), as the
//! JVM implementation's primitives (their messages included).
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const ports = @import("ports.zig");
const net = @import("net.zig");
const tds = @import("tds.zig");
const sys = @import("prims_sys.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const arg = P.arg;
const raise = P.raise;

const pa = std.heap.c_allocator;

/// A socket: its connection and its ports (static objects, made on demand;
/// a new set after STARTTLS, as on the JVM)
/// A socket; its heap object has four slots for its ports (in, out,
/// binary in, binary out), made at their first use
pub const Socket = struct {
    conn: *net.Conn,
};

const port_slots = 4;

/// A socket the collector found unreachable: its connection is released
/// (closed and freed when its ports are gone too)
pub fn freeSocket(p: *anyopaque) void {
    const s: *Socket = @ptrCast(@alignCast(p));
    s.conn.release();
    pa.destroy(s);
}

fn msg(comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(pa, fmt, args) catch rt.oom();
}

pub fn newSocket(t: *Thread, conn: *net.Conn) Word {
    const s = pa.create(Socket) catch rt.oom();
    s.* = .{ .conn = conn };
    t.reserve(3 + port_slots);
    return sys.allocNativeSlots(t, .socket, s, null, port_slots);
}

pub fn socketArg(t: *Thread, i: usize) Err!*Socket {
    const p = sys.nativeOf(arg(t, i), .socket) orelse return P.argTypeError(t);
    return @ptrCast(@alignCast(p));
}

fn portArg(t: *Thread, i: usize) Err!u16 {
    const w = arg(t, i);
    if (!rt.isFix(w) or rt.unfix(w) < 0 or rt.unfix(w) > 65535) return P.argTypeError(t);
    return @intCast(rt.unfix(w));
}

fn tcpConnect(t: *Thread) Err!Word {
    const host = data.toUtf8(try P.stringArg(t, 0));
    const port = try portArg(t, 1);
    const c = net.connect(host, port) orelse return raise(t, msg("tcp-connect: {s}", .{net.last_error}), &.{});
    return newSocket(t, c);
}
pub const @"%tcp-connect" = WN("tcp-connect", tcpConnect, 2, 2);

fn verifyArg(t: *Thread, i: usize) bool {
    return !(t.argc > i and arg(t, i) == rt.FALSE);
}

fn tlsConnect(t: *Thread) Err!Word {
    const host = data.toUtf8(try P.stringArg(t, 0));
    const port = try portArg(t, 1);
    const c = net.connect(host, port) orelse return raise(t, msg("tls-connect: {s}", .{net.last_error}), &.{});
    if (!net.startTls(c, host, verifyArg(t, 2))) {
        c.close();
        c.release();
        return raise(t, msg("tls-connect: {s}", .{net.last_error}), &.{});
    }
    return newSocket(t, c);
}
pub const @"%tls-connect" = WN("tls-connect", tlsConnect, 2, 3);

fn startTls(t: *Thread) Err!Word {
    const s = try socketArg(t, 0);
    const host = data.toUtf8(try P.stringArg(t, 1));
    if (!net.startTls(s.conn, host, verifyArg(t, 2))) return raise(t, msg("socket-starttls!: {s}", .{net.last_error}), &.{});
    // new ports at their next use, over TLS
    for (rt.ptr(arg(t, 0))[3 .. 3 + port_slots]) |*w| w.* = rt.FALSE;
    return arg(t, 0);
}
pub const @"%socket-starttls!" = WN("socket-starttls!", startTls, 2, 3);

fn tdsConnect(t: *Thread) Err!Word {
    const host = data.toUtf8(try P.stringArg(t, 0));
    const pw = arg(t, 1);
    const port_spec = if (rt.isFix(pw))
        tds.PortSpec{ .port = try portArg(t, 1) }
    else
        tds.PortSpec{ .instance = data.toUtf8(try P.stringArg(t, 1)) };
    const encrypt = !(t.argc > 2 and arg(t, 2) == rt.FALSE);
    const verify = t.argc > 3 and arg(t, 3) != rt.FALSE;
    const cert_host = if (t.argc > 4 and arg(t, 4) != rt.FALSE) data.toUtf8(try P.stringArg(t, 4)) else host;
    const c = tds.connect(host, port_spec, encrypt, verify, cert_host) orelse return raise(t, tds.last_error, &.{});
    return newSocket(t, c);
}
pub const @"%tds-connect" = WN("tds-connect", tdsConnect, 2, 5);

fn sqlBrowserPort(t: *Thread) Err!Word {
    const host = data.toUtf8(try P.stringArg(t, 0));
    const instance = data.toUtf8(try P.stringArg(t, 1));
    var timeout: i64 = 5000;
    if (t.argc > 2) {
        const w = arg(t, 2);
        if (!rt.isFix(w)) return P.argTypeError(t);
        timeout = rt.unfix(w);
    }
    const port = tds.lookup(host, instance, timeout) catch return raise(t, msg("sql-browser-port: {s}", .{tds.last_error}), &.{});
    return rt.fix(port);
}
pub const @"%sql-browser-port" = WN("sql-browser-port", sqlBrowserPort, 2, 3);

fn tcpListen(t: *Thread) Err!Word {
    const port = try portArg(t, 0);
    const l = net.listen(null, port) orelse return raise(t, msg("tcp-listen: {s}", .{net.last_error}), &.{});
    return sys.wrapNativeOf(t, .listener, l);
}
pub const @"%tcp-listen" = WN("tcp-listen", tcpListen, 1, 1);

fn tcpAccept(t: *Thread) Err!Word {
    const p = sys.nativeOf(arg(t, 0), .listener) orelse return P.argTypeError(t);
    const l: *net.Listener = @ptrCast(@alignCast(p));
    const c = l.accept() orelse return raise(t, msg("tcp-accept: {s}", .{net.last_error}), &.{});
    return newSocket(t, c);
}
pub const @"%tcp-accept" = WN("tcp-accept", tcpAccept, 1, 1);

fn socketPort(comptime which: enum { in, out, bin_in, bin_out }) fn (*Thread) Err!Word {
    return struct {
        fn f(t: *Thread) Err!Word {
            const s = try socketArg(t, 0);
            const i: usize = 3 + @as(usize, @intFromEnum(which));
            const have = rt.ptr(arg(t, 0))[i];
            if (have != rt.FALSE) return have;
            t.reserve(2);
            const p = ports.newPort(if (which == .in or which == .bin_in) .net_in else .net_out, which == .bin_in or which == .bin_out);
            s.conn.retain();
            p.conn = s.conn;
            p.name = "{socket}";
            const w = ports.wrap(t, p);
            // the socket object again (the reservation may have moved it)
            const obj = arg(t, 0);
            rt.ptr(obj)[i] = w;
            rt.barrier(t, obj, w);
            return w;
        }
    }.f;
}
pub const @"%socket-input-port" = WN("socket-input-port", socketPort(.in), 1, 1);
pub const @"%socket-output-port" = WN("socket-output-port", socketPort(.out), 1, 1);
pub const @"%socket-binary-input-port" = WN("socket-binary-input-port", socketPort(.bin_in), 1, 1);
pub const @"%socket-binary-output-port" = WN("socket-binary-output-port", socketPort(.bin_out), 1, 1);

/// A line read byte by byte from the connection (no read-ahead), the CR
/// dropped, as UTF-8
fn socketReadLine(t: *Thread) Err!Word {
    const s = try socketArg(t, 0);
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(pa);
    var any = false;
    while (true) {
        var b: [1]u8 = undefined;
        if (s.conn.read(&b) == 0) break;
        any = true;
        if (b[0] == '\n') break;
        if (b[0] == '\r') continue;
        line.append(pa, b[0]) catch rt.oom();
    }
    if (!any) return rt.EOF;
    t.reserve(data.stringWords(line.items.len, true));
    return data.heapStringUtf8(t, line.items);
}
pub const @"%socket-read-line" = WN("socket-read-line", socketReadLine, 1, 1);

fn socketClose(t: *Thread) Err!Word {
    if (sys.nativeOf(arg(t, 0), .socket)) |p| {
        const s: *Socket = @ptrCast(@alignCast(p));
        // what the ports hold is sent first (the JVM's close flushes too)
        for (rt.ptr(arg(t, 0))[3 .. 3 + port_slots]) |w| if (ports.get(w)) |port| {
            if (port.kind == .net_out) port.flush();
        };
        s.conn.close();
    } else if (sys.nativeOf(arg(t, 0), .listener)) |p| {
        const l: *net.Listener = @ptrCast(@alignCast(p));
        l.close();
    } else return raise(t, "socket-close: expected socket or listener", &.{});
    return rt.TRUE;
}
pub const @"%socket-close" = WN("socket-close", socketClose, 1, 1);

fn socketP(t: *Thread) Err!Word {
    return rt.boolean(sys.nativeOf(arg(t, 0), .socket) != null);
}
pub const @"%socket?" = WN("socket?", socketP, 1, 1);

fn listenerP(t: *Thread) Err!Word {
    return rt.boolean(sys.nativeOf(arg(t, 0), .listener) != null);
}
pub const @"%tcp-listener?" = WN("tcp-listener?", listenerP, 1, 1);

// --- (scm database postgres) helpers ------------------------------------------------

/// s in single quotes, its quotes doubled
fn pgQuoteLiteral(t: *Thread) Err!Word {
    const s = data.toUtf8(try P.stringArg(t, 0));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(pa);
    out.append(pa, '\'') catch rt.oom();
    for (s) |c| {
        if (c == '\'') out.append(pa, '\'') catch rt.oom();
        out.append(pa, c) catch rt.oom();
    }
    out.append(pa, '\'') catch rt.oom();
    t.reserve(data.stringWords(out.items.len, true));
    return data.heapStringUtf8(t, out.items);
}
pub const @"%pg-quote-literal" = WN("pg-quote-literal", pgQuoteLiteral, 1, 1);

/// A DataRow message body: a vector of the columns (strings, #f for NULL)
fn pgParseDatarow(t: *Thread) Err!Word {
    const b = data.bvBytes(try @import("prims_text.zig").bvArg(t, 0));
    const fail = struct {
        fn f(tt: *Thread, i: usize, n: usize) Err {
            return raise(tt, msg("pg-parse-datarow: parse failure: Index {d} out of bounds for length {d}", .{ i, n }), &.{});
        }
    }.f;
    if (b.len < 2) return fail(t, b.len, b.len);
    const ncols: usize = (@as(usize, b[0]) << 8) | b[1];
    // first pass: the sizes, so that one reservation covers everything
    var words: usize = 1 + ncols;
    var off: usize = 2;
    for (0..ncols) |_| {
        if (off + 4 > b.len) return fail(t, off + @min(4, b.len - @min(off, b.len)), b.len);
        const len = std.mem.readInt(i32, b[off..][0..4], .big);
        off += 4;
        if (len > 0) {
            const l: usize = @intCast(len);
            if (off + l > b.len) return fail(t, b.len, b.len);
            words += data.stringWords(l, true);
            off += l;
        } else words += data.stringWords(0, false);
    }
    t.reserve(words);
    const body = data.bvBytes(arg(t, 0));
    const v = data.makeVector(t, ncols, rt.FALSE);
    off = 2;
    for (0..ncols) |i| {
        const len = std.mem.readInt(i32, body[off..][0..4], .big);
        off += 4;
        if (len == -1) continue;
        const l: usize = if (len > 0) @intCast(len) else 0;
        data.vectorItems(v)[i] = data.heapStringUtf8(t, body[off .. off + l]);
        off += l;
    }
    return v;
}
pub const @"%pg-parse-datarow" = WN("pg-parse-datarow", pgParseDatarow, 1, 1);

// --- non-blocking operations, for (scm native http) ----------------------

/// (%socket-recv-some socket max): a bytevector of the bytes available now
/// (at most max, at least one), the eof object, or #f if none are there yet
fn recvSome(t: *Thread) Err!Word {
    const s = try socketArg(t, 0);
    const max_w = arg(t, 1);
    if (!rt.isFix(max_w) or rt.unfix(max_w) <= 0) return P.argTypeError(t);
    const max: usize = @intCast(rt.unfix(max_w));
    if (s.conn.closed) return rt.EOF;
    if (s.conn.buffered() == 0) {
        var ready = [1]bool{false};
        _ = net.poll(&.{s.conn.handle()}, &.{false}, &ready, 0);
        if (!ready[0]) return rt.FALSE;
    }
    var buf: [65536]u8 = undefined;
    const n = s.conn.read(buf[0..@min(max, buf.len)]);
    if (n == 0) return rt.EOF;
    t.reserve(data.bvWords(n));
    const bv = data.makeBytevector(t, n);
    @memcpy(data.bvBytes(bv), buf[0..n]);
    return bv;
}
pub const @"%%socket-recv-some" = WN("%socket-recv-some", recvSome, 2, 2);

/// (%socket-send-some socket bytevector start end): the number of bytes the
/// socket took now (0 if it would block); an error if the connection failed
fn sendSome(t: *Thread) Err!Word {
    const s = try socketArg(t, 0);
    const bv = arg(t, 1);
    if (!data.isBytevector(bv)) return P.argTypeError(t);
    const bytes = data.bvBytes(bv);
    const start: usize = @intCast(@max(0, rt.unfix(arg(t, 2))));
    const end: usize = @intCast(@min(@as(i64, @intCast(bytes.len)), rt.unfix(arg(t, 3))));
    if (start >= end) return rt.fix(0);
    const n = s.conn.sendSome(bytes[start..end]) orelse return raise(t, "Broken pipe", &.{});
    return rt.fix(@intCast(n));
}
pub const @"%%socket-send-some" = WN("%socket-send-some", sendSome, 4, 4);

fn shutdownOutput(t: *Thread) Err!Word {
    const s = try socketArg(t, 0);
    s.conn.shutdownOutput();
    return rt.UNSPEC;
}
pub const @"%%socket-shutdown-output" = WN("%socket-shutdown-output", shutdownOutput, 1, 1);

/// (%net-poll items timeout-ms): items a list of (object . mode), object a
/// socket or listener, mode read or write; the list of the ready items.
/// timeout-ms -1 waits without limit.
fn netPoll(t: *Thread) Err!Word {
    var handles: std.ArrayList(?net.Handle) = .empty;
    defer handles.deinit(pa);
    var writes: std.ArrayList(bool) = .empty;
    defer writes.deinit(pa);
    var items: std.ArrayList(Word) = .empty;
    defer items.deinit(pa);
    var already = false; // a socket with buffered input is ready now
    var l = arg(t, 0);
    while (rt.isPair(l)) : (l = rt.cdr(l)) {
        const item = rt.car(l);
        if (!rt.isPair(item)) return P.argTypeError(t);
        const obj = rt.car(item);
        const write = rt.cdr(item) == data.intern("write");
        if (sys.nativeOf(obj, .socket)) |p| {
            const s: *Socket = @ptrCast(@alignCast(p));
            if (s.conn.closed) {
                already = true;
                handles.append(pa, null) catch rt.oom();
            } else {
                if (!write and s.conn.buffered() > 0) already = true;
                handles.append(pa, s.conn.handle()) catch rt.oom();
            }
        } else if (sys.nativeOf(obj, .listener)) |p| {
            const ls: *net.Listener = @ptrCast(@alignCast(p));
            handles.append(pa, if (ls.closed) null else ls.handle()) catch rt.oom();
        } else return P.argTypeError(t);
        writes.append(pa, write) catch rt.oom();
        items.append(pa, item) catch rt.oom();
    }
    const timeout_w = arg(t, 1);
    const timeout: i32 = if (already) 0 else if (rt.isFix(timeout_w)) @intCast(std.math.clamp(rt.unfix(timeout_w), -1, std.math.maxInt(i32))) else -1;
    const ready = pa.alloc(bool, handles.items.len) catch rt.oom();
    defer pa.free(ready);
    @memset(ready, false);
    if (!net.poll(handles.items, writes.items, ready, timeout)) return raise(t, "%net-poll: poll failed", &.{});
    // buffered input and closed sockets count as ready
    l = arg(t, 0);
    var i: usize = 0;
    while (rt.isPair(l)) : ({
        l = rt.cdr(l);
        i += 1;
    }) {
        const item = rt.car(l);
        if (sys.nativeOf(rt.car(item), .socket)) |p| {
            const s: *Socket = @ptrCast(@alignCast(p));
            if (s.conn.closed or (rt.cdr(item) != data.intern("write") and s.conn.buffered() > 0)) ready[i] = true;
        }
    }
    var n: usize = 0;
    for (ready) |r| if (r) {
        n += 1;
    };
    t.reserve(3 * n);
    var result = rt.NIL;
    i = items.items.len;
    l = arg(t, 0);
    // the items again from the argument (a collection may have moved them)
    var all: std.ArrayList(Word) = .empty;
    defer all.deinit(pa);
    while (rt.isPair(l)) : (l = rt.cdr(l)) all.append(pa, rt.car(l)) catch rt.oom();
    while (i > 0) {
        i -= 1;
        if (ready[i]) result = t.cons(all.items[i], result);
    }
    return result;
}
pub const @"%%net-poll" = WN("%net-poll", netPoll, 2, 2);

/// (%tcp-listen-host host port): tcp-listen on one address
fn listenHost(t: *Thread) Err!Word {
    const host = data.toUtf8(try P.stringArg(t, 0));
    const port = try portArg(t, 1);
    const l = net.listen(if (host.len == 0 or std.mem.eql(u8, host, "0.0.0.0")) null else host, port) orelse return raise(t, msg("tcp-http-serve: {s}", .{net.last_error}), &.{});
    return sys.wrapNativeOf(t, .listener, l);
}
pub const @"%%tcp-listen-host" = WN("%tcp-listen-host", listenHost, 2, 2);



/// (%shutdown-signal): the SIGINT or SIGTERM received so far, 0 if none
/// (the first call installs the handlers)
fn shutdownSignal(t: *Thread) Err!Word {
    _ = t;
    return rt.fix(@import("os.zig").shutdownSignal());
}
pub const @"%%shutdown-signal" = WN("%shutdown-signal", shutdownSignal, 0, 0);

/// (%set-record-printer! type parts): records of type print as parts
/// (strings, and field indices for the field's display), as the JVM
/// implementation's HTTP objects
fn setRecordPrinter(t: *Thread) Err!Word {
    if (!data.isRecord(arg(t, 0))) return P.argTypeError(t);
    // (cons (cons type parts) record_printers): reserve first (a collection
    // updates the arguments)
    t.reserve(6);
    const entry = t.cons(arg(t, 0), arg(t, 1));
    rt.record_printers = t.cons(entry, rt.record_printers);
    return rt.UNSPEC;
}
pub const @"%%set-record-printer!" = WN("%set-record-printer!", setRecordPrinter, 2, 2);


