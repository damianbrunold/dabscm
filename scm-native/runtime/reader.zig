//! The datum reader (read). It parses into a temporary tree outside the GC
//! heap, then reserves the words the datum needs and builds it, so that a
//! collection never sees half-built data.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const chars = @import("chars.zig");
const ports = @import("ports.zig");
const Word = rt.Word;
const Thread = rt.Thread;

const pa = std.heap.c_allocator;

const Node = union(enum) {
    eof,
    word: Word, // fixnums, characters, booleans, (), symbols
    flo: f64,
    exact: num.Lit, // made by the numeric tower
    string: []const u21,
    list: struct { items: []Node, tail: ?*Node },
    vector: []Node,
    bytes: []const u8,
    label_def: struct { n: u64, node: *Node },
    label_ref: u64,
};

/// A label reference while the datum is built: patched afterwards
inline fn placeholder(n: u64) Word {
    return (n << 16) | 0b111011;
}
inline fn isPlaceholder(w: Word) bool {
    return w & 0xFFFF == 0b111011;
}

pub const Error = error{ReadError};

pub const Reader = struct {
    port: *ports.Port,
    msg: []const u8 = "",
    fold_case: bool = false,
    /// nesting of lists, vectors and quote forms: limited, as the recursion
    /// uses the machine stack (the JVM implementation catches its stack
    /// overflow instead)
    depth: usize = 0,
    max_depth: usize = default_max_depth,
    /// read-data: datum labels are rejected
    no_labels: bool = false,
    prefix: []const u8 = "",

    pub const default_max_depth = 10000;

    fn enter(r: *Reader) Error!void {
        r.depth += 1;
        if (r.depth > r.max_depth) return r.fail(if (r.no_labels) "nesting too deep" else "nesting too deep");
    }

    fn fail(r: *Reader, msg: []const u8) Error {
        r.msg = msg;
        return error.ReadError;
    }

    fn peek(r: *Reader) ?u21 {
        return r.port.peekChar();
    }
    fn next(r: *Reader) ?u21 {
        return r.port.readChar();
    }

    fn skipAtmosphere(r: *Reader) Error!void {
        while (r.peek()) |c| {
            if (chars.isWhitespace(c)) {
                _ = r.next();
            } else if (c == ';') {
                while (r.next()) |d| if (d == '\n') break;
            } else if (c == '#') {
                // #| ... |# and #; need a second character of look-ahead
                const save = r.port.pos;
                _ = r.next();
                const d = r.peek();
                if (d == '|') {
                    _ = r.next();
                    try r.skipBlockComment();
                } else if (d == ';') {
                    _ = r.next();
                    _ = try r.datum();
                } else {
                    r.port.pos = save;
                    return;
                }
            } else return;
        }
    }

    fn skipBlockComment(r: *Reader) Error!void {
        var depth: usize = 1;
        while (depth > 0) {
            const c = r.next() orelse return r.fail("unterminated block comment");
            if (c == '|' and r.peek() == '#') {
                _ = r.next();
                depth -= 1;
            } else if (c == '#' and r.peek() == '|') {
                _ = r.next();
                depth += 1;
            }
        }
    }

    fn isDelimiter(c: u21) bool {
        return chars.isWhitespace(c) or switch (c) {
            '(', ')', '[', ']', '"', ';', '\'', '`', ',' => true,
            else => false,
        };
    }

    /// The characters up to a delimiter, as UTF-8
    fn token(r: *Reader, first: ?u21) []u8 {
        var buf: std.ArrayList(u8) = .empty;
        if (first) |c| appendCp(&buf, c);
        while (r.peek()) |c| {
            if (isDelimiter(c)) break;
            appendCp(&buf, r.next().?);
        }
        return buf.items;
    }

    fn appendCp(buf: *std.ArrayList(u8), cp: u21) void {
        var tmp: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(cp, &tmp) catch 0;
        buf.appendSlice(pa, tmp[0..n]) catch rt.oom();
    }

    pub fn datum(r: *Reader) Error!Node {
        try r.skipAtmosphere();
        const c = r.next() orelse return .eof;
        switch (c) {
            '(', '[' => return r.list(if (c == '(') ')' else ']'),
            ')', ']' => return r.fail("unexpected close parenthesis"),
            '\'' => return r.quoted("quote"),
            '`' => return r.quoted("quasiquote"),
            ',' => {
                if (r.peek() == '@') {
                    _ = r.next();
                    return r.quoted("unquote-splicing");
                }
                return r.quoted("unquote");
            },
            '"' => return r.string(),
            '|' => {
                var buf: std.ArrayList(u8) = .empty;
                while (true) {
                    const d = r.next() orelse return r.fail("unterminated |symbol|");
                    if (d == '|') break;
                    appendCp(&buf, if (d == '\\') try r.escape() else d);
                }
                return .{ .word = data.intern(buf.items) };
            },
            '#' => return r.hash(),
            else => return r.atom(r.token(c)),
        }
    }

    fn quoted(r: *Reader, name: []const u8) Error!Node {
        try r.enter();
        defer r.depth -= 1;
        const d = try r.datum();
        if (d == .eof) return r.fail("end of file after quote");
        const items = pa.alloc(Node, 2) catch rt.oom();
        items[0] = .{ .word = data.intern(name) };
        items[1] = d;
        return .{ .list = .{ .items = items, .tail = null } };
    }

    fn list(r: *Reader, close: u21) Error!Node {
        try r.enter();
        defer r.depth -= 1;
        var items: std.ArrayList(Node) = .empty;
        while (true) {
            try r.skipAtmosphere();
            const c = r.peek() orelse return r.fail("end of file in list");
            if (c == close) {
                _ = r.next();
                return .{ .list = .{ .items = items.items, .tail = null } };
            }
            if (c == ')' or c == ']') return r.fail("mismatched close parenthesis");
            if (c == '.') {
                const save = r.port.pos;
                _ = r.next();
                if (r.peek() == null or isDelimiter(r.peek().?)) {
                    if (items.items.len == 0) return r.fail("dot at the start of a list");
                    const tail = pa.create(Node) catch rt.oom();
                    tail.* = try r.datum();
                    try r.skipAtmosphere();
                    if (r.next() != close) return r.fail("expected one datum after dot");
                    return .{ .list = .{ .items = items.items, .tail = tail } };
                }
                r.port.pos = save;
            }
            const d = try r.datum();
            if (d == .eof) return r.fail("end of file in list");
            items.append(pa, d) catch rt.oom();
        }
    }

    fn escape(r: *Reader) Error!u21 {
        const c = r.next() orelse return r.fail("end of file in escape");
        return switch (c) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            'a' => 7,
            'b' => 8,
            '0' => 0,
            'x', 'X' => blk: {
                var v: u21 = 0;
                while (true) {
                    const d = r.next() orelse return r.fail("end of file in \\x escape");
                    if (d == ';') break;
                    const dv = if (d < 128) num.digitOf(@intCast(d), 16) else null;
                    v = v * 16 + (dv orelse return r.fail("bad \\x escape"));
                }
                break :blk v;
            },
            else => c,
        };
    }

    fn string(r: *Reader) Error!Node {
        var cps: std.ArrayList(u21) = .empty;
        while (true) {
            const c = r.next() orelse return r.fail("end of file in string");
            if (c == '"') break;
            if (c == '\\') {
                const d = r.peek() orelse return r.fail("end of file in string");
                if (d == '\n' or d == ' ' or d == '\t') {
                    // line continuation: \ <spaces> newline <spaces>
                    while (r.peek()) |e| {
                        if (e == ' ' or e == '\t') _ = r.next() else break;
                    }
                    if (r.peek() == '\n') _ = r.next();
                    while (r.peek()) |e| {
                        if (e == ' ' or e == '\t') _ = r.next() else break;
                    }
                    continue;
                }
                cps.append(pa, try r.escape()) catch rt.oom();
            } else cps.append(pa, c) catch rt.oom();
        }
        return .{ .string = cps.items };
    }

    fn hash(r: *Reader) Error!Node {
        const c = r.peek() orelse return r.fail("end of file after #");
        switch (c) {
            '(' => {
                _ = r.next();
                const l = try r.list(')');
                return .{ .vector = l.list.items };
            },
            '0'...'9' => {
                if (r.no_labels) return r.fail("datum labels are not allowed");
                var n: u64 = 0;
                while (r.peek()) |d| {
                    if (d < '0' or d > '9') break;
                    n = n * 10 + (r.next().? - '0');
                }
                const d = r.next() orelse return r.fail("end of file in datum label");
                if (d == '#') return .{ .label_ref = n };
                if (d != '=') return r.fail("bad datum label");
                const node = pa.create(Node) catch rt.oom();
                node.* = try r.datum();
                return .{ .label_def = .{ .n = n, .node = node } };
            },
            '\\' => {
                _ = r.next();
                const first = r.next() orelse return r.fail("end of file in character");
                const rest = r.token(null);
                if (rest.len == 0) return .{ .word = rt.char(first) };
                var buf: std.ArrayList(u8) = .empty;
                appendCp(&buf, first);
                buf.appendSlice(pa, rest) catch rt.oom();
                return .{ .word = rt.char(charName(buf.items) orelse return r.fail("unknown character name")) };
            },
            '\'' => {
                _ = r.next();
                return r.quoted("syntax");
            },
            '`' => {
                _ = r.next();
                return r.quoted("quasisyntax");
            },
            ',' => {
                _ = r.next();
                if (r.peek() == '@') {
                    _ = r.next();
                    return r.quoted("unsyntax-splicing");
                }
                return r.quoted("unsyntax");
            },
            '!' => {
                _ = r.next();
                if (r.peek() == '/' or r.peek() == ' ') {
                    // a script's #! line
                    while (r.next()) |d| if (d == '\n') break;
                    return r.datum();
                }
                r.port.pos -= 1;
                const tok = r.token(null);
                if (tok.len == 1) return r.fail("bad #! syntax");
                if (std.mem.eql(u8, tok, "!fold-case")) r.fold_case = true else if (std.mem.eql(u8, tok, "!no-fold-case")) r.fold_case = false else if (std.mem.eql(u8, tok, "!eof")) return .{ .word = rt.EOF } else if (std.mem.eql(u8, tok, "!default")) return .{ .word = rt.DEFAULT } else if (std.mem.eql(u8, tok, "!unspecific")) return .{ .word = rt.UNSPEC };
                return r.datum();
            },
            else => {
                const tok = r.token('#');
                if (std.mem.eql(u8, tok, "#t") or std.mem.eql(u8, tok, "#true")) return .{ .word = rt.TRUE };
                if (std.mem.eql(u8, tok, "#f") or std.mem.eql(u8, tok, "#false")) return .{ .word = rt.FALSE };
                if (std.mem.eql(u8, tok, "#u8") and r.peek() == '(') {
                    _ = r.next();
                    const l = try r.list(')');
                    const bytes = pa.alloc(u8, l.list.items.len) catch rt.oom();
                    for (l.list.items, 0..) |item, i| {
                        if (item != .word or !rt.isFix(item.word) or rt.unfix(item.word) < 0 or rt.unfix(item.word) > 255)
                            return r.fail("bad bytevector element");
                        bytes[i] = @intCast(rt.unfix(item.word));
                    }
                    return .{ .bytes = bytes };
                }
                return r.atom(tok);
            },
        }
    }

    fn atom(r: *Reader, tok: []u8) Error!Node {
        if (num.parseNumber(tok, 10)) |lit| return switch (lit) {
            .fix => |n| .{ .word = rt.fix(n) },
            .flo => |f| .{ .flo = f },
            .exact => .{ .exact = lit },
        };
        if (tok.len > 0 and tok[0] == '#') return r.fail("bad # syntax");
        if (r.fold_case) for (tok) |*b| {
            b.* = std.ascii.toLower(b.*);
        };
        return .{ .word = data.intern(tok) };
    }
};

fn charName(name: []const u8) ?u21 {
    const names = [_]struct { []const u8, u21 }{
        .{ "space", ' ' },     .{ "newline", '\n' }, .{ "tab", '\t' },     .{ "nul", 0 },
        .{ "null", 0 },        .{ "alarm", 7 },      .{ "backspace", 8 },  .{ "delete", 127 },
        .{ "escape", 27 },     .{ "return", '\r' },  .{ "linefeed", '\n' }, .{ "altmode", 27 },
        .{ "rubout", 127 },    .{ "page", 12 },
    };
    for (names) |n| if (std.mem.eql(u8, n[0], name)) return n[1];
    if (name.len > 1 and (name[0] == 'x' or name[0] == 'X')) {
        const v = std.fmt.parseInt(u21, name[1..], 16) catch return null;
        return v;
    }
    return null;
}

// --- building ----------------------------------------------------------------

fn words(n: Node) usize {
    return switch (n) {
        .eof, .word => 0,
        .flo => 2,
        .exact => 0, // large objects
        .string => |s| data.stringWords(s.len, true),
        .list => |l| blk: {
            var w: usize = 3 * l.items.len;
            for (l.items) |i| w += words(i);
            if (l.tail) |tl| w += words(tl.*);
            break :blk w;
        },
        .vector => |v| blk: {
            var w: usize = 1 + v.len;
            for (v) |i| w += words(i);
            break :blk w;
        },
        .bytes => |b| data.bvWords(b.len),
        .label_def => |l| words(l.node.*),
        .label_ref => 0,
    };
}

var label_values: std.AutoHashMapUnmanaged(u64, Word) = .empty;

/// Replace the placeholders in w (a tree before patching) by the labels
fn patch(w: Word) Word {
    if (isPlaceholder(w)) return label_values.get(w >> 16) orelse rt.UNSPEC;
    if (rt.isPair(w)) {
        var p = w;
        while (true) {
            rt.ptr(p)[1] = patch(rt.car(p));
            const d = rt.cdr(p);
            if (rt.isPair(d)) {
                p = d;
                continue;
            }
            rt.ptr(p)[2] = patch(d);
            break;
        }
    } else if (data.isVector(w)) {
        for (data.vectorItems(w)) |*x| x.* = patch(x.*);
    }
    return w;
}

fn build(t: *Thread, n: Node) Word {
    return switch (n) {
        .eof => rt.EOF,
        .word => |w| w,
        .flo => |f| t.makeFlo(f),
        .exact => |lit| num.exactFromLit(t, lit) orelse rt.FALSE,
        .string => |cps| blk: {
            var wide = false;
            for (cps) |c| if (c > 255) {
                wide = true;
            };
            const s = data.makeString(t, cps.len, wide);
            for (cps, 0..) |c, i| data.stringSetFits(s, i, c);
            break :blk s;
        },
        .list => |l| blk: {
            var result = if (l.tail) |tl| build(t, tl.*) else rt.NIL;
            var i = l.items.len;
            while (i > 0) {
                i -= 1;
                const item = build(t, l.items[i]);
                result = t.cons(item, result);
            }
            break :blk result;
        },
        .vector => |v| blk: {
            const vec = data.makeVector(t, v.len, rt.FALSE);
            // elements are built after the vector: vec is not moved (reserved)
            for (v, 0..) |item, i| data.vectorItems(vec)[i] = build(t, item);
            break :blk vec;
        },
        .bytes => |b| blk: {
            const bv = data.makeBytevector(t, b.len);
            @memcpy(data.bvBytes(bv), b);
            break :blk bv;
        },
        .label_def => |l| blk: {
            const w = build(t, l.node.*);
            label_values.put(pa, l.n, w) catch rt.oom();
            break :blk w;
        },
        .label_ref => |label| placeholder(label),
    };
}

/// Read a datum from port p. On a syntax error, sets the thread's pending
/// error and returns null.
pub fn read(t: *Thread, p: *ports.Port) ?Word {
    return readWith(t, .{ .port = p });
}

/// read-data: no datum labels, at most max_depth levels of nesting
pub fn readData(t: *Thread, p: *ports.Port, max_depth: usize) ?Word {
    return readWith(t, .{ .port = p, .max_depth = max_depth, .no_labels = true, .prefix = "read-data: " });
}

fn readWith(t: *Thread, r0: Reader) ?Word {
    var r = r0;
    const node = r.datum() catch {
        const m = if (r.prefix.len > 0) std.fmt.allocPrint(pa, "{s}{s}", .{ r.prefix, r.msg }) catch rt.oom() else r.msg;
        _ = rt.failKind(t, rt.ErrorKind.read, m, &.{});
        return null;
    };
    t.reserve(words(node));
    label_values.clearRetainingCapacity();
    const w = build(t, node);
    return if (label_values.count() > 0) patch(w) else w;
}
