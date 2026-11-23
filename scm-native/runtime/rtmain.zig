//! The runtime object: compiled once per target and optimize mode, and
//! linked with the objects of the libraries and the program. It exports the
//! runtime functions (exports.zig), the primitives, and the C main.
const std = @import("std");
const rt = @import("rt.zig");
const exports = @import("exports.zig");

/// abi.impl: in the runtime object, runtime functions are called directly
pub const scm_runtime = exports;

const prim_modules = .{
    @import("prims.zig"),
    @import("prims_ctl.zig"),
    @import("prims_text.zig"),
    @import("prims_io.zig"),
    @import("prims_num.zig"),
    @import("prims_fs.zig"),
    @import("prims_hash.zig"),
    @import("prims_string.zig"),
    @import("prims_format.zig"),
    @import("prims_bytes.zig"),
    @import("prims_sys.zig"),
    @import("prims_crypto.zig"),
    @import("prims_json.zig"),
    @import("prims_xml.zig"),
    @import("prims_image.zig"),
    @import("prims_module.zig"),
    @import("prims_net.zig"),
    @import("prims_thread.zig"),
};

comptime {
    @setEvalBranchQuota(1000000);
    for (std.meta.declarations(exports)) |name| {
        if (std.mem.startsWith(u8, name, "scm_")) @export(&@field(exports, name), .{ .name = name });
    }
    for (prim_modules) |m| {
        for (std.meta.declarations(m)) |name| {
            if (name.len < 2 or name[0] != '%') continue;
            const v = @field(m, name);
            if (@TypeOf(v) == rt.Code) {
                @export(v, .{ .name = exports.mangle("scmp_", name[1..]) });
            } else if (@TypeOf(v) == @import("prims.zig").Prim) {
                @export(v.code, .{ .name = exports.mangle("scmp_", name[1..]) });
                @export(v.direct, .{ .name = exports.mangle("scmd_", name[1..]) });
            } else if (@TypeOf(v) == rt.ValuePrim) {
                @export(v.make, .{ .name = exports.mangle("scmv_", name[1..]) });
            }
        }
    }
}

/// Every primitive by name, for eval (%primitive-ref)
pub const PrimEntry = struct { name: []const u8, code: ?rt.Code, make: ?*const fn () callconv(.c) rt.Word };
pub const primitive_table = blk: {
    @setEvalBranchQuota(1000000);
    var n = 0;
    for (prim_modules) |m| {
        for (std.meta.declarations(m)) |name| {
            if (name.len >= 2 and name[0] == '%') n += 1;
        }
    }
    var table: [n]PrimEntry = undefined;
    var i = 0;
    for (prim_modules) |m| {
        for (std.meta.declarations(m)) |name| {
            if (name.len < 2 or name[0] != '%') continue;
            const v = @field(m, name);
            table[i] = if (@TypeOf(v) == rt.Code)
                .{ .name = name[1..], .code = v, .make = null }
            else if (@TypeOf(v) == @import("prims.zig").Prim)
                .{ .name = name[1..], .code = v.code, .make = null }
            else
                .{ .name = name[1..], .code = null, .make = v.make };
            i += 1;
        }
    }
    const final = table;
    break :blk &final;
};

/// The program object provides its modules, in initialization order
extern fn scm_program_modules() callconv(.c) rt.abi.ModuleList;
/// ... of which the first this many start before the program; the others
/// start at the program's import that brings them in (%module-entry)
extern fn scm_program_eager() callconv(.c) usize;

fn cMain(c_argc: c_int, c_argv: [*][*:0]u8, c_envp: [*:null]?[*:0]u8) callconv(.c) c_int {
    const args = rt.os.initProcess(@intCast(c_argc), c_argv, c_envp);
    return rt.start(scm_program_modules(), scm_program_eager(), args);
}

comptime {
    @export(&cMain, .{ .name = "main" });
}
