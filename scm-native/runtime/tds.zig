//! SQL Server connections (TDS): the PreLogin exchange and TLS with its
//! handshake wrapped in TDS PRELOGIN packets (after it, the TLS records go
//! over the socket directly), and the SQL Server Browser's instance lookup
//! (UDP 1434), as the JVM and C# implementations' tds-connect and
//! sql-browser-port.
const std = @import("std");
const os = @import("os.zig");
const net = @import("net.zig");
const tls = std.crypto.tls;
const Io = std.Io;

const pa = std.heap.c_allocator;

const encrypt_off = 0;
const encrypt_on = 1;
const encrypt_not_sup = 2;
const encrypt_req = 3;

/// The message of the last failure
pub var last_error: []const u8 = "";

fn fail(comptime fmt: []const u8, args: anytype) void {
    last_error = std.fmt.allocPrint(pa, fmt, args) catch @panic("out of memory");
}

fn debug() bool {
    const v = os.getEnv("SCM_TDS_DEBUG") orelse return false;
    const t = std.mem.trim(u8, v, " \t");
    return std.mem.eql(u8, t, "1") or std.ascii.eqlIgnoreCase(t, "true") or std.ascii.eqlIgnoreCase(t, "yes");
}

fn log(comptime fmt: []const u8, args: anytype) void {
    if (!debug()) return;
    const s = std.fmt.allocPrint(pa, "scm-tds: " ++ fmt ++ "\n", args) catch return;
    defer pa.free(s);
    os.writeStderr(s);
}

/// Write payload as TDS packets of the given type (at most 4096 bytes each,
/// EOM on the last)
fn writePackets(w: *Io.Writer, typ: u8, payload: []const u8) Io.Writer.Error!void {
    const max = 4096 - 8;
    var pos: usize = 0;
    var id: u8 = 1;
    while (true) {
        const n = @min(max, payload.len - pos);
        const last = pos + n >= payload.len;
        const len: u16 = @intCast(n + 8);
        const header = [8]u8{ typ, if (last) 1 else 0, @intCast(len >> 8), @intCast(len & 0xff), 0, 0, id, 0 };
        id +%= 1;
        try w.writeAll(&header);
        try w.writeAll(payload[pos..][0..n]);
        pos += n;
        if (last) break;
    }
}

/// A reader and writer over the connection's stream that strip and add the
/// PRELOGIN framing of the TLS handshake
const Framer = struct {
    inner_r: *Io.Reader,
    inner_w: *Io.Writer,
    remaining: usize = 0,
    reader: Io.Reader,
    writer: Io.Writer,

    fn stream(r: *Io.Reader, w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
        const f: *Framer = @alignCast(@fieldParentPtr("reader", r));
        if (f.remaining == 0) {
            const h = try f.inner_r.takeArray(8);
            const len = (@as(usize, h[2]) << 8) | h[3];
            if (len < 8) return error.ReadFailed;
            f.remaining = len - 8;
            if (f.remaining == 0) return 0;
        }
        const n = try f.inner_r.stream(w, limit.min(.limited(f.remaining)));
        f.remaining -= n;
        return n;
    }

    fn drain(w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
        const f: *Framer = @alignCast(@fieldParentPtr("writer", w));
        if (w.end > 0) {
            try writePackets(f.inner_w, 0x12, w.buffer[0..w.end]);
            w.end = 0;
        }
        var n: usize = 0;
        for (data[0 .. data.len - 1]) |d| {
            if (d.len == 0) continue;
            try writePackets(f.inner_w, 0x12, d);
            n += d.len;
        }
        const last = data[data.len - 1];
        if (last.len > 0) for (0..splat) |_| {
            try writePackets(f.inner_w, 0x12, last);
            n += last.len;
        };
        return n;
    }

    fn flush(w: *Io.Writer) Io.Writer.Error!void {
        const f: *Framer = @alignCast(@fieldParentPtr("writer", w));
        _ = try drain(w, &.{""}, 0);
        try f.inner_w.flush();
    }
};

fn sendPreLogin(w: *Io.Writer, encryption: u8) Io.Writer.Error!void {
    // VERSION (offset 11, length 6), ENCRYPTION (offset 17, length 1), terminator
    const body = [_]u8{
        0x00, 0x00, 0x0B, 0x00, 0x06,
        0x01, 0x00, 0x11, 0x00, 0x01,
        0xFF, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, encryption,
    };
    try writePackets(w, 0x12, &body);
    try w.flush();
}

/// The server's PreLogin response (all packets up to EOM): its ENCRYPTION
fn readPreLoginResponse(r: *Io.Reader) !u8 {
    var acc: std.ArrayList(u8) = .empty;
    defer acc.deinit(pa);
    while (true) {
        const h = try r.takeArray(8);
        const len = (@as(usize, h[2]) << 8) | h[3];
        if (len < 8) return error.BadPacket;
        try acc.appendSlice(pa, try r.take(len - 8));
        if (h[1] & 1 != 0) break;
    }
    const body = acc.items;
    var enc: u8 = encrypt_not_sup;
    var i: usize = 0;
    while (i + 4 < body.len and body[i] != 0xFF) : (i += 5) {
        const off = (@as(usize, body[i + 1]) << 8) | body[i + 2];
        const len = (@as(usize, body[i + 3]) << 8) | body[i + 4];
        if (body[i] == 0x00 and len >= 4 and off + 4 <= body.len)
            log("server version {d}.{d}.{d}", .{ body[off], body[off + 1], (@as(u16, body[off + 2]) << 8) | body[off + 3] });
        if (body[i] == 0x01 and len >= 1 and off < body.len) enc = body[off];
    }
    return enc;
}

fn ioText(e: anyerror) []const u8 {
    return switch (e) {
        error.EndOfStream => "Connection closed during TDS read",
        error.ReadFailed => "Connection reset",
        error.WriteFailed => "Broken pipe",
        else => @errorName(e),
    };
}

/// Connect to a SQL Server at host:port (or at the named instance's port),
/// PreLogin and, when encrypt, TLS
pub const PortSpec = union(enum) { port: u16, instance: []const u8 };

pub fn connect(host: []const u8, port_spec: PortSpec, encrypt: bool, verify_in: bool, cert_host: []const u8) ?*net.Conn {
    var verify = verify_in;
    if (verify) if (os.getEnv("SCM_TLS_INSECURE")) |v| {
        const tv = std.mem.trim(u8, v, " \t");
        if (std.mem.eql(u8, tv, "1") or std.ascii.eqlIgnoreCase(tv, "true") or std.ascii.eqlIgnoreCase(tv, "yes")) {
            os.writeStderr("warning: SCM_TLS_INSECURE is set, SQL Server certificate verification is disabled\n");
            verify = false;
        }
    };
    const port: u16 = switch (port_spec) {
        .port => |p| p,
        .instance => |inst| lookup(host, inst, 5000) catch {
            fail("tds-connect (instance lookup): {s}", .{last_error});
            return null;
        },
    };
    if (port_spec == .instance) log("instance {s} on {s} listens on tcp port {d}", .{ port_spec.instance, host, port });
    const c = net.connect(host, port) orelse {
        fail("tds-connect (connect): {s}", .{net.last_error});
        return null;
    };
    log("tcp connected to {s}:{d}", .{ host, port });
    const r = &c.reader.interface;
    const w = &c.writer.interface;
    sendPreLogin(w, if (encrypt) encrypt_on else encrypt_not_sup) catch |e| return closeFail(c, "prelogin", ioText(e));
    const server_enc = readPreLoginResponse(r) catch |e| return closeFail(c, "prelogin", ioText(e));
    log("server encryption flag {d}", .{server_enc});
    if (encrypt and server_enc == encrypt_not_sup) return closeFail(c, "prelogin", "server does not support encryption (use encrypt #f)");
    if (!encrypt and (server_enc == encrypt_req or server_enc == encrypt_on)) return closeFail(c, "prelogin", "server requires encryption");
    if (!encrypt) return c;

    const f = pa.create(Framer) catch @panic("out of memory");
    defer pa.destroy(f);
    const rbuf = pa.alloc(u8, tls.Client.min_buffer_len) catch @panic("out of memory");
    defer pa.free(rbuf);
    const wbuf = pa.alloc(u8, tls.Client.min_buffer_len) catch @panic("out of memory");
    defer pa.free(wbuf);
    f.* = .{
        .inner_r = r,
        .inner_w = w,
        .reader = .{ .vtable = &.{ .stream = Framer.stream }, .buffer = rbuf, .seek = 0, .end = 0 },
        .writer = .{ .vtable = &.{ .drain = Framer.drain, .flush = Framer.flush }, .buffer = wbuf },
    };
    if (!net.startTlsOver(c, cert_host, verify, &f.reader, &f.writer)) return closeFail(c, "tls", net.last_error);
    // the handshake is complete: nothing of it may be left in the framer
    if (f.reader.bufferedLen() != 0 or f.remaining != 0 or f.writer.end != 0)
        return closeFail(c, "tls", "unexpected data after the TLS handshake");
    log("tls {s}", .{@tagName(c.tls_client.?.tls_version)});
    return c;
}

fn closeFail(c: *net.Conn, step: []const u8, text: []const u8) ?*net.Conn {
    c.close();
    fail("tds-connect ({s}): {s}", .{ step, text });
    return null;
}

fn browserPort() u16 {
    const v = os.getEnv("SCM_SQL_BROWSER_PORT") orelse return 1434;
    const t = std.mem.trim(u8, v, " \t");
    if (t.len == 0) return 1434;
    return std.fmt.parseInt(u16, t, 10) catch 1434;
}

/// The TCP port of the named instance on host, from the SQL Server Browser
/// (SSRP CLNT_UCAST_INST); errors leave their message in last_error
pub fn lookup(host: []const u8, instance: []const u8, timeout_ms: i64) !u16 {
    const c = std.c;
    const udp_port = browserPort();
    const host_z = try pa.dupeSentinel(u8, host, 0);
    defer pa.free(host_z);
    var hints = std.mem.zeroes(c.addrinfo);
    hints.family = c.AF.INET;
    hints.socktype = c.SOCK.DGRAM;
    var res: ?*c.addrinfo = null;
    if (@intFromEnum(c.getaddrinfo(host_z, null, &hints, &res)) != 0 or res == null) {
        fail("{s}", .{host});
        return error.Lookup;
    }
    defer c.freeaddrinfo(res.?);
    var addr: c.sockaddr.in = @as(*const c.sockaddr.in, @ptrCast(@alignCast(res.?.addr.?))).*;
    addr.port = std.mem.nativeToBig(u16, udp_port);
    const fd = c.socket(c.AF.INET, c.SOCK.DGRAM, 0);
    if (fd < 0) {
        fail("cannot open a UDP socket", .{});
        return error.Lookup;
    }
    defer _ = c.close(fd);
    const half: i64 = @max(1, @divTrunc(timeout_ms, 2));
    const tv = c.timeval{ .sec = @intCast(@divTrunc(half, 1000)), .usec = @intCast(@mod(half, 1000) * 1000) };
    _ = c.setsockopt(fd, c.SOL.SOCKET, c.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(c.timeval));
    const req = try pa.alloc(u8, instance.len + 1);
    defer pa.free(req);
    req[0] = 0x04;
    @memcpy(req[1..], instance);
    const buf = try pa.alloc(u8, 65535);
    defer pa.free(buf);
    var reply: ?[]const u8 = null;
    var attempt: usize = 0;
    while (attempt < 2 and reply == null) : (attempt += 1) {
        _ = c.sendto(fd, req.ptr, req.len, 0, @ptrCast(&addr), @sizeOf(c.sockaddr.in));
        const got = c.recvfrom(fd, buf.ptr, buf.len, 0, null, null);
        if (got < 0) continue; // timed out, or ICMP port unreachable
        const n: usize = @intCast(got);
        if (n < 3 or buf[0] != 0x05) {
            fail("unexpected SQL Browser reply from {s}", .{host});
            return error.Lookup;
        }
        const size = @as(usize, buf[1]) | (@as(usize, buf[2]) << 8);
        reply = buf[3..][0..@min(size, n - 3)];
    }
    const text = reply orelse {
        fail("no answer from SQL Browser at {s}:{d} for instance {s} (unknown instance, UDP blocked or SQL Server Browser service not running?)", .{ host, udp_port, instance });
        return error.Lookup;
    };
    return parsePort(text, instance, host);
}

fn parsePort(reply: []const u8, instance: []const u8, host: []const u8) !u16 {
    // the reply may list several instances, each terminated by ";;"
    var entries = std.mem.splitSequence(u8, reply, ";;");
    while (entries.next()) |entry| {
        var fields: std.ArrayList([]const u8) = .empty;
        defer fields.deinit(pa);
        var it = std.mem.splitScalar(u8, entry, ';');
        while (it.next()) |x| try fields.append(pa, x);
        var inst: ?[]const u8 = null;
        var tcp: ?[]const u8 = null;
        var i: usize = 0;
        while (i + 1 < fields.items.len) : (i += 2) {
            if (std.ascii.eqlIgnoreCase(fields.items[i], "InstanceName")) inst = fields.items[i + 1] else if (std.ascii.eqlIgnoreCase(fields.items[i], "tcp")) tcp = fields.items[i + 1];
        }
        if (inst) |name| if (std.ascii.eqlIgnoreCase(name, instance)) {
            const p = tcp orelse "";
            if (p.len == 0) {
                fail("instance {s} on {s} has no TCP endpoint (TCP/IP disabled?)", .{ instance, host });
                return error.Lookup;
            }
            return std.fmt.parseInt(u16, std.mem.trim(u8, p, " "), 10) catch {
                fail("For input string: \"{s}\"", .{p});
                return error.Lookup;
            };
        };
    }
    fail("SQL Browser at {s} does not know instance {s}", .{ host, instance });
    return error.Lookup;
}

test "parsePort" {
    const r = "ServerName;H;InstanceName;A;IsClustered;No;Version;16;tcp;1500;;ServerName;H;InstanceName;SQLEXPRESS;IsClustered;No;Version;16;tcp;49170;np;\\\\H\\pipe;;";
    try std.testing.expectEqual(@as(u16, 49170), try parsePort(r, "sqlexpress", "H"));
}
