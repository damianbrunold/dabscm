//! Arithmetic. Phase 1: fixnums and flonums; bignums, rationals and complex
//! numbers come in Phase 2. The open-coded operations return null on a type
//! error or an overflow; the generated code then reports the error.
//! Operations that can produce a flonum need 2 reserved words.
const std = @import("std");
const rt = @import("rt.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const isFix = rt.isFix;

pub inline fn isNumber(w: Word) bool {
    return isFix(w) or rt.isFlonum(w);
}

pub inline fn toF(w: Word) ?f64 {
    if (isFix(w)) return @floatFromInt(rt.unfix(w));
    if (rt.isFlonum(w)) return rt.flo(w);
    return null;
}

pub inline fn add(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b)) {
        const r = @addWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
        if (r[1] == 0) return @bitCast(r[0]);
        return null;
    }
    return floOp(t, a, b, .add);
}

pub inline fn sub(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b)) {
        const r = @subWithOverflow(@as(i64, @bitCast(a)), @as(i64, @bitCast(b)));
        if (r[1] == 0) return @bitCast(r[0]);
        return null;
    }
    return floOp(t, a, b, .sub);
}

pub inline fn mul(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b)) {
        const r = @mulWithOverflow(rt.unfix(a), @as(i64, @bitCast(b)));
        if (r[1] == 0) return @bitCast(r[0]);
        return null;
    }
    return floOp(t, a, b, .mul);
}

const Op = enum { add, sub, mul, div };

noinline fn floOp(t: *Thread, a: Word, b: Word, comptime op: Op) ?Word {
    const x = toF(a) orelse return null;
    const y = toF(b) orelse return null;
    return t.makeFlo(switch (op) {
        .add => x + y,
        .sub => x - y,
        .mul => x * y,
        .div => x / y,
    });
}

pub inline fn div(t: *Thread, a: Word, b: Word) ?Word {
    if (isFix(a | b) and b != rt.fix(0)) {
        const x = rt.unfix(a);
        const y = rt.unfix(b);
        if (@rem(x, y) == 0) return rt.fix(@divTrunc(x, y));
        return null; // rationals: Phase 2
    }
    return floOp(t, a, b, .div);
}

pub const Cmp = enum { lt, gt, le, ge, eq };

pub inline fn cmp(a: Word, b: Word, comptime c: Cmp) ?bool {
    if (isFix(a | b)) {
        const x: i64 = @bitCast(a);
        const y: i64 = @bitCast(b);
        return switch (c) {
            .lt => x < y,
            .gt => x > y,
            .le => x <= y,
            .ge => x >= y,
            .eq => x == y,
        };
    }
    return cmpSlow(a, b, c);
}

noinline fn cmpSlow(a: Word, b: Word, comptime c: Cmp) ?bool {
    const x = toF(a) orelse return null;
    const y = toF(b) orelse return null;
    return switch (c) {
        .lt => x < y,
        .gt => x > y,
        .le => x <= y,
        .ge => x >= y,
        .eq => x == y,
    };
}

pub fn isInteger(w: Word) bool {
    if (isFix(w)) return true;
    if (rt.isFlonum(w)) {
        const f = rt.flo(w);
        return std.math.isFinite(f) and @floor(f) == f;
    }
    return false;
}

/// Shortest representation in the layout of Java's %.{15..17}g, as the
/// JVM implementation prints flonums: 1.5, 3.0, 1.0e+21, 1.0e-7, +inf.0
pub fn formatFlonum(buf: *std.ArrayList(u8), f: f64) void {
    const a = std.heap.page_allocator;
    if (std.math.isNan(f)) return buf.appendSlice(a, "+nan.0") catch rt.oom();
    if (std.math.isInf(f)) return buf.appendSlice(a, if (f > 0) "+inf.0" else "-inf.0") catch rt.oom();
    if (std.math.signbit(f)) buf.append(a, '-') catch rt.oom();
    const x = @abs(f);
    if (x == 0) return buf.appendSlice(a, "0.0") catch rt.oom();
    // shortest round-trip digits d1 d2 ... dn and the decimal exponent
    var tmp: [64]u8 = undefined;
    const sci = std.fmt.float.render(&tmp, x, .{ .mode = .scientific }) catch unreachable;
    const e_idx = std.mem.indexOfScalar(u8, sci, 'e').?;
    var digits: [24]u8 = undefined;
    var nd: usize = 0;
    for (sci[0..e_idx]) |ch| if (ch != '.') {
        digits[nd] = ch;
        nd += 1;
    };
    while (nd > 1 and digits[nd - 1] == '0') nd -= 1;
    const exp = std.fmt.parseInt(i32, sci[e_idx + 1 ..], 10) catch unreachable;
    const p: i32 = @intCast(@max(15, nd));
    if (exp < -4 or exp >= p) {
        buf.append(a, digits[0]) catch rt.oom();
        buf.append(a, '.') catch rt.oom();
        if (nd > 1) buf.appendSlice(a, digits[1..nd]) catch rt.oom() else buf.append(a, '0') catch rt.oom();
        var eb: [16]u8 = undefined;
        const es = std.fmt.bufPrint(&eb, "e{s}{d}", .{ if (exp >= 0) "+" else "-", @abs(exp) }) catch unreachable;
        buf.appendSlice(a, es) catch rt.oom();
    } else if (exp < 0) {
        buf.appendSlice(a, "0.") catch rt.oom();
        for (0..@intCast(-exp - 1)) |_| buf.append(a, '0') catch rt.oom();
        buf.appendSlice(a, digits[0..nd]) catch rt.oom();
    } else {
        const ip: usize = @intCast(exp + 1);
        for (0..ip) |i| buf.append(a, if (i < nd) digits[i] else '0') catch rt.oom();
        buf.append(a, '.') catch rt.oom();
        if (nd > ip) buf.appendSlice(a, digits[ip..nd]) catch rt.oom() else buf.append(a, '0') catch rt.oom();
    }
}
