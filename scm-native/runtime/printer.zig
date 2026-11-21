//! write and display, in the output format of the JVM implementation.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const ports = @import("ports.zig");
const Word = rt.Word;

const a = std.heap.c_allocator;

fn put(buf: *std.ArrayList(u8), s: []const u8) void {
    buf.appendSlice(a, s) catch rt.oom();
}

// --- datum labels ----------------------------------------------------------
// write labels cycles (#0=, #0#), write-shared all shared structure, as the
// JVM implementation; display is also safe on cycles here.

const State = enum { active, done };

const Labels = struct {
    state: std.AutoHashMapUnmanaged(Word, State) = .empty,
    /// nodes to label, with their number once printed (-1: not yet)
    labels: std.AutoHashMapUnmanaged(Word, i64) = .empty,
    next: i64 = 0,
    shared: bool,

    fn deinit(l: *Labels) void {
        l.state.deinit(a);
        l.labels.deinit(a);
    }

    fn compound(x: Word) bool {
        return rt.isPair(x) or (rt.isPtr(x) and rt.objType(x) == rt.T_VECTOR and data.vectorLen(x) > 0);
    }

    /// true if x was seen before (and is handled)
    fn seen(l: *Labels, x: Word) bool {
        if (l.state.get(x)) |st| {
            if (st == .active or l.shared) l.labels.put(a, x, -1) catch rt.oom();
            return true;
        }
        return false;
    }

    fn visit(l: *Labels, x: Word) void {
        if (!compound(x) or l.seen(x)) return;
        if (rt.isPair(x)) {
            var chain: std.ArrayList(Word) = .empty;
            defer chain.deinit(a);
            var p = x;
            while (true) {
                l.state.put(a, p, .active) catch rt.oom();
                chain.append(a, p) catch rt.oom();
                l.visit(rt.car(p));
                const d = rt.cdr(p);
                if (!rt.isPair(d)) {
                    l.visit(d);
                    break;
                }
                if (l.seen(d)) break;
                p = d;
            }
            for (chain.items) |q| l.state.put(a, q, .done) catch rt.oom();
        } else {
            l.state.put(a, x, .active) catch rt.oom();
            for (data.vectorItems(x)) |item| l.visit(item);
            l.state.put(a, x, .done) catch rt.oom();
        }
    }
};

var labels: ?*Labels = null;

fn isLabeled(x: Word) bool {
    const l = labels orelse return false;
    return l.labels.contains(x);
}

/// Print the label prefix of x; true if x was printed already (as #n#)
fn printLabel(buf: *std.ArrayList(u8), x: Word) bool {
    const l = labels orelse return false;
    const entry = l.labels.getPtr(x) orelse return false;
    var tmp: [24]u8 = undefined;
    if (entry.* >= 0) {
        put(buf, std.fmt.bufPrint(&tmp, "#{d}#", .{entry.*}) catch unreachable);
        return true;
    }
    entry.* = l.next;
    l.next += 1;
    put(buf, std.fmt.bufPrint(&tmp, "#{d}=", .{entry.*}) catch unreachable);
    return false;
}

/// Print w (write or display), with datum labels for cycles, or for all
/// shared structure when shared.
pub fn printTop(buf: *std.ArrayList(u8), w: Word, write: bool, shared: bool) void {
    if (!Labels.compound(w) or labels != null) return print(buf, w, write);
    var l = Labels{ .shared = shared };
    defer l.deinit();
    l.visit(w);
    if (l.labels.count() == 0) return print(buf, w, write);
    labels = &l;
    defer labels = null;
    print(buf, w, write);
}

pub fn print(buf: *std.ArrayList(u8), w: Word, write: bool) void {
    if (rt.isFix(w)) {
        var tmp: [24]u8 = undefined;
        put(buf, std.fmt.bufPrint(&tmp, "{d}", .{rt.unfix(w)}) catch unreachable);
        return;
    }
    if (rt.isChar(w)) {
        const cp = rt.charCode(w);
        if (!write) return data.appendCp(buf, cp);
        put(buf, switch (cp) {
            ' ' => "#\\space",
            '\t' => "#\\tab",
            '\r' => "#\\return",
            '\n' => "#\\newline",
            else => {
                put(buf, "#\\");
                return data.appendCp(buf, cp);
            },
        });
        return;
    }
    if (!rt.isPtr(w)) {
        put(buf, switch (w) {
            rt.FALSE => "#f",
            rt.TRUE => "#t",
            rt.NIL => "()",
            rt.UNSPEC => "",
            rt.EOF => "#<eof>",
            rt.DEFAULT => "#<default>",
            rt.UNBOUND => "#<unbound>",
            else => "#<unknown>",
        });
        return;
    }
    switch (rt.objType(w)) {
        rt.T_FLONUM => num.formatFlonum(buf, rt.flo(w)),
        rt.T_STRING => if (write) writeString(buf, w) else data.appendUtf8(buf, w),
        rt.T_SYMBOL => if (write) writeSymbol(buf, data.symbolName(w)) else put(buf, data.symbolName(w)),
        rt.T_PAIR => if (!printLabel(buf, w)) printPair(buf, w, write),
        rt.T_VECTOR => {
            if (printLabel(buf, w)) return;
            put(buf, "#(");
            for (data.vectorItems(w), 0..) |x, i| {
                if (i > 0) put(buf, " ");
                print(buf, x, write);
            }
            put(buf, ")");
        },
        rt.T_CLOSURE => if (rt.isPrimitive(w)) {
            put(buf, "#<p:");
            put(buf, data.symbolName(rt.ptr(w)[2]));
            put(buf, ">");
        } else put(buf, "#<lambda>"),
        rt.T_BOX => put(buf, "#<box>"),
        rt.T_RECORD => put(buf, "#<record>"),
        rt.T_HASHTABLE => put(buf, if (rt.prims_hash.isDict(w)) "#<dict>" else "#<hash-table>"),
        rt.T_NATIVE => put(buf, rt.prims_sys.nativeName(w)),
        rt.T_ERROR => {
            put(buf, "#<error-object ");
            print(buf, rt.ptr(w)[1], true);
            put(buf, ">");
        },
        rt.T_PORT => {
            const port = ports.get(w).?;
            put(buf, if (port.isInput())
                (if (port.binary) "#<binary-input-port>" else "#<input-port>")
            else if (port.binary) "#<binary-output-port>" else "#<output-port>");
        },
        rt.T_BYTEVECTOR => {
            put(buf, "#u8(");
            for (data.bvBytes(w), 0..) |b, i| {
                if (i > 0) put(buf, " ");
                var tmp: [4]u8 = undefined;
                put(buf, std.fmt.bufPrint(&tmp, "{d}", .{b}) catch unreachable);
            }
            put(buf, ")");
        },
        rt.T_VALUES => {
            const n = rt.hdrLen(rt.ptr(w)[0]);
            for (rt.ptr(w)[1 .. 1 + n], 0..) |x, i| {
                if (i > 0) put(buf, "\n");
                print(buf, x, write);
            }
        },
        rt.T_BIGNUM, rt.T_RATNUM, rt.T_COMPNUM => num.formatExact(buf, w),
        else => put(buf, "#<object>"),
    }
}

fn printPair(buf: *std.ArrayList(u8), w: Word, write: bool) void {
    const head = rt.car(w);
    if (data.isSymbol(head) and rt.isPair(rt.cdr(w)) and rt.cdr(rt.cdr(w)) == rt.NIL) {
        const name = data.symbolName(head);
        const prefix: ?[]const u8 = if (std.mem.eql(u8, name, "quote"))
            "'"
        else if (std.mem.eql(u8, name, "quasiquote"))
            "`"
        else if (std.mem.eql(u8, name, "unquote"))
            ","
        else if (std.mem.eql(u8, name, "unquote-splicing"))
            ",@"
        else
            null;
        if (prefix) |p| {
            put(buf, p);
            return print(buf, rt.car(rt.cdr(w)), write);
        }
    }
    put(buf, "(");
    var x = w;
    while (true) {
        print(buf, rt.car(x), write);
        const d = rt.cdr(x);
        if (d == rt.NIL) break;
        if (!rt.isPair(d) or isLabeled(d)) {
            put(buf, " . ");
            print(buf, d, write);
            break;
        }
        put(buf, " ");
        x = d;
    }
    put(buf, ")");
}

fn writeString(buf: *std.ArrayList(u8), s: Word) void {
    put(buf, "\"");
    for (0..data.stringLen(s)) |i| {
        const cp = data.stringRef(s, i);
        switch (cp) {
            '"' => put(buf, "\\\""),
            '\\' => put(buf, "\\\\"),
            '\n' => put(buf, "\\n"),
            '\r' => put(buf, "\\r"),
            '\t' => put(buf, "\\t"),
            else => data.appendCp(buf, cp),
        }
    }
    put(buf, "\"");
}

fn writeSymbol(buf: *std.ArrayList(u8), name: []const u8) void {
    var plain = name.len > 0;
    for (name) |ch| switch (ch) {
        ' ', '\t', '\n', '\r', '(', ')', '"', ';', '\'', '`', ',', '|' => plain = false,
        else => {},
    };
    if (plain) return put(buf, name);
    put(buf, "|");
    for (name) |ch| {
        if (ch == '|' or ch == '\\') put(buf, "\\");
        buf.append(a, ch) catch rt.oom();
    }
    put(buf, "|");
}
