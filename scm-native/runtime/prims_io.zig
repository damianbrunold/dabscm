//! Primitives: ports, reading and writing, files.
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const printer = @import("printer.zig");
const ports = @import("ports.zig");
const reader = @import("reader.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Code = rt.Code;
const Err = P.Err;
const W = P.W;
const WN = P.WN;
const WD = P.WD;
const arg = P.arg;
const raise = P.raise;
const any = P.any;
const fix = rt.fix;
const unfix = rt.unfix;
const Port = ports.Port;

const pa = std.heap.c_allocator;

fn makeStdin() callconv(.c) Word {
    return ports.stdinObject();
}
fn makeStdout() callconv(.c) Word {
    return ports.stdoutObject();
}
fn makeStderr() callconv(.c) Word {
    return ports.stderrObject();
}
pub const @"%*input-port*" = rt.ValuePrim{ .make = &makeStdin };
pub const @"%*output-port*" = rt.ValuePrim{ .make = &makeStdout };
pub const @"%*error-port*" = rt.ValuePrim{ .make = &makeStderr };

fn portArg(t: *Thread, i: usize) Err!*Port {
    return ports.get(arg(t, i)) orelse raise(t, "not a port", &.{arg(t, i)});
}

/// The output port argument at i, or the current output port
fn outPort(t: *Thread, i: usize) Err!*Port {
    if (t.argc <= i) return ports.current(t, .output_port);
    const p = try portArg(t, i);
    if (p.isInput()) return raise(t, "not an output port", &.{arg(t, i)});
    if (!p.open) return raise(t, "output port is closed", &.{arg(t, i)});
    return p;
}

fn inPort(t: *Thread, i: usize) Err!*Port {
    if (t.argc <= i) return ports.current(t, .input_port);
    const p = try portArg(t, i);
    if (!p.isInput()) return raise(t, "not an input port", &.{arg(t, i)});
    if (!p.open) return raise(t, "input port is closed", &.{arg(t, i)});
    return p;
}

// --- writing ---------------------------------------------------------------------

fn out(p: *Port, w: Word, write: bool) void {
    outMode(p, w, write, false);
}

fn outMode(p: *Port, w: Word, write: bool, shared: bool) void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    printer.printTop(&buf, w, write, shared);
    p.write(buf.items);
}

fn writeImpl(t: *Thread) Err!Word {
    out(try outPort(t, 1), arg(t, 0), true);
    return rt.UNSPEC;
}
fn writeSharedImpl(t: *Thread) Err!Word {
    outMode(try outPort(t, 1), arg(t, 0), true, true);
    return rt.UNSPEC;
}
fn displayImpl(t: *Thread) Err!Word {
    out(try outPort(t, 1), arg(t, 0), false);
    return rt.UNSPEC;
}
fn newlineImpl(t: *Thread) Err!Word {
    (try outPort(t, 0)).write("\n");
    return rt.UNSPEC;
}
fn writeChar(t: *Thread) Err!Word {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    data.appendCp(&buf, try P.charArg(t, 0));
    (try outPort(t, 1)).write(buf.items);
    return rt.UNSPEC;
}
fn writeString(t: *Thread) Err!Word {
    const s = try P.stringArg(t, 0);
    const p = try outPort(t, 1);
    const len = data.stringLen(s);
    const start: usize = if (t.argc > 2) try P.count(t, arg(t, 2)) else 0;
    const end: usize = if (t.argc > 3) try P.count(t, arg(t, 3)) else len;
    if (start > end or end > len) return raise(t, "write-string: index out of range", &.{});
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    for (start..end) |i| data.appendCp(&buf, data.stringRef(s, i));
    p.write(buf.items);
    return rt.UNSPEC;
}
pub const @"%write" = WD("write", writeImpl, 1, 2);
pub const @"%write-shared" = WD("write-shared", writeSharedImpl, 1, 2);
pub const @"%write-simple" = WD("write-simple", writeImpl, 1, 2);
pub const @"%display" = WD("display", displayImpl, 1, 2);
pub const @"%newline" = WD("newline", newlineImpl, 0, 1);
pub const @"%write-char" = WD("write-char", writeChar, 1, 2);
pub const @"%write-string" = WD("write-string", writeString, 1, 4);

fn writeU8(t: *Thread) Err!Word {
    const b = arg(t, 0);
    if (!rt.isFix(b) or unfix(b) < 0 or unfix(b) > 255) return raise(t, "write-u8: not a byte", &.{b});
    const byte = [1]u8{@intCast(unfix(b))};
    (try outPort(t, 1)).write(&byte);
    return rt.UNSPEC;
}
pub const @"%write-u8" = WD("write-u8", writeU8, 1, 2);

fn writeBytevector(t: *Thread) Err!Word {
    const bv = arg(t, 0);
    if (!data.isBytevector(bv)) return raise(t, "write-bytevector: not a bytevector", &.{bv});
    const len = data.bvLen(bv);
    const start: usize = if (t.argc > 2) try P.count(t, arg(t, 2)) else 0;
    const end: usize = if (t.argc > 3) try P.count(t, arg(t, 3)) else len;
    if (start > end or end > len) return raise(t, "write-bytevector: index out of range", &.{});
    (try outPort(t, 1)).write(data.bvBytes(bv)[start..end]);
    return rt.UNSPEC;
}
pub const @"%write-bytevector" = WD("write-bytevector", writeBytevector, 1, 4);

fn flushOutputPort(t: *Thread) Err!Word {
    (try outPort(t, 0)).flush();
    return rt.UNSPEC;
}
pub const @"%flush-output-port" = WD("flush-output-port", flushOutputPort, 0, 1);

// --- reading ---------------------------------------------------------------------

fn readCharImpl(t: *Thread) Err!Word {
    const c = (try inPort(t, 0)).readChar() orelse return rt.EOF;
    return rt.char(c);
}
fn peekCharImpl(t: *Thread) Err!Word {
    const c = (try inPort(t, 0)).peekChar() orelse return rt.EOF;
    return rt.char(c);
}
fn readU8(t: *Thread) Err!Word {
    const b = (try inPort(t, 0)).readByte() orelse return rt.EOF;
    return fix(b);
}
fn peekU8(t: *Thread) Err!Word {
    const b = (try inPort(t, 0)).peekByte() orelse return rt.EOF;
    return fix(b);
}
pub const @"%read-char" = WD("read-char", readCharImpl, 0, 1);
pub const @"%peek-char" = WD("peek-char", peekCharImpl, 0, 1);
pub const @"%read-u8" = WD("read-u8", readU8, 0, 1);
pub const @"%peek-u8" = WD("peek-u8", peekU8, 0, 1);

fn readLine(t: *Thread) Err!Word {
    const p = try inPort(t, 0);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    var any_read = false;
    while (p.readByte()) |b| {
        any_read = true;
        if (b == '\n') break;
        buf.append(pa, b) catch rt.oom();
    }
    if (!any_read) return rt.EOF;
    if (buf.items.len > 0 and buf.items[buf.items.len - 1] == '\r') buf.items.len -= 1;
    t.reserve(data.stringWords(buf.items.len, true));
    return data.heapStringUtf8(t, buf.items);
}
pub const @"%read-line" = WN("read-line", readLine, 0, 1);

fn readBytevector(t: *Thread) Err!Word {
    const k = try P.count(t, arg(t, 0));
    const p = try inPort(t, 1);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(pa);
    while (buf.items.len < k) {
        const b = p.readByte() orelse break;
        buf.append(pa, b) catch rt.oom();
    }
    if (buf.items.len == 0 and k > 0) return rt.EOF;
    t.reserve(data.bvWords(buf.items.len));
    const bv = data.makeBytevector(t, buf.items.len);
    @memcpy(data.bvBytes(bv), buf.items);
    return bv;
}
pub const @"%read-bytevector" = WN("read-bytevector", readBytevector, 1, 2);

fn readBytevectorB(t: *Thread) Err!Word {
    const bv = arg(t, 0);
    if (!data.isBytevector(bv)) return raise(t, "read-bytevector!: not a bytevector", &.{bv});
    const p = try inPort(t, 1);
    const len = data.bvLen(bv);
    const start: usize = if (t.argc > 2) try P.count(t, arg(t, 2)) else 0;
    const end: usize = if (t.argc > 3) try P.count(t, arg(t, 3)) else len;
    if (start > end or end > len) return raise(t, "read-bytevector!: index out of range", &.{});
    var i = start;
    while (i < end) : (i += 1) data.bvBytes(bv)[i] = p.readByte() orelse break;
    if (i == start and end > start) return rt.EOF;
    return fix(@intCast(i - start));
}
pub const @"%read-bytevector!" = WN("read-bytevector!", readBytevectorB, 1, 4);

fn readImpl(t: *Thread) Err!Word {
    const p = try inPort(t, 0);
    return reader.read(t, p) orelse error.Scheme;
}
pub const @"%read" = WN("read", readImpl, 0, 1);

/// (read-data port [max-depth]): read for untrusted data
fn readDataImpl(t: *Thread) Err!Word {
    const p = try inPort(t, 0);
    var depth: usize = 1000;
    if (t.argc > 1) {
        const d = arg(t, 1);
        if (!rt.isFix(d) or rt.unfix(d) < 1) return P.raise(t, "read-data: max-depth must be positive", &.{});
        depth = @intCast(@min(rt.unfix(d), 100000));
    }
    return reader.readData(t, p, @min(depth, reader.Reader.default_max_depth)) orelse error.Scheme;
}
pub const @"%read-data" = WN("read-data", readDataImpl, 1, 2);

fn charReady(_: *Thread) Err!Word {
    return rt.TRUE;
}
pub const @"%char-ready?" = WD("char-ready?", charReady, 0, 1);

// --- string and bytevector ports ---------------------------------------------------

fn openInputString(t: *Thread) Err!Word {
    const s = try P.stringArg(t, 0);
    const p = ports.newPort(.string_in, false);
    data.appendUtf8(&p.in, s);
    t.reserve(2);
    return ports.wrap(t, p);
}
pub const @"%open-input-string" = WN("open-input-string", openInputString, 1, 1);

fn openOutputString(t: *Thread) Err!Word {
    t.reserve(2);
    return ports.wrap(t, ports.newPort(.string_out, false));
}
pub const @"%open-output-string" = WN("open-output-string", openOutputString, 0, 0);

fn getOutputString(t: *Thread) Err!Word {
    const p = try portArg(t, 0);
    if (p.kind != .string_out) return raise(t, "get-output-string: not a string output port", &.{arg(t, 0)});
    t.reserve(data.stringWords(p.out.items.len, true));
    return data.heapStringUtf8(t, (try portArg(t, 0)).out.items);
}
pub const @"%get-output-string" = WN("get-output-string", getOutputString, 1, 1);

fn openInputBytevector(t: *Thread) Err!Word {
    const bv = arg(t, 0);
    if (!data.isBytevector(bv)) return raise(t, "open-input-bytevector: not a bytevector", &.{bv});
    const p = ports.newPort(.bytes_in, true);
    p.in.appendSlice(pa, data.bvBytes(bv)) catch rt.oom();
    t.reserve(2);
    return ports.wrap(t, p);
}
pub const @"%open-input-bytevector" = WN("open-input-bytevector", openInputBytevector, 1, 1);

fn openOutputBytevector(t: *Thread) Err!Word {
    t.reserve(2);
    return ports.wrap(t, ports.newPort(.bytes_out, true));
}
pub const @"%open-output-bytevector" = WN("open-output-bytevector", openOutputBytevector, 0, 0);

fn getOutputBytevector(t: *Thread) Err!Word {
    const n = (try portArg(t, 0)).out.items.len;
    t.reserve(data.bvWords(n));
    const bv = data.makeBytevector(t, n);
    @memcpy(data.bvBytes(bv), (try portArg(t, 0)).out.items);
    return bv;
}
pub const @"%get-output-bytevector" = WN("get-output-bytevector", getOutputBytevector, 1, 1);

// --- file ports ------------------------------------------------------------------

fn fileError(t: *Thread, msg: []const u8, name: Word) Err {
    _ = rt.failKind(t, rt.ErrorKind.file, msg, &.{name});
    return error.Scheme;
}

/// The options of open-input-file and open-output-file after the file name,
/// as the JVM implementation's: an encoding name, 'deflate, 'append
/// (symbols or strings; others are ignored)
const FileOptions = struct { enc: ports.Encoding = .utf8, bom: bool = false, deflate: bool = false, append: bool = false };

fn fileOptions(t: *Thread) FileOptions {
    var o: FileOptions = .{};
    var i: usize = 1;
    while (i < t.argc) : (i += 1) {
        const a = arg(t, i);
        const name: []const u8 = if (data.isSymbol(a)) data.symbolName(a) else if (data.isString(a)) data.toUtf8(a) else continue;
        if (ports.parseEncoding(name)) |e| {
            o.enc = e.enc;
            o.bom = e.bom;
        } else if (std.mem.eql(u8, name, "deflate")) {
            o.deflate = true;
        } else if (std.mem.eql(u8, name, "append")) {
            o.append = true;
        }
    }
    return o;
}

fn openInput(t: *Thread, binary: bool) Err!Word {
    const name = data.toUtf8(try P.stringArg(t, 0));
    var bytes = rt.os.readFile(name) orelse return fileError(t, "cannot open file", arg(t, 0));
    if (!binary) {
        const o = fileOptions(t);
        if (o.deflate) {
            const z = @import("compress.zig");
            const raw = z.decompress(bytes, .raw) catch {
                pa.free(bytes);
                return fileError(t, "open-input-file: io error", arg(t, 0));
            };
            pa.free(bytes);
            bytes = raw;
        }
        bytes = ports.decodeText(bytes, o.enc, !o.deflate);
    }
    const p = ports.newPort(.file_in, binary);
    p.in = .fromOwnedSlice(bytes);
    p.name = name;
    t.reserve(2);
    return ports.wrap(t, p);
}
fn openInputFile(t: *Thread) Err!Word {
    return openInput(t, false);
}
fn openBinaryInputFile(t: *Thread) Err!Word {
    return openInput(t, true);
}
pub const @"%open-input-file" = WN("open-input-file", openInputFile, 1, 3);
pub const @"%open-binary-input-file" = WN("open-binary-input-file", openBinaryInputFile, 1, 2);

fn openOutput(t: *Thread, binary: bool) Err!Word {
    const name = data.toUtf8(try P.stringArg(t, 0));
    const o: FileOptions = if (binary) .{} else fileOptions(t);
    var offset: ?u64 = null;
    const f = if (o.append) blk: {
        const a = rt.os.openAppend(name) orelse return fileError(t, "cannot open file for writing", arg(t, 0));
        offset = a.len;
        break :blk a.file;
    } else rt.os.createFile(name) orelse return fileError(t, "cannot open file for writing", arg(t, 0));
    const p = ports.newPort(.file_out, binary);
    p.file = f;
    p.enc = o.enc;
    p.deflate = o.deflate;
    p.offset = offset;
    // a UTF-8 byte order mark only at the start of the file (C#'s
    // StreamWriter, the JVM implementation): not when appending to a
    // file that has content
    if (o.bom and (offset orelse 0) == 0) p.out.appendSlice(pa, "\xef\xbb\xbf") catch rt.oom();
    t.reserve(2);
    return ports.wrap(t, p);
}
fn openOutputFile(t: *Thread) Err!Word {
    return openOutput(t, false);
}
fn openBinaryOutputFile(t: *Thread) Err!Word {
    return openOutput(t, true);
}
pub const @"%open-output-file" = WN("open-output-file", openOutputFile, 1, 4);
pub const @"%open-binary-output-file" = WN("open-binary-output-file", openBinaryOutputFile, 1, 2);

fn closePort(t: *Thread) Err!Word {
    (try portArg(t, 0)).close();
    return rt.UNSPEC;
}
pub const @"%close-input-port" = WD("close-input-port", closePort, 1, 1);
pub const @"%close-output-port" = WD("close-output-port", closePort, 1, 1);
pub const @"%close-port" = WD("close-port", closePort, 1, 1);

fn portPredD(comptime f: fn (*Port) bool) P.Prim {
    const S = struct {
        fn g(t: *Thread) Err!Word {
            const p = ports.get(arg(t, 0)) orelse return rt.FALSE;
            return rt.boolean(f(p));
        }
    };
    return P.WD("", S.g, 1, 1);
}
fn isIn(p: *Port) bool {
    return p.isInput();
}
fn isOut(p: *Port) bool {
    return !p.isInput();
}
fn isTextual(p: *Port) bool {
    return !p.binary;
}
fn isBinary(p: *Port) bool {
    return p.binary;
}
fn isInOpen(p: *Port) bool {
    return p.isInput() and p.open;
}
fn isOutOpen(p: *Port) bool {
    return !p.isInput() and p.open;
}
pub const @"%input-port?" = portPredD(isIn);
pub const @"%output-port?" = portPredD(isOut);
pub const @"%textual-port?" = portPredD(isTextual);
pub const @"%binary-port?" = portPredD(isBinary);
pub const @"%input-port-open?" = portPredD(isInOpen);
pub const @"%output-port-open?" = portPredD(isOutOpen);

fn fileExists(t: *Thread) Err!Word {
    // a regular file (symbolic links followed), as the JVM implementation
    return rt.boolean(rt.os.kindOf(data.toUtf8(try P.stringArg(t, 0)), true) == .file);
}
pub const @"%file-exists?" = WD("file-exists?", fileExists, 1, 1);

fn deleteFile(t: *Thread) Err!Word {
    if (!rt.os.deleteFile(data.toUtf8(try P.stringArg(t, 0)))) return fileError(t, "cannot delete file", arg(t, 0));
    return rt.UNSPEC;
}
pub const @"%delete-file" = WN("delete-file", deleteFile, 1, 1);
