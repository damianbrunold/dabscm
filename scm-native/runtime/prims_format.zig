//! Primitives: format (the JVM implementation's directives), read-chars,
//! port-position, and constants (PI, line-sep, field-sep).
const std = @import("std");
const builtin = @import("builtin");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const tower = @import("tower.zig");
const printer = @import("printer.zig");
const ports = @import("ports.zig");
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
const Buf = std.ArrayList(u8);

fn put(b: *Buf, s: []const u8) void {
    b.appendSlice(pa, s) catch rt.oom();
}

fn rep(w: Word, mode: enum { display, write, shared }) Buf {
    var b: Buf = .empty;
    switch (mode) {
        .display => printer.printTop(&b, w, false, false),
        .write => printer.printTop(&b, w, true, false),
        .shared => printer.printTop(&b, w, true, true),
    }
    return b;
}

/// pad s to width (right-aligned, or left-aligned for ~-W), as the JVM
/// implementation (width in UTF-16 units there; code points here)
fn padded(out: *Buf, s: []const u8, left: bool, width: usize) void {
    const len = std.unicode.utf8CountCodepoints(s) catch s.len;
    if (len >= width) return put(out, s);
    if (left) put(out, s);
    for (0..width - len) |_| put(out, " ");
    if (!left) put(out, s);
}

// --- pretty printing (~y), as PrimitiveFormat.prettyPrint ---------------------------

const indent2_forms = [_][]const u8{ "begin", "define", "define-syntax", "define-record-type", "lambda", "let", "let*", "letrec", "letrec*", "let-values", "let*-values", "when", "unless", "do", "guard", "define-library" };

fn ppExpr(out: *Buf, e: Word, indent: usize, width: usize) void {
    var s = rep(e, .write);
    defer s.deinit(pa);
    if (!rt.isPair(e) or indent + s.items.len <= width) return put(out, s.items);
    ppList(out, e, indent, width);
}

fn ppList(out: *Buf, e: Word, indent: usize, width: usize) void {
    put(out, "(");
    const head = rt.car(e);
    var hs = rep(head, .write);
    defer hs.deinit(pa);
    put(out, hs.items);
    var indent2 = false;
    if (data.isSymbol(head)) for (indent2_forms) |f| if (std.mem.eql(u8, f, data.symbolName(head))) {
        indent2 = true;
    };
    const first_col = indent + 1 + hs.items.len + 1;
    const body = if (indent2) indent + 2 else first_col;
    const tail = rt.cdr(e);
    if (tail == rt.NIL) return put(out, ")");
    if (!rt.isPair(tail)) {
        put(out, " . ");
        var ts = rep(tail, .write);
        defer ts.deinit(pa);
        put(out, ts.items);
        return put(out, ")");
    }
    put(out, " ");
    ppExpr(out, rt.car(tail), first_col, width);
    var items = rt.cdr(tail);
    while (true) {
        if (items == rt.NIL) return put(out, ")");
        if (rt.isPair(items)) {
            put(out, "\n");
            for (0..body) |_| put(out, " ");
            ppExpr(out, rt.car(items), body, width);
            items = rt.cdr(items);
        } else {
            put(out, " . ");
            var ts = rep(items, .write);
            defer ts.deinit(pa);
            put(out, ts.items);
            return put(out, ")");
        }
    }
}

// --- format ----------------------------------------------------------------------------

const help_text =
    "~a  display          ~s  write            ~w  write-shared\n" ++
    "~d  decimal          ~x  hex              ~o  octal\n" ++
    "~b  binary           ~c  character        ~y  pretty-print\n" ++
    "~f  fixed-float      ~?  recursive        ~k  recursive (alias)\n" ++
    "~%  newline          ~n  newline (alias)   ~&  freshline\n" ++
    "~t  tab              ~_  space            ~~  tilde\n" ++
    "~h  help\n";

fn formatInto(t: *Thread, out: *Buf, fmt: []const u8, args: []const Word) Err!void {
    var k: usize = 0;
    var i: usize = 0;
    while (i < fmt.len) {
        const c = fmt[i];
        if (c != '~') {
            out.append(pa, c) catch rt.oom();
            i += 1;
            continue;
        }
        i += 1;
        if (i >= fmt.len) return raise(t, "format: unexpected end of format string after ~", &.{});
        var left = false;
        if (fmt[i] == '-') {
            left = true;
            i += 1;
        }
        var width: usize = 0;
        while (i < fmt.len and std.ascii.isDigit(fmt[i])) : (i += 1) width = width * 10 + (fmt[i] - '0');
        var precision: ?usize = null;
        if (i < fmt.len and fmt[i] == ',') {
            i += 1;
            var pr: usize = 0;
            var any = false;
            while (i < fmt.len and std.ascii.isDigit(fmt[i])) : (i += 1) {
                pr = pr * 10 + (fmt[i] - '0');
                any = true;
            }
            if (any) precision = pr;
        }
        if (i >= fmt.len) return raise(t, "format: unexpected end of format string after ~", &.{});
        const d = fmt[i];
        i += 1;
        switch (std.ascii.toLower(d)) {
            'a', 's', 'w', 'y', 'd', 'x', 'o', 'b', 'c', 'f' => {
                if (k >= args.len) return raise(t, "format: not enough arguments for format string", &.{});
                const v = args[k];
                k += 1;
                var s: Buf = .empty;
                defer s.deinit(pa);
                switch (std.ascii.toLower(d)) {
                    'a' => s = rep(v, .display),
                    's' => s = rep(v, .write),
                    'w' => s = rep(v, .shared),
                    'y' => ppExpr(&s, v, 0, if (width > 0) width else 79),
                    'd', 'x', 'o', 'b' => {
                        if (!tower.isExactInteger(v)) return P.typeError(t, "format");
                        tower.format(&s, v, switch (std.ascii.toLower(d)) {
                            'd' => 10,
                            'x' => 16,
                            'o' => 8,
                            else => 2,
                        });
                    },
                    'c' => {
                        if (!rt.isChar(v)) return P.typeError(t, "format");
                        data.appendCp(&s, rt.charCode(v));
                    },
                    'f' => {
                        const x = num.toF(v) orelse return P.typeError(t, "format");
                        var tmp: [512]u8 = undefined;
                        const r = std.fmt.float.render(&tmp, x, .{ .mode = .decimal, .precision = precision orelse 6 }) catch "?";
                        put(&s, r);
                    },
                    else => unreachable,
                }
                padded(out, s.items, left, width);
            },
            '?', 'k' => {
                if (k + 2 > args.len)
                    return raise(t, "format: not enough arguments for format string", &.{});
                const sub = args[k];
                const lst = args[k + 1];
                k += 2;
                if (!data.isString(sub)) return P.typeError(t, "format");
                var sub_args: std.ArrayList(Word) = .empty;
                defer sub_args.deinit(pa);
                var l = lst;
                while (rt.isPair(l)) : (l = rt.cdr(l)) sub_args.append(pa, rt.car(l)) catch rt.oom();
                const sub_text = data.toUtf8(sub);
                try formatInto(t, out, sub_text, sub_args.items);
            },
            'n', '%' => put(out, "\n"),
            '&' => if (out.items.len == 0 or out.items[out.items.len - 1] != '\n') put(out, "\n"),
            't' => put(out, "\t"),
            '_' => put(out, " "),
            '~' => put(out, "~"),
            'h' => put(out, help_text),
            else => return raise(t, "format: unrecognized directive", &.{rt.char(d)}),
        }
    }
}

/// (format dest fmt arg ...): dest #f gives a string, #t the current
/// output port, else a port
fn formatImpl(t: *Thread) Err!Word {
    const dest = arg(t, 0);
    const fmt = data.toUtf8(try P.stringArg(t, 1));
    var out: Buf = .empty;
    defer out.deinit(pa);
    try formatInto(t, &out, fmt, t.args[2..t.argc]);
    if (dest == rt.FALSE) {
        t.reserve(data.stringWords(out.items.len, true));
        return data.heapStringUtf8(t, out.items);
    }
    const port = if (dest == rt.TRUE) ports.current(t, .output_port) else ports.get(dest) orelse return P.argTypeError(t);
    port.write(out.items);
    if (out.items.len > 0 and out.items[out.items.len - 1] == '\n') port.flush();
    return rt.UNSPEC;
}
pub const @"%format" = WN("format", formatImpl, 2, std.math.maxInt(u64));

// --- input -----------------------------------------------------------------------------

/// (read-chars n port): up to n characters, or eof
fn readChars(t: *Thread) Err!Word {
    const n = try P.count(t, arg(t, 0));
    const p = if (t.argc > 1) ports.get(arg(t, 1)) orelse return P.argTypeError(t) else ports.current(t, .input_port);
    var buf: Buf = .empty;
    defer buf.deinit(pa);
    var k: usize = 0;
    while (k < n) : (k += 1) {
        const c = p.readChar() orelse break;
        data.appendCp(&buf, c);
    }
    if (k == 0 and n > 0) return rt.EOF;
    t.reserve(data.stringWords(buf.items.len, true));
    return data.heapStringUtf8(t, buf.items);
}
pub const @"%read-chars" = WN("read-chars", readChars, 1, 2);

/// (port-position port): (filename line column), line 1-based, column
/// 0-based; "{string}" for string ports
fn portPosition(t: *Thread) Err!Word {
    const p = ports.get(arg(t, 0)) orelse return P.argTypeError(t);
    var line: i64 = 1;
    var col: i64 = 0;
    const consumed = p.in.items[0..@min(p.pos, p.in.items.len)];
    var i: usize = 0;
    while (i < consumed.len) {
        const b = consumed[i];
        if (b == '\n') {
            line += 1;
            col = 0;
            i += 1;
        } else {
            const len = std.unicode.utf8ByteSequenceLength(b) catch 1;
            col += 1;
            i += len;
        }
    }
    const name = p.name;
    t.reserve(data.stringWords(name.len, true) + 9);
    const s = data.heapStringUtf8(t, name);
    return t.cons(s, t.cons(fix(line), t.cons(fix(col), rt.NIL)));
}
pub const @"%port-position" = WN("port-position", portPosition, 1, 1);

// --- constants -------------------------------------------------------------------------

fn makePi() callconv(.c) Word {
    return data.constFlonum(std.math.pi);
}
fn makeLineSep() callconv(.c) Word {
    return data.constString(if (builtin.os.tag == .windows) "\r\n" else "\n");
}
fn makeFieldSep() callconv(.c) Word {
    return data.constString(if (builtin.os.tag == .windows) ";" else ":");
}
pub const @"%PI" = rt.ValuePrim{ .make = &makePi };
pub const @"%line-sep" = rt.ValuePrim{ .make = &makeLineSep };
pub const @"%field-sep" = rt.ValuePrim{ .make = &makeFieldSep };
