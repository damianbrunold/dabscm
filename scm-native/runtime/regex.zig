//! Regular expressions for (scm string): the subset that java.util.regex
//! and .NET Regex (the JVM and .NET implementations' engines) share, as the
//! regex primitives document it. Patterns outside that subset are rejected
//! (BadPattern), so that a program does not depend on one host's dialect.
//!
//! Supported: literals and escapes (\t \n \r \f \e \a \cX \xhh \uhhhh and
//! escaped metacharacters), . (not a line terminator, unless (?s)),
//! classes [...] with ranges and negation, \d \D \w \W \s \S (ASCII),
//! \p{L} \p{Lu} \p{Ll} \p{N} \p{Nd} and \P{...}, anchors ^ $ \A \z \Z \b \B,
//! groups (...) (?:...) (?<name>...), alternation, quantifiers * + ? {n}
//! {n,} {n,m} and their lazy forms, backreferences \1..\9 and \k<name>,
//! lookahead and lookbehind, atomic groups (?>...), and the inline flags
//! i m s x, as (?flags) and (?flags:...).
//!
//! Rejected (one host only): \Q...\E, possessive quantifiers, \x{...},
//! octal \0, \h \v \R and other classes, (?'name'...), nested classes
//! (Java union and intersection, .NET subtraction), the flags u d U n, and
//! {,m}.
//!
//! Where the hosts differ on input, java.util.regex is followed: \w \d \s
//! are ASCII, and . and $ treat \n \r \u0085     as line
//! terminators.
//!
//! The pattern is parsed into a tree and compiled to a program for a
//! backtracking matcher over code points.
const std = @import("std");
const chars = @import("chars.zig");

const pa = std.heap.c_allocator;

pub const Error = error{ BadPattern, OutOfMemory };

// --- syntax tree ------------------------------------------------------------------

const ClassItem = union(enum) {
    range: struct { lo: u21, hi: u21 },
    digit: bool, // true: \d, false: \D
    word: bool,
    space: bool,
    category: struct { cat: Category, positive: bool },
};

const Category = enum { letter, upper, lower, number };

const Class = struct {
    items: []const ClassItem,
    negated: bool,
    icase: bool,
};

const Assertion = enum { bol, eol, bol_multi, eol_multi, begin, end_input, end_or_final_newline, word, not_word };

const Node = union(enum) {
    char: struct { ch: u21, icase: bool },
    any: bool, // true: also line terminators ((?s))
    class: *const Class,
    seq: []const *Node,
    alt: []const *Node,
    repeat: struct { node: *Node, min: usize, max: ?usize, lazy: bool },
    group: struct { n: usize, node: *Node }, // n = 0: not capturing
    assertion: Assertion,
    backref: struct { n: usize, icase: bool },
    look: struct { node: *Node, ahead: bool, negated: bool },
    atomic: *Node,
};

const Flags = struct { icase: bool = false, multi: bool = false, dotall: bool = false, extended: bool = false };

const Parser = struct {
    pat: []const u21,
    pos: usize = 0,
    ngroups: usize = 0,
    names: std.ArrayList(struct { name: []const u21, n: usize }) = .empty,

    fn peek(p: *Parser) ?u21 {
        return if (p.pos < p.pat.len) p.pat[p.pos] else null;
    }
    fn next(p: *Parser) ?u21 {
        const ch = p.peek() orelse return null;
        p.pos += 1;
        return ch;
    }
    fn node(_: *Parser, n: Node) Error!*Node {
        const x = try pa.create(Node);
        x.* = n;
        return x;
    }

    /// in (?x) mode: skip whitespace and # comments
    fn skipExtended(p: *Parser, f: *Flags) void {
        if (!f.extended) return;
        while (p.peek()) |ch| {
            if (ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r' or ch == 0x0B or ch == 0x0C) {
                p.pos += 1;
            } else if (ch == '#') {
                while (p.next()) |d| if (d == '\n') break;
            } else break;
        }
    }

    fn alternation(p: *Parser, f: *Flags) Error!*Node {
        var alts: std.ArrayList(*Node) = .empty;
        try alts.append(pa, try p.sequence(f));
        while (p.peek() == '|') {
            p.pos += 1;
            try alts.append(pa, try p.sequence(f));
        }
        if (alts.items.len == 1) return alts.items[0];
        return p.node(.{ .alt = alts.items });
    }

    fn sequence(p: *Parser, f: *Flags) Error!*Node {
        var items: std.ArrayList(*Node) = .empty;
        while (true) {
            p.skipExtended(f);
            const ch = p.peek() orelse break;
            if (ch == '|' or ch == ')') break;
            if (try p.quantified(f)) |n| try items.append(pa, n);
        }
        return p.node(.{ .seq = items.items });
    }

    /// an atom and its quantifier; null for a flag group like (?i)
    fn quantified(p: *Parser, f: *Flags) Error!?*Node {
        const a = (try p.atom(f)) orelse return null;
        p.skipExtended(f);
        const q = p.peek() orelse return a;
        var min: usize = 0;
        var max: ?usize = null;
        switch (q) {
            '*' => p.pos += 1,
            '+' => {
                p.pos += 1;
                min = 1;
            },
            '?' => {
                p.pos += 1;
                max = 1;
            },
            '{' => {
                const save = p.pos;
                p.pos += 1;
                const lo = p.number() orelse {
                    // {,m} means different things to the hosts; a literal {
                    // elsewhere is ambiguous too
                    p.pos = save;
                    return error.BadPattern;
                };
                min = lo;
                max = lo;
                if (p.peek() == ',') {
                    p.pos += 1;
                    max = p.number();
                }
                if (p.next() != '}') return error.BadPattern;
                if (max) |m| if (m < min) return error.BadPattern;
            },
            else => return a,
        }
        var lazy = false;
        if (p.peek() == '?') {
            p.pos += 1;
            lazy = true;
        } else if (p.peek() == '+') {
            return error.BadPattern; // possessive: Java only
        }
        return try p.node(.{ .repeat = .{ .node = a, .min = min, .max = max, .lazy = lazy } });
    }

    fn number(p: *Parser) ?usize {
        var n: ?usize = null;
        while (p.peek()) |ch| {
            if (ch < '0' or ch > '9') break;
            p.pos += 1;
            n = (n orelse 0) * 10 + (ch - '0');
        }
        return n;
    }

    fn atom(p: *Parser, f: *Flags) Error!?*Node {
        const ch = p.next() orelse return error.BadPattern;
        return switch (ch) {
            '.' => try p.node(.{ .any = f.dotall }),
            '^' => try p.node(.{ .assertion = if (f.multi) .bol_multi else .bol }),
            '$' => try p.node(.{ .assertion = if (f.multi) .eol_multi else .eol }),
            '[' => try p.node(.{ .class = try p.class(f) }),
            '(' => try p.group(f),
            '\\' => try p.escape(f),
            '*', '+', '?', '{' => error.BadPattern, // nothing to repeat
            else => try p.node(.{ .char = .{ .ch = ch, .icase = f.icase } }),
        };
    }

    fn group(p: *Parser, f: *Flags) Error!?*Node {
        if (p.peek() != '?') {
            p.ngroups += 1;
            const n = p.ngroups;
            var inner = f.*;
            const body = try p.alternation(&inner);
            if (p.next() != ')') return error.BadPattern;
            return try p.node(.{ .group = .{ .n = n, .node = body } });
        }
        p.pos += 1;
        const kind = p.next() orelse return error.BadPattern;
        switch (kind) {
            ':' => return try p.groupBody(f, 0),
            '>' => {
                var inner = f.*;
                const body = try p.alternation(&inner);
                if (p.next() != ')') return error.BadPattern;
                return try p.node(.{ .atomic = body });
            },
            '=', '!' => return try p.lookBody(f, true, kind == '!'),
            '<' => {
                if (p.peek() == '=' or p.peek() == '!') {
                    const neg = p.next().? == '!';
                    return try p.lookBody(f, false, neg);
                }
                // named group (?<name>...)
                const start = p.pos;
                while (p.next()) |c| {
                    if (c == '>') break;
                    if (!isWord(c)) return error.BadPattern;
                }
                p.ngroups += 1;
                try p.names.append(pa, .{ .name = p.pat[start .. p.pos - 1], .n = p.ngroups });
                return try p.groupBody(f, p.ngroups);
            },
            else => {
                // inline flags: (?imsx-imsx) or (?imsx-imsx:...)
                p.pos -= 1;
                var g = f.*;
                var on = true;
                while (p.next()) |c| switch (c) {
                    'i' => g.icase = on,
                    'm' => g.multi = on,
                    's' => g.dotall = on,
                    'x' => g.extended = on,
                    '-' => on = false,
                    ')' => {
                        f.* = g; // for the rest of the enclosing group
                        return null;
                    },
                    ':' => {
                        const body = try p.alternation(&g);
                        if (p.next() != ')') return error.BadPattern;
                        return try p.node(.{ .group = .{ .n = 0, .node = body } });
                    },
                    else => return error.BadPattern, // u d U n ...: one host only
                };
                return error.BadPattern;
            },
        }
    }

    fn groupBody(p: *Parser, f: *Flags, n: usize) Error!*Node {
        var inner = f.*;
        const body = try p.alternation(&inner);
        if (p.next() != ')') return error.BadPattern;
        return p.node(.{ .group = .{ .n = n, .node = body } });
    }

    fn lookBody(p: *Parser, f: *Flags, ahead: bool, negated: bool) Error!*Node {
        var inner = f.*;
        const body = try p.alternation(&inner);
        if (p.next() != ')') return error.BadPattern;
        return p.node(.{ .look = .{ .node = body, .ahead = ahead, .negated = negated } });
    }

    fn escape(p: *Parser, f: *Flags) Error!*Node {
        const ch = p.next() orelse return error.BadPattern;
        switch (ch) {
            'd', 'D', 'w', 'W', 's', 'S' => {
                const items = try pa.alloc(ClassItem, 1);
                items[0] = predefined(ch);
                return p.classNode(items, false, false);
            },
            'p', 'P' => {
                const items = try pa.alloc(ClassItem, 1);
                items[0] = try p.property(ch == 'p');
                return p.classNode(items, false, false);
            },
            'b' => return p.node(.{ .assertion = .word }),
            'B' => return p.node(.{ .assertion = .not_word }),
            'A' => return p.node(.{ .assertion = .begin }),
            'z' => return p.node(.{ .assertion = .end_input }),
            'Z' => return p.node(.{ .assertion = .end_or_final_newline }),
            '1'...'9' => {
                const n: usize = ch - '0';
                return p.node(.{ .backref = .{ .n = n, .icase = f.icase } });
            },
            'k' => {
                if (p.next() != '<') return error.BadPattern;
                const start = p.pos;
                while (p.next()) |c| if (c == '>') break;
                const name = p.pat[start .. p.pos - 1];
                for (p.names.items) |entry| if (std.mem.eql(u21, entry.name, name))
                    return p.node(.{ .backref = .{ .n = entry.n, .icase = f.icase } });
                return error.BadPattern;
            },
            else => return p.node(.{ .char = .{ .ch = try p.escapeChar(ch), .icase = f.icase } }),
        }
    }

    fn classNode(p: *Parser, items: []const ClassItem, negated: bool, icase: bool) Error!*Node {
        const cl = try pa.create(Class);
        cl.* = .{ .items = items, .negated = negated, .icase = icase };
        return p.node(.{ .class = cl });
    }

    fn escapeChar(p: *Parser, ch: u21) Error!u21 {
        return switch (ch) {
            't' => '\t',
            'n' => '\n',
            'r' => '\r',
            'f' => 0x0C,
            'e' => 0x1B,
            'a' => 7,
            'x' => blk: {
                if (p.peek() == '{') return error.BadPattern; // \x{...}: Java only
                const h1 = hexValue(p.next() orelse return error.BadPattern) orelse return error.BadPattern;
                const h2 = hexValue(p.next() orelse return error.BadPattern) orelse return error.BadPattern;
                break :blk h1 * 16 + h2;
            },
            'u' => blk: {
                var v: u21 = 0;
                for (0..4) |_| v = v * 16 + (hexValue(p.next() orelse return error.BadPattern) orelse return error.BadPattern);
                break :blk v;
            },
            'c' => blk: {
                const c = p.next() orelse return error.BadPattern;
                if (!((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z'))) return error.BadPattern;
                break :blk (c & 0x1F);
            },
            // escaped metacharacters and other punctuation
            '\\', '.', '*', '+', '?', '(', ')', '[', ']', '{', '}', '|', '^', '$', '-', '/', '#', ' ', '&', '~', '!', '"', '\'', ',', ':', ';', '<', '=', '>', '@', '%', '`', '_' => ch,
            else => error.BadPattern, // \Q \0 \h \v \R \G ...: one host only or unknown
        };
    }

    fn property(p: *Parser, positive: bool) Error!ClassItem {
        if (p.next() != '{') return error.BadPattern;
        const start = p.pos;
        while (p.next()) |c| if (c == '}') break;
        const name = p.pat[start .. p.pos - 1];
        const cat: Category = if (eqlName(name, "L")) .letter else if (eqlName(name, "Lu")) .upper else if (eqlName(name, "Ll")) .lower else if (eqlName(name, "N") or eqlName(name, "Nd")) .number else return error.BadPattern;
        return .{ .category = .{ .cat = cat, .positive = positive } };
    }

    fn class(p: *Parser, f: *Flags) Error!*const Class {
        var items: std.ArrayList(ClassItem) = .empty;
        var negated = false;
        if (p.peek() == '^') {
            p.pos += 1;
            negated = true;
        }
        var first = true;
        while (true) {
            const ch = p.next() orelse return error.BadPattern;
            if (ch == ']' and !first) break;
            first = false;
            if (ch == '[') return error.BadPattern; // nested classes: one host each
            if (ch == '&' and p.peek() == '&') return error.BadPattern; // Java intersection
            var lo: u21 = ch;
            if (ch == '\\') {
                const e = p.next() orelse return error.BadPattern;
                switch (e) {
                    'd', 'D', 'w', 'W', 's', 'S' => {
                        try items.append(pa, predefined(e));
                        continue;
                    },
                    'p', 'P' => {
                        try items.append(pa, try p.property(e == 'p'));
                        continue;
                    },
                    'b' => lo = 8,
                    else => lo = try p.escapeChar(e),
                }
            }
            var hi = lo;
            if (p.peek() == '-' and p.pos + 1 < p.pat.len and p.pat[p.pos + 1] != ']') {
                p.pos += 1;
                if (p.peek() == '[') return error.BadPattern; // .NET subtraction
                hi = p.next() orelse return error.BadPattern;
                if (hi == '\\') hi = try p.escapeChar(p.next() orelse return error.BadPattern);
                if (hi < lo) return error.BadPattern;
            }
            try items.append(pa, .{ .range = .{ .lo = lo, .hi = hi } });
        }
        const cl = try pa.create(Class);
        cl.* = .{ .items = items.items, .negated = negated, .icase = f.icase };
        return cl;
    }
};

fn eqlName(name: []const u21, s: []const u8) bool {
    if (name.len != s.len) return false;
    for (name, s) |a, b| if (a != b) return false;
    return true;
}

fn hexValue(d: u21) ?u21 {
    return switch (d) {
        '0'...'9' => d - '0',
        'a'...'f' => d - 'a' + 10,
        'A'...'F' => d - 'A' + 10,
        else => null,
    };
}

fn predefined(ch: u21) ClassItem {
    return switch (ch) {
        'd' => .{ .digit = true },
        'D' => .{ .digit = false },
        'w' => .{ .word = true },
        'W' => .{ .word = false },
        's' => .{ .space = true },
        else => .{ .space = false },
    };
}

// --- program -----------------------------------------------------------------------

const Inst = union(enum) {
    char: struct { ch: u21, icase: bool },
    any: bool,
    class: *const Class,
    split: struct { x: usize, y: usize }, // try x first
    jmp: usize,
    save: usize,
    assertion: Assertion,
    backref: struct { n: usize, icase: bool },
    look: struct { start: usize, ahead: bool, negated: bool },
    atomic: usize, // start of a subprogram ending in match
    /// a loop whose body can match the empty string: remember the position
    /// at the start of an iteration; an iteration that consumed nothing
    /// leaves the loop (so that (a*)* terminates, with the group's last,
    /// empty match, as java.util.regex)
    loop_enter: usize,
    loop_progress: struct { reg: usize, exit: usize },
    match: void,
};

pub const Regex = struct {
    prog: []Inst,
    ngroups: usize, // capture groups, without the whole match
    nloops: usize, // loop registers
    anchored: bool, // starts with ^ (not multi-line) or \A
};

const Gen = struct {
    prog: std.ArrayList(Inst) = .empty,
    nloops: usize = 0,
    subs: std.ArrayList(struct { at: usize, node: *Node }) = .empty,

    fn emit(g: *Gen, i: Inst) Error!usize {
        try g.prog.append(pa, i);
        return g.prog.items.len - 1;
    }
    fn here(g: *Gen) usize {
        return g.prog.items.len;
    }

    fn gen(g: *Gen, n: *const Node) Error!void {
        switch (n.*) {
            .char => |c| _ = try g.emit(.{ .char = .{ .ch = c.ch, .icase = c.icase } }),
            .any => |all| _ = try g.emit(.{ .any = all }),
            .class => |cl| _ = try g.emit(.{ .class = cl }),
            .seq => |items| for (items) |x| try g.gen(x),
            .alt => |alts| {
                var jumps: std.ArrayList(usize) = .empty;
                defer jumps.deinit(pa);
                for (alts, 0..) |a, i| {
                    if (i + 1 < alts.len) {
                        const sp = try g.emit(.{ .split = .{ .x = 0, .y = 0 } });
                        try g.gen(a);
                        try jumps.append(pa, try g.emit(.{ .jmp = 0 }));
                        g.prog.items[sp] = .{ .split = .{ .x = sp + 1, .y = g.here() } };
                    } else try g.gen(a);
                }
                for (jumps.items) |j| g.prog.items[j] = .{ .jmp = g.here() };
            },
            .repeat => |r| {
                for (0..r.min) |_| try g.gen(r.node);
                if (r.max) |mx| {
                    // optional copies: each one may be skipped
                    var skips: std.ArrayList(usize) = .empty;
                    defer skips.deinit(pa);
                    var i = r.min;
                    while (i < mx) : (i += 1) {
                        try skips.append(pa, try g.emit(.{ .split = .{ .x = 0, .y = 0 } }));
                        try g.gen(r.node);
                    }
                    const end = g.here();
                    for (skips.items) |sp| g.prog.items[sp] = if (r.lazy)
                        .{ .split = .{ .x = end, .y = sp + 1 } }
                    else
                        .{ .split = .{ .x = sp + 1, .y = end } };
                } else {
                    const sp = try g.emit(.{ .split = .{ .x = 0, .y = 0 } });
                    const body = g.here();
                    const empty = canBeEmpty(r.node);
                    const reg = g.nloops;
                    if (empty) {
                        g.nloops += 1;
                        _ = try g.emit(.{ .loop_enter = reg });
                    }
                    try g.gen(r.node);
                    const progress = if (empty) try g.emit(.{ .loop_progress = .{ .reg = reg, .exit = 0 } }) else null;
                    _ = try g.emit(.{ .jmp = sp });
                    const end = g.here();
                    if (progress) |pp| g.prog.items[pp] = .{ .loop_progress = .{ .reg = reg, .exit = end } };
                    g.prog.items[sp] = if (r.lazy) .{ .split = .{ .x = end, .y = body } } else .{ .split = .{ .x = body, .y = end } };
                }
            },
            .group => |grp| {
                if (grp.n > 0) _ = try g.emit(.{ .save = 2 * grp.n });
                try g.gen(grp.node);
                if (grp.n > 0) _ = try g.emit(.{ .save = 2 * grp.n + 1 });
            },
            .assertion => |a| _ = try g.emit(.{ .assertion = a }),
            .backref => |b| _ = try g.emit(.{ .backref = .{ .n = b.n, .icase = b.icase } }),
            .look => |l| {
                const at = try g.emit(.{ .look = .{ .start = 0, .ahead = l.ahead, .negated = l.negated } });
                try g.subs.append(pa, .{ .at = at, .node = l.node });
            },
            .atomic => |a| {
                const at = try g.emit(.{ .atomic = 0 });
                try g.subs.append(pa, .{ .at = at, .node = a });
            },
        }
    }
};

pub fn compile(pattern: []const u21) Error!Regex {
    var p = Parser{ .pat = pattern };
    var flags = Flags{};
    const tree = try p.alternation(&flags);
    if (p.pos != pattern.len) return error.BadPattern; // an unmatched )
    // backreferences to groups that do not exist
    if (maxBackref(tree) > p.ngroups) return error.BadPattern;
    var g = Gen{};
    try g.gen(tree);
    _ = try g.emit(.match);
    // subprograms (lookaround, atomic groups), each ending in match
    var i: usize = 0;
    while (i < g.subs.items.len) : (i += 1) {
        const sub = g.subs.items[i];
        const start = g.here();
        try g.gen(sub.node);
        _ = try g.emit(.match);
        switch (g.prog.items[sub.at]) {
            .look => |*l| l.start = start,
            .atomic => |*a| a.* = start,
            else => unreachable,
        }
    }
    const first = g.prog.items[0];
    const anchored = first == .assertion and (first.assertion == .bol or first.assertion == .begin);
    return .{ .prog = g.prog.items, .ngroups = p.ngroups, .nloops = g.nloops, .anchored = anchored };
}

fn canBeEmpty(n: *const Node) bool {
    return switch (n.*) {
        .char, .any, .class => false,
        .seq => |items| blk: {
            for (items) |x| if (!canBeEmpty(x)) break :blk false;
            break :blk true;
        },
        .alt => |items| blk: {
            for (items) |x| if (canBeEmpty(x)) break :blk true;
            break :blk false;
        },
        .repeat => |r| r.min == 0 or canBeEmpty(r.node),
        .group => |grp| canBeEmpty(grp.node),
        .atomic => |a| canBeEmpty(a),
        .assertion, .look, .backref => true,
    };
}

fn maxBackref(n: *const Node) usize {
    return switch (n.*) {
        .backref => |b| b.n,
        .seq, .alt => |items| blk: {
            var m: usize = 0;
            for (items) |x| m = @max(m, maxBackref(x));
            break :blk m;
        },
        .repeat => |r| maxBackref(r.node),
        .group => |grp| maxBackref(grp.node),
        .look => |l| maxBackref(l.node),
        .atomic => |a| maxBackref(a),
        else => 0,
    };
}

// --- matcher -------------------------------------------------------------------------

fn isWord(ch: u21) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_';
}

fn isLineTerminator(ch: u21) bool {
    return ch == '\n' or ch == '\r' or ch == 0x85 or ch == 0x2028 or ch == 0x2029;
}

fn itemMatches(item: ClassItem, ch: u21) bool {
    return switch (item) {
        .range => |r| ch >= r.lo and ch <= r.hi,
        .digit => |pos| (ch >= '0' and ch <= '9') == pos,
        .word => |pos| isWord(ch) == pos,
        .space => |pos| (ch == ' ' or ch == '\t' or ch == '\n' or ch == 0x0B or ch == 0x0C or ch == '\r') == pos,
        .category => |c| (switch (c.cat) {
            .letter => chars.isAlphabetic(ch),
            .upper => chars.isUpper(ch),
            .lower => chars.isLower(ch),
            .number => chars.isDigit(ch),
        }) == c.positive,
    };
}

fn inClass(cl: *const Class, ch: u21) bool {
    var hit = false;
    for (cl.items) |item| {
        if (itemMatches(item, ch) or (cl.icase and (itemMatches(item, chars.foldcase(ch)) or itemMatches(item, chars.upcase(ch))))) {
            hit = true;
            break;
        }
    }
    return hit != cl.negated;
}

const Matcher = struct {
    re: *const Regex,
    s: []const u21,
    caps: []?usize,
    loops: []usize,
    /// for lookbehind: the subprogram's match must end here
    end_at: ?usize = null,
    end_pos: usize = 0,

    fn run(m: *Matcher, pc0: usize, pos0: usize) bool {
        var pc = pc0;
        var pos = pos0;
        while (true) {
            switch (m.re.prog[pc]) {
                .char => |c| {
                    if (pos >= m.s.len) return false;
                    const x = m.s[pos];
                    if (x != c.ch and !(c.icase and (chars.foldcase(x) == chars.foldcase(c.ch) or chars.upcase(x) == chars.upcase(c.ch)))) return false;
                    pos += 1;
                    pc += 1;
                },
                .any => |all| {
                    if (pos >= m.s.len or (!all and isLineTerminator(m.s[pos]))) return false;
                    pos += 1;
                    pc += 1;
                },
                .class => |cl| {
                    if (pos >= m.s.len or !inClass(cl, m.s[pos])) return false;
                    pos += 1;
                    pc += 1;
                },
                .split => |sp| {
                    if (m.run(sp.x, pos)) return true;
                    pc = sp.y;
                },
                .jmp => |j| pc = j,
                .save => |n| {
                    const old = m.caps[n];
                    m.caps[n] = pos;
                    if (m.run(pc + 1, pos)) return true;
                    m.caps[n] = old;
                    return false;
                },
                .assertion => |a| {
                    const ok = switch (a) {
                        .bol, .begin => pos == 0,
                        .eol, .end_or_final_newline => pos == m.s.len or (pos + 1 == m.s.len and isLineTerminator(m.s[pos])) or
                            (pos + 2 == m.s.len and m.s[pos] == '\r' and m.s[pos + 1] == '\n'),
                        .bol_multi => pos == 0 or (isLineTerminator(m.s[pos - 1]) and !(m.s[pos - 1] == '\r' and pos < m.s.len and m.s[pos] == '\n') and pos < m.s.len),
                        .eol_multi => pos == m.s.len or (isLineTerminator(m.s[pos]) and !(m.s[pos] == '\n' and pos > 0 and m.s[pos - 1] == '\r')),
                        .end_input => pos == m.s.len,
                        .word, .not_word => blk: {
                            const before = pos > 0 and isWord(m.s[pos - 1]);
                            const after = pos < m.s.len and isWord(m.s[pos]);
                            break :blk (before != after) == (a == .word);
                        },
                    };
                    if (!ok) return false;
                    pc += 1;
                },
                .backref => |b| {
                    const start = m.caps[2 * b.n] orelse return false;
                    const end = m.caps[2 * b.n + 1] orelse return false;
                    const len = end - start;
                    if (pos + len > m.s.len) return false;
                    for (0..len) |i| {
                        const x = m.s[start + i];
                        const y = m.s[pos + i];
                        if (x != y and !(b.icase and chars.foldcase(x) == chars.foldcase(y))) return false;
                    }
                    pos += len;
                    pc += 1;
                },
                .look => |l| {
                    const saved_end = m.end_at;
                    const saved_pos = m.end_pos;
                    var ok = false;
                    if (l.ahead) {
                        m.end_at = null;
                        ok = m.run(l.start, pos);
                    } else {
                        // a match of the body that ends at pos
                        var start = pos + 1;
                        while (start > 0) {
                            start -= 1;
                            m.end_at = pos;
                            if (m.run(l.start, start)) {
                                ok = true;
                                break;
                            }
                        }
                    }
                    m.end_at = saved_end;
                    m.end_pos = saved_pos;
                    if (ok == l.negated) return false;
                    pc += 1;
                },
                .atomic => |start| {
                    const saved_end = m.end_at;
                    m.end_at = null;
                    const ok = m.run(start, pos);
                    m.end_at = saved_end;
                    if (!ok) return false;
                    pos = m.end_pos;
                    pc += 1;
                },
                .loop_enter => |k| {
                    const old = m.loops[k];
                    m.loops[k] = pos;
                    if (m.run(pc + 1, pos)) return true;
                    m.loops[k] = old;
                    return false;
                },
                .loop_progress => |lp| {
                    pc = if (pos == m.loops[lp.reg]) lp.exit else pc + 1;
                },
                .match => {
                    if (m.end_at) |e| return pos == e;
                    m.end_pos = pos;
                    return true;
                },
            }
        }
    }
};

/// Search s from start; on success, caps (2 * (ngroups + 1) entries) holds
/// the positions of the whole match and of each group
pub fn search(re: *const Regex, s: []const u21, start: usize, caps: []?usize) bool {
    var loop_buf: [64]usize = undefined;
    const loops = if (re.nloops <= loop_buf.len) loop_buf[0..re.nloops] else pa.alloc(usize, re.nloops) catch return false;
    var m = Matcher{ .re = re, .s = s, .caps = caps, .loops = loops };
    var i = start;
    while (i <= s.len) : (i += 1) {
        @memset(caps, null);
        if (m.run(0, i)) {
            caps[0] = i;
            caps[1] = m.end_pos;
            return true;
        }
        if (re.anchored) return false;
    }
    return false;
}

// --- cache -------------------------------------------------------------------------

var cache: std.StringHashMapUnmanaged(*Regex) = .empty;
var cache_lock: std.Io.Mutex = .init;

/// The compiled pattern for the UTF-8 pattern text (cached)
pub fn get(pattern_utf8: []const u8) Error!*Regex {
    const io = @import("os.zig").io;
    cache_lock.lockUncancelable(io);
    defer cache_lock.unlock(io);
    if (cache.get(pattern_utf8)) |r| return r;
    var cps: std.ArrayList(u21) = .empty;
    var it = std.unicode.Utf8View.initUnchecked(pattern_utf8).iterator();
    while (it.nextCodepoint()) |cp| try cps.append(pa, cp);
    const r = try pa.create(Regex);
    r.* = try compile(cps.items);
    if (cache.count() > 256) cache.clearRetainingCapacity();
    try cache.put(pa, try pa.dupe(u8, pattern_utf8), r);
    return r;
}
