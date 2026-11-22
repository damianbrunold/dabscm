//! Zip archives: reading (central directory, stored and deflated entries,
//! zip64 sizes and offsets) and writing (entries compressed in memory, so
//! their sizes are known up front: no data descriptors).
const std = @import("std");
const compress = @import("compress.zig");
const os = @import("os.zig");

const pa = std.heap.c_allocator;

pub const Error = error{ BadZip, OutOfMemory, BadData, NotFound };

fn u16At(b: []const u8, i: usize) u16 {
    return std.mem.readInt(u16, b[i..][0..2], .little);
}
fn u32At(b: []const u8, i: usize) u32 {
    return std.mem.readInt(u32, b[i..][0..4], .little);
}
fn u64At(b: []const u8, i: usize) u64 {
    return std.mem.readInt(u64, b[i..][0..8], .little);
}

// --- reading --------------------------------------------------------------------------

pub const Entry = struct {
    name: []const u8,
    method: u16,
    csize: u64,
    usize: u64,
    offset: u64, // of the local header
};

pub const Reader = struct {
    bytes: []const u8,
    entries: []Entry,

    pub fn find(r: *const Reader, name: []const u8) ?*const Entry {
        for (r.entries) |*e| if (std.mem.eql(u8, e.name, name)) return e;
        return null;
    }

    /// The uncompressed contents of e
    pub fn read(r: *const Reader, e: *const Entry) Error![]u8 {
        const b = r.bytes;
        if (e.offset + 30 > b.len or u32At(b, @intCast(e.offset)) != 0x04034b50) return error.BadZip;
        const o: usize = @intCast(e.offset);
        const start = o + 30 + u16At(b, o + 26) + u16At(b, o + 28);
        if (start + e.csize > b.len) return error.BadZip;
        const raw = b[start .. start + @as(usize, @intCast(e.csize))];
        return switch (e.method) {
            0 => pa.dupe(u8, raw) catch error.OutOfMemory,
            8 => compress.decompress(raw, .raw) catch |err| switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.BadData => error.BadData,
            },
            else => error.BadData,
        };
    }
};

pub fn open(bytes: []const u8) Error!Reader {
    if (bytes.len < 22) return error.BadZip;
    // the end of central directory record, at most 64 KiB of comment before the end
    var i = bytes.len - 22;
    const stop = if (bytes.len > 22 + 65535) bytes.len - 22 - 65535 else 0;
    while (true) : (i -= 1) {
        if (u32At(bytes, i) == 0x06054b50) break;
        if (i == stop) return error.BadZip;
    }
    var count: u64 = u16At(bytes, i + 10);
    var cd_off: u64 = u32At(bytes, i + 16);
    // zip64: the locator before the record points at the zip64 record
    if (i >= 20 and u32At(bytes, i - 20) == 0x07064b50) {
        const z = u64At(bytes, i - 20 + 8);
        if (z + 56 <= bytes.len and u32At(bytes, @intCast(z)) == 0x06064b50) {
            count = u64At(bytes, @intCast(z + 32));
            cd_off = u64At(bytes, @intCast(z + 48));
        }
    }
    var entries: std.ArrayList(Entry) = .empty;
    var p: usize = @intCast(cd_off);
    var n: u64 = 0;
    while (n < count) : (n += 1) {
        if (p + 46 > bytes.len or u32At(bytes, p) != 0x02014b50) return error.BadZip;
        const name_len = u16At(bytes, p + 28);
        const extra_len = u16At(bytes, p + 30);
        const comment_len = u16At(bytes, p + 32);
        if (p + 46 + name_len + extra_len > bytes.len) return error.BadZip;
        var e = Entry{
            .name = bytes[p + 46 .. p + 46 + name_len],
            .method = u16At(bytes, p + 10),
            .csize = u32At(bytes, p + 20),
            .usize = u32At(bytes, p + 24),
            .offset = u32At(bytes, p + 42),
        };
        // zip64 extended information: the fields that are 0xFFFFFFFF, in order
        var x = p + 46 + name_len;
        const xend = x + extra_len;
        while (x + 4 <= xend) {
            const id = u16At(bytes, x);
            const len = u16At(bytes, x + 2);
            if (id == 1) {
                var q = x + 4;
                if (e.usize == 0xFFFFFFFF and q + 8 <= x + 4 + len) {
                    e.usize = u64At(bytes, q);
                    q += 8;
                }
                if (e.csize == 0xFFFFFFFF and q + 8 <= x + 4 + len) {
                    e.csize = u64At(bytes, q);
                    q += 8;
                }
                if (e.offset == 0xFFFFFFFF and q + 8 <= x + 4 + len) e.offset = u64At(bytes, q);
            }
            x += 4 + len;
        }
        entries.append(pa, e) catch return error.OutOfMemory;
        p += 46 + name_len + extra_len + comment_len;
    }
    return .{ .bytes = bytes, .entries = entries.items };
}

// --- writing --------------------------------------------------------------------------

const Central = struct {
    name: []const u8,
    method: u16,
    time: u16,
    date: u16,
    crc: u32,
    csize: u64,
    usize: u64,
    offset: u64,
    /// the modification time in an extra field, for times MS-DOS dates
    /// cannot hold (as Java's ZipOutputStream)
    ext: Ext,
};

pub const Writer = struct {
    out: std.ArrayList(u8) = .empty,
    central: std.ArrayList(Central) = .empty,
    /// the entry being written through a port: its name, time and method
    pending: ?struct { name: []const u8, ms: i64, method: u16 } = null,

    fn put16(w: *Writer, v: u16) Error!void {
        var b: [2]u8 = undefined;
        std.mem.writeInt(u16, &b, v, .little);
        w.out.appendSlice(pa, &b) catch return error.OutOfMemory;
    }
    fn put32(w: *Writer, v: u32) Error!void {
        var b: [4]u8 = undefined;
        std.mem.writeInt(u32, &b, v, .little);
        w.out.appendSlice(pa, &b) catch return error.OutOfMemory;
    }

    /// Add an entry: ms is its modification time (local time, as the JVM's
    /// ZipEntry.setTime); method 0 stores, 8 deflates
    pub fn add(w: *Writer, name: []const u8, contents: []const u8, ms: i64, method: u16) Error!void {
        const crc = compress.crc32(contents);
        const packed_bytes = if (method == 8) compress.compressEntry(contents) catch return error.OutOfMemory else contents;
        defer if (method == 8) pa.free(packed_bytes);
        const dt = dosTime(ms);
        const offset = w.out.items.len;
        // as Java's ZipOutputStream: UTF-8 names; a deflated entry has its
        // CRC and sizes in a data descriptor after the data (flag 8)
        const deflated = method == 8;
        const flags: u16 = if (deflated) 0x0808 else 0x0800;
        const ext = extFor(ms, dt);
        try w.put32(0x04034b50);
        try w.put16(version(method));
        try w.put16(flags);
        try w.put16(method);
        try w.put16(dt[0]);
        try w.put16(dt[1]);
        try w.put32(if (deflated) 0 else crc);
        try w.put32(if (deflated) 0 else @intCast(packed_bytes.len));
        try w.put32(if (deflated) 0 else @intCast(contents.len));
        try w.put16(@intCast(name.len));
        try w.put16(ext.len());
        w.out.appendSlice(pa, name) catch return error.OutOfMemory;
        try w.extraTime(ext);
        w.out.appendSlice(pa, packed_bytes) catch return error.OutOfMemory;
        if (deflated) {
            try w.put32(0x08074b50);
            try w.put32(crc);
            try w.put32(@intCast(packed_bytes.len));
            try w.put32(@intCast(contents.len));
        }
        w.central.append(pa, .{
            .name = pa.dupe(u8, name) catch return error.OutOfMemory,
            .method = method,
            .time = dt[0],
            .date = dt[1],
            .crc = crc,
            .csize = packed_bytes.len,
            .usize = contents.len,
            .offset = offset,
            .ext = ext,
        }) catch return error.OutOfMemory;
    }

    /// the extra field of ext: an extended timestamp (0x5455) with the
    /// modification time only, or an NTFS times field (0x000a) without access
    /// and creation times
    fn extraTime(w: *Writer, ext: Ext) Error!void {
        switch (ext) {
            .none => {},
            .ut => |u| {
                try w.put16(0x5455);
                try w.put16(5);
                w.out.append(pa, 1) catch return error.OutOfMemory;
                try w.put32(u);
            },
            .ntfs => |wt| {
                try w.put16(0x000a);
                try w.put16(32);
                try w.put32(0);
                try w.put16(1);
                try w.put16(24);
                for ([_]u64{ wt, 1 << 63, 1 << 63 }) |v| {
                    var b8: [8]u8 = undefined;
                    std.mem.writeInt(u64, &b8, v, .little);
                    w.out.appendSlice(pa, &b8) catch return error.OutOfMemory;
                }
            },
        }
    }

    /// The archive's bytes, with the central directory
    pub fn finish(w: *Writer) Error![]const u8 {
        const cd_start = w.out.items.len;
        for (w.central.items) |c| {
            try w.put32(0x02014b50);
            try w.put16(version(c.method));
            try w.put16(version(c.method));
            try w.put16(if (c.method == 8) 0x0808 else 0x0800);
            try w.put16(c.method);
            try w.put16(c.time);
            try w.put16(c.date);
            try w.put32(c.crc);
            try w.put32(@intCast(c.csize));
            try w.put32(@intCast(c.usize));
            try w.put16(@intCast(c.name.len));
            try w.put16(c.ext.len());
            try w.put16(0);
            try w.put16(0);
            try w.put16(0);
            try w.put32(0);
            try w.put32(@intCast(c.offset));
            w.out.appendSlice(pa, c.name) catch return error.OutOfMemory;
            try w.extraTime(c.ext);
        }
        const cd_len = w.out.items.len - cd_start;
        try w.put32(0x06054b50);
        try w.put16(0);
        try w.put16(0);
        try w.put16(@intCast(w.central.items.len));
        try w.put16(@intCast(w.central.items.len));
        try w.put32(@intCast(cd_len));
        try w.put32(@intCast(cd_start));
        try w.put16(0);
        return w.out.items;
    }
};

const Ext = union(enum) {
    none,
    ut: u32,
    ntfs: u64,

    fn len(e: Ext) u16 {
        return switch (e) {
            .none => 0,
            .ut => 9,
            .ntfs => 36,
        };
    }
};

/// As java.util.zip.ZipEntry.setTime and ZipOutputStream: times before 1980
/// or after 128 years from 1970 also get an extra field, an extended
/// timestamp if the seconds fit into 32 bits, else NTFS times
fn extFor(ms: i64, dt: [2]u16) Ext {
    const before_1980 = dt[1] == (1 << 5) | 1 and dt[0] == 0;
    if (!before_1980 and ms <= 128 * 365 * 24 * 60 * 60 * 1000) return .none;
    const secs = @divTrunc(ms, 1000);
    if (secs > 0x7fffffff) return .{ .ntfs = @bitCast((ms * 1000 - -11644473600000000) * 10) };
    return .{ .ut = @truncate(@as(u64, @bitCast(secs))) };
}

/// the version needed to extract (and made by), as Java's ZipOutputStream
fn version(method: u16) u16 {
    return if (method == 8) 20 else 10;
}

/// MS-DOS time and date of ms (local time); 1980-01-01 for earlier times
fn dosTime(ms: i64) [2]u16 {
    const secs = @divFloor(ms, 1000);
    const local = secs + os.localOffset(secs);
    const c = os.civilFromDays(@divFloor(local, 86400));
    if (c.year < 1980) return .{ 0, (1 << 5) | 1 };
    const in_day = @mod(local, 86400);
    const time: u16 = @intCast((@divFloor(in_day, 3600) << 11) | (@mod(@divFloor(in_day, 60), 60) << 5) | @divFloor(@mod(in_day, 60), 2));
    const date: u16 = @intCast(((c.year - 1980) << 9) | (@as(i64, c.month) << 5) | c.day);
    return .{ time, date };
}
