//! `zig test -fllvm check.zig` compiles every primitive (Zig compiles lazily).
const std = @import("std");
const rt = @import("rt.zig");

test "all runtime declarations compile" {
    std.testing.refAllDecls(rt);
    std.testing.refAllDecls(rt.prims);
    std.testing.refAllDecls(rt.prims_ctl);
    std.testing.refAllDecls(rt.prims_text);
    std.testing.refAllDecls(rt.prims_io);
    std.testing.refAllDecls(rt.prims_num);
    std.testing.refAllDecls(rt.prims_fs);
    std.testing.refAllDecls(rt.num.tower);
    std.testing.refAllDecls(rt.data);
    std.testing.refAllDecls(rt.num);
    std.testing.refAllDecls(rt.ports);
    std.testing.refAllDecls(@import("reader.zig"));
}
