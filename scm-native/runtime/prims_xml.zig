//! Primitives: the forward-only XML reader of (scm xml), with the event
//! stream of the JVM implementation's StAX reader (DTDs not processed,
//! external entities off): the document start, elements (an empty element
//! gives a start and an end), text (split at every entity and character
//! reference; CDATA sections are text), comments, processing instructions,
//! a doctype event and the document end. The XML declaration and
//! whitespace outside the root element give no events.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const os = @import("os.zig");
const sys = @import("prims_sys.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const WN = P.WN;
const arg = P.arg;
const raise = P.raise;

const pa = std.heap.c_allocator;

const Event = enum { doc, element, end_element, text, comment, pi, doctype, end_doc };

const Attr = struct { local: []const u8, value: []const u8 };

/// A byte that is a character XML 1.0 does not allow (the control
/// characters other than tab, newline and carriage return), as the JVM's
/// and .NET's parsers reject it
fn invalidChar(d: u8) bool {
    return d < 0x20 and d != '\t' and d != '\n' and d != '\r';
}

const Reader = struct {
    s: []const u8, // UTF-8
    pos: usize = 0,
    event: Event = .doc,
    name: []const u8 = "", // qualified
    local: []const u8 = "",
    text: std.ArrayList(u8) = .empty,
    attrs: std.ArrayList(Attr) = .empty,
    stack: std.ArrayList([]const u8) = .empty,
    /// an empty element's end is the next event
    pending_end: bool = false,
    root_done: bool = false,
    root_seen: bool = false,
    finished: bool = false,
    err: []const u8 = "",

    fn fail(r: *Reader, comptime fmt: []const u8, args: anytype) error{Xml} {
        // the position as the JVM's StAX parser reports it: [row,col], 1-based
        var row: usize = 1;
        var col: usize = 1;
        for (r.s[0..@min(r.pos, r.s.len)]) |c| {
            if (c == '\n') {
                row += 1;
                col = 1;
            } else if (c & 0xC0 != 0x80) col += 1;
        }
        const m = std.fmt.allocPrint(pa, fmt, args) catch rt.oom();
        r.err = std.fmt.allocPrint(pa, "ParseError at [row,col]:[{d},{d}]\nMessage: {s}", .{ row, col, m }) catch rt.oom();
        return error.Xml;
    }

    fn peek(r: *Reader) ?u8 {
        return if (r.pos < r.s.len) r.s[r.pos] else null;
    }
    fn startsWith(r: *Reader, p: []const u8) bool {
        return std.mem.startsWith(u8, r.s[r.pos..], p);
    }
    fn skipSpace(r: *Reader) void {
        while (r.peek()) |c| {
            if (c != ' ' and c != '\t' and c != '\r' and c != '\n') break;
            r.pos += 1;
        }
    }

    fn isNameChar(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_' or c == ':' or c == '-' or c == '.' or c >= 0x80;
    }

    fn readName(r: *Reader) error{Xml}![]const u8 {
        const start = r.pos;
        while (r.peek()) |c| {
            if (!isNameChar(c)) break;
            r.pos += 1;
        }
        if (r.pos == start) return r.fail("The markup in the document preceding the root element must be well-formed.", .{});
        return r.s[start..r.pos];
    }

    fn localOf(q: []const u8) []const u8 {
        return if (std.mem.indexOfScalar(u8, q, ':')) |i| q[i + 1 ..] else q;
    }

    /// &...; at pos (after the &): its replacement into out
    fn reference(r: *Reader, out: *std.ArrayList(u8)) error{Xml}!void {
        const start = r.pos;
        const end = std.mem.indexOfScalarPos(u8, r.s, r.pos, ';') orelse return r.fail("The entity name must immediately follow the '&' in the entity reference.", .{});
        const ref = r.s[start..end];
        r.pos = end + 1;
        if (ref.len > 1 and ref[0] == '#') {
            const cp = (if (ref[1] == 'x') std.fmt.parseInt(u21, ref[2..], 16) else std.fmt.parseInt(u21, ref[1..], 10)) catch
                return r.fail("A decimal representation must immediately follow the \"&#\" in a character reference.", .{});
            data.appendCp(out, cp);
            return;
        }
        const rep: []const u8 = if (std.mem.eql(u8, ref, "amp")) "&" else if (std.mem.eql(u8, ref, "lt")) "<" else if (std.mem.eql(u8, ref, "gt")) ">" else if (std.mem.eql(u8, ref, "quot")) "\"" else if (std.mem.eql(u8, ref, "apos")) "'" else {
            r.pos += 1; // the JVM's parser has read one character further
            return r.fail("The entity \"{s}\" was referenced, but not declared.", .{ref});
        };
        out.appendSlice(pa, rep) catch rt.oom();
    }

    fn attributes(r: *Reader) error{Xml}!void {
        r.attrs.clearRetainingCapacity();
        while (true) {
            r.skipSpace();
            const c = r.peek() orelse return r.fail("XML document structures must start and end within the same entity.", .{});
            if (c == '>' or c == '/') return;
            const n = try r.readName();
            r.skipSpace();
            if (r.peek() != '=') return r.fail("Attribute name \"{s}\" associated with an element type \"{s}\" must be followed by the ' = ' character.", .{ n, r.name });
            r.pos += 1;
            r.skipSpace();
            const q = r.peek() orelse return r.fail("XML document structures must start and end within the same entity.", .{});
            if (q != '"' and q != '\'') return r.fail("Open quote is expected for attribute \"{s}\" associated with an  element type  \"{s}\".", .{ n, r.name });
            r.pos += 1;
            var v: std.ArrayList(u8) = .empty;
            while (true) {
                const d = r.peek() orelse return r.fail("XML document structures must start and end within the same entity.", .{});
                r.pos += 1;
                if (d == q) break;
                if (d == '&') {
                    try r.reference(&v);
                } else if (d == '<') {
                    return r.fail("The value of attribute \"{s}\" associated with an element type \"{s}\" must not contain the '<' character.", .{ n, r.name });
                } else if (invalidChar(d)) {
                    r.pos -= 1;
                    return r.fail("An invalid XML character (Unicode: 0x{x}) was found in the value of attribute \"{s}\" and element is \"{s}\".", .{ d, n, r.name });
                } else v.append(pa, if (d == '\t' or d == '\n' or d == '\r') ' ' else d) catch rt.oom();
            }
            r.attrs.append(pa, .{ .local = localOf(n), .value = v.items }) catch rt.oom();
        }
    }

    /// Advance to the next event; false after the end of the document
    fn next(r: *Reader) error{Xml}!bool {
        if (r.finished) return false;
        if (r.pending_end) {
            r.pending_end = false;
            r.event = .end_element;
            _ = r.stack.pop();
            if (r.stack.items.len == 0) r.root_done = true;
            return true;
        }
        while (true) {
            const outside = r.stack.items.len == 0;
            if (outside) r.skipSpace();
            const c = r.peek() orelse {
                if (!outside) return r.fail("XML document structures must start and end within the same entity.", .{});
                if (!r.root_seen) return r.fail("Premature end of file.", .{});
                if (r.event == .end_doc) {
                    r.finished = true;
                    return false;
                }
                r.event = .end_doc;
                return true;
            };
            if (c == '<') {
                if (r.startsWith("<?")) {
                    r.pos += 2;
                    const target = try r.readName();
                    const end = std.mem.indexOfPos(u8, r.s, r.pos, "?>") orelse return r.fail("XML document structures must start and end within the same entity.", .{});
                    r.pos = end + 2;
                    if (std.ascii.eqlIgnoreCase(target, "xml")) continue; // the declaration
                    r.event = .pi;
                    r.name = "";
                    return true;
                }
                if (r.startsWith("<!--")) {
                    const end = std.mem.indexOfPos(u8, r.s, r.pos + 4, "-->") orelse return r.fail("XML document structures must start and end within the same entity.", .{});
                    r.text.clearRetainingCapacity();
                    r.text.appendSlice(pa, r.s[r.pos + 4 .. end]) catch rt.oom();
                    r.pos = end + 3;
                    r.event = .comment;
                    r.name = "";
                    return true;
                }
                if (r.startsWith("<![CDATA[")) {
                    if (outside) return r.fail("The markup in the document following the root element must be well-formed.", .{});
                    const end = std.mem.indexOfPos(u8, r.s, r.pos + 9, "]]>") orelse return r.fail("The CDATA section must end with \"]]>\".", .{});
                    r.text.clearRetainingCapacity();
                    r.text.appendSlice(pa, r.s[r.pos + 9 .. end]) catch rt.oom();
                    r.pos = end + 3;
                    r.event = .text;
                    r.name = "";
                    return true;
                }
                if (r.startsWith("<!DOCTYPE")) {
                    // skipped, with its internal subset (DTDs are not processed)
                    var depth: usize = 0;
                    while (r.peek()) |d| {
                        r.pos += 1;
                        if (d == '[') depth += 1;
                        if (d == ']' and depth > 0) depth -= 1;
                        if (d == '>' and depth == 0) break;
                    }
                    r.event = .doctype;
                    r.name = "";
                    return true;
                }
                if (r.startsWith("</")) {
                    r.pos += 2;
                    const name_start = r.pos;
                    const n = try r.readName();
                    r.skipSpace();
                    if (r.peek() != '>') return r.fail("The end-tag for element type \"{s}\" must end with a '>' delimiter.", .{n});
                    if (r.stack.items.len == 0) return r.fail("The markup in the document following the root element must be well-formed.", .{});
                    const open = r.stack.items[r.stack.items.len - 1];
                    if (!std.mem.eql(u8, open, n)) {
                        r.pos = name_start; // where the JVM's parser reports it
                        return r.fail("The element type \"{s}\" must be terminated by the matching end-tag \"</{s}>\".", .{ open, open });
                    }
                    r.pos += 1;
                    _ = r.stack.pop();
                    if (r.stack.items.len == 0) r.root_done = true;
                    r.event = .end_element;
                    r.name = n;
                    r.local = localOf(n);
                    return true;
                }
                // a start tag
                if (r.root_done) return r.fail("The markup in the document following the root element must be well-formed.", .{});
                r.pos += 1;
                const n = try r.readName();
                r.name = n;
                r.local = localOf(n);
                try r.attributes();
                if (r.startsWith("/>")) {
                    r.pos += 2;
                    r.pending_end = true;
                } else r.pos += 1;
                r.stack.append(pa, n) catch rt.oom();
                r.root_seen = true;
                r.event = .element;
                return true;
            }
            if (outside) return r.fail("Content is not allowed in {s}.", .{if (r.root_done) "trailing section" else "prolog"});
            // character data up to the next markup or reference
            r.text.clearRetainingCapacity();
            if (c == '&') {
                r.pos += 1;
                try r.reference(&r.text);
            } else {
                while (r.peek()) |d| {
                    if (d == '<' or d == '&') break;
                    if (invalidChar(d)) return r.fail("An invalid XML character (Unicode: 0x{x}) was found in the element content of the document.", .{d});
                    r.text.append(pa, d) catch rt.oom();
                    r.pos += 1;
                }
            }
            r.event = .text;
            r.name = "";
            return true;
        }
    }

    /// getElementText: the text of the current (start) element, leaving the
    /// reader on its end
    fn elementText(r: *Reader) error{Xml}![]const u8 {
        if (r.event != .element) return r.fail("parser must be on START_ELEMENT to read next text", .{});
        var out: std.ArrayList(u8) = .empty;
        while (true) {
            if (!try r.next()) return r.fail("unexpected end of document when reading element text content", .{});
            switch (r.event) {
                .text => out.appendSlice(pa, r.text.items) catch rt.oom(),
                .comment, .pi => {},
                .end_element => return out.items,
                .element => return r.fail("elementGetText() function expects text only elment but START_ELEMENT was encountered.", .{}),
                else => return r.fail("Unexpected event type {d}", .{@intFromEnum(r.event)}),
            }
        }
    }
};

/// The text decoded to UTF-8 by the XML declaration's encoding (UTF-8,
/// ISO-8859-1 and UTF-16 with a byte order mark)
fn decode(bytes: []const u8) []const u8 {
    if (bytes.len >= 3 and std.mem.eql(u8, bytes[0..3], "\xEF\xBB\xBF")) return bytes[3..];
    if (bytes.len >= 2 and (std.mem.eql(u8, bytes[0..2], "\xFF\xFE") or std.mem.eql(u8, bytes[0..2], "\xFE\xFF"))) {
        const le = bytes[0] == 0xFF;
        var out: std.ArrayList(u8) = .empty;
        var i: usize = 2;
        while (i + 1 < bytes.len) : (i += 2) {
            var u: u21 = if (le) @as(u21, bytes[i]) | (@as(u21, bytes[i + 1]) << 8) else (@as(u21, bytes[i]) << 8) | bytes[i + 1];
            if (u >= 0xD800 and u <= 0xDBFF and i + 3 < bytes.len) {
                const lo: u21 = if (le) @as(u21, bytes[i + 2]) | (@as(u21, bytes[i + 3]) << 8) else (@as(u21, bytes[i + 2]) << 8) | bytes[i + 3];
                u = 0x10000 + ((u - 0xD800) << 10) + (lo -% 0xDC00);
                i += 2;
            }
            data.appendCp(&out, u);
        }
        return out.items;
    }
    const head = bytes[0..@min(bytes.len, 200)];
    if (std.mem.startsWith(u8, head, "<?xml")) {
        if (std.mem.indexOf(u8, head, "encoding=")) |e| {
            const rest = head[e + 9 ..];
            if (rest.len > 1) {
                const q = rest[0];
                if (std.mem.indexOfScalarPos(u8, rest, 1, q)) |end| {
                    const enc = rest[1..end];
                    if (std.ascii.eqlIgnoreCase(enc, "ISO-8859-1") or std.ascii.eqlIgnoreCase(enc, "latin1") or std.ascii.eqlIgnoreCase(enc, "windows-1252") or std.ascii.eqlIgnoreCase(enc, "US-ASCII")) {
                        var out: std.ArrayList(u8) = .empty;
                        for (bytes) |b| data.appendCp(&out, b);
                        return out.items;
                    }
                }
            }
        }
    }
    return bytes;
}

fn openReader(t: *Thread, text: []const u8) Word {
    const r = pa.create(Reader) catch rt.oom();
    r.* = .{ .s = text };
    return sys.wrapNativeOf(t, .xml_reader, r);
}

fn openXmlString(t: *Thread) Err!Word {
    return openReader(t, data.toUtf8Owned(try P.stringArg(t, 0)));
}
pub const @"%open-xml-string" = WN("open-xml-string", openXmlString, 1, 1);

fn openXmlBytevector(t: *Thread) Err!Word {
    const bv = arg(t, 0);
    if (!data.isBytevector(bv)) return P.argTypeError(t);
    return openReader(t, decode(pa.dupe(u8, data.bvBytes(bv)) catch rt.oom()));
}
pub const @"%open-xml-bytevector" = WN("open-xml-bytevector", openXmlBytevector, 1, 1);

fn openXmlFile(t: *Thread) Err!Word {
    const name = data.toUtf8(try P.stringArg(t, 0));
    if (!os.fileExists(name)) return raise(t, std.fmt.allocPrint(pa, "open-xml-file {s}: file not found", .{name}) catch rt.oom(), &.{});
    const bytes = os.readFile(name) orelse return raise(t, std.fmt.allocPrint(pa, "open-xml-file {s}: io error", .{name}) catch rt.oom(), &.{});
    return openReader(t, decode(bytes));
}
pub const @"%open-xml-file" = WN("open-xml-file", openXmlFile, 1, 1);

fn readerArg(t: *Thread) Err!*Reader {
    const p = sys.nativeOf(arg(t, 0), .xml_reader) orelse return P.argTypeError(t);
    return @ptrCast(@alignCast(p));
}

/// the message as the JVM formats it: the Java exception message, written
/// as a symbol (|...|)
fn xmlError(t: *Thread, who: []const u8, r: *Reader) Err {
    return raise(t, std.fmt.allocPrint(pa, "{s}|{s}|", .{ who, r.err }) catch rt.oom(), &.{});
}

fn xmlRead(t: *Thread) Err!Word {
    const r = try readerArg(t);
    return rt.boolean(r.next() catch return xmlError(t, "xml-read failed ", r));
}
pub const @"%xml-read" = WN("xml-read", xmlRead, 1, 1);

fn xmlReadTo(t: *Thread) Err!Word {
    const r = try readerArg(t);
    const n = arg(t, 1);
    const name = if (data.isSymbol(n)) data.symbolName(n) else data.toUtf8(try P.stringArg(t, 1));
    while (r.next() catch return xmlError(t, "xml-read-to failed: ", r)) {
        if (r.event == .element and std.mem.eql(u8, r.local, name)) return rt.TRUE;
    }
    return rt.FALSE;
}
pub const @"%xml-read-to" = WN("xml-read-to", xmlReadTo, 2, 2);

fn xmlNodeType(t: *Thread) Err!Word {
    const r = try readerArg(t);
    return switch (r.event) {
        .element => data.intern("element"),
        .end_element => data.intern("end-element"),
        .text => data.intern("text"),
        .comment => data.intern("comment"),
        .pi => data.intern("pi"),
        .doc => data.intern("doc"),
        .doctype, .end_doc => rt.FALSE,
    };
}
pub const @"%xml-node-type" = WN("xml-node-type", xmlNodeType, 1, 1);

fn str(t: *Thread, s: []const u8) Word {
    t.reserve(data.stringWords(s.len, true));
    return data.heapStringUtf8(t, s);
}

fn xmlName(t: *Thread) Err!Word {
    const r = try readerArg(t);
    if (r.event == .element or r.event == .end_element) return str(t, r.name);
    return data.intern(""); // the JVM returns a Java string: the empty symbol
}
pub const @"%xml-name" = WN("xml-name", xmlName, 1, 1);

fn xmlValue(t: *Thread) Err!Word {
    const r = try readerArg(t);
    const text = r.elementText() catch return xmlError(t, "xml-value failed: ", r);
    return str(t, text);
}
pub const @"%xml-value" = WN("xml-value", xmlValue, 1, 1);

fn xmlAttribute(t: *Thread) Err!Word {
    const r = try readerArg(t);
    const n = arg(t, 1);
    const name = if (data.isSymbol(n)) data.symbolName(n) else data.toUtf8(try P.stringArg(t, 1));
    if (r.event != .element) return rt.FALSE;
    for (r.attrs.items) |a| if (std.mem.eql(u8, a.local, name)) return str(t, a.value);
    return rt.FALSE;
}
pub const @"%xml-attribute" = WN("xml-attribute", xmlAttribute, 2, 2);

fn closeXml(t: *Thread) Err!Word {
    _ = try readerArg(t);
    return rt.UNSPEC;
}
pub const @"%close-xml" = WN("close-xml", closeXml, 1, 1);
