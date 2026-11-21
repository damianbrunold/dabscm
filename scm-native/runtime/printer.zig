//! write and display, in the output format of the JVM implementation.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const Word = rt.Word;

const a = std.heap.page_allocator;

fn put(buf: *std.ArrayList(u8), s: []const u8) void {
    buf.appendSlice(a, s) catch rt.oom();
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
        rt.T_PAIR => printPair(buf, w, write),
        rt.T_VECTOR => {
            put(buf, "#(");
            for (data.vectorItems(w), 0..) |x, i| {
                if (i > 0) put(buf, " ");
                print(buf, x, write);
            }
            put(buf, ")");
        },
        rt.T_CLOSURE => put(buf, "#<procedure>"),
        rt.T_BOX => put(buf, "#<box>"),
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
        if (!rt.isPair(d)) {
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
