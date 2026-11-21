//! `zig test check.zig` compiles every primitive (Zig compiles lazily).
const std = @import("std");
const rt = @import("rt.zig");

test "all runtime declarations compile" {
    std.testing.refAllDecls(rt);
    std.testing.refAllDecls(rt.prims);
    std.testing.refAllDecls(rt.data);
    std.testing.refAllDecls(rt.num);
}
