//! Primitives: the file system ((scm fs)), as in the JVM implementation.
//! Phase 2 provides the basic ones; Phase 4 completes them.
const std = @import("std");
const builtin = @import("builtin");
const rt = @import("rt.zig");
const data = @import("data.zig");
const os = @import("os.zig");
const P = @import("prims.zig");
const Word = rt.Word;
const Thread = rt.Thread;
const Err = P.Err;
const W = P.W;
const WN = P.WN;
const arg = P.arg;

const pa = std.heap.page_allocator;

fn str(t: *Thread, utf8: []const u8) Word {
    t.reserve(data.stringWords(utf8.len, true));
    return data.heapStringUtf8(t, utf8);
}

fn pathArg(t: *Thread, i: usize) Err![]const u8 {
    return data.toUtf8(try P.stringArg(t, i));
}

const sep = if (builtin.os.tag == .windows) "\\" else "/";

fn makePathSep() Word {
    return data.constString(sep);
}
pub const @"%path-sep" = rt.ValuePrim{ .make = &makePathSep };

fn absolutePath(t: *Thread) Err!Word {
    const p = try pathArg(t, 0);
    if (os.realPath(p)) |r| return str(t, r);
    if (std.fs.path.isAbsolute(p)) return arg(t, 0);
    return str(t, std.fs.path.join(pa, &.{ os.currentDirectory(), p }) catch rt.oom());
}
pub const @"%absolute-path" = WN("absolute-path", absolutePath, 1, 1);

fn baseName(t: *Thread) Err!Word {
    return str(t, std.fs.path.basename(try pathArg(t, 0)));
}
pub const @"%base-name" = WN("base-name", baseName, 1, 1);

fn directoryName(t: *Thread) Err!Word {
    const p = try pathArg(t, 0);
    const abs = if (std.fs.path.isAbsolute(p)) p else std.fs.path.join(pa, &.{ os.currentDirectory(), p }) catch rt.oom();
    const d = std.fs.path.dirname(abs) orelse return rt.FALSE;
    return str(t, d);
}
pub const @"%directory-name" = WN("directory-name", directoryName, 1, 1);

fn currentDirectory(t: *Thread) Err!Word {
    return str(t, os.currentDirectory());
}
pub const @"%current-directory" = WN("current-directory", currentDirectory, 0, 0);

fn specialFolderTemp(t: *Thread) Err!Word {
    return str(t, os.getEnv("TMPDIR") orelse os.getEnv("TEMP") orelse "/tmp");
}
pub const @"%special-folder-temp" = WN("special-folder-temp", specialFolderTemp, 0, 0);

fn specialFolderUserHome(t: *Thread) Err!Word {
    return str(t, os.getEnv("HOME") orelse os.getEnv("USERPROFILE") orelse "/");
}
pub const @"%special-folder-user-home" = WN("special-folder-user-home", specialFolderUserHome, 0, 0);

fn directoryExists(t: *Thread) Err!Word {
    return rt.boolean(os.kindOf(try pathArg(t, 0), true) == .directory);
}
pub const @"%directory-exists?" = WN("directory-exists?", directoryExists, 1, 1);

fn pathExists(t: *Thread) Err!Word {
    return rt.boolean(os.kindOf(try pathArg(t, 0), false) != null);
}
pub const @"%path-exists?" = WN("path-exists?", pathExists, 1, 1);

fn fileSymlinkP(t: *Thread) Err!Word {
    return rt.boolean(os.kindOf(try pathArg(t, 0), false) == .symlink);
}
pub const @"%file-symlink?" = WN("file-symlink?", fileSymlinkP, 1, 1);

fn fileSize(t: *Thread) Err!Word {
    const n = os.fileSize(try pathArg(t, 0)) orelse return rt.FALSE;
    return rt.fix(@intCast(n));
}
pub const @"%file-size" = WN("file-size", fileSize, 1, 1);

fn makeDirectory(t: *Thread) Err!Word {
    if (!os.makeDirectory(try pathArg(t, 0))) return P.raise(t, "make-directory: cannot create directory", &.{arg(t, 0)});
    return rt.UNSPEC;
}
pub const @"%make-directory" = WN("make-directory", makeDirectory, 1, 1);

fn deleteDirectory(t: *Thread) Err!Word {
    return if (os.deleteTree(try pathArg(t, 0))) rt.UNSPEC else rt.FALSE;
}
pub const @"%delete-directory" = WN("delete-directory", deleteDirectory, 1, 1);

fn listing(t: *Thread, comptime which: enum { files, directories, entries }) Err!Word {
    const entries = os.listDirectory(try pathArg(t, 0)) orelse return P.raise(t, "cannot read directory", &.{arg(t, 0)});
    var total: usize = 0;
    for (entries) |e| total += data.stringWords(e.name.len, true) + 6;
    t.reserve(total);
    var l = rt.NIL;
    var i = entries.len;
    while (i > 0) {
        i -= 1;
        const e = entries[i];
        switch (which) {
            .files => if (e.kind != .directory) {
                l = t.cons(data.heapStringUtf8(t, e.name), l);
            },
            .directories => if (e.kind == .directory) {
                l = t.cons(data.heapStringUtf8(t, e.name), l);
            },
            .entries => {
                const kind = data.intern(switch (e.kind) {
                    .directory => "directory",
                    .symlink => "symlink",
                    else => "file",
                });
                l = t.cons(t.cons(data.heapStringUtf8(t, e.name), kind), l);
            },
        }
    }
    return l;
}
fn directoryFiles(t: *Thread) Err!Word {
    return listing(t, .files);
}
fn directoryDirectories(t: *Thread) Err!Word {
    return listing(t, .directories);
}
fn directoryEntries(t: *Thread) Err!Word {
    return listing(t, .entries);
}
pub const @"%directory-files" = WN("directory-files", directoryFiles, 1, 1);
pub const @"%directory-directories" = WN("directory-directories", directoryDirectories, 1, 1);
pub const @"%directory-entries" = WN("directory-entries", directoryEntries, 1, 1);

fn sysPlatform(_: *Thread) Err!Word {
    return data.intern(switch (builtin.os.tag) {
        .windows => "windows",
        .macos => "unknown", // as the JVM implementation
        else => "linux",
    });
}
pub const @"%%sys-platform" = WN("%sys-platform", sysPlatform, 0, 0);
pub const @"%sys-platform" = WN("sys-platform", sysPlatform, 0, 0);
