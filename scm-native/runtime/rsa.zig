//! RSA for (scm crypto), as the JVM implementation's: key generation with
//! e = 65537 (the public key as SubjectPublicKeyInfo DER, the private key as
//! PKCS#8 DER with the CRT values), encryption and decryption with OAEP
//! (SHA-256, MGF1 with SHA-256, empty label). Over std.crypto.ff.
const std = @import("std");
const ff = std.crypto.ff;
const Sha256 = std.crypto.hash.sha2.Sha256;

const pa = std.heap.c_allocator;

pub const Error = error{ BadKey, MessageTooLong, DecryptionError, BadSize, OutOfMemory };

/// The message of the last failure, in the JVM's words
pub threadlocal var last_error: []const u8 = "";

const max_bits = 4096;
const U = ff.Uint(max_bits);
const M = ff.Modulus(max_bits);

const e_value: u32 = 65537;

// --- random primes -----------------------------------------------------------------

fn randomBytes(buf: []u8) void {
    @import("os.zig").randomBytes(buf);
}

const small_primes = blk: {
    @setEvalBranchQuota(100000);
    var list: [300]u32 = undefined;
    var n = 0;
    var c: u32 = 3;
    while (n < list.len) : (c += 2) {
        var prime = true;
        var d: u32 = 3;
        while (d * d <= c) : (d += 2) if (c % d == 0) {
            prime = false;
            break;
        };
        if (prime) {
            list[n] = c;
            n += 1;
        }
    }
    break :blk list;
};

fn fromBytes(bytes: []const u8) U {
    return U.fromBytes(bytes, .big) catch unreachable;
}

/// x - 1 (x odd, so no borrow beyond the last limb)
fn minusOne(x: U) U {
    var r = x;
    _ = r.subWithOverflow(U.fromPrimitive(u8, 1) catch unreachable);
    return r;
}

fn millerRabin(n: U, rounds: usize) bool {
    const m = M.fromUint(n) catch return false;
    const nm1 = minusOne(n);
    var d = nm1;
    const s = d.trailingZeroBitsPublic();
    d.shiftRightPublic(s);
    var dbytes: [max_bits / 8]u8 = undefined;
    d.toBytes(&dbytes, .big) catch return false;
    const len = (n.bitLenPublic() + 7) / 8;
    const one = m.one();
    const minus_one = M.Fe.fromBytes(m, blk: {
        var b: [max_bits / 8]u8 = undefined;
        nm1.toBytes(&b, .big) catch return false;
        break :blk b[b.len - len ..];
    }, .big) catch return false;
    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        // a random base in [2, n-2]
        var abytes: [max_bits / 8]u8 = undefined;
        randomBytes(abytes[0..len]);
        abytes[0] = 0; // below n
        var a = M.Fe.fromBytes(m, abytes[0..len], .big) catch continue;
        if (a.eql(one) or a.isZero()) continue;
        a = m.powWithEncodedPublicExponent(a, &dbytes, .big) catch return false;
        if (a.eql(one) or a.eql(minus_one)) continue;
        var composite = true;
        var i: usize = 1;
        while (i < s) : (i += 1) {
            a = m.sq(a);
            if (a.eql(minus_one)) {
                composite = false;
                break;
            }
            if (a.eql(one)) break;
        }
        if (composite) return false;
    }
    return true;
}

/// A random prime of bits bits (the top two set, so that p*q has 2*bits),
/// with p - 1 coprime to e
fn randomPrime(bits: usize) U {
    const len = (bits + 7) / 8;
    while (true) {
        var b: [max_bits / 8]u8 = @splat(0);
        const cand = b[b.len - len ..];
        randomBytes(cand);
        const extra = len * 8 - bits;
        cand[0] &= @as(u8, 0xff) >> @intCast(extra);
        cand[0] |= @as(u8, 0xc0) >> @intCast(extra);
        cand[len - 1] |= 1;
        const p = fromBytes(&b);
        var ok = true;
        for (small_primes) |sp| {
            var r = p;
            if ((r.divRemPublic(sp) catch unreachable) == 0) {
                ok = false;
                break;
            }
        }
        if (!ok) continue;
        var r = p;
        if ((r.divRemPublic(e_value) catch unreachable) == 1) continue; // e | p - 1
        if (millerRabin(p, 40)) return p;
    }
}

fn mul(a: U, b: U) U {
    var r = U.fromPrimitive(u8, 0) catch unreachable;
    _ = r.mulAddWithOverflow(a, b);
    return r;
}

/// e^-1 mod m, for e = 65537 prime and m not a multiple of e: (1 + k*m)/e
/// with k = -m^-1 mod e
fn inverseOfE(m: U) U {
    var r = m;
    const mm: u64 = r.divRemPublic(e_value) catch unreachable;
    // m^-1 mod e by Fermat (e is prime)
    var inv: u64 = 1;
    var base = mm;
    var ex: u64 = e_value - 2;
    while (ex > 0) : (ex >>= 1) {
        if (ex & 1 == 1) inv = inv * base % e_value;
        base = base * base % e_value;
    }
    const k: u64 = (e_value - inv) % e_value;
    var x = mul(m, U.fromPrimitive(u64, k) catch unreachable);
    _ = x.addWithOverflow(U.fromPrimitive(u8, 1) catch unreachable);
    _ = x.divRemPublic(e_value) catch unreachable;
    return x;
}

// --- DER ---------------------------------------------------------------------------

fn derLen(out: *std.ArrayList(u8), n: usize) void {
    if (n < 128) {
        out.append(pa, @intCast(n)) catch @panic("oom");
    } else {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, n, .big);
        var i: usize = 0;
        while (bytes[i] == 0) i += 1;
        out.append(pa, @intCast(0x80 + (8 - i))) catch @panic("oom");
        out.appendSlice(pa, bytes[i..]) catch @panic("oom");
    }
}

fn derTlv(out: *std.ArrayList(u8), tag: u8, content: []const u8) void {
    out.append(pa, tag) catch @panic("oom");
    derLen(out, content.len);
    out.appendSlice(pa, content) catch @panic("oom");
}

fn derInt(out: *std.ArrayList(u8), x: U) void {
    var b: [max_bits / 8]u8 = undefined;
    x.toBytes(&b, .big) catch unreachable;
    var i: usize = 0;
    while (i < b.len - 1 and b[i] == 0) i += 1;
    var c: std.ArrayList(u8) = .empty;
    defer c.deinit(pa);
    if (b[i] & 0x80 != 0) c.append(pa, 0) catch @panic("oom");
    c.appendSlice(pa, b[i..]) catch @panic("oom");
    derTlv(out, 0x02, c.items);
}

const rsa_algorithm = [_]u8{ 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00 };

/// The DER parser: the content of the next element of tag in d (and its end)
const Der = struct {
    b: []const u8,
    pos: usize = 0,

    fn next(d: *Der, tag: u8) Error![]const u8 {
        if (d.pos + 2 > d.b.len or d.b[d.pos] != tag) return error.BadKey;
        var len: usize = d.b[d.pos + 1];
        d.pos += 2;
        if (len >= 0x80) {
            const n = len - 0x80;
            if (n == 0 or n > 4 or d.pos + n > d.b.len) return error.BadKey;
            len = 0;
            for (d.b[d.pos .. d.pos + n]) |x| len = len * 256 + x;
            d.pos += n;
        }
        if (d.pos + len > d.b.len) return error.BadKey;
        const c = d.b[d.pos .. d.pos + len];
        d.pos += len;
        return c;
    }

    fn int(d: *Der) Error![]const u8 {
        var c = try d.next(0x02);
        while (c.len > 1 and c[0] == 0) c = c[1..];
        if (c.len > max_bits / 8) return error.BadKey;
        return c;
    }
};

// --- keys ----------------------------------------------------------------------------

pub const KeyPair = struct { public: []u8, private: []u8 };

pub fn generate(bits: usize) Error!KeyPair {
    if (bits < 512 or bits > max_bits) {
        last_error = "RSA keys must be at least 512 bits long";
        return error.BadSize;
    }
    const e = U.fromPrimitive(u32, e_value) catch unreachable;
    while (true) {
        const p0 = randomPrime(bits - bits / 2);
        const q0 = randomPrime(bits / 2);
        if (p0.eql(q0)) continue;
        // p > q, as usual for the CRT coefficient
        const p = if (p0.compare(q0) == .gt) p0 else q0;
        const q = if (p0.compare(q0) == .gt) q0 else p0;
        const n = mul(p, q);
        if (n.bitLenPublic() != bits) continue;
        const pm1 = minusOne(p);
        const qm1 = minusOne(q);
        const phi = mul(pm1, qm1);
        const d = inverseOfE(phi);
        const dp = inverseOfE(pm1);
        const dq = inverseOfE(qm1);
        // q^-1 mod p = q^(p-2) mod p
        const mp = M.fromUint(p) catch continue;
        var pb: [max_bits / 8]u8 = undefined;
        var pm2 = pm1;
        _ = pm2.subWithOverflow(U.fromPrimitive(u8, 1) catch unreachable);
        pm2.toBytes(&pb, .big) catch unreachable;
        var qb: [max_bits / 8]u8 = undefined;
        q.toBytes(&qb, .big) catch unreachable;
        const qfe = M.Fe.fromBytes(mp, &qb, .big) catch continue; // q < p
        const qinv_fe = mp.powWithEncodedExponent(qfe, &pb, .big) catch continue;
        var qinv_b: [max_bits / 8]u8 = @splat(0);
        qinv_fe.toBytes(qinv_b[0..], .big) catch continue;
        const qinv = fromBytes(&qinv_b);

        var rsa_pub: std.ArrayList(u8) = .empty;
        defer rsa_pub.deinit(pa);
        derInt(&rsa_pub, n);
        derInt(&rsa_pub, e);
        var pub_seq: std.ArrayList(u8) = .empty;
        defer pub_seq.deinit(pa);
        derTlv(&pub_seq, 0x30, rsa_pub.items);
        var bitstr: std.ArrayList(u8) = .empty;
        defer bitstr.deinit(pa);
        bitstr.append(pa, 0) catch @panic("oom");
        bitstr.appendSlice(pa, pub_seq.items) catch @panic("oom");
        var spki_c: std.ArrayList(u8) = .empty;
        defer spki_c.deinit(pa);
        spki_c.appendSlice(pa, &rsa_algorithm) catch @panic("oom");
        derTlv(&spki_c, 0x03, bitstr.items);
        var spki: std.ArrayList(u8) = .empty;
        derTlv(&spki, 0x30, spki_c.items);

        var rsa_priv: std.ArrayList(u8) = .empty;
        defer rsa_priv.deinit(pa);
        derTlv(&rsa_priv, 0x02, &.{0});
        for ([_]U{ n, e, d, p, q, dp, dq, qinv }) |x| derInt(&rsa_priv, x);
        var priv_seq: std.ArrayList(u8) = .empty;
        defer priv_seq.deinit(pa);
        derTlv(&priv_seq, 0x30, rsa_priv.items);
        var p8_c: std.ArrayList(u8) = .empty;
        defer p8_c.deinit(pa);
        derTlv(&p8_c, 0x02, &.{0});
        p8_c.appendSlice(pa, &rsa_algorithm) catch @panic("oom");
        derTlv(&p8_c, 0x04, priv_seq.items);
        var p8: std.ArrayList(u8) = .empty;
        derTlv(&p8, 0x30, p8_c.items);
        return .{ .public = spki.items, .private = p8.items };
    }
}

/// n and e of a SubjectPublicKeyInfo
fn parsePublic(der: []const u8) Error!struct { n: []const u8, e: []const u8 } {
    var top = Der{ .b = der };
    var spki = Der{ .b = try top.next(0x30) };
    _ = try spki.next(0x30); // the algorithm
    const bits = try spki.next(0x03);
    if (bits.len < 1 or bits[0] != 0) return error.BadKey;
    var k = Der{ .b = bits[1..] };
    var seq = Der{ .b = try k.next(0x30) };
    const n = try seq.int();
    const e = try seq.int();
    return .{ .n = n, .e = e };
}

/// n and d of a PKCS#8 private key
fn parsePrivate(der: []const u8) Error!struct { n: []const u8, d: []const u8 } {
    var top = Der{ .b = der };
    var p8 = Der{ .b = try top.next(0x30) };
    _ = try p8.int(); // version
    _ = try p8.next(0x30); // the algorithm
    var k = Der{ .b = try p8.next(0x04) };
    var seq = Der{ .b = try k.next(0x30) };
    _ = try seq.int(); // version
    const n = try seq.int();
    _ = try seq.int(); // e
    const d = try seq.int();
    return .{ .n = n, .d = d };
}

// --- OAEP --------------------------------------------------------------------------

fn mgf1(seed: []const u8, mask: []u8) void {
    var counter: u32 = 0;
    var done: usize = 0;
    while (done < mask.len) : (counter += 1) {
        var h = Sha256.init(.{});
        h.update(seed);
        var c: [4]u8 = undefined;
        std.mem.writeInt(u32, &c, counter, .big);
        h.update(&c);
        var out: [32]u8 = undefined;
        h.final(&out);
        const n = @min(32, mask.len - done);
        for (0..n) |i| mask[done + i] ^= out[i];
        done += n;
    }
}

const empty_label_hash = blk: {
    @setEvalBranchQuota(100000);
    var h: [32]u8 = undefined;
    Sha256.hash("", &h, .{});
    break :blk h;
};

pub fn encrypt(public_der: []const u8, msg: []const u8) Error![]u8 {
    const key = parsePublic(public_der) catch {
        last_error = "java.security.InvalidKeyException: invalid key format";
        return error.BadKey;
    };
    const m = M.fromBytes(key.n, .big) catch {
        last_error = "java.security.InvalidKeyException: invalid key format";
        return error.BadKey;
    };
    const k = key.n.len;
    if (k < 2 * 32 + 2 or msg.len > k - 2 * 32 - 2) {
        last_error = std.fmt.allocPrint(pa, "Data must not be longer than {d} bytes", .{if (k >= 66) k - 66 else 0}) catch "Data too long";
        return error.MessageTooLong;
    }
    // EM = 0x00 || maskedSeed || maskedDB
    const em = try pa.alloc(u8, k);
    defer pa.free(em);
    @memset(em, 0);
    const seed = em[1..33];
    const db = em[33..];
    @memcpy(db[0..32], &empty_label_hash);
    db[db.len - msg.len - 1] = 1;
    @memcpy(db[db.len - msg.len ..], msg);
    randomBytes(seed);
    mgf1(seed, db);
    mgf1(db, seed);
    const x = M.Fe.fromBytes(m, em, .big) catch return error.BadKey;
    const c = m.powWithEncodedPublicExponent(x, key.e, .big) catch return error.BadKey;
    const out = try pa.alloc(u8, k);
    c.toBytes(out, .big) catch return error.BadKey;
    return out;
}

pub fn decrypt(private_der: []const u8, ct: []const u8) Error![]u8 {
    const key = parsePrivate(private_der) catch {
        last_error = "java.security.InvalidKeyException: invalid key format";
        return error.BadKey;
    };
    const m = M.fromBytes(key.n, .big) catch {
        last_error = "java.security.InvalidKeyException: invalid key format";
        return error.BadKey;
    };
    const k = key.n.len;
    if (ct.len > k) {
        last_error = std.fmt.allocPrint(pa, "Data must not be longer than {d} bytes", .{k}) catch "Data too long";
        return error.DecryptionError;
    }
    last_error = "Padding error in decryption";
    const x = M.Fe.fromBytes(m, ct, .big) catch return error.DecryptionError;
    const y = m.powWithEncodedExponent(x, key.d, .big) catch return error.DecryptionError;
    const em = try pa.alloc(u8, k);
    defer pa.free(em);
    y.toBytes(em, .big) catch return error.DecryptionError;
    const seed = em[1..33];
    const db = em[33..];
    mgf1(db, seed);
    mgf1(seed, db);
    if (em[0] != 0 or !std.mem.eql(u8, db[0..32], &empty_label_hash)) return error.DecryptionError;
    var i: usize = 32;
    while (i < db.len and db[i] == 0) i += 1;
    if (i == db.len or db[i] != 1) return error.DecryptionError;
    return pa.dupe(u8, db[i + 1 ..]);
}
