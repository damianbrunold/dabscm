//! Primitives: strings ((scm string), SRFI 13 helpers), regular
//! expressions (regex.zig), HTML escaping, CSV lines.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const printer = @import("printer.zig");
const regex = @import("regex.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const W = P.W;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const fix = rt.fix;
const unfix = rt.unfix;

const pa = std.heap.c_allocator;

/// The code points of string s (a copy)
fn cps(s: Word) []u21 {
    const n = data.stringLen(s);
    const out = pa.alloc(u21, n) catch rt.oom();
    for (out, 0..) |*c, i| c.* = data.stringRef(s, i);
    return out;
}

fn wide(cs: []const u21) bool {
    for (cs) |c| if (c > 255) return true;
    return false;
}

/// A new string from code points; reserve data.stringWords(cs.len, wide(cs)) first
fn makeStr(t: *Thread, cs: []const u21) Word {
    const s = data.makeString(t, cs.len, wide(cs));
    for (cs, 0..) |c, i| data.stringSetFits(s, i, c);
    return s;
}

fn strWords(cs: []const u21) usize {
    return data.stringWords(cs.len, wide(cs));
}

fn resultStr(t: *Thread, cs: []const u21) Word {
    t.reserve(strWords(cs));
    return makeStr(t, cs);
}

fn pattern(t: *Thread, i: usize) Err!*regex.Regex {
    const p = try P.stringArg(t, i);
    const text = data.toUtf8(p);
    return regex.get(text) catch raise(t, "regular expression not supported (only the subset common to java.util.regex and .NET)", &.{arg(t, i)});
}

// --- regular expressions ---------------------------------------------------------

/// (regex-search s pattern [start]): #(( start . end ) ...) or #f
fn regexSearch(t: *Thread) Err!Word {
    const s = cps(try P.stringArg(t, 0));
    defer pa.free(s);
    const re = try pattern(t, 1);
    const start: usize = if (t.argc > 2) try P.count(t, arg(t, 2)) else 0;
    if (start > s.len) return raise(t, std.fmt.allocPrint(pa, "regex-search: start {d} out of range", .{start}) catch rt.oom(), &.{});
    const caps = pa.alloc(?usize, 2 * (re.ngroups + 1)) catch rt.oom();
    defer pa.free(caps);
    if (!regex.search(re, s, start, caps)) return rt.FALSE;
    const n = re.ngroups + 1;
    t.reserve(1 + n + 3 * n);
    const v = data.makeVector(t, n, rt.FALSE);
    for (0..n) |g| if (caps[2 * g]) |a| if (caps[2 * g + 1]) |b| {
        data.vectorItems(v)[g] = t.cons(fix(@intCast(a)), fix(@intCast(b)));
    };
    return v;
}
pub const @"%regex-search" = WN("regex-search", regexSearch, 2, 3);

/// (string-matches s pattern): the first match and its groups, as strings
fn stringMatches(t: *Thread) Err!Word {
    const s = cps(try P.stringArg(t, 0));
    defer pa.free(s);
    const re = try pattern(t, 1);
    const caps = pa.alloc(?usize, 2 * (re.ngroups + 1)) catch rt.oom();
    defer pa.free(caps);
    if (!regex.search(re, s, 0, caps)) return rt.FALSE;
    const n = re.ngroups + 1;
    var words: usize = 3 * n;
    for (0..n) |g| if (caps[2 * g]) |a| {
        words += strWords(s[a..caps[2 * g + 1].?]);
    };
    t.reserve(words);
    var l = rt.NIL;
    var g = n;
    while (g > 0) {
        g -= 1;
        const item = if (caps[2 * g]) |a| makeStr(t, s[a..caps[2 * g + 1].?]) else rt.FALSE;
        l = t.cons(item, l);
    }
    return l;
}
pub const @"%string-matches" = WN("string-matches", stringMatches, 2, 2);

/// The matches of re in s, java.util.regex Matcher.find style: after an
/// empty match, the next search starts one further
fn allMatches(re: *const regex.Regex, s: []const u21) std.ArrayList([]?usize) {
    var out: std.ArrayList([]?usize) = .empty;
    var from: usize = 0;
    var last_empty_end: ?usize = null;
    while (from <= s.len) {
        const caps = pa.alloc(?usize, 2 * (re.ngroups + 1)) catch rt.oom();
        if (!regex.search(re, s, from, caps)) {
            pa.free(caps);
            break;
        }
        const a = caps[0].?;
        const b = caps[1].?;
        if (a == b and last_empty_end != null and last_empty_end.? == a) {
            // an empty match where the previous one ended: try one further
            pa.free(caps);
            from = a + 1;
            last_empty_end = null;
            continue;
        }
        out.append(pa, caps) catch rt.oom();
        if (a == b) {
            from = b + 1;
            last_empty_end = b;
        } else {
            from = b;
            last_empty_end = b;
        }
    }
    return out;
}

fn freeMatches(ms: *std.ArrayList([]?usize)) void {
    for (ms.items) |m| pa.free(m);
    ms.deinit(pa);
}

/// (string-replace-all-regex s pattern replacement): ~n is group n, ~~ is ~
fn replaceAllRegex(t: *Thread) Err!Word {
    const s = cps(try P.stringArg(t, 0));
    defer pa.free(s);
    const re = try pattern(t, 1);
    const tmpl = cps(try P.stringArg(t, 2));
    defer pa.free(tmpl);
    var ms = allMatches(re, s);
    defer freeMatches(&ms);
    var out: std.ArrayList(u21) = .empty;
    defer out.deinit(pa);
    var last: usize = 0;
    for (ms.items) |caps| {
        out.appendSlice(pa, s[last..caps[0].?]) catch rt.oom();
        var i: usize = 0;
        while (i < tmpl.len) {
            const c = tmpl[i];
            if (c == '~' and i + 1 < tmpl.len) {
                const d = tmpl[i + 1];
                if (d == '~') {
                    out.append(pa, '~') catch rt.oom();
                    i += 2;
                    continue;
                }
                if (d >= '0' and d <= '9') {
                    var j = i + 1;
                    var g: usize = 0;
                    while (j < tmpl.len and tmpl[j] >= '0' and tmpl[j] <= '9') : (j += 1) g = g * 10 + (tmpl[j] - '0');
                    if (g <= re.ngroups) if (caps[2 * g]) |a| {
                        out.appendSlice(pa, s[a..caps[2 * g + 1].?]) catch rt.oom();
                    };
                    i = j;
                    continue;
                }
            }
            out.append(pa, c) catch rt.oom();
            i += 1;
        }
        last = caps[1].?;
    }
    out.appendSlice(pa, s[last..]) catch rt.oom();
    return resultStr(t, out.items);
}
pub const @"%string-replace-all-regex" = WN("string-replace-all-regex", replaceAllRegex, 3, 3);

/// The pieces of s split at matches of re, as java.lang.String.split(re,
/// limit): limit -1 keeps trailing empty pieces, 0 drops them. A zero-width
/// match at the start makes no leading empty piece.
fn splitPieces(re: *const regex.Regex, s: []const u21, keep_trailing: bool) std.ArrayList([2]usize) {
    var pieces: std.ArrayList([2]usize) = .empty;
    var ms = allMatches(re, s);
    defer freeMatches(&ms);
    var index: usize = 0;
    for (ms.items) |caps| {
        const a = caps[0].?;
        const b = caps[1].?;
        if (a == 0 and b == 0) continue;
        pieces.append(pa, .{ index, a }) catch rt.oom();
        index = b;
    }
    if (ms.items.len == 0) {
        pieces.append(pa, .{ 0, s.len }) catch rt.oom();
        return pieces;
    }
    pieces.append(pa, .{ index, s.len }) catch rt.oom();
    if (!keep_trailing) {
        while (pieces.items.len > 0 and pieces.items[pieces.items.len - 1][0] == pieces.items[pieces.items.len - 1][1])
            pieces.items.len -= 1;
    }
    return pieces;
}

const default_split = "[ \\t\\r\\n]+";

fn split(t: *Thread, comptime as_vector: bool) Err!Word {
    const s = cps(try P.stringArg(t, 0));
    defer pa.free(s);
    const re = if (t.argc > 1) try pattern(t, 1) else regex.get(default_split) catch unreachable;
    var pieces = splitPieces(re, s, true);
    defer pieces.deinit(pa);
    var words: usize = if (as_vector) 1 + pieces.items.len else 3 * pieces.items.len;
    for (pieces.items) |pc| words += strWords(s[pc[0]..pc[1]]);
    t.reserve(words);
    if (as_vector) {
        const v = data.makeVector(t, pieces.items.len, rt.FALSE);
        for (pieces.items, 0..) |pc, i| data.vectorItems(v)[i] = makeStr(t, s[pc[0]..pc[1]]);
        return v;
    }
    var l = rt.NIL;
    var i = pieces.items.len;
    while (i > 0) {
        i -= 1;
        const pc = pieces.items[i];
        l = t.cons(makeStr(t, s[pc[0]..pc[1]]), l);
    }
    return l;
}
fn stringSplit(t: *Thread) Err!Word {
    return split(t, false);
}
fn stringSplitVector(t: *Thread) Err!Word {
    return split(t, true);
}
pub const @"%string-split" = WN("string-split", stringSplit, 1, 2);
pub const @"%string-split-vector" = WN("string-split-vector", stringSplitVector, 1, 2);

/// (csv-line->fields str sep ['trim]): split at the regular expression sep
/// (trailing empty fields dropped), strip surrounding double quotes
fn csvLineToFields(t: *Thread) Err!Word {
    const s = cps(try P.stringArg(t, 0));
    defer pa.free(s);
    const re = try pattern(t, 1);
    const trim = t.argc > 2 and data.isSymbol(arg(t, 2)) and std.mem.eql(u8, data.symbolName(arg(t, 2)), "trim");
    var pieces = splitPieces(re, s, false);
    defer pieces.deinit(pa);
    for (pieces.items) |*pc| {
        if (pc[1] - pc[0] >= 2 and s[pc[0]] == '"' and s[pc[1] - 1] == '"') {
            pc[0] += 1;
            pc[1] -= 1;
        } else if (pc[1] - pc[0] == 1 and s[pc[0]] == '"') {
            // "\"" is both prefix and suffix in Java: an empty field
            pc[1] = pc[0];
        }
        if (trim) {
            while (pc[0] < pc[1] and s[pc[0]] <= ' ') pc[0] += 1;
            while (pc[1] > pc[0] and s[pc[1] - 1] <= ' ') pc[1] -= 1;
        }
    }
    var words: usize = 1 + pieces.items.len;
    for (pieces.items) |pc| words += strWords(s[pc[0]..pc[1]]);
    t.reserve(words);
    const v = data.makeVector(t, pieces.items.len, rt.FALSE);
    for (pieces.items, 0..) |pc, i| data.vectorItems(v)[i] = makeStr(t, s[pc[0]..pc[1]]);
    return v;
}
pub const @"%csv-line->fields" = WN("csv-line->fields", csvLineToFields, 2, 3);

// --- plain string operations ------------------------------------------------------

fn startsWith(s: Word, prefix: Word, at: usize) bool {
    const n = data.stringLen(prefix);
    if (at + n > data.stringLen(s)) return false;
    for (0..n) |i| if (data.stringRef(s, at + i) != data.stringRef(prefix, i)) return false;
    return true;
}

fn stringPrefixP(t: *Thread) Err!Word {
    return rt.boolean(startsWith(try P.stringArg(t, 1), try P.stringArg(t, 0), 0));
}
fn stringSuffixP(t: *Thread) Err!Word {
    const suffix = try P.stringArg(t, 0);
    const s = try P.stringArg(t, 1);
    const n = data.stringLen(suffix);
    const len = data.stringLen(s);
    return rt.boolean(n <= len and startsWith(s, suffix, len - n));
}
pub const @"%string-prefix?" = WD("string-prefix?", stringPrefixP, 2, 2);
pub const @"%string-suffix?" = WD("string-suffix?", stringSuffixP, 2, 2);

fn stringContains(t: *Thread) Err!Word {
    const s1 = try P.stringArg(t, 0);
    const s2 = try P.stringArg(t, 1);
    const len1 = data.stringLen(s1);
    const len2 = data.stringLen(s2);
    const start1: usize = if (t.argc > 2) try P.count(t, arg(t, 2)) else 0;
    const end1: usize = if (t.argc > 3) try P.count(t, arg(t, 3)) else len1;
    const start2: usize = if (t.argc > 4) try P.count(t, arg(t, 4)) else 0;
    const end2: usize = if (t.argc > 5) try P.count(t, arg(t, 5)) else len2;
    if (start1 > end1 or end1 > len1 or start2 > end2 or end2 > len2) return raise(t, "string-contains: index out of range", &.{});
    const n = end2 - start2;
    if (n > end1 - start1) return rt.FALSE;
    var i = start1;
    while (i + n <= end1) : (i += 1) {
        var ok = true;
        for (0..n) |k| if (data.stringRef(s1, i + k) != data.stringRef(s2, start2 + k)) {
            ok = false;
            break;
        };
        if (ok) return fix(@intCast(i));
    }
    return rt.FALSE;
}
pub const @"%string-contains" = WD("string-contains", stringContains, 2, 6);

fn stringIndexChar(t: *Thread) Err!Word {
    const s = try P.stringArg(t, 0);
    const c = try P.charArg(t, 1);
    for (0..data.stringLen(s)) |i| if (data.stringRef(s, i) == c) return fix(@intCast(i));
    return rt.FALSE;
}
pub const @"%%string-index-char" = WD("%string-index-char", stringIndexChar, 2, 2);

fn symbolStartsWith(t: *Thread) Err!Word {
    const sym = arg(t, 0);
    if (!data.isSymbol(sym)) return P.argTypeError(t);
    const name = data.symbolName(sym);
    const prefix = arg(t, 1);
    const p = if (data.isSymbol(prefix)) data.symbolName(prefix) else data.toUtf8(try P.stringArg(t, 1));
    return rt.boolean(std.mem.startsWith(u8, name, p));
}
pub const @"%symbol-starts-with?" = WD("symbol-starts-with?", symbolStartsWith, 2, 2);

/// (string-replace-all s what replacement): plain text, every occurrence
fn stringReplaceAll(t: *Thread) Err!Word {
    const s = cps(try P.stringArg(t, 0));
    defer pa.free(s);
    const what = cps(try P.stringArg(t, 1));
    defer pa.free(what);
    const with = cps(try P.stringArg(t, 2));
    defer pa.free(with);
    var out: std.ArrayList(u21) = .empty;
    defer out.deinit(pa);
    var i: usize = 0;
    while (i < s.len) {
        if (what.len > 0 and i + what.len <= s.len and std.mem.eql(u21, s[i .. i + what.len], what)) {
            out.appendSlice(pa, with) catch rt.oom();
            i += what.len;
        } else {
            // Java's String.replace with an empty target inserts between characters
            if (what.len == 0) out.appendSlice(pa, with) catch rt.oom();
            out.append(pa, s[i]) catch rt.oom();
            i += 1;
        }
    }
    if (what.len == 0) out.appendSlice(pa, with) catch rt.oom();
    return resultStr(t, out.items);
}
pub const @"%string-replace-all" = WN("string-replace-all", stringReplaceAll, 3, 3);

/// (string-join strs [delim [grammar]]): non-strings are displayed
fn stringJoin(t: *Thread) Err!Word {
    var delim: []u21 = &.{};
    var own_delim = false;
    if (t.argc > 1) {
        delim = cps(try P.stringArg(t, 1));
        own_delim = true;
    } else {
        delim = pa.dupe(u21, &[_]u21{' '}) catch rt.oom();
        own_delim = true;
    }
    defer if (own_delim) pa.free(delim);
    const Grammar = enum { infix, prefix, suffix };
    var grammar: Grammar = .infix;
    if (t.argc > 2) {
        const g = arg(t, 2);
        if (!data.isSymbol(g)) return P.argTypeError(t);
        const name = data.symbolName(g);
        grammar = if (std.mem.eql(u8, name, "prefix")) .prefix else if (std.mem.eql(u8, name, "suffix")) .suffix else .infix;
    }
    var out: std.ArrayList(u21) = .empty;
    defer out.deinit(pa);
    var l = arg(t, 0);
    var first = true;
    while (rt.isPair(l)) : (l = rt.cdr(l)) {
        if (grammar == .prefix or (grammar == .infix and !first)) out.appendSlice(pa, delim) catch rt.oom();
        const x = rt.car(l);
        if (data.isString(x)) {
            for (0..data.stringLen(x)) |i| out.append(pa, data.stringRef(x, i)) catch rt.oom();
        } else {
            var buf: std.ArrayList(u8) = .empty;
            defer buf.deinit(pa);
            printer.print(&buf, x, false);
            var it = std.unicode.Utf8View.initUnchecked(buf.items).iterator();
            while (it.nextCodepoint()) |cp| out.append(pa, cp) catch rt.oom();
        }
        if (grammar == .suffix) out.appendSlice(pa, delim) catch rt.oom();
        first = false;
    }
    return resultStr(t, out.items);
}
pub const @"%string-join" = WN("string-join", stringJoin, 1, 3);

/// (html-escape s): & < > " ' as entities
fn htmlEscape(t: *Thread) Err!Word {
    const s = try P.stringArg(t, 0);
    const n = data.stringLen(s);
    var needed = false;
    for (0..n) |i| switch (data.stringRef(s, i)) {
        '&', '<', '>', '"', '\'' => needed = true,
        else => {},
    };
    if (!needed) return s;
    const src = cps(s);
    defer pa.free(src);
    var out: std.ArrayList(u21) = .empty;
    defer out.deinit(pa);
    for (src) |c| {
        const rep: []const u8 = switch (c) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            else => {
                out.append(pa, c) catch rt.oom();
                continue;
            },
        };
        for (rep) |b| out.append(pa, b) catch rt.oom();
    }
    return resultStr(t, out.items);
}
pub const @"%html-escape" = WN("html-escape", htmlEscape, 1, 1);
