//! Primitives: JSON. The simple reader and writers of (scm json simple)
//! (objects as alists with string keys, arrays as vectors, null as the
//! symbol null), and the streaming reader of (scm json) (open-json-string,
//! json-next-object, json-attribute), a port of the JVM implementation's
//! JsonLexer and JsonParser.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const os = @import("os.zig");
const tower = @import("tower.zig");
const printer = @import("printer.zig");
const sys = @import("prims_sys.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;

const pa = std.heap.c_allocator;

fn msg(comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(pa, fmt, args) catch rt.oom();
}

fn isJavaWhitespace(c: u21) bool {
    return @import("chars.zig").isWhitespace(c);
}

// --- json-simple-parse -----------------------------------------------------------------

/// A parsed value, built on the heap after parsing (one reservation)
const Val = union(enum) {
    word: Word, // #t #f null, fixnums
    big: []const u8, // an integer too large for a fixnum (decimal digits)
    flo: f64,
    str: []const u21,
    vec: []const Val,
    obj: []const [2]Val, // (key . value); key is a .str
};

const SimpleParser = struct {
    s: []const u21,
    pos: usize = 0,
    err: []const u8 = "",

    fn fail(p: *SimpleParser, m: []const u8) error{Json} {
        p.err = m;
        return error.Json;
    }
    fn peek(p: *SimpleParser) ?u21 {
        return if (p.pos < p.s.len) p.s[p.pos] else null;
    }
    fn next(p: *SimpleParser) error{Json}!u21 {
        if (p.pos >= p.s.len) return p.fail("unexpected end of input");
        p.pos += 1;
        return p.s[p.pos - 1];
    }
    fn skipWs(p: *SimpleParser) void {
        while (p.pos < p.s.len and isJavaWhitespace(p.s[p.pos])) p.pos += 1;
    }
    fn expect(p: *SimpleParser, c: u21) error{Json}!void {
        p.skipWs();
        if (p.peek() == c) {
            p.pos += 1;
        } else return p.fail(msg("expected {u}", .{c}));
    }

    fn value(p: *SimpleParser) error{Json}!Val {
        p.skipWs();
        const c = p.peek() orelse return p.fail("unexpected end of input");
        return switch (c) {
            '{' => p.object(),
            '[' => p.array(),
            '"' => .{ .str = try p.string() },
            't' => p.literal("true", rt.TRUE),
            'f' => p.literal("false", rt.FALSE),
            'n' => p.literal("null", data.intern("null")),
            else => if (c == '-' or (c >= '0' and c <= '9')) p.number() else p.fail(msg("unexpected char {u}", .{c})),
        };
    }

    fn literal(p: *SimpleParser, word: []const u8, v: Word) error{Json}!Val {
        for (word) |ch| {
            if (p.peek() != ch) return p.fail(msg("expected {s}", .{word}));
            p.pos += 1;
        }
        return .{ .word = v };
    }

    fn object(p: *SimpleParser) error{Json}!Val {
        p.pos += 1;
        p.skipWs();
        if (p.peek() == '}') {
            p.pos += 1;
            return .{ .word = rt.NIL };
        }
        var entries: std.ArrayList([2]Val) = .empty;
        while (true) {
            p.skipWs();
            const key = try p.string();
            try p.expect(':');
            const v = try p.value();
            entries.append(pa, .{ .{ .str = key }, v }) catch rt.oom();
            p.skipWs();
            const c = p.peek();
            if (c == ',') {
                p.pos += 1;
                continue;
            }
            if (c == '}') {
                p.pos += 1;
                break;
            }
            return p.fail("expected , or }");
        }
        return .{ .obj = entries.items };
    }

    fn array(p: *SimpleParser) error{Json}!Val {
        p.pos += 1;
        p.skipWs();
        if (p.peek() == ']') {
            p.pos += 1;
            return .{ .vec = &.{} };
        }
        var items: std.ArrayList(Val) = .empty;
        while (true) {
            items.append(pa, try p.value()) catch rt.oom();
            p.skipWs();
            const c = p.peek();
            if (c == ',') {
                p.pos += 1;
                continue;
            }
            if (c == ']') {
                p.pos += 1;
                break;
            }
            return p.fail("expected , or ]");
        }
        return .{ .vec = items.items };
    }

    fn string(p: *SimpleParser) error{Json}![]const u21 {
        p.skipWs();
        if (p.peek() != '"') return p.fail("expected string");
        p.pos += 1;
        var out: std.ArrayList(u21) = .empty;
        while (true) {
            const c = try p.next();
            if (c == '"') return out.items;
            if (c != '\\') {
                out.append(pa, c) catch rt.oom();
                continue;
            }
            const e = try p.next();
            const v: u21 = switch (e) {
                '"' => '"',
                '\\' => '\\',
                '/' => '/',
                'b' => 8,
                'f' => 12,
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                'u' => blk: {
                    const cp = try p.hex4();
                    if (cp >= 0xD800 and cp <= 0xDBFF) {
                        if (try p.next() != '\\') return p.fail("expected low surrogate");
                        if (try p.next() != 'u') return p.fail("expected \\u low surrogate");
                        const lo = try p.hex4();
                        // a full code point (the JVM truncates to 16 bits)
                        break :blk @intCast(0x10000 + (@as(u32, cp) - 0xD800) * 0x400 + (@as(u32, lo) -% 0xDC00));
                    }
                    break :blk cp;
                },
                else => return p.fail("bad escape"),
            };
            out.append(pa, v) catch rt.oom();
        }
    }

    fn hex4(p: *SimpleParser) error{Json}!u21 {
        var acc: u21 = 0;
        for (0..4) |_| {
            const c = try p.next();
            const d: u21 = switch (c) {
                '0'...'9' => c - '0',
                'a'...'f' => c - 'a' + 10,
                'A'...'F' => c - 'A' + 10,
                else => return p.fail("bad hex digit"),
            };
            acc = acc * 16 + d;
        }
        return acc;
    }

    fn number(p: *SimpleParser) error{Json}!Val {
        const start = p.pos;
        if (p.peek() == '-') p.pos += 1;
        while (p.peek()) |c| {
            if (c < '0' or c > '9') break;
            p.pos += 1;
        }
        var exact = true;
        if (p.peek() == '.') {
            exact = false;
            p.pos += 1;
            while (p.peek()) |c| {
                if (c < '0' or c > '9') break;
                p.pos += 1;
            }
        }
        if (p.peek() == 'e' or p.peek() == 'E') {
            exact = false;
            p.pos += 1;
            if (p.peek() == '+' or p.peek() == '-') p.pos += 1;
            while (p.peek()) |c| {
                if (c < '0' or c > '9') break;
                p.pos += 1;
            }
        }
        var text: std.ArrayList(u8) = .empty;
        for (p.s[start..p.pos]) |c| text.append(pa, @intCast(c)) catch rt.oom();
        if (exact) {
            if (std.fmt.parseInt(i64, text.items, 10)) |n| {
                if (rt.fixFits(n)) return .{ .word = fix(n) };
            } else |_| {}
            if (text.items.len == 0 or std.mem.eql(u8, text.items, "-")) return p.fail(msg("For input string: \"{s}\"", .{text.items}));
            return .{ .big = text.items };
        }
        const f = std.fmt.parseFloat(f64, text.items) catch return p.fail(msg("For input string: \"{s}\"", .{text.items}));
        return .{ .flo = f };
    }
};

fn valWords(v: Val) usize {
    return switch (v) {
        .word, .big => 0,
        .flo => 2,
        .str => |s| data.stringWords(s.len, true),
        .vec => |items| blk: {
            var n: usize = 1 + items.len;
            for (items) |x| n += valWords(x);
            break :blk n;
        },
        .obj => |entries| blk: {
            var n: usize = 0;
            for (entries) |e| n += 6 + valWords(e[0]) + valWords(e[1]);
            break :blk n;
        },
    };
}

fn makeStr(t: *Thread, cps: []const u21) Word {
    var wide = false;
    for (cps) |c| if (c > 255) {
        wide = true;
    };
    const s = data.makeString(t, cps.len, wide);
    for (cps, 0..) |c, i| data.stringSetFits(s, i, c);
    return s;
}

fn build(t: *Thread, v: Val) Word {
    return switch (v) {
        .word => |w| w,
        .big => |digits| blk: {
            const num = @import("num.zig");
            const lit = num.parseNumber(digits, 10) orelse break :blk rt.FALSE;
            break :blk num.exactFromLit(t, lit) orelse rt.FALSE;
        },
        .flo => |f| t.makeFlo(f),
        .str => |s| makeStr(t, s),
        .vec => |items| blk: {
            const vec = data.makeVector(t, items.len, rt.FALSE);
            for (items, 0..) |x, i| data.vectorItems(vec)[i] = build(t, x);
            break :blk vec;
        },
        .obj => |entries| blk: {
            var l = rt.NIL;
            var i = entries.len;
            while (i > 0) {
                i -= 1;
                const k = build(t, entries[i][0]);
                const x = build(t, entries[i][1]);
                l = t.cons(t.cons(k, x), l);
            }
            break :blk l;
        },
    };
}

fn jsonSimpleParse(t: *Thread) Err!Word {
    const s0 = try P.stringArg(t, 0);
    const cps = pa.alloc(u21, data.stringLen(s0)) catch rt.oom();
    for (cps, 0..) |*c, i| c.* = data.stringRef(s0, i);
    var p = SimpleParser{ .s = cps };
    const v = p.value() catch return raise(t, msg("json: {s}", .{p.err}), &.{});
    t.reserve(valWords(v));
    return build(t, v);
}
pub const @"%json-simple-parse" = WN("json-simple-parse", jsonSimpleParse, 1, 1);

// --- json-simple->string ---------------------------------------------------------------------

const Buf = std.ArrayList(u8);

fn put(b: *Buf, s: []const u8) void {
    b.appendSlice(pa, s) catch rt.oom();
}

fn writeString(b: *Buf, s: Word) void {
    put(b, "\"");
    for (0..data.stringLen(s)) |i| {
        const c = data.stringRef(s, i);
        switch (c) {
            '"' => put(b, "\\\""),
            '\\' => put(b, "\\\\"),
            '\n' => put(b, "\\n"),
            '\r' => put(b, "\\r"),
            '\t' => put(b, "\\t"),
            8 => put(b, "\\b"),
            12 => put(b, "\\f"),
            else => if (c < 0x20) {
                var tmp: [8]u8 = undefined;
                put(b, std.fmt.bufPrint(&tmp, "\\u{x:0>4}", .{c}) catch unreachable);
            } else data.appendCp(b, c),
        }
    }
    put(b, "\"");
}

fn writeValue(t: *Thread, b: *Buf, v: Word) Err!void {
    if (v == rt.TRUE) return put(b, "true");
    if (v == rt.FALSE) return put(b, "false");
    if (data.isString(v)) return writeString(b, v);
    if (tower.isNumber(v)) return printer.print(b, v, false);
    if (data.isVector(v)) {
        put(b, "[");
        for (data.vectorItems(v), 0..) |x, i| {
            if (i > 0) put(b, ",");
            try writeValue(t, b, x);
        }
        return put(b, "]");
    }
    if (v == rt.NIL) return put(b, "{}");
    if (rt.isPair(v)) {
        put(b, "{");
        var items = v;
        var first = true;
        while (rt.isPair(items)) : (items = rt.cdr(items)) {
            const kv = try entryOf(t, rt.car(items));
            if (!first) put(b, ",");
            first = false;
            writeString(b, rt.car(kv));
            put(b, ":");
            try writeValue(t, b, rt.cdr(kv));
        }
        return put(b, "}");
    }
    if (data.isSymbol(v) and std.mem.eql(u8, data.symbolName(v), "null")) return put(b, "null");
    return raise(t, "json-write: cannot serialize: ~s", &.{v});
}

fn entryOf(t: *Thread, e: Word) Err!Word {
    if (!rt.isPair(e)) return raise(t, "json-write: object entry is not a pair: ~s", &.{e});
    if (!data.isString(rt.car(e))) return raise(t, "json-write: object key is not a string: ~s", &.{rt.car(e)});
    return e;
}

fn indent(b: *Buf, n: usize) void {
    for (0..2 * n) |_| put(b, " ");
}

fn writePretty(t: *Thread, b: *Buf, v: Word, depth: usize) Err!void {
    if (data.isVector(v)) {
        const items = data.vectorItems(v);
        if (items.len == 0) return put(b, "[]");
        put(b, "[\n");
        for (items, 0..) |x, i| {
            indent(b, depth + 1);
            try writePretty(t, b, x, depth + 1);
            if (i + 1 < items.len) put(b, ",");
            put(b, "\n");
        }
        indent(b, depth);
        return put(b, "]");
    }
    if (v == rt.NIL) return put(b, "{}");
    if (rt.isPair(v)) {
        put(b, "{\n");
        var items = v;
        while (rt.isPair(items)) : (items = rt.cdr(items)) {
            const kv = try entryOf(t, rt.car(items));
            indent(b, depth + 1);
            writeString(b, rt.car(kv));
            put(b, ": ");
            try writePretty(t, b, rt.cdr(kv), depth + 1);
            if (rt.isPair(rt.cdr(items))) put(b, ",");
            put(b, "\n");
        }
        indent(b, depth);
        return put(b, "}");
    }
    return writeValue(t, b, v);
}

fn stringResult(t: *Thread, b: []const u8) Word {
    t.reserve(data.stringWords(b.len, true));
    return data.heapStringUtf8(t, b);
}

fn jsonSimpleToString(t: *Thread) Err!Word {
    var b: Buf = .empty;
    defer b.deinit(pa);
    try writeValue(t, &b, arg(t, 0));
    return stringResult(t, b.items);
}
fn jsonSimpleToPrettyString(t: *Thread) Err!Word {
    var b: Buf = .empty;
    defer b.deinit(pa);
    try writePretty(t, &b, arg(t, 0), 0);
    return stringResult(t, b.items);
}
pub const @"%json-simple->string" = WN("json-simple->string", jsonSimpleToString, 1, 1);
pub const @"%json-simple->pretty-string" = WN("json-simple->pretty-string", jsonSimpleToPrettyString, 1, 1);

// --- streaming reader (JsonLexer, JsonParser) --------------------------------------------------

pub const JValue = union(enum) {
    null_,
    true_,
    false_,
    number: f64,
    string: []const u8,
    object: *JObject,
    list: []JValue,
};

pub const JObject = struct {
    keys: std.ArrayList([]const u8) = .empty,
    values: std.ArrayList(JValue) = .empty,

    fn put(o: *JObject, a: std.mem.Allocator, k: []const u8, v: JValue) void {
        for (o.keys.items, 0..) |x, i| if (std.mem.eql(u8, x, k)) {
            o.values.items[i] = v;
            return;
        };
        o.keys.append(a, k) catch rt.oom();
        o.values.append(a, v) catch rt.oom();
    }

    fn get(o: *const JObject, k: []const u8) ?JValue {
        for (o.keys.items, 0..) |x, i| if (std.mem.eql(u8, x, k)) return o.values.items[i];
        return null;
    }
};

const JError = error{Json};

const Lexer = struct {
    in: []const u8, // UTF-8
    /// the parser's arena, for the tokens (object names and strings point
    /// into them)
    alloc: std.mem.Allocator = pa,
    pos: usize = 0,
    tokens: std.ArrayList([]const u8) = .empty,
    err: []const u8 = "",

    fn read(l: *Lexer) ?u21 {
        if (l.pos >= l.in.len) return null;
        const len = std.unicode.utf8ByteSequenceLength(l.in[l.pos]) catch 1;
        const end = @min(l.pos + len, l.in.len);
        const c = std.unicode.utf8Decode(l.in[l.pos..end]) catch 0xFFFD;
        l.pos = end;
        return c;
    }

    fn unread(l: *Lexer, c: u21) void {
        l.pos -= std.unicode.utf8CodepointSequenceLength(c) catch 1;
    }

    fn putBack(l: *Lexer, token: []const u8) void {
        l.tokens.append(pa, token) catch rt.oom();
    }

    fn next(l: *Lexer) ?[]const u8 {
        if (l.tokens.pop()) |tok| return tok;
        var r: Buf = .empty;
        var state: i32 = 0;
        while (l.read()) |c| {
            switch (state) {
                0 => {
                    if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {} else if (c == '"') {
                        state = 1;
                        data.appendCp(&r, c);
                    } else if (@import("chars.zig").isDigit(c) or c == '+' or c == '-') {
                        state = 2;
                        data.appendCp(&r, c);
                    } else if (c == ':' or c == ',' or c == '{' or c == '}' or c == '[' or c == ']') {
                        data.appendCp(&r, c);
                        state = -1;
                    } else {
                        state = 3;
                        data.appendCp(&r, c);
                    }
                },
                1 => {
                    if (c == '\\') {
                        state = 4;
                    } else if (c == '"') {
                        data.appendCp(&r, c);
                        state = -1;
                    } else data.appendCp(&r, c);
                },
                2 => {
                    if (@import("chars.zig").isDigit(c)) {
                        data.appendCp(&r, c);
                    } else if (c == '.') {
                        data.appendCp(&r, c);
                        state = 21;
                    } else {
                        l.unread(c);
                        state = -1;
                    }
                },
                21 => {
                    if (@import("chars.zig").isDigit(c)) {
                        data.appendCp(&r, c);
                    } else {
                        l.unread(c);
                        state = -1;
                    }
                },
                3 => {
                    if (c >= 'a' and c <= 'z') {
                        data.appendCp(&r, c);
                    } else {
                        l.unread(c);
                        state = -1;
                    }
                },
                4 => {
                    switch (c) {
                        '\\' => data.appendCp(&r, '\\'),
                        '"' => data.appendCp(&r, '"'),
                        'b' => data.appendCp(&r, 8),
                        'f' => data.appendCp(&r, 12),
                        'n' => data.appendCp(&r, '\n'),
                        'r' => data.appendCp(&r, '\r'),
                        't' => data.appendCp(&r, '\t'),
                        'u' => {
                            var v: u21 = 0;
                            var ok = true;
                            for (0..4) |_| {
                                const d = l.read() orelse {
                                    ok = false;
                                    break;
                                };
                                const x: u21 = switch (d) {
                                    '0'...'9' => d - '0',
                                    'a'...'f' => d - 'a' + 10,
                                    'A'...'F' => d - 'A' + 10,
                                    else => 0,
                                };
                                v = v * 16 + x;
                            }
                            if (ok) data.appendCp(&r, if (v >= 0xD800 and v <= 0xDFFF) 0xFFFD else v);
                        },
                        else => {
                            data.appendCp(&r, '\\');
                            data.appendCp(&r, c);
                        },
                    }
                    state = 1;
                },
                else => {},
            }
            if (state == -1) break;
        }
        defer r.deinit(pa);
        return if (r.items.len > 0) (l.alloc.dupe(u8, r.items) catch rt.oom()) else null;
    }

    fn match(l: *Lexer, token: []const u8) JError!void {
        const n = l.next();
        if (n == null or !std.mem.eql(u8, n.?, token)) {
            l.err = msg("Expected {s} but got {s}", .{ token, n orelse "null" });
            return error.Json;
        }
    }
};

/// A JSON reader. Its text, tokens and objects are in its arena, freed
/// when the reader and every object read from it are unreachable (refs:
/// the reader's native object and each JSON object's)
const Parser = struct {
    lexer: Lexer,
    list_id: []const u8 = "data",
    status: enum { start, reading, end } = .start,
    arena: std.heap.ArenaAllocator,
    text: []const u8,
    refs: std.atomic.Value(u32) = .init(1),

    fn alloc(p: *Parser) std.mem.Allocator {
        return p.arena.allocator();
    }

    fn fail(p: *Parser, m: []const u8) JError {
        p.lexer.err = m;
        return error.Json;
    }

    fn nextObject(p: *Parser) JError!?*JObject {
        switch (p.status) {
            .start => {
                const tok = p.lexer.next();
                if (tok != null and std.mem.eql(u8, tok.?, "{")) {
                    const t2 = p.lexer.next();
                    if (t2) |k| {
                        if (k.len == p.list_id.len + 2 and k[0] == '"' and std.mem.eql(u8, k[1 .. k.len - 1], p.list_id)) {
                            try p.lexer.match(":");
                            try p.lexer.match("[");
                            p.status = .reading;
                            return try p.object();
                        }
                        p.lexer.putBack(k);
                        p.lexer.putBack("{");
                        p.status = .reading;
                        return try p.object();
                    }
                } else if (tok != null and std.mem.eql(u8, tok.?, "[")) {
                    p.status = .reading;
                    return try p.object();
                }
                return null;
            },
            .reading => {
                var tok = p.lexer.next();
                if (tok != null and std.mem.eql(u8, tok.?, ",")) tok = p.lexer.next();
                if (tok == null or std.mem.eql(u8, tok.?, "]")) {
                    p.status = .end;
                    return null;
                }
                p.lexer.putBack(tok.?);
                return try p.object();
            },
            .end => return null,
        }
    }

    fn scalar(p: *Parser, tok: []const u8) JError!JValue {
        if (std.mem.eql(u8, tok, "null")) return .null_;
        if (std.mem.eql(u8, tok, "true")) return .true_;
        if (std.mem.eql(u8, tok, "false")) return .false_;
        if (std.mem.eql(u8, tok, "{")) {
            p.lexer.putBack("{");
            return .{ .object = try p.object() };
        }
        if (std.mem.eql(u8, tok, "[")) {
            p.lexer.putBack("[");
            return .{ .list = try p.list() };
        }
        if (tok[0] == '"') return .{ .string = tok[1 .. tok.len - 1] };
        const f = std.fmt.parseFloat(f64, tok) catch return p.fail(msg("For input string: \"{s}\"", .{tok}));
        return .{ .number = f };
    }

    fn object(p: *Parser) JError!*JObject {
        const result = p.alloc().create(JObject) catch rt.oom();
        result.* = .{};
        try p.lexer.match("{");
        var tok = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
        if (std.mem.eql(u8, tok, "}")) return result;
        while (true) {
            if (tok[0] != '"') return p.fail(msg("Expected string but got {s}", .{tok}));
            const name = tok[1 .. tok.len - 1];
            try p.lexer.match(":");
            const v = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
            result.put(p.alloc(), name, try p.scalar(v));
            tok = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
            if (std.mem.eql(u8, tok, "}")) break;
            if (!std.mem.eql(u8, tok, ",")) return p.fail(msg("Expected comma or end of object but got {s}", .{tok}));
            tok = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
        }
        return result;
    }

    fn list(p: *Parser) JError![]JValue {
        var items: std.ArrayList(JValue) = .empty;
        try p.lexer.match("[");
        var tok = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
        if (std.mem.eql(u8, tok, "]")) return items.items;
        while (true) {
            items.append(p.alloc(), try p.scalar(tok)) catch rt.oom();
            tok = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
            if (std.mem.eql(u8, tok, "]")) break;
            if (!std.mem.eql(u8, tok, ",")) return p.fail(msg("Expected comma or end of list but got {s}", .{tok}));
            tok = p.lexer.next() orelse return p.fail("Unexpected end of tokens");
        }
        return items.items;
    }
};

/// text: owned by the reader
fn openJson(t: *Thread, text: []const u8) Err!Word {
    var list_id: []const u8 = "data";
    if (t.argc == 2) {
        const id = arg(t, 1);
        list_id = if (data.isSymbol(id)) data.symbolName(id) else data.toUtf8(P.stringArg(t, 1) catch |e| {
            pa.free(text);
            return e;
        });
    }
    const p = pa.create(Parser) catch rt.oom();
    p.* = .{ .lexer = .{ .in = text }, .arena = .init(pa), .text = text };
    p.lexer.alloc = p.alloc();
    p.list_id = p.alloc().dupe(u8, list_id) catch rt.oom();
    return sys.wrapNativeOf(t, .json_reader, p);
}

/// A holder of the parser is gone (the collector, every thread stopped)
pub fn releaseParser(o: *anyopaque) void {
    const p: *Parser = @ptrCast(@alignCast(o));
    if (p.refs.fetchSub(1, .acq_rel) != 1) return;
    p.lexer.tokens.deinit(pa);
    p.arena.deinit();
    pa.free(p.text);
    pa.destroy(p);
}

/// A JSON object read by parser p, keeping p alive; reserve 3 words first
fn wrapObject(t: *Thread, p: *Parser, o: *JObject) Word {
    _ = p.refs.fetchAdd(1, .monotonic);
    return sys.allocNativeSlots(t, .json_object, o, p, 0);
}

fn openJsonString(t: *Thread) Err!Word {
    return openJson(t, data.toUtf8Owned(try P.stringArg(t, 0)));
}
pub const @"%open-json-string" = WN("open-json-string", openJsonString, 1, 2);

fn openJsonFile(t: *Thread) Err!Word {
    const name = data.toUtf8(try P.stringArg(t, 0));
    if (!os.fileExists(name)) return raise(t, msg("open-json-file {s}: file not found", .{name}), &.{});
    const text = os.readFile(name) orelse return raise(t, msg("open-json-file {s}: io error", .{name}), &.{});
    return openJson(t, text);
}
pub const @"%open-json-file" = WN("open-json-file", openJsonFile, 1, 2);

fn parserArg(t: *Thread) Err!*Parser {
    const p = sys.nativeOf(arg(t, 0), .json_reader) orelse return P.argTypeError(t);
    return @ptrCast(@alignCast(p));
}

fn jsonNextObject(t: *Thread) Err!Word {
    const p = try parserArg(t);
    const o = p.nextObject() catch return raise(t, msg("json-next-object failed: {s}", .{p.lexer.err}), &.{});
    t.reserve(3);
    return wrapObject(t, p, o orelse return rt.FALSE);
}
pub const @"%json-next-object" = WN("json-next-object", jsonNextObject, 1, 1);

fn closeJson(t: *Thread) Err!Word {
    _ = try parserArg(t);
    return rt.UNSPEC;
}
pub const @"%close-json" = WN("close-json", closeJson, 1, 1);

/// toScm: strings, #t/#f, '() for null, numbers (exact when integral),
/// objects as native objects, lists as lists
fn jWords(v: JValue) usize {
    return switch (v) {
        .string => |s| data.stringWords(s.len, true),
        .number => 2,
        .object => 3,
        .list => |items| blk: {
            var n: usize = 3 * items.len;
            for (items) |x| n += jWords(x);
            break :blk n;
        },
        else => 0,
    };
}

fn jBuild(t: *Thread, p: *Parser, v: JValue) Word {
    return switch (v) {
        .null_ => rt.NIL,
        .true_ => rt.TRUE,
        .false_ => rt.FALSE,
        .string => |s| data.heapStringUtf8(t, s),
        .number => |f| blk: {
            if (f == @trunc(f) and @abs(f) < 9.2e18) {
                const n: i64 = @intFromFloat(f);
                if (rt.fixFits(n)) break :blk fix(n);
            }
            break :blk t.makeFlo(f);
        },
        .object => |o| wrapObject(t, p, o),
        .list => |items| blk: {
            var l = rt.NIL;
            var i = items.len;
            while (i > 0) {
                i -= 1;
                l = t.cons(jBuild(t, p, items[i]), l);
            }
            break :blk l;
        },
    };
}

fn jsonAttribute(t: *Thread) Err!Word {
    const p = sys.nativeOf(arg(t, 0), .json_object) orelse return raise(t, "json-attribute failed: not a JSON object", &.{});
    const o: *JObject = @ptrCast(@alignCast(p));
    const parser: *Parser = @ptrCast(@alignCast(sys.nativeRecord(arg(t, 0)).owner.?));
    const k = arg(t, 1);
    const name = if (data.isSymbol(k)) data.symbolName(k) else data.toUtf8(try P.stringArg(t, 1));
    const v = o.get(name) orelse return if (t.argc == 3) arg(t, 2) else rt.FALSE;
    t.reserve(jWords(v));
    return jBuild(t, parser, v);
}
pub const @"%json-attribute" = WN("json-attribute", jsonAttribute, 2, 3);

/// JsonObject.toString, for printing
pub fn objectText(o: *const JObject, b: *Buf) void {
    put(b, "{");
    for (o.keys.items, o.values.items, 0..) |k, v, i| {
        if (i > 0) put(b, ", ");
        put(b, "\"");
        for (k) |c| switch (c) {
            '\\' => put(b, "\\\\"),
            '"' => put(b, "\\\""),
            else => b.append(pa, c) catch rt.oom(),
        };
        put(b, "\": ");
        valueText(v, b);
    }
    put(b, "}");
}

fn valueText(v: JValue, b: *Buf) void {
    switch (v) {
        .null_ => put(b, "null"),
        .true_ => put(b, "true"),
        .false_ => put(b, "false"),
        .number => |f| {
            // JsonNumber.toString: integral values as Java ints
            if (f == @floor(f)) {
                const n: i64 = if (std.math.isNan(f)) 0 else if (f >= 2147483647) 2147483647 else if (f <= -2147483648) -2147483648 else @intFromFloat(f);
                var tmp: [24]u8 = undefined;
                put(b, std.fmt.bufPrint(&tmp, "{d}", .{n}) catch unreachable);
            } else @import("num.zig").formatFlonum(b, f);
        },
        .string => |s| {
            put(b, "\"");
            put(b, s);
            put(b, "\"");
        },
        .object => |o| objectText(o, b),
        .list => |items| {
            put(b, "[");
            for (items, 0..) |x, i| {
                if (i > 0) put(b, ", ");
                valueText(x, b);
            }
            put(b, "]");
        },
    }
}
