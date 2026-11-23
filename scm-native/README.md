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
java -jar scm-java/scm.jar scm-native/lib-tests.scm [tests_scm_string ...]
```

- `scmc` compiles a program together with every library it imports, from `scm-lib` (the
  same sources the JVM and .NET implementations use), into one executable. It warns about
  primitives the native runtime does not implement yet; calling one is an error at run time.
  On Linux the default target is `x86_64-linux-musl`: a static executable that needs nothing
  installed.
- `test.scm` compiles each program in `tests/`, runs it, and compares its output and exit
  code with the JVM implementation's.
- `core-tests.scm` runs `scm-tests/core` natively, with the assertions of the JVM harness
  (`SchemeTests.runCoreTest`).
- `lib-tests.scm` runs the library tests in `scm-tests/tests` natively (each file as a
  program, in the tests directory, as `SchemeTests.runTestsTest`) and prints the number of
  tests and failures of each. It keeps only the executables of failing tests.
- `tools/lint.scm` and `tools/fmt.scm` are `scm lint` and `scm fmt` as native programs.

Environment variables of compiled programs, for debugging the runtime:
`SCM_NATIVE_GC_STATS=1` (collection counts at exit), `SCM_NATIVE_GC_VERIFY=1` (looks for
missing write barriers before each minor collection), `SCM_NATIVE_SEGV=1` (a stack trace on
a crash).

## Build structure

- **The runtime is one object** (`runtime/rtmain.zig`). It exports the runtime functions,
  every primitive (`scmp_<name>`, `scmv_<name>` for values) and the C `main`.
- **Every library and the program is an object of its own.**
  - Each owns its globals as `scml_<module>_g`; other modules declare that array `extern`.
  - Each module exports `scml_<module>_init` (its constants) and `scml_<module>_entry` (its
    body).
  - The program object lists the modules in initialization order (`scm_program_modules`) and
    tells the runtime where `raise` and the current ports are (`scm_program_specials`).
- **Compiled code imports only `runtime/abi.zig`.** It holds the value representation, the
  thread (an `extern struct`), inline fast paths, and the runtime functions as `extern`.
  Inside the runtime object, the same calls are direct.
- **Names are numbered per module,** so a library's Zig code is the same for every program
  that uses it.
- **The Zig command line does not cache,** so `build/objects/` holds the objects under the
  hash of what goes into them. A program whose libraries are built already compiles in about
  2 s (most of it the expansion on the JVM); the core tests take about a minute.
- **`zig build-exe` only links** the objects with libc (statically, for musl).

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
  - `abi.zig`: the interface to compiled code.
  - `exports.zig`: the runtime functions compiled code calls.
  - `rtmain.zig`: the runtime object's root and the C `main`. Building it compiles every
    primitive, since all of them are exported.

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

## Phase 3: optimizer

`(scm native optimize)` rewrites the whole program's Core IR before ANF:
- **Constant primitives:** globals that are constant primitives become the primitive, and
  primitive calls are open-coded.
- **Records:** `define-record-type` procedures become open-coded record operations with a
  type check (the record type is recognized from `make-record-type` with constant fields).
- **Inlining:** calls of small known global procedures are inlined, across libraries.
- **Folding:** `if` with a constant test, and `(if (not e) ...)`, are folded.

The emitter adds:
- **Known calls:** calls of known procedures (`letrec` and named-`let` bindings, and globals of
  the same module defined once to a lambda) jump to their code directly.
- **Direct leaf calls:** leaf primitives (those that never collect and never call Scheme:
  `car`, `string-ref`, `assv`, `display`, ...; made with `WD` in the runtime) are called
  directly as Zig functions, with no frame and no block split.
- **Flonums without reservation:** arithmetic slow paths take flonums from a separate area at
  the top of the heap, so arithmetic reserves nothing.
- **Numeric primitives are leaf primitives.** Their flonums come from the flonum area, their
  bignums from the large-object space; neither collects. An allocation outside the nursery
  requests a collection by lowering `hlimit` to the heap base, and a loop's heap check notices
  that.
- **A generational collector** (`rt.zig`):
  - **Nursery:** 8 MB, its top quarter for flonums; compiled code bump-allocates in it.
  - **Minor collections** promote the nursery's survivors into the old space. Their roots
    include the remembered set: old objects into which a young pointer was stored, kept by a
    write barrier (`abi.barrier`) at every mutation.
  - **Major collections** copy everything live into a new old space of about three times the
    live data, and sweep the large-object space.
  - **Requested collections:** allocations outside the nursery request a collection, which
    happens at the next procedure entry (`t.poll()`), loop head or reservation; every
    unbounded computation passes through one.
  - `SCM_NATIVE_GC_STATS=1` prints the numbers of collections at exit.
- **Escape continuations:** a `call/cc` receiver with one parameter that it only calls
  directly (the JVM implementation's escape-only rule) is marked by the compiler.
  `library.scm`'s `call/cc` then gives it an escape continuation: a marker frame with a stamp,
  where invoking the continuation cuts the stack back to the marker instead of copying the
  stack. At a stack depth of 10,000, 10,000 escapes take 1.2 ms instead of 83 ms.
- **Loops:** a named `let` whose name is only called in tail position, in a body without
  non-tail calls, becomes a Zig `while` loop. The parameters become variables, and a self
  call becomes assignments and `continue`. If the body allocates, every iteration checks the
  heap; to collect, the loop's values (the parameters and the outer values it uses) are
  spilled to `t.args`, which are roots.

`bench/bench.scm`, per run, JVM implementation with the JIT after warm-up against native
(x86-64 Linux):

| benchmark | JVM | native | speedup |
|---|---|---|---|
| fib30 | 37.4 ms | 14.9 ms | 3× |
| tak | 1.05 ms | 0.44 ms | 2× |
| ctak (call/cc) | 122 ms | 6.9 ms | 18× |
| nqueens8 | 1.92 ms | 0.32 ms | 6× |
| loops (named let, do, vectors) | 359 ms | 5.8 ms | 62× |
| lists (map, filter, for-each, apply) | 791 ms | 46.5 ms | 17× |
| strings (string ports, chars) | 222 ms | 51 ms | 4× |
| records (define-record-type) | 569 ms | 8.0 ms | 71× |
| sorting (list-sort) | 487 ms | 71 ms | 7× |
| assocs (assv) | 99.8 ms | 30.8 ms | 3× |
| floats | 223 ms | 37.4 ms | 6× |

Times vary between runs by 10 to 20%.

Phase 1 numbers (unoptimized compiled code, per run): fib(30) 19 ms, tak 18 12 6 0.47 ms. The
hand-written spike took 11 ms and 0.29 ms, the JVM JIT 30 ms and 0.85 ms. The difference to the
spike is what Phase 3 (the optimizer) addresses.

## Phase 4: operating system layer and libraries

The primitives of the CLI and batch libraries, as in the JVM implementation (its messages
included), in `runtime/prims_*.zig`; the version-sensitive `std` APIs stay in `os.zig`:

- strings and text: `(scm string)`, `format`, Unicode tables (`unicode.zig`, generated by
  `tools/gen-unicode.scm` from the Unicode Character Database), display widths, Latin-1,
  base64, here-strings and `read-data` in the reader;
- regular expressions (`regex.zig`): the subset java.util.regex and .NET share; patterns
  outside it are rejected, so a program does not depend on one host's dialect;
- hash tables, dicts, bit operations, bytevector number accessors, exact conversion of
  flonums to the simplest rational, correctly rounded rationals to flonums, complex literals;
- time (TZif files and POSIX TZ rules), the file system, processes (`run-program` and its
  variants, `ps`, `kill`), system information, the terminal, random-access files;
- deflate, zlib and gzip (`compress.zig`, over the vendored zlib 1.3.1 in
  `vendor/zlib-1.3.1` through `zshim.c`, called as java.util.zip calls it: the JVM's bytes),
  zip archives (`zip.zig`, with ZipOutputStream's data descriptors and time fields), the image codec (`image.zig`, a port of `ImageCodec.java`: the same pixels and
  JPEG bytes), crypto (`std.crypto`), JSON and XML readers;
- library introspection (`%module-exports` and friends) over `library_exports.zig`, the
  exports of every library and their kind, generated by `tools/gen-library-exports.scm` on
  the JVM; regenerate it when exports change;
- `procedure-doc`: docstrings of lambdas, and the texts of primitives from
  `primitive_docs.zig` (generated by `tools/gen-primitive-docs.scm` on the JVM).

Milestones: native `scm fmt --diff` over `scm-lib`, `scm-tests` and `scm-native` gives the
JVM's output byte for byte (3.5 s against about a minute); native `scm lint` over
`scm-lib/libraries` gives the same findings (1.3 s against 16 s);
`update-documentation.scm` compiled natively produces the same documentation, byte for byte
(`reference.docx` included).

Differences to the JVM implementation:

- Strings hold code points: a character outside the BMP is one character (two on the JVM),
  JSON's `\uD83D\uDE00` is one character, `char-foldcase` is the Unicode simple case folding.
- Character literals beyond U+FFFF (`#\x1F600`) are characters; the compiler, which runs
  on the JVM with its UTF-16 characters, reads them through a marker (`read-file` in
  `scm-native-expand.sld`).
- The gzip reader's message for a truncated header or trailer is "Unexpected end of ZLIB
  input stream" (the JVM gives a NullPointerException's text).
- `string->number` reads complex numbers.
- Not yet: RSA, threads, sockets and the network libraries (Phases 6 and 7), `eval` and
  `environment` (Phase 5).

## Phase 5: self-hosting

`scmc` compiles itself:

    scm scm-native/scmc.scm scm-native/scmc.scm -I scm-native/compiler -o scm-native/build/scmc

The native `scmc` (same options; `-I dir` adds a library directory) finds `scm-native` from
`SCM_NATIVE_DIR`, else as the parent of its executable's directory. It emits the same Zig as
`scmc` on the JVM and compiles a program in about a second when the objects are cached
(about a minute on the JVM). The driver builds objects with `start-program`, one process per
core.

### eval, environment, load

`(scheme eval)` and `(scheme load)` are, natively, `(scm native eval)`
(`compiler/scm-native-eval.sld`): a program that imports them links the expander and a
closure-generating interpreter over Core IR, whose procedures are ordinary procedures of the
program (compiled code calls them directly).

- The compiler embeds its expander state after compiling the program (`expander-state` in
  `scm-native-expand.sld`: the binding table without local bindings, the libraries with their
  exports and globals, the macros' syntax-rules), and registers the program's global cells by
  name (`registerGlobal`, `%native-global`). `eval` installs the state on first use, so it
  expands code against the linked libraries as the compiler did, without their sources.
- Globals of linked libraries are the program's own cells; primitives come from the runtime's
  table of all primitives (`%primitive-ref`).
- A library the program does not link is loaded from its source, over the search path the
  program was compiled with, and its body runs in the interpreter.
- As on the JVM, `(environment spec ...)` gives one environment per list of import sets, and
  library names such as `(scheme r5rs)` and `(user main)` are environments too.
- Programs without eval do not carry any of this.
- `macroexpand` and `bound?` need the expander at run time: the runtime's primitives call
  `%eval-hook` of `(scm native eval)` (the special `eval_hook`), and the driver links that
  library into a program that uses them. `%module-exports` also knows the program's own
  libraries (defined in it, or not in `scm-lib`), registered at startup.

### scm as a native program

`tools/scm.scm` is `scm` over the native eval:

    scm scm-native/scmc.scm scm-native/tools/scm.scm -o scm-native/build/scm

It is a REPL (line editing and history in `~/.dabscm-history` on a terminal, values written as
by the JVM's REPL), `scm -e expr`, `scm script.scm arg ...` (the script interpreted, with
`script-name`, `script-arguments` and `command-line` as on the JVM) and the built-in tools
`scm fmt`, `scm lint` and `scm new-app`. The common libraries are compiled into it; others
are loaded from source. `scm lint` over `scm-lib/libraries` this way (interpreting
`(scm source lint)`) takes 10 s and gives the JVM's findings (JVM 16 s, the compiled
`tools/lint.scm` 1.3 s).

## Phase 6: network

- Sockets and TLS (`net.zig`, `prims_net.zig`): `(scm net sockets)` over `std.Io.net`, TLS 1.2
  and 1.3 clients with `std.crypto.tls.Client` (ECDHE with AES-GCM or ChaCha20-Poly1305) for
  `tls-connect`, `socket-starttls!` and HTTPS; the trusted CAs are `SSL_CERT_FILE` or the
  system's; `SCM_TLS_INSECURE` turns verification off. SIGPIPE is ignored.
- RSA (`rsa.zig`, over `std.crypto.ff`): key generation (e = 65537, SubjectPublicKeyInfo and
  PKCS#8 DER) and OAEP with SHA-256, interchangeable with the JVM's keys and ciphertexts.
  AES with 192-bit keys (`aes192.zig`; `std.crypto` has 128 and 256 only).
- `pg-quote-literal`, `pg-parse-datarow` for `(scm database postgres)`.
- SQL Server (`tds.zig`): `tds-connect` performs the PreLogin exchange and TLS with the
  handshake wrapped in TDS PRELOGIN packets (a framing reader and writer under
  `std.crypto.tls.Client`, which afterwards talks to the socket directly), with or without
  certificate verification; `sql-browser-port` asks the SQL Server Browser (UDP 1434,
  `SCM_SQL_BROWSER_PORT`) for a named instance's port. `SCM_TDS_DEBUG` as on the JVM.
  Tested against a fake TDS server (Python's `ssl.MemoryBIO`), not yet against SQL Server.
- HTTP and WebSockets in Scheme (`lib/scm-native-http.sld`): the client (`http-get`,
  `http-post`, `http-send`; redirects, response headers and text/binary bodies as the JDK
  client's), request and response objects, `tcp-http-serve` (as the JVM's: one request per
  connection, spooling of large bodies, the same status lines and log lines) and WebSockets.
  The scm-lib libraries import it natively (`cond-expand`). Requests, responses, servers
  and WebSockets print as on the JVM (`#<http-request GET url>`; `%set-record-printer!`).
  `server-install-shutdown-hook`: SIGINT and SIGTERM stop the server, let open connections
  finish for the grace time and exit with 130 or 143, as the JVM does.
- The server has an accept thread and serves each connection on a thread of its own, at
  most max-threads at once, with up to max-queued more waiting and 503 beyond, as the JVM's
  pool (Phase 7). Socket reads wait in `poll` for their socket (`(scm native tasks)`,
  `lib/scm-native-tasks.sld`).

## Phase 7: threads

- SRFI 18 (`runtime/prims_thread.zig`) with the JVM and C# implementations' semantics: every
  thread is an OS thread with its own nursery, Scheme stack and registers (`abi.Thread`);
  the old space, large objects, static objects and globals are shared, so a `set!` of a
  global is seen by every thread. Threads end with the program (daemons, as on the JVM).
  Mutexes (abandoned when their owner ends), condition variables (SRFI 18's atomic unlock
  and wait), `thread-join!` with timeouts and the thread exceptions (join timeout,
  abandoned mutex, terminated thread, uncaught exception with its reason);
  `thread-terminate!` ends the thread at its next procedure entry or loop head, and its
  join raises the uncaught "thread terminated" error, as on the JVM. Parameter objects have
  a value per thread (falling back to the default, as C#'s `Parameter`); the current ports
  are shared globals, as on the JVM.
- Collections stop the world: the thread that needs one lowers every other thread's
  allocation limit and sets its `gc_requested`; each stops at its next safepoint (every
  procedure entry checks `t.attention()`, loop heads and `reserve` check the limit), or
  counts as stopped while in a blocking call (reads, accepts, polls, sleeps, waits for a
  mutex, a condition variable, a thread or a process: `rt.blockingBegin`/`blockingEnd`,
  during which a thread must not touch the heap). The collector then collects every
  nursery at once. All nurseries come from one reserved range of address space (64 GB,
  committed when used), so "young" is a single range check for the write barrier of every
  thread. An ended thread's nursery is freed by the next collection (asked for when eight
  are waiting).
- Thread-safe runtime state: locks for the symbol table, static and large objects, the
  remembered set, each port's output, the standard output buffer, the regex and primitive
  caches and the process list; thread-local error texts, printer and reader label tables.

## Phase 8: Windows, macOS, arm64

- `scmc --target <triple>` cross-compiles from Linux: `x86_64-linux-musl` (the default),
  `aarch64-linux-musl`, `x86_64-macos`, `aarch64-macos` and `x86_64-windows` all build,
  the native `scm` tool included. Windows programs link `crypt32` and `ws2_32` (the
  system's certificate store for TLS) and `advapi32` (process owners).
- Windows OS layer (`runtime/os_windows.zig`, Win32 declarations of its own, since Zig's
  std has few): processes (wait, poll, exit codes, `TerminateProcess` for kill as the
  JVM's `destroy`, process lists and trees through Toolhelp snapshots, start times and
  CPU times), the console (UTF-8 code pages, raw mode and echo through console modes
  with VT input and output, size, input readiness, resizes by comparison), Ctrl+C and
  closing as SIGINT and SIGTERM for `server-install-shutdown-hook`, the local time zone
  with the daylight saving time of each date, the OS version. The young space is
  reserved with `VirtualAlloc` and committed per nursery. Sockets: `std.Io` uses AFD
  handles on Windows, so `poll` is the AFD driver's poll request (as wepoll and libuv);
  the SQL Server Browser lookup uses `std.Io.net` UDP sockets on every system.
- macOS (`runtime/os_macos.zig`): process lists, parents, paths, start and CPU times
  through libproc, user names through `getpwuid` (Linux reads `/proc` and `/etc/passwd`).
- Run on Windows 11 (x86_64, 2026-11-23); see "Testing on Windows" below. macOS is only
  cross-compiled so far.

### Debian packages of programs

`tools/package-deb.scm` packages a compiled program (pure Scheme over `(scm deb)`, on any
dabscm):

    scm scm-native/scmc.scm app.scm -o build/app --strip
    scm scm-native/tools/package-deb.scm --exe build/app --name app --version 1.0 \
        --description "one line" [--long "more"] [--maintainer "Name <mail>"] \
        [--depends "..."] [--file src /usr/share/doc/app/README [mode]] ... [--out dist]

The program becomes `/usr/bin/<name>` in `<name>_<version>_<arch>.deb`; the architecture
comes from the executable's ELF header, so `--target aarch64-linux-musl` gives an arm64
package. The executables are static, so they need no dependencies. `scmc --strip` leaves
out debug information (hello: 3.6 MB instead of 22 MB).

### The dabscm-native package

`package-deb-native.scm` (in the repository root) packages scmc, the native `scm` (as
`scm-native`) and `scmc-deb` (`tools/package-deb.scm` compiled), the runtime, lib,
compiler and vendor sources, scm-lib and the pinned Zig, under `/usr/lib/dabscm-native`
(about 400 MB installed, 97 MB as a package). The commands in `/usr/bin` are wrappers that
set `SCM_NATIVE_DIR`. Installed, scmc finds the bundled Zig (`zig/` next to `scm-native/`,
else `SCM_NATIVE_ZIG`, else `zig` on the PATH) and keeps its build directory in
`$XDG_CACHE_HOME/dabscm-native` (`~/.cache`), since its own directory is not writable
(`SCM_NATIVE_BUILD` overrides both); `eval` in installed programs loads libraries that are
not linked from the installation's scm-lib (`SCM_NATIVE_DIR`).

### Testing on Windows (or macOS)

1. Install Zig 0.17.1 for the machine (ziglang.org/download, the `zig-x86_64-windows-0.17.1`
   or `zig-aarch64-macos-0.17.1` archive) and put `zig` on the PATH. `zig version` must print
   `0.17.1`.
2. The compiler runs on the Java or C# implementation there: `scm scm-native/scmc.scm
   prog.scm -o prog.exe` builds for the machine itself (the default target is the host
   outside Linux). Try small programs first: hello, then one with threads, then one with
   sockets.
3. Run the suites: `cd scm-native && scm lib-tests.scm` and `scm core-tests.scm` (a list
   of test names runs only those). For comparison, on Linux the library tests are clean in
   110 of 111 files (`tests_geiser` needs `current-module`), and the core tests fail only
   in `tests_compiler` (bytecode introspection), `tests_tspl3ed` (1) and `tests_vm` (1). On Windows the scripts name executables `.exe` and run them without a
   time limit (there is no `timeout` command).
4. On macOS: `os_macos.zig` (libproc) and the TLS certificate store (std's macOS keychain
   scan) are untested.

Results on Windows 11 x86_64 (2026-11-23), scmc on the JVM:

- The library tests are clean in 110 of 111 files (`tests_geiser` needs `current-module`,
  as on Linux). The core tests fail as on
  Linux: `tests_compiler`, `tests_tspl3ed` (1), `tests_vm` (1). Sockets (AFD poll), TLS,
  threads, the HTTP server and WebSockets pass (`tests_net`, `tests_srfi_18`,
  `tests_scm_http_large`, `tests_scm_websocket_upgrade`, `tests_smtp`).
- The native `scmc` and `scm` build and run (scmc: about 1 s per program with cached
  objects). The REPL's line editing, history, UTF-8 input (also outside the BMP) and
  Ctrl+C at the prompt work in a console. A server with `server-install-shutdown-hook`
  finishes open requests on Ctrl+C and exits with 130. Closing the console window
  (SIGTERM) is untested.
- Fixed on the way:
  - `cond-expand` on a Windows (or macOS) host: without `--target` the driver gave the
    features of `x86_64-linux` (`gnu-linux`, `unix`); now those of the host (from the
    compiling implementation's `features`).
  - `directory-name` on Windows makes paths absolute as the JVM does: a path without a
    drive (`/a/b`) is on the current directory's drive, `C:foo` is relative to C:'s
    directory, and the separators become `\`.
  - `tests_scm_fs_paths` expected `/` as the separator: its expected paths now use
    `path-sep` and the root of the current drive, with Windows-only cases (drives,
    backslashes) under `cond-expand`. The JVM, .NET and native pass it on Windows.
  - Object names of the C sources: `file-name-base` split only at `/`.
  - Setting modification times (`copy-file` and others): Zig 0.17's
    `Dir.setTimestamps` panics on Windows ("TODO"), so `SetFileTime` is called directly.
  - The console is read with `ReadConsoleW`, and the UTF-8 bytes of a key that are not
    taken yet are kept in the runtime. One key can give several bytes, and after a
    byte-wise `ReadFile` the console keeps the rest where waiting on the handle does
    not see it. Before, `terminal-byte-ready?` missed them and multibyte characters
    reached the line editor broken. `terminal-byte-ready?` skips console events that
    give no bytes (key releases, focus, mouse).
  - `(scm terminal)` gives a character above #xFFFF as one char natively (a surrogate
    pair string on the JVM and .NET).
  - `ps-info`: `command` is the executable's full path and `user` is `DOMAIN\user`, as
    on the JVM. `sys-machine-name` is the DNS host name, as on the JVM.
  - Closing the console: the handler waits, so that the shutdown hooks run before
    Windows ends the process.
  - A build's log file that another build in the same directory holds open is left
    in place.

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
