//! Entry point of a compiled program: the generated module `program`
//! provides the globals count, the constant initializer and the entry code.
const std = @import("std");
const rt = @import("rt");
const program = @import("program");

pub fn main(init: std.process.Init) u8 {
    rt.os.init(init.io);
    return rt.start(program.program);
}
