//! The runtime functions that compiled code calls (abi.impl), with the C
//! ABI. rtmain.zig exports them, and every primitive as scmp_<name> (code)
//! or scmv_<name> (a value).
const std = @import("std");
const rt = @import("rt.zig");
const data = @import("data.zig");
const num = @import("num.zig");
const Word = rt.Word;
const Code = rt.Code;
const Thread = rt.Thread;

pub fn scm_gc(t: *Thread, n: usize) callconv(.c) void {
    rt.gcEntry(t, n);
}

pub fn scm_attention(t: *Thread) callconv(.c) ?Code {
    return rt.attention(t);
}
pub fn scm_grow_stack(t: *Thread, need: usize) callconv(.c) void {
    rt.growStackEntry(t, need);
}
pub fn scm_grow_args(t: *Thread, need: usize) callconv(.c) void {
    rt.growArgsEntry(t, need);
}
pub fn scm_not_procedure(t: *Thread, p: Word) callconv(.c) Code {
    return rt.notProcedure(t, p);
}
pub fn scm_fail(t: *Thread, msg: [*]const u8, len: usize, irritants: [*]const Word, n: usize) callconv(.c) Code {
    return rt.fail(t, msg[0..len], irritants[0..n]);
}
pub fn scm_type_error(t: *Thread, who: [*]const u8, len: usize, irritants: [*]const Word, n: usize) callconv(.c) Code {
    return rt.typeError(t, who[0..len], irritants[0..n]);
}
pub fn scm_arith_error(t: *Thread, who: [*]const u8, len: usize, a: Word, b: Word) callconv(.c) Code {
    return rt.arithError(t, who[0..len], a, b);
}
pub fn scm_vector_error(t: *Thread, who: [*]const u8, len: usize, v: Word, i: Word) callconv(.c) Code {
    return rt.vectorError(t, who[0..len], v, i);
}
pub fn scm_unbound_error(t: *Thread, name: [*]const u8, len: usize) callconv(.c) Code {
    return rt.unboundError(t, name[0..len]);
}
pub fn scm_arity_error(t: *Thread, n: u64, at_least: bool) callconv(.c) Code {
    return rt.arityErrorN(t, n, at_least);
}
pub fn scm_rest_list(t: *Thread, nreq: usize) callconv(.c) Word {
    return rt.restList(t, nreq);
}
/// The slow path of the open-coded arithmetic; UNBOUND on an error
pub fn scm_arith(t: *Thread, a: Word, b: Word, op: u8) callconv(.c) Word {
    const r = switch (@as(rt.abi.Op, @enumFromInt(op))) {
        .add => num.add(t, a, b),
        .sub => num.sub(t, a, b),
        .mul => num.mul(t, a, b),
        .div => num.div(t, a, b),
    };
    return r orelse rt.UNBOUND;
}
/// The slow path of the open-coded comparisons: 0 false, 1 true, 2 error
pub fn scm_compare(a: Word, b: Word, op: u8) callconv(.c) u8 {
    const r = switch (@as(rt.abi.Cmp, @enumFromInt(op))) {
        .lt => num.cmp(a, b, .lt),
        .gt => num.cmp(a, b, .gt),
        .le => num.cmp(a, b, .le),
        .ge => num.cmp(a, b, .ge),
        .eq => num.cmp(a, b, .eq),
    };
    return if (r) |b2| @intFromBool(b2) else 2;
}
pub fn scm_eqv(a: Word, b: Word) callconv(.c) bool {
    return data.eqv(a, b);
}
pub fn scm_const_string(utf8: [*]const u8, len: usize) callconv(.c) Word {
    return data.constString(utf8[0..len]);
}
pub fn scm_intern(name: [*]const u8, len: usize) callconv(.c) Word {
    return data.intern(name[0..len]);
}
pub fn scm_const_pair(a: Word, d: Word) callconv(.c) Word {
    return data.constPair(a, d);
}
pub fn scm_const_vector(items: [*]const Word, n: usize) callconv(.c) Word {
    return data.constVector(items[0..n]);
}
pub fn scm_const_flonum(f: f64) callconv(.c) Word {
    return data.constFlonum(f);
}
pub fn scm_const_bytevector(bytes: [*]const u8, n: usize) callconv(.c) Word {
    return data.constBytevector(bytes[0..n]);
}
pub fn scm_const_number(t: *Thread, text: [*]const u8, len: usize) callconv(.c) Word {
    return data.constNumber(t, text[0..len]);
}
pub fn scm_static_proc(code: Code) callconv(.c) Word {
    return rt.staticProc(code);
}
pub fn scm_primitive(code: Code, name: [*]const u8, len: usize) callconv(.c) Word {
    return rt.primitive(code, name[0..len]);
}
pub fn scm_missing_primitive(name: [*]const u8, len: usize) callconv(.c) Word {
    return rt.missingPrimitive(name[0..len]);
}
pub fn scm_set_doc(code: Code, doc: [*]const u8, len: usize) callconv(.c) void {
    @import("prims_module.zig").setDoc(code, doc[0..len]);
}
pub fn scm_set_eval_state(s: [*]const u8, len: usize) callconv(.c) void {
    @import("prims_module.zig").setEvalState(s[0..len]);
}
pub fn scm_register_global(name: [*]const u8, len: usize, cell: *Word) callconv(.c) void {
    @import("prims_module.zig").registerGlobal(name[0..len], cell);
}
pub fn scm_register_library(name: [*]const u8, len: usize, spec: [*]const u8, spec_len: usize) callconv(.c) void {
    @import("prims_module.zig").registerLibrary(name[0..len], spec[0..spec_len]);
}
pub fn scm_remember(obj: Word) callconv(.c) void {
    rt.remember(obj);
}

/// Raise the pending error (after a direct primitive call returned UNBOUND)
pub fn scm_error_code(t: *Thread) callconv(.c) void {
    return @call(.always_tail, rt.errorCode, .{t});
}
pub fn scm_not_procedure_code(t: *Thread) callconv(.c) void {
    return @call(.always_tail, rt.notProcedureCode, .{t});
}

/// The symbol name of a primitive: scmp_ or scmv_ and the Scheme name with
/// every character that is not a letter or digit as _xx (hex)
pub fn mangle(comptime prefix: []const u8, comptime name: []const u8) []const u8 {
    comptime {
        @setEvalBranchQuota(100000);
        var out: []const u8 = prefix;
        for (name) |c| {
            if (std.ascii.isAlphanumeric(c)) {
                out = out ++ &[_]u8{c};
            } else {
                const hex = "0123456789abcdef";
                out = out ++ &[_]u8{ '_', hex[c >> 4], hex[c & 15] };
            }
        }
        return out;
    }
}
