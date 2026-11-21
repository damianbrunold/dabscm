//! Primitives: the image codec ((scm image)); see image.zig.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const P = @import("prims.zig");
const image = @import("image.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;
const unfix = rt.unfix;

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

fn bvArg(t: *Thread, i: usize) Err![]const u8 {
    const w = arg(t, i);
    if (!data.isBytevector(w)) return P.argTypeError(t);
    return data.bvBytes(w);
}

/// A Java long argument
fn longArg(t: *Thread, i: usize) Err!i64 {
    const w = arg(t, i);
    if (!rt.isFix(w)) return P.argTypeError(t);
    return unfix(w);
}

/// A Java (int) (long) argument
fn intArg(t: *Thread, i: usize) Err!i32 {
    return @truncate(try longArg(t, i));
}

/// The primitive's error for an image.zig error
fn imageError(t: *Thread, comptime who: []const u8, e: image.Error) Err {
    return switch (e) {
        error.OutOfMemory => rt.oom(),
        error.Image => raise(t, msg(who ++ ": {s}", .{image.last_error}), &.{}),
        error.Malformed => raise(t, who ++ ": truncated or malformed image", &.{}),
    };
}

fn imageDecodeRgba(t: *Thread) Err!Word {
    const bytes = try bvArg(t, 0);
    const max = try longArg(t, 1);
    const img = image.decode(bytes, max) catch |e| return imageError(t, "image-decode", e);
    defer pa.free(img.rgba);
    t.reserve(data.bvWords(img.rgba.len) + 9);
    const bv = data.makeBytevector(t, img.rgba.len);
    @memcpy(data.bvBytes(bv), img.rgba);
    var l = t.cons(bv, rt.NIL);
    l = t.cons(fix(img.height), l);
    return t.cons(fix(img.width), l);
}
pub const @"%image-decode-rgba" = WN("image-decode-rgba", imageDecodeRgba, 2, 2);

fn imageOrientRgba(t: *Thread) Err!Word {
    const px = try bvArg(t, 0);
    const w = try intArg(t, 1);
    const h = try intArg(t, 2);
    const o = try intArg(t, 3);
    if (@as(i64, @intCast(px.len)) < @as(i64, w) * h * 4) return raise(t, "image-orient: too few pixels", &.{});
    const out = image.orient(px, w, h, o) catch |e| return imageError(t, "image-orient", e);
    defer pa.free(out);
    return bytesResult(t, out);
}
pub const @"%image-orient-rgba" = WN("image-orient-rgba", imageOrientRgba, 4, 4);

fn imageResizeRgba(t: *Thread) Err!Word {
    const px = try bvArg(t, 0);
    const w = try intArg(t, 1);
    const h = try intArg(t, 2);
    const nw = try intArg(t, 3);
    const nh = try intArg(t, 4);
    const m = arg(t, 5);
    if (!data.isSymbol(m)) return P.argTypeError(t);
    const name = data.symbolName(m);
    const method: i32 = if (std.mem.eql(u8, name, "box")) 0 else if (std.mem.eql(u8, name, "bilinear")) 1 else return raise(t, msg("image-resize: unknown method {s} (box or bilinear)", .{name}), &.{});
    const out = image.resize(px, w, h, nw, nh, method) catch |e| return imageError(t, "image-resize", e);
    defer pa.free(out);
    return bytesResult(t, out);
}
pub const @"%image-resize-rgba" = WN("image-resize-rgba", imageResizeRgba, 6, 6);

fn rgbaToJpeg(t: *Thread) Err!Word {
    const px = try bvArg(t, 0);
    const w = try intArg(t, 1);
    const h = try intArg(t, 2);
    const q = try intArg(t, 3);
    if (@as(i64, @intCast(px.len)) < @as(i64, w) * h * 4) return raise(t, "image->jpeg: too few pixels", &.{});
    const out = image.encodeJpeg(px, w, h, q) catch |e| return imageError(t, "image->jpeg", e);
    defer pa.free(out);
    return bytesResult(t, out);
}
pub const @"%rgba->jpeg" = WN("rgba->jpeg", rgbaToJpeg, 4, 4);

fn rgbaSplit(t: *Thread) Err!Word {
    const px0 = try bvArg(t, 0);
    const comps = try longArg(t, 1);
    if (comps != 1 and comps != 3) return raise(t, "rgba-split: components must be 1 or 3, got ~a", &.{arg(t, 1)});
    if (px0.len % 4 != 0) return raise(t, "rgba-split: pixel bytes not a multiple of 4", &.{});
    const n = px0.len / 4;
    const c: usize = @intCast(comps);
    var opaque_ = true;
    for (0..n) |i| {
        if (px0[i * 4 + 3] != 255) {
            opaque_ = false;
            break;
        }
    }
    t.reserve(data.bvWords(n * c) + (if (opaque_) 0 else data.bvWords(n)) + 6);
    const color = data.makeBytevector(t, n * c);
    const alpha = if (opaque_) rt.FALSE else data.makeBytevector(t, n);
    const px = data.bvBytes(arg(t, 0)); // after the reserve
    const cb = data.bvBytes(color);
    for (0..n) |i| {
        const s = i * 4;
        if (c == 3) {
            cb[i * 3] = px[s];
            cb[i * 3 + 1] = px[s + 1];
            cb[i * 3 + 2] = px[s + 2];
        } else {
            cb[i] = px[s];
        }
    }
    if (!opaque_) {
        const ab = data.bvBytes(alpha);
        for (0..n) |i| ab[i] = px[i * 4 + 3];
    }
    return t.cons(color, t.cons(alpha, rt.NIL));
}
pub const @"%rgba-split" = WN("rgba-split", rgbaSplit, 2, 2);
