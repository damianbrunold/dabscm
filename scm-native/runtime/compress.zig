//! Deflate compression (raw, zlib and gzip containers) and CRC-32, over
//! std.compress.flate. The rest of the runtime uses only this file, so a
//! vendored zlib could replace it (for byte-identical output with the JVM
//! implementation, whose Deflater is zlib).
const std = @import("std");
const flate = std.compress.flate;

const pa = std.heap.c_allocator;

pub const Container = flate.Container;

pub const Error = error{ OutOfMemory, BadData };

/// The message of the last decompression error, in zlib's words (as the
/// JVM implementation reports them)
pub var last_error: []const u8 = "invalid compressed data";

/// Compress data; level 0 stores, 1..9 as zlib's levels, -1 the default (6)
pub fn compress(data: []const u8, container: Container, level: i64) Error![]u8 {
    var out = std.Io.Writer.Allocating.initCapacity(pa, @max(64, data.len / 2 + 64)) catch return error.OutOfMemory;
    errdefer out.deinit();
    const window = pa.alloc(u8, flate.max_window_len) catch return error.OutOfMemory;
    defer pa.free(window);
    if (level == 0) {
        var c = flate.Compress.Raw.init(&out.writer, window, container) catch return error.OutOfMemory;
        c.writer.writeAll(data) catch return error.OutOfMemory;
        c.finish() catch return error.OutOfMemory;
    } else {
        const opts: flate.Compress.Options = switch (level) {
            1 => .level_1,
            2 => .level_2,
            3 => .level_3,
            4 => .level_4,
            5 => .level_5,
            7 => .level_7,
            8 => .level_8,
            9 => .level_9,
            else => .level_6,
        };
        var c = flate.Compress.init(&out.writer, window, container, opts) catch return error.OutOfMemory;
        c.writer.writeAll(data) catch return error.OutOfMemory;
        c.finish() catch return error.OutOfMemory;
    }
    return out.toOwnedSlice() catch error.OutOfMemory;
}

/// Decompress data. For the raw container, trailing bytes after the final
/// block are ignored (as java.util.zip.Inflater).
pub fn decompress(data: []const u8, container: Container) Error![]u8 {
    var in: std.Io.Reader = .fixed(data);
    const window = pa.alloc(u8, flate.max_window_len) catch return error.OutOfMemory;
    defer pa.free(window);
    var d = flate.Decompress.init(&in, container, window);
    var out = std.Io.Writer.Allocating.init(pa);
    errdefer out.deinit();
    _ = d.reader.streamRemaining(&out.writer) catch {
        last_error = if (d.err) |e| switch (e) {
            error.BadZlibHeader => "incorrect header check",
            error.BadGzipHeader => "Not in GZIP format",
            error.WrongZlibChecksum => "incorrect data check",
            error.WrongGzipChecksum => "Corrupt GZIP trailer",
            error.WrongGzipSize => "Corrupt GZIP trailer",
            error.WrongStoredBlockNlen => "invalid stored block lengths",
            error.InvalidBlockType => "invalid block type",
            error.InvalidMatch => "invalid distance too far back",
            error.InvalidCode => "invalid code lengths set",
            error.EndOfStream => "Unexpected end of ZLIB input stream",
            else => "invalid compressed data",
        } else "invalid compressed data";
        return error.BadData;
    };
    return out.toOwnedSlice() catch error.OutOfMemory;
}

pub fn crc32(data: []const u8) u32 {
    return std.hash.Crc32.hash(data);
}

/// CRC-32 continued from crc (for streams)
pub fn crc32Update(crc: u32, data: []const u8) u32 {
    var h = std.hash.Crc32{ .crc = ~crc };
    h.update(data);
    return h.final();
}
