# dabscm native

A third dabscm implementation. It compiles Scheme ahead of time to Zig and links a
self-contained native executable, with no JVM and no .NET. It is in development, and nothing
here is used by the Java or C# implementations or by their builds.

Toolchain: Zig 0.17.1, pinned.

## Phase 0 spike (2026-11-21)

`spike/rt.zig` is a minimal runtime. `spike/bench.zig` holds hand-written code in the shape the
compiler will emit. `spike/bench.scm` is the same programs as Scheme source, for the JVM/.NET
implementations.

The runtime model tested:

- **Tagged 64-bit words.**
  - fixnum `xxx0` (63 bit)
  - heap pointer `x001`
  - immediates `x011`
  - characters `x101` (code points)
  - Heap objects have a header word holding the type and the payload length.
- **An explicit Scheme stack instead of the machine stack.** Every procedure and every return
  point is a Zig function `fn (*Thread) callconv(.c) void`.
  - Control passes with `@call(.always_tail, next, .{t})`: proper tail calls, no trampoline,
    and the machine stack stays flat.
  - Arguments go in `t.reg`, the closure in `t.self`, the return value in `t.val`.
  - A frame is its live slots plus a pointer to a static `RetInfo {code, size}`, which is
    also the GC's frame descriptor.
  - The stack grows by reallocation. 1e6-deep non-tail recursion works.
- **Precise Cheney semispace GC.**
  - Code that allocates first calls `reserve(n)` while all live values are in roots, then
    bump-allocates without checks. The GC therefore never has to find Zig locals.
  - Roots: registers, stack frames, globals.
- **`call/cc`** copies the stack into a heap object, and calling the continuation copies it
  back.

Results on x86-64 Linux, ReleaseFast, per run. The JVM column is the Java implementation with
the JIT, after warm-up.

| benchmark | JVM | native spike | speedup |
|---|---|---|---|
| fib 30 | 30.3 ms | 11.1 ms | 2.7× |
| tak 18 12 6 | 0.85 ms | 0.29 ms | 2.9× |
| ctak 18 12 6 (call/cc) | 110 ms | 9.7 ms | 11× |
| mk+sum 1e6 (deep recursion, 1e6 pairs, GC) | 262 ms | 18.4 ms | 14× |

There is no optimizer yet: every call goes through a global cell and the closure's code
pointer.

Findings:

- **`.always_tail` works** for x86_64-linux, x86_64-windows, x86_64-macos, aarch64-macos and
  aarch64-linux; all cross-compile from Linux. The Windows and macOS binaries still need to be
  run on those machines.
- **Debug builds must use `-fllvm`.** Zig's own x86-64 backend (the Debug default) rejects
  tail calls. Debug code runs about 10× slower.
- **Compile time is the main cost.**
  - 145k lines of generated Zig (10k code blocks) take 38 s stripped and 77 s with debug info
    in ReleaseFast. LLVM uses one core.
  - Consequences:
    - one object per library, compiled in parallel and cached by content hash;
    - out-of-line slow paths, so that the code per block stays small;
    - libraries prebuilt once per target.
- **Zig 0.17 `std` has changed again** (`std.time` timing moved to `std.Io.Clock`; `main`
  takes `std.process.Init`). That confirms the plan's rule: the generated code uses no `std`,
  and runtime use of `std` sits behind one OS layer.

Decision: keep this model for Phase 1. Segmented stacks (cheaper `call/cc` on deep stacks)
and a generational GC are later refinements.

To reproduce:

```
cd scm-native/spike
zig build-exe -OReleaseFast bench.zig && ./bench
java -jar ../../scm-java/scm.jar bench.scm
```
