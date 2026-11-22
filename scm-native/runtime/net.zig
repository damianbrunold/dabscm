//! TCP connections and listeners (std.Io.net) and TLS clients
//! (std.crypto.tls.Client), for (scm net sockets) and the network
//! libraries. A Conn reads and writes the plain stream, or the TLS stream
//! once tls-connect or socket-starttls! started one over it.
const std = @import("std");
const os = @import("os.zig");
const net = std.Io.net;
const tls = std.crypto.tls;

const pa = std.heap.c_allocator;

pub const Error = error{ConnectFailed} || error{OutOfMemory};

/// The message of the last failure, in the JVM's words where it has them
pub threadlocal var last_error: []const u8 = "";

pub const Conn = struct {
    stream: net.Stream,
    reader: net.Stream.Reader,
    writer: net.Stream.Writer,
    tls_client: ?*tls.Client = null,
    closed: bool = false,

    /// For a socket port
    pub fn portRead(c: *Conn, dst: []u8) usize {
        return c.read(dst);
    }

    /// Up to dst.len bytes, at least one; 0 at the end of the stream
    pub fn read(c: *Conn, dst: []u8) usize {
        if (c.closed or dst.len == 0) return 0;
        const r: *std.Io.Reader = if (c.tls_client) |t| &t.reader else &c.reader.interface;
        // dst must not be in the heap (a collection may move it meanwhile)
        const blocks = r.bufferedLen() == 0;
        if (blocks) os.blockingBegin();
        defer if (blocks) os.blockingEnd();
        const avail = r.peekGreedy(1) catch return 0;
        const n = @min(avail.len, dst.len);
        @memcpy(dst[0..n], avail[0..n]);
        r.toss(n);
        return n;
    }

    /// bytes must not be in the heap (a collection may move them meanwhile)
    pub fn writeAll(c: *Conn, bytes: []const u8) bool {
        if (c.closed) return false;
        os.blockingBegin();
        defer os.blockingEnd();
        if (c.tls_client) |t| {
            t.writer.writeAll(bytes) catch return false;
            t.writer.flush() catch return false;
        } else {
            c.writer.interface.writeAll(bytes) catch return false;
        }
        c.writer.interface.flush() catch return false;
        return true;
    }

    /// Bytes already received and buffered (no read needed)
    pub fn buffered(c: *Conn) usize {
        if (c.closed) return 0;
        if (c.tls_client) |t| return t.reader.bufferedLen() + c.reader.interface.bufferedLen();
        return c.reader.interface.bufferedLen();
    }

    /// The socket's handle (for poll)
    pub fn handle(c: *Conn) std.posix.fd_t {
        return c.stream.socket.handle;
    }

    /// Write what the socket takes now, without blocking: the number of
    /// bytes written (0 if none), null on error. Over TLS, all of it.
    pub fn sendSome(c: *Conn, bytes: []const u8) ?usize {
        if (c.closed) return null;
        if (c.tls_client != null) {
            // a copy: bytes may be in the heap
            const copy = pa.dupe(u8, bytes) catch @panic("out of memory");
            defer pa.free(copy);
            return if (c.writeAll(copy)) bytes.len else null;
        }
        c.writer.interface.flush() catch return null;
        const flags: u32 = std.c.MSG.DONTWAIT | std.c.MSG.NOSIGNAL;
        const n = std.c.send(c.handle(), bytes.ptr, bytes.len, flags);
        if (n >= 0) return @intCast(n);
        return switch (std.posix.errno(n)) {
            .AGAIN => 0,
            else => null,
        };
    }

    pub fn shutdownOutput(c: *Conn) void {
        if (c.closed) return;
        c.stream.shutdown(os.io, .send) catch {};
    }

    pub fn close(c: *Conn) void {
        if (c.closed) return;
        if (c.tls_client) |t| {
            t.end() catch {};
            c.writer.interface.flush() catch {};
        }
        c.stream.close(os.io);
        c.closed = true;
    }
};

fn newConn(stream: net.Stream) *Conn {
    const c = pa.create(Conn) catch @panic("out of memory");
    const rbuf = pa.alloc(u8, tls.Client.min_buffer_len) catch @panic("out of memory");
    const wbuf = pa.alloc(u8, tls.Client.min_buffer_len) catch @panic("out of memory");
    c.* = .{ .stream = stream, .reader = stream.reader(os.io, rbuf), .writer = stream.writer(os.io, wbuf) };
    return c;
}

fn errorText(e: anyerror) []const u8 {
    return switch (e) {
        error.ConnectionRefused => "Connection refused",
        error.UnknownHostName, error.NameServerFailure, error.HostLacksNetworkAddresses => "Unknown host",
        error.NetworkUnreachable => "Network is unreachable",
        error.HostUnreachable => "No route to host",
        error.ConnectionTimedOut, error.Timeout => "Connection timed out",
        error.AddressInUse => "Address already in use",
        error.ConnectionResetByPeer => "Connection reset",
        error.AccessDenied, error.PermissionDenied => "Permission denied",
        else => @errorName(e),
    };
}

pub fn connect(host: []const u8, port: u16) ?*Conn {
    ignoreSigpipe();
    os.blockingBegin();
    defer os.blockingEnd();
    const stream = blk: {
        if (net.IpAddress.parse(host, port)) |addr| {
            break :blk addr.connect(os.io, .{ .mode = .stream, .protocol = .tcp }) catch |e| {
                last_error = errorText(e);
                return null;
            };
        } else |_| {
            const name = net.HostName.init(host) catch {
                last_error = host;
                return null;
            };
            break :blk name.connect(os.io, port, .{ .mode = .stream, .protocol = .tcp }) catch |e| {
                // as Java's UnknownHostException: the host name
                const ae: anyerror = e;
                last_error = switch (ae) {
                    error.UnknownHostName, error.NameServerFailure, error.HostLacksNetworkAddresses, error.NoAddressReturned => host,
                    else => errorText(e),
                };
                return null;
            };
        }
    };
    setNoDelay(stream);
    return newConn(stream);
}

/// TCP_NODELAY, as the JVM implementation sets it on its client sockets
fn setNoDelay(stream: net.Stream) void {
    if (@import("builtin").os.tag == .windows) return;
    const one: c_int = 1;
    _ = std.c.setsockopt(stream.socket.handle, std.c.IPPROTO.TCP, std.c.TCP.NODELAY, std.mem.asBytes(&one), @sizeOf(c_int));
}

pub const Listener = struct {
    server: net.Server,
    closed: bool = false,

    pub fn accept(l: *Listener) ?*Conn {
        os.blockingBegin();
        const stream = l.server.accept(os.io) catch |e| {
            os.blockingEnd();
            last_error = errorText(e);
            return null;
        };
        os.blockingEnd();
        return newConn(stream);
    }

    pub fn close(l: *Listener) void {
        if (l.closed) return;
        l.server.deinit(os.io);
        l.closed = true;
    }

    pub fn handle(l: *Listener) std.posix.fd_t {
        return l.server.socket.handle;
    }

    pub fn port(l: *Listener) u16 {
        return l.server.socket.address.getPort();
    }
};

/// A listener on port of host (all interfaces if null)
pub fn listen(host: ?[]const u8, port: u16) ?*Listener {
    ignoreSigpipe();
    const addr = if (host) |h| (net.IpAddress.parse(h, port) catch {
        last_error = h;
        return null;
    }) else net.IpAddress{ .ip4 = .unspecified(port) };
    const server = addr.listen(os.io, .{ .reuse_address = true }) catch |e| {
        last_error = errorText(e);
        return null;
    };
    const l = pa.create(Listener) catch @panic("out of memory");
    l.* = .{ .server = server };
    return l;
}

// --- TLS -----------------------------------------------------------------------

var ca_bundle: std.crypto.Certificate.Bundle = .empty;
var ca_loaded = false;
var ca_lock: std.Io.RwLock = .init;

fn envFlag(name: []const u8) bool {
    const v = os.getEnv(name) orelse return false;
    return std.mem.eql(u8, v, "1") or std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "yes");
}

/// The trusted CAs: SSL_CERT_FILE if set, else the system's (as curl and
/// OpenSSL, and the JVM implementation besides its own store)
fn loadCas() void {
    if (ca_loaded) return;
    ca_loaded = true;
    const now = std.Io.Clock.real.now(os.io);
    if (os.getEnv("SSL_CERT_FILE")) |f| {
        ca_bundle.addCertsFromFilePathAbsolute(pa, os.io, now, f) catch {};
        if (ca_bundle.map.count() > 0) return;
    }
    ca_bundle.rescan(pa, os.io, now) catch {};
}

/// Start TLS on c (the handshake), verifying the server's certificate for
/// host unless verify is false or SCM_TLS_INSECURE is set
pub fn startTls(c: *Conn, host: []const u8, verify: bool) bool {
    return startTlsOver(c, host, verify, &c.reader.interface, &c.writer.interface);
}

/// As startTls, with the handshake read from input and written to output
/// (TDS wraps it in its packets); the client then uses c's stream
pub fn startTlsOver(c: *Conn, host: []const u8, verify: bool, input: *std.Io.Reader, output: *std.Io.Writer) bool {
    os.blockingBegin();
    defer os.blockingEnd();
    const insecure = !verify or envFlag("SCM_TLS_INSECURE");
    if (!insecure) loadCas();
    const t = pa.create(tls.Client) catch @panic("out of memory");
    const rbuf = pa.alloc(u8, tls.Client.min_buffer_len) catch @panic("out of memory");
    const wbuf = pa.alloc(u8, tls.Client.min_buffer_len) catch @panic("out of memory");
    var entropy: [tls.Client.Options.entropy_len]u8 = undefined;
    os.randomBytes(&entropy);
    const host_copy = pa.dupe(u8, host) catch @panic("out of memory");
    t.* = tls.Client.init(input, output, .{
        .host = if (insecure) .no_verification else .{ .explicit = host_copy },
        .ca = if (insecure) .no_verification else .{ .bundle = .{ .gpa = pa, .io = os.io, .lock = &ca_lock, .bundle = &ca_bundle } },
        .read_buffer = rbuf,
        .write_buffer = wbuf,
        .entropy = &entropy,
        .realtime_now = std.Io.Clock.real.now(os.io),
        .allow_truncation_attacks = true,
    }) catch |e| {
        const ae: anyerror = e;
        last_error = switch (ae) {
            error.TlsCertificateNotVerified, error.CertificateIssuerNotFound, error.CertificateSignatureInvalid, error.CertificateExpired, error.CertificateNotYetValid => "PKIX path building failed: unable to find valid certification path to requested target",
            error.CertificateHostMismatch => "No subject alternative names matching the host name",
            // the socket's error (a read error, such as a reset)
            error.ReadFailed => if (c.reader.err) |re| errorText(re) else "Connection closed",
            else => @errorName(e),
        };
        return false;
    };
    t.input = &c.reader.interface;
    t.output = &c.writer.interface;
    c.tls_client = t;
    return true;
}

/// poll(2) over handles; events: read (or accept) / write. The ready flags
/// are set in ready; false on error.
pub fn poll(handles: []const std.posix.fd_t, write: []const bool, ready: []bool, timeout_ms: i32) bool {
    const fds = pa.alloc(std.posix.pollfd, handles.len) catch @panic("out of memory");
    defer pa.free(fds);
    if (timeout_ms != 0) os.blockingBegin();
    defer if (timeout_ms != 0) os.blockingEnd();
    for (handles, write, fds) |h, w, *f| f.* = .{ .fd = h, .events = if (w) std.posix.POLL.OUT else std.posix.POLL.IN, .revents = 0 };
    const n = std.c.poll(fds.ptr, @intCast(fds.len), timeout_ms);
    if (n < 0) return std.posix.errno(n) == .INTR;
    for (fds, ready) |f, *r| r.* = f.revents != 0;
    return true;
}

/// Writing to a peer that closed is an error, not SIGPIPE (as on the JVM)
pub fn ignoreSigpipe() void {
    if (@import("builtin").os.tag == .windows) return;
    const act = std.posix.Sigaction{ .handler = .{ .handler = std.posix.SIG.IGN }, .mask = std.posix.sigemptyset(), .flags = 0 };
    std.posix.sigaction(.PIPE, &act, null);
}
