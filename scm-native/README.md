# dabscm native

A third dabscm implementation. It compiles Scheme ahead of time to Zig and links a
self-contained native executable, with no JVM and no .NET. It is in development, and nothing
here is used by the Java or C# implementations or by their builds.

Toolchain: Zig 0.17.1, pinned.

## Usage

```
java -jar scm-java/scm.jar scm-native/scmc.scm program.scm [-o output]
     [-O ReleaseFast|ReleaseSafe|Debug] [--target x86_64-windows] [--emit-zig]
java -jar scm-java/scm.jar scm-native/test.scm [name ...]
java -jar scm-java/scm.jar scm-native/core-tests.scm [tests_r7rs ...]
```

- `scmc` compiles a program together with every library it imports, from `scm-lib` (the
  same sources the JVM and .NET implementations use), into one executable. It warns about
  primitives the native runtime does not implement yet; calling one is an error at run time.
- `test.scm` compiles each program in `tests/`, runs it, and compares its output and exit
  code with the JVM implementation's.
- `core-tests.scm` runs `scm-tests/core` natively, with the assertions of the JVM harness
  (`SchemeTests.runCoreTest`).

## Structure

- `compiler/`: the compiler, written in Scheme. It runs on the JVM implementation for now.
  - `(scm native syntax)`: identifiers with sets of scopes, the binding table, `syntax-rules`.
  - `(scm native expand)`: the expander and the library system, following the JVM
    implementation's `Expander.java`. It handles `define-library`, `import` sets,
    `include`, `cond-expand` (features of the target) and `%primitive`.
    `library.scm` is `(scm core)`.
  - `(scm native ast)`: Core IR, free-variable analysis.
  - `(scm native optimize)`: globals that are constant primitives (`(define car (%primitive
    "car"))`) become the primitive; primitive calls are open-coded.
  - `(scm native anf)`: A-normal form. A complex expression (one containing a call) remains
    only in tail position or as the right-hand side of a `let`.
  - `(scm native emit)`: Zig code generation.
    - Every lambda becomes an entry block, and every non-tail call ends a block and continues
      in a return block.
    - Live values are saved in the frame.
    - Each block reserves its heap words at entry.
    - Closures are flat; lambdas without free variables become static closures.
    - Assigned variables are boxed.
    - Hot primitives are open-coded.
  - `(scm native driver)`: runs the passes and calls `zig build-exe`.
- `runtime/`: the runtime, written in Zig.
  - `rt.zig`: values, thread, GC (copying heap plus a mark-and-sweep large-object space),
    control, multiple values, errors.
  - `data.zig`: strings (Latin-1 or UTF-32 buffers), symbols, vectors, bytevectors, records,
    equality, static constants.
  - `num.zig` and `tower.zig`: arithmetic. The tower covers bignums (`std.math.big.int`),
    exact rationals and complex numbers.
  - `printer.zig`: `write`, `display`, with datum labels.
  - `reader.zig`: `read`.
  - `ports.zig`: ports.
  - `chars.zig`: character classes.
  - `prims*.zig`: primitive procedures, named `@"%name"` for the Scheme name.
  - `os.zig`: the only user of version-sensitive `std` APIs.
  - `main.zig`: the entry point.
  - `zig test -fllvm runtime/check.zig` compiles every primitive (Zig compiles lazily).

Behavior kept from the JVM implementation:
- Unbound identifiers resolve in the module being expanded.
- The JVM compiler's intrinsics (`car`, `null?`, ...) are available everywhere.
- Error messages use the same wording (`Failed in car: wrong argument type`).
- `%raise-fatal` raises to the remaining handlers.
- Literals are distinct objects.
- `write` labels cycles.

Not available natively (yet):
- `eval`, `environment` and the REPL (planned for Phase 5).
- Bytecode introspection (`(scm compile)`, never).
- Procedure docstrings and `macroexpand`.
- Most of `(scm fs)` and `(scm string)` (regular expressions), planned for Phase 4.
- Unicode character tables: Latin, Greek and Cyrillic only for now.

Known difference: the JVM implementation runs a program one top-level form at a time. A
continuation captured in a top-level form therefore ends with that form there, but continues
with the rest of the program in a native executable (the R7RS program semantics).
`core-tests.scm` emulates the JVM behavior for the core tests.

Phase 1 numbers (unoptimized compiled code, per run): fib(30) 19 ms, tak 18 12 6 0.47 ms. The
hand-written spike took 11 ms and 0.29 ms, the JVM JIT 30 ms and 0.85 ms. The difference to the
spike is what Phase 3 (the optimizer) addresses.

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
