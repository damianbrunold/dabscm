//! Primitives: hashes, MACs, key derivation, ciphers and random bytes
//! ((scm crypto), (srfi 271)), over std.crypto, with the JVM
//! implementation's conventions (strings hashed as UTF-8, PKCS#7 padding
//! for AES-CBC and AES-ECB, 128-bit tags appended for the AEADs).
//! RSA comes with the TLS library (Phase 6).
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const os = @import("os.zig");
const ports = @import("ports.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;
const unfix = rt.unfix;
const crypto = std.crypto;

const pa = std.heap.c_allocator;

fn msg(comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(pa, fmt, args) catch rt.oom();
}

fn bytesResult(t: *Thread, bytes: []const u8) Word {
    t.reserve(data.bvWords(bytes.len));
    const bv = data.makeBytevector(t, bytes.len);
    @memcpy(data.bvBytes(bv), bytes);
    return bv;
}

fn hexResult(t: *Thread, bytes: []const u8) Word {
    var buf: [128]u8 = undefined;
    const digits = "0123456789abcdef";
    for (bytes, 0..) |b, i| {
        buf[2 * i] = digits[b >> 4];
        buf[2 * i + 1] = digits[b & 15];
    }
    const s = buf[0 .. 2 * bytes.len];
    t.reserve(data.stringWords(s.len, false));
    const str = data.makeString(t, s.len, false);
    for (s, 0..) |c, i| data.stringSetFits(str, i, c);
    return str;
}

fn bvArg(t: *Thread, i: usize) Err![]const u8 {
    const w = arg(t, i);
    if (!data.isBytevector(w)) return P.argTypeError(t);
    return data.bvBytes(w);
}

/// The bytes to hash: strings and symbols as UTF-8, bytevectors as they are
fn hashInput(t: *Thread, who: []const u8, any: bool) Err![]const u8 {
    const x = arg(t, 0);
    if (data.isString(x)) return data.toUtf8(x);
    if (data.isSymbol(x)) return data.symbolName(x);
    if (data.isBytevector(x)) return data.bvBytes(x);
    if (any) {
        var b: std.ArrayList(u8) = .empty;
        @import("printer.zig").print(&b, x, false);
        return b.items;
    }
    return raise(t, msg("{s}: cannot hash value", .{who}), &.{});
}

fn intArg(t: *Thread, i: usize) Err!i64 {
    const w = arg(t, i);
    if (!rt.isFix(w)) return raise(t, "value out of range: ~s", &.{w});
    return unfix(w);
}

// --- hashes -----------------------------------------------------------------------------

fn sha256Hash(t: *Thread) Err!Word {
    var out: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(try hashInput(t, "sha256-hash", false), &out, .{});
    return bytesResult(t, &out);
}
pub const @"%sha256-hash" = WN("sha256-hash", sha256Hash, 1, 1);

fn sha2Hash(comptime H: type, comptime who: []const u8) fn (*Thread) Err!Word {
    return struct {
        fn f(t: *Thread) Err!Word {
            var out: [H.digest_length]u8 = undefined;
            H.hash(try hashInput(t, who, false), &out, .{});
            return bytesResult(t, &out);
        }
    }.f;
}
pub const @"%sha224-hash" = WN("sha224-hash", sha2Hash(crypto.hash.sha2.Sha224, "sha224-hash"), 1, 1);
pub const @"%sha384-hash" = WN("sha384-hash", sha2Hash(crypto.hash.sha2.Sha384, "sha384-hash"), 1, 1);
pub const @"%sha512-hash" = WN("sha512-hash", sha2Hash(crypto.hash.sha2.Sha512, "sha512-hash"), 1, 1);

fn sha1Hash(t: *Thread) Err!Word {
    var out: [20]u8 = undefined;
    crypto.hash.Sha1.hash(try hashInput(t, "sha1-hash", true), &out, .{});
    return hexResult(t, &out);
}
pub const @"%sha1-hash" = WN("sha1-hash", sha1Hash, 1, 1);

fn md5Hash(t: *Thread) Err!Word {
    var out: [16]u8 = undefined;
    crypto.hash.Md5.hash(try hashInput(t, "md5-hash", false), &out, .{});
    return hexResult(t, &out);
}
pub const @"%md5-hash" = WN("md5-hash", md5Hash, 1, 1);

fn sha256File(t: *Thread) Err!Word {
    const path = data.toUtf8(try P.stringArg(t, 0));
    const bytes = os.readFile(path) orelse
        return raise(t, msg("sha256-file: {s}", .{path}), &.{});
    defer pa.free(bytes);
    var out: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(bytes, &out, .{});
    return bytesResult(t, &out);
}
pub const @"%sha256-file" = WN("sha256-file", sha256File, 1, 1);

fn hmacSha256(t: *Thread) Err!Word {
    const key = try bvArg(t, 0);
    const m = try bvArg(t, 1);
    var out: [32]u8 = undefined;
    crypto.auth.hmac.sha2.HmacSha256.create(&out, m, key);
    return bytesResult(t, &out);
}
pub const @"%hmac-sha256" = WN("hmac-sha256", hmacSha256, 2, 2);

// --- key derivation -------------------------------------------------------------------------

fn passwordArg(t: *Thread) Err![]const u8 {
    const x = arg(t, 0);
    if (data.isString(x)) return data.toUtf8(x);
    return bvArg(t, 0);
}

fn pbkdf2Sha256(t: *Thread) Err!Word {
    const password = try passwordArg(t);
    const salt = try bvArg(t, 1);
    const iterations = try intArg(t, 2);
    const length = try intArg(t, 3);
    if (iterations < 1 or length < 1) return raise(t, "pbkdf2-sha256: Iteration count and key length must be positive", &.{});
    const dk = pa.alloc(u8, @intCast(length)) catch rt.oom();
    defer pa.free(dk);
    crypto.pwhash.pbkdf2(dk, password, salt, @intCast(iterations), crypto.auth.hmac.sha2.HmacSha256) catch
        return raise(t, "pbkdf2-sha256: invalid parameters", &.{});
    return bytesResult(t, dk);
}
pub const @"%pbkdf2-sha256" = WN("pbkdf2-sha256", pbkdf2Sha256, 4, 4);

fn scrypt(t: *Thread) Err!Word {
    const password = try passwordArg(t);
    const salt = try bvArg(t, 1);
    const n = try intArg(t, 2);
    const r = try intArg(t, 3);
    const p = try intArg(t, 4);
    const length = try intArg(t, 5);
    if (n < 2 or (n & (n - 1)) != 0) return raise(t, "scrypt: n must be a power of 2 greater than 1", &.{});
    if (r < 1 or p < 1 or length < 1) return raise(t, "scrypt: r, p and length must be positive", &.{});
    if (128 * r * n > (1 << 30) or 128 * r * p > std.math.maxInt(i32)) return raise(t, "scrypt: parameters need too much memory", &.{});
    const dk = pa.alloc(u8, @intCast(length)) catch rt.oom();
    defer pa.free(dk);
    crypto.pwhash.scrypt.kdf(pa, dk, password, salt, .{ .ln = @intCast(std.math.log2_int(u64, @intCast(n))), .r = @intCast(r), .p = @intCast(p) }) catch
        return raise(t, "scrypt: invalid parameters", &.{});
    return bytesResult(t, dk);
}
pub const @"%scrypt" = WN("scrypt", scrypt, 6, 6);

// --- random bytes ---------------------------------------------------------------------------

fn randomBytes(t: *Thread) Err!Word {
    const n = try intArg(t, 0);
    if (n < 0) return raise(t, "random-bytes: negative length", &.{});
    try P.reserveObject(t, "random-bytes", data.bvWords(@intCast(n)));
    const bv = data.makeBytevector(t, @intCast(n));
    os.randomBytes(data.bvBytes(bv));
    return bv;
}
pub const @"%random-bytes" = WN("random-bytes", randomBytes, 1, 1);

fn xorKey(t: *Thread) Err!Word {
    const v = try bvArg(t, 0);
    _ = try bvArg(t, 1);
    t.reserve(data.bvWords(v.len));
    const bv = data.makeBytevector(t, v.len);
    const vv = data.bvBytes(arg(t, 0));
    const kk = data.bvBytes(arg(t, 1));
    for (data.bvBytes(bv), 0..) |*b, i| b.* = vv[i] ^ (if (kk.len == 0) 0 else kk[i % kk.len]);
    return bv;
}
pub const @"%xor-key" = WN("xor-key", xorKey, 2, 2);

// --- AES -------------------------------------------------------------------------------------

const Aes = union(enum) {
    a128: struct { enc: crypto.core.aes.AesEncryptCtx(crypto.core.aes.Aes128), dec: crypto.core.aes.AesDecryptCtx(crypto.core.aes.Aes128) },
    a256: struct { enc: crypto.core.aes.AesEncryptCtx(crypto.core.aes.Aes256), dec: crypto.core.aes.AesDecryptCtx(crypto.core.aes.Aes256) },
    /// std.crypto has no AES-192
    a192: @import("aes192.zig").Ctx,

    fn init(key: []const u8) ?Aes {
        if (key.len == 16) return .{ .a128 = .{ .enc = crypto.core.aes.Aes128.initEnc(key[0..16].*), .dec = crypto.core.aes.Aes128.initDec(key[0..16].*) } };
        if (key.len == 32) return .{ .a256 = .{ .enc = crypto.core.aes.Aes256.initEnc(key[0..32].*), .dec = crypto.core.aes.Aes256.initDec(key[0..32].*) } };
        if (key.len == 24) return .{ .a192 = @import("aes192.zig").Ctx.init(key[0..24].*) };
        return null;
    }
    fn encrypt(a: *const Aes, dst: *[16]u8, src: *const [16]u8) void {
        switch (a.*) {
            .a192 => |*c| c.encrypt(dst, src),
            inline else => |*c| c.enc.encrypt(dst, src),
        }
    }
    fn decrypt(a: *const Aes, dst: *[16]u8, src: *const [16]u8) void {
        switch (a.*) {
            .a192 => |*c| c.decrypt(dst, src),
            inline else => |*c| c.dec.decrypt(dst, src),
        }
    }
};

fn aesKey(t: *Thread, who: []const u8, key: []const u8) Err!Aes {
    return Aes.init(key) orelse raise(t, msg("{s}: Invalid AES key length: {d} bytes", .{ who, key.len }), &.{});
}

/// PKCS#7-padded copy of m
fn padded(m: []const u8) []u8 {
    const n = (m.len / 16 + 1) * 16;
    const out = pa.alloc(u8, n) catch rt.oom();
    @memcpy(out[0..m.len], m);
    @memset(out[m.len..], @intCast(n - m.len));
    return out;
}

fn unpad(t: *Thread, who: []const u8, b: []u8) Err![]u8 {
    const bad = msg("{s}: Given final block not properly padded. Such issues can arise if a bad key is used during decryption.", .{who});
    if (b.len == 0) return raise(t, bad, &.{});
    const k = b[b.len - 1];
    if (k == 0 or k > 16 or k > b.len) return raise(t, bad, &.{});
    for (b[b.len - k ..]) |x| if (x != k) return raise(t, bad, &.{});
    return b[0 .. b.len - k];
}

fn cbc(t: *Thread, comptime decrypting: bool) Err!Word {
    const who = if (decrypting) "aes-cbc-decrypt" else "aes-cbc-encrypt";
    const a = try aesKey(t, who, try bvArg(t, 0));
    const iv = try bvArg(t, 1);
    if (iv.len != 16) return raise(t, msg("{s}: Wrong IV length: must be 16 bytes long", .{who}), &.{});
    const input = try bvArg(t, 2);
    var prev: [16]u8 = iv[0..16].*;
    if (!decrypting) {
        const buf = padded(input);
        defer pa.free(buf);
        var i: usize = 0;
        while (i < buf.len) : (i += 16) {
            var x: [16]u8 = undefined;
            for (0..16) |k| x[k] = buf[i + k] ^ prev[k];
            a.encrypt(buf[i..][0..16], &x);
            prev = buf[i..][0..16].*;
        }
        return bytesResult(t, buf);
    }
    if (input.len % 16 != 0 or input.len == 0)
        return raise(t, msg("{s}: Input length must be multiple of 16 when decrypting with padded cipher", .{who}), &.{});
    const buf = pa.alloc(u8, input.len) catch rt.oom();
    defer pa.free(buf);
    var i: usize = 0;
    while (i < input.len) : (i += 16) {
        var x: [16]u8 = undefined;
        a.decrypt(&x, input[i..][0..16]);
        for (0..16) |k| buf[i + k] = x[k] ^ prev[k];
        prev = input[i..][0..16].*;
    }
    return bytesResult(t, try unpad(t, who, buf));
}
fn aesCbcEncrypt(t: *Thread) Err!Word {
    return cbc(t, false);
}
fn aesCbcDecrypt(t: *Thread) Err!Word {
    return cbc(t, true);
}
pub const @"%aes-cbc-encrypt" = WN("aes-cbc-encrypt", aesCbcEncrypt, 3, 3);
pub const @"%aes-cbc-decrypt" = WN("aes-cbc-decrypt", aesCbcDecrypt, 3, 3);

fn ecb(t: *Thread, comptime decrypting: bool) Err!Word {
    const who = if (decrypting) "aes-ecb-decrypt" else "aes-ecb-encrypt";
    const a = try aesKey(t, who, try bvArg(t, 0));
    const input = try bvArg(t, 1);
    if (!decrypting) {
        const buf = padded(input);
        defer pa.free(buf);
        var i: usize = 0;
        while (i < buf.len) : (i += 16) {
            const x: [16]u8 = buf[i..][0..16].*;
            a.encrypt(buf[i..][0..16], &x);
        }
        return bytesResult(t, buf);
    }
    if (input.len % 16 != 0 or input.len == 0)
        return raise(t, msg("{s}: Input length must be multiple of 16 when decrypting with padded cipher", .{who}), &.{});
    const buf = pa.alloc(u8, input.len) catch rt.oom();
    defer pa.free(buf);
    var i: usize = 0;
    while (i < input.len) : (i += 16) a.decrypt(buf[i..][0..16], input[i..][0..16]);
    return bytesResult(t, try unpad(t, who, buf));
}
fn aesEcbEncrypt(t: *Thread) Err!Word {
    return ecb(t, false);
}
fn aesEcbDecrypt(t: *Thread) Err!Word {
    return ecb(t, true);
}
pub const @"%aes-ecb-encrypt" = WN("aes-ecb-encrypt", aesEcbEncrypt, 2, 2);
pub const @"%aes-ecb-decrypt" = WN("aes-ecb-decrypt", aesEcbDecrypt, 2, 2);

// --- AEADs (tag appended to the ciphertext) ----------------------------------------------------

fn aead(t: *Thread, comptime A: type, comptime who: []const u8, comptime decrypting: bool) Err!Word {
    const key = try bvArg(t, 0);
    const nonce = try bvArg(t, 1);
    const input = try bvArg(t, 2);
    const ad: []const u8 = if (t.argc > 3) try bvArg(t, 3) else &.{};
    if (key.len != A.key_length) return raise(t, msg(who ++ ": Invalid key length: {d} bytes", .{key.len}), &.{});
    if (nonce.len != A.nonce_length) return raise(t, msg(who ++ ": nonce must be {d} bytes", .{A.nonce_length}), &.{});
    if (!decrypting) {
        const out = pa.alloc(u8, input.len + A.tag_length) catch rt.oom();
        defer pa.free(out);
        A.encrypt(out[0..input.len], out[input.len..][0..A.tag_length], input, ad, nonce[0..A.nonce_length].*, key[0..A.key_length].*);
        return bytesResult(t, out);
    }
    if (input.len < A.tag_length) return raise(t, who ++ ": authentication tag mismatch", &.{});
    const n = input.len - A.tag_length;
    const out = pa.alloc(u8, n) catch rt.oom();
    defer pa.free(out);
    A.decrypt(out, input[0..n], input[n..][0..A.tag_length].*, ad, nonce[0..A.nonce_length].*, key[0..A.key_length].*) catch
        return raise(t, who ++ ": authentication tag mismatch", &.{});
    return bytesResult(t, out);
}

/// AES-GCM with a 16- or 32-byte key
fn gcm(t: *Thread, comptime decrypting: bool) Err!Word {
    const who = if (decrypting) "aes-gcm-decrypt" else "aes-gcm-encrypt";
    const key = try bvArg(t, 0);
    return switch (key.len) {
        16 => aead(t, crypto.aead.aes_gcm.Aes128Gcm, who, decrypting),
        32 => aead(t, crypto.aead.aes_gcm.Aes256Gcm, who, decrypting),
        else => raise(t, msg("{s}: Invalid AES key length: {d} bytes", .{ who, key.len }), &.{}),
    };
}
fn aesGcmEncrypt(t: *Thread) Err!Word {
    return gcm(t, false);
}
fn aesGcmDecrypt(t: *Thread) Err!Word {
    return gcm(t, true);
}
pub const @"%aes-gcm-encrypt" = WN("aes-gcm-encrypt", aesGcmEncrypt, 3, 4);
pub const @"%aes-gcm-decrypt" = WN("aes-gcm-decrypt", aesGcmDecrypt, 3, 4);

fn chachaEncrypt(t: *Thread) Err!Word {
    return aead(t, crypto.aead.chacha_poly.ChaCha20Poly1305, "chacha20poly1305-encrypt", false);
}
fn chachaDecrypt(t: *Thread) Err!Word {
    return aead(t, crypto.aead.chacha_poly.ChaCha20Poly1305, "chacha20poly1305-decrypt", true);
}
pub const @"%chacha20poly1305-encrypt" = WN("chacha20poly1305-encrypt", chachaEncrypt, 3, 4);
pub const @"%chacha20poly1305-decrypt" = WN("chacha20poly1305-decrypt", chachaDecrypt, 3, 4);

// --- random ports (SRFI 271) ---------------------------------------------------------------

const TAG_CHACHA: u8 = 1;
const TAG_SECURE: u8 = 2;

/// ChaCha20 keystream with the original layout (64-bit block counter,
/// 64-bit nonce fixed at zero), from byte offset of block counter
const ChaCha = struct {
    key: [32]u8,
    counter: u64, // of the next block to generate
    offset: u8, // bytes of the first block to skip
    start_counter: u64,
    start_offset: u8,

    fn block(c: *const ChaCha, out: *[64]u8, counter: u64) void {
        var input: [16]u32 = undefined;
        input[0] = 0x61707865;
        input[1] = 0x3320646e;
        input[2] = 0x79622d32;
        input[3] = 0x6b206574;
        for (0..8) |i| input[4 + i] = std.mem.readInt(u32, c.key[4 * i ..][0..4], .little);
        input[12] = @truncate(counter);
        input[13] = @truncate(counter >> 32);
        input[14] = 0;
        input[15] = 0;
        var x = input;
        for (0..10) |_| {
            qr(&x, 0, 4, 8, 12);
            qr(&x, 1, 5, 9, 13);
            qr(&x, 2, 6, 10, 14);
            qr(&x, 3, 7, 11, 15);
            qr(&x, 0, 5, 10, 15);
            qr(&x, 1, 6, 11, 12);
            qr(&x, 2, 7, 8, 13);
            qr(&x, 3, 4, 9, 14);
        }
        for (0..16) |i| std.mem.writeInt(u32, out[4 * i ..][0..4], x[i] +% input[i], .little);
    }

    fn qr(x: *[16]u32, a: usize, b: usize, c: usize, d: usize) void {
        x[a] +%= x[b];
        x[d] = std.math.rotl(u32, x[d] ^ x[a], 16);
        x[c] +%= x[d];
        x[b] = std.math.rotl(u32, x[b] ^ x[c], 12);
        x[a] +%= x[b];
        x[d] = std.math.rotl(u32, x[d] ^ x[a], 8);
        x[c] +%= x[d];
        x[b] = std.math.rotl(u32, x[b] ^ x[c], 7);
    }

    fn generate(state: *anyopaque, buf: []u8) void {
        const c: *ChaCha = @ptrCast(@alignCast(state));
        var i: usize = 0;
        while (i < buf.len) {
            var b: [64]u8 = undefined;
            c.block(&b, c.counter);
            const avail = b[c.offset..];
            const n = @min(avail.len, buf.len - i);
            @memcpy(buf[i .. i + n], avail[0..n]);
            i += n;
            if (n == avail.len) {
                c.counter +%= 1;
                c.offset = 0;
            } else c.offset += @intCast(n);
        }
    }
};

fn makeChacha20Port(t: *Thread) Err!Word {
    const k = arg(t, 0);
    if (!data.isBytevector(k) or data.bvLen(k) != 32) return raise(t, "make-chacha20-port: key must be a bytevector of length 32", &.{});
    const counter = arg(t, 1);
    if (!rt.isFix(counter) or unfix(counter) < 0) return raise(t, "make-chacha20-port: counter must be an exact integer in 0..2^63-1", &.{});
    const offset = arg(t, 2);
    if (!rt.isFix(offset) or unfix(offset) < 0 or unfix(offset) > 63) return raise(t, "make-chacha20-port: offset must be an exact integer in 0..63", &.{});
    const c = pa.create(ChaCha) catch rt.oom();
    c.* = .{
        .key = data.bvBytes(k)[0..32].*,
        .counter = @intCast(unfix(counter)),
        .offset = @intCast(unfix(offset)),
        .start_counter = @intCast(unfix(counter)),
        .start_offset = @intCast(unfix(offset)),
    };
    const p = ports.newPort(.generator, true);
    p.gen = &ChaCha.generate;
    p.gen_state = c;
    p.tag = TAG_CHACHA;
    t.reserve(2);
    return ports.wrap(t, p);
}
pub const @"%make-chacha20-port" = WN("make-chacha20-port", makeChacha20Port, 3, 3);

fn portTagged(w: Word, tag: u8) ?*ports.Port {
    const p = ports.get(w) orelse return null;
    return if (p.kind == .generator and p.tag == tag) p else null;
}

fn chacha20PortP(t: *Thread) Err!Word {
    return rt.boolean(portTagged(arg(t, 0), TAG_CHACHA) != null);
}
pub const @"%chacha20-port?" = WD("chacha20-port?", chacha20PortP, 1, 1);

/// #(key counter offset): the position of the next byte to be read
fn chacha20PortState(t: *Thread) Err!Word {
    const p = portTagged(arg(t, 0), TAG_CHACHA) orelse return raise(t, "chacha20-port-state: not a ChaCha20 port", &.{});
    const c: *ChaCha = @ptrCast(@alignCast(p.gen_state.?));
    const total = c.start_counter * 64 + c.start_offset + p.consumed();
    t.reserve(data.bvWords(32) + 4);
    const key = data.makeBytevector(t, 32);
    @memcpy(data.bvBytes(key), &c.key);
    const v = data.makeVector(t, 3, rt.FALSE);
    data.vectorItems(v)[0] = key;
    data.vectorItems(v)[1] = fix(@intCast(total / 64));
    data.vectorItems(v)[2] = fix(@intCast(total % 64));
    return v;
}
pub const @"%chacha20-port-state" = WN("chacha20-port-state", chacha20PortState, 1, 1);

fn secureGenerate(_: *anyopaque, buf: []u8) void {
    os.randomBytes(buf);
}

var secure_state: u8 = 0;

fn makeSecureRandomPort(t: *Thread) Err!Word {
    const p = ports.newPort(.generator, true);
    p.gen = &secureGenerate;
    p.gen_state = &secure_state;
    p.tag = TAG_SECURE;
    t.reserve(2);
    return ports.wrap(t, p);
}
pub const @"%make-secure-random-port" = WN("make-secure-random-port", makeSecureRandomPort, 0, 0);

fn secureRandomPortP(t: *Thread) Err!Word {
    return rt.boolean(portTagged(arg(t, 0), TAG_SECURE) != null);
}
pub const @"%secure-random-port?" = WD("secure-random-port?", secureRandomPortP, 1, 1);

// --- RSA (rsa.zig) ------------------------------------------------------------------

const rsa = @import("rsa.zig");

fn rsaGenerate(t: *Thread) Err!Word {
    const bits = arg(t, 0);
    if (!rt.isFix(bits)) return P.argTypeError(t);
    const kp = rsa.generate(@intCast(@max(0, rt.unfix(bits)))) catch
        return raise(t, msg("rsa-generate-keypair: {s}", .{rsa.last_error}), &.{});
    t.reserve(data.bvWords(kp.public.len) + data.bvWords(kp.private.len) + 6);
    const pub_bv = data.makeBytevector(t, kp.public.len);
    @memcpy(data.bvBytes(pub_bv), kp.public);
    const priv_bv = data.makeBytevector(t, kp.private.len);
    @memcpy(data.bvBytes(priv_bv), kp.private);
    return t.cons(pub_bv, t.cons(priv_bv, rt.NIL));
}
pub const @"%rsa-generate-keypair" = WN("rsa-generate-keypair", rsaGenerate, 1, 1);

fn rsaEncrypt(t: *Thread) Err!Word {
    const out = rsa.encrypt(try bvArg(t, 0), try bvArg(t, 1)) catch
        return raise(t, msg("rsa-encrypt: {s}", .{rsa.last_error}), &.{});
    defer pa.free(out);
    return bytesResult(t, out);
}
pub const @"%rsa-encrypt" = WN("rsa-encrypt", rsaEncrypt, 2, 2);

fn rsaDecrypt(t: *Thread) Err!Word {
    const out = rsa.decrypt(try bvArg(t, 0), try bvArg(t, 1)) catch
        return raise(t, msg("rsa-decrypt: {s}", .{rsa.last_error}), &.{});
    defer pa.free(out);
    return bytesResult(t, out);
}
pub const @"%rsa-decrypt" = WN("rsa-decrypt", rsaDecrypt, 2, 2);
