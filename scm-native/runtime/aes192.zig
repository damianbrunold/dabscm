//! AES with a 192-bit key (FIPS-197; std.crypto has 128 and 256 only), for
//! the JVM implementation's AES-CBC and AES-ECB with 24-byte keys. A plain
//! byte-oriented implementation (12 rounds).
const std = @import("std");

const sbox = [256]u8{
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
};

const inv_sbox = blk: {
    var s: [256]u8 = undefined;
    for (0..256) |i| s[sbox[i]] = @intCast(i);
    break :blk s;
};

fn xtime(x: u8) u8 {
    return (x << 1) ^ (if (x & 0x80 != 0) @as(u8, 0x1b) else 0);
}

fn gmul(a: u8, b: u8) u8 {
    var r: u8 = 0;
    var x = a;
    var y = b;
    while (y != 0) : (y >>= 1) {
        if (y & 1 != 0) r ^= x;
        x = xtime(x);
    }
    return r;
}

const rounds = 12;

pub const Ctx = struct {
    w: [4 * (rounds + 1)][4]u8,

    pub fn init(key: [24]u8) Ctx {
        var c: Ctx = undefined;
        for (0..6) |i| c.w[i] = key[4 * i ..][0..4].*;
        var rcon: u8 = 1;
        var i: usize = 6;
        while (i < c.w.len) : (i += 1) {
            var tmp = c.w[i - 1];
            if (i % 6 == 0) {
                // (a new value: tmp is read while the result is built)
                const rotated = [4]u8{ sbox[tmp[1]] ^ rcon, sbox[tmp[2]], sbox[tmp[3]], sbox[tmp[0]] };
                tmp = rotated;
                rcon = xtime(rcon);
            }
            for (0..4) |j| c.w[i][j] = c.w[i - 6][j] ^ tmp[j];
        }
        return c;
    }

    fn addRoundKey(c: *const Ctx, s: *[16]u8, r: usize) void {
        for (0..4) |col| for (0..4) |row| {
            s[4 * col + row] ^= c.w[4 * r + col][row];
        };
    }

    pub fn encrypt(c: *const Ctx, dst: *[16]u8, src: *const [16]u8) void {
        var s = src.*;
        c.addRoundKey(&s, 0);
        for (1..rounds + 1) |r| {
            for (&s) |*b| b.* = sbox[b.*];
            // shift rows (column-major state: s[4*col + row])
            var t = s;
            for (0..4) |col| for (0..4) |row| {
                t[4 * col + row] = s[4 * ((col + row) % 4) + row];
            };
            s = t;
            if (r != rounds) {
                for (0..4) |col| {
                    const a = s[4 * col ..][0..4].*;
                    s[4 * col + 0] = xtime(a[0]) ^ (xtime(a[1]) ^ a[1]) ^ a[2] ^ a[3];
                    s[4 * col + 1] = a[0] ^ xtime(a[1]) ^ (xtime(a[2]) ^ a[2]) ^ a[3];
                    s[4 * col + 2] = a[0] ^ a[1] ^ xtime(a[2]) ^ (xtime(a[3]) ^ a[3]);
                    s[4 * col + 3] = (xtime(a[0]) ^ a[0]) ^ a[1] ^ a[2] ^ xtime(a[3]);
                }
            }
            c.addRoundKey(&s, r);
        }
        dst.* = s;
    }

    pub fn decrypt(c: *const Ctx, dst: *[16]u8, src: *const [16]u8) void {
        var s = src.*;
        c.addRoundKey(&s, rounds);
        var r: usize = rounds;
        while (r > 0) {
            r -= 1;
            // inverse shift rows
            var t = s;
            for (0..4) |col| for (0..4) |row| {
                t[4 * ((col + row) % 4) + row] = s[4 * col + row];
            };
            s = t;
            for (&s) |*b| b.* = inv_sbox[b.*];
            c.addRoundKey(&s, r);
            if (r != 0) {
                for (0..4) |col| {
                    const a = s[4 * col ..][0..4].*;
                    s[4 * col + 0] = gmul(a[0], 14) ^ gmul(a[1], 11) ^ gmul(a[2], 13) ^ gmul(a[3], 9);
                    s[4 * col + 1] = gmul(a[0], 9) ^ gmul(a[1], 14) ^ gmul(a[2], 11) ^ gmul(a[3], 13);
                    s[4 * col + 2] = gmul(a[0], 13) ^ gmul(a[1], 9) ^ gmul(a[2], 14) ^ gmul(a[3], 11);
                    s[4 * col + 3] = gmul(a[0], 11) ^ gmul(a[1], 13) ^ gmul(a[2], 9) ^ gmul(a[3], 14);
                }
            }
        }
        dst.* = s;
    }
};

test "FIPS-197 C.2" {
    const key = [24]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 };
    const pt = [16]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff };
    const expect = [16]u8{ 0xdd, 0xa9, 0x7c, 0xa4, 0x86, 0x4c, 0xdf, 0xe0, 0x6e, 0xaf, 0x70, 0xa0, 0xec, 0x0d, 0x71, 0x91 };
    const c = Ctx.init(key);
    var out: [16]u8 = undefined;
    c.encrypt(&out, &pt);
    try std.testing.expectEqualSlices(u8, &expect, &out);
    var back: [16]u8 = undefined;
    c.decrypt(&back, &out);
    try std.testing.expectEqualSlices(u8, &pt, &back);
}
