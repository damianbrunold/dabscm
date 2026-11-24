# dabscm native

dabscm native is a third implementation of dabscm, next to the Java and C# ones. It
compiles a Scheme program, together with every library it imports, into one native
executable. The executable needs no JVM, no .NET and nothing else installed. It uses the
same `scm-lib` libraries as the other implementations, and the same `scm-tests` test it.

- **Compiling:** the compiler `scmc` turns the program into Zig source code and has the
  pinned Zig 0.17.1 compile and link it. On Linux the result is a static executable, so it
  runs on any Linux of that architecture.
- **Speed:** programs typically run 3 to 70 times faster than on the JVM with its JIT (see
  [Performance](#performance)).
- **Coverage:** R7RS and the scm libraries, including threads, sockets, TLS, HTTP, `eval`
  and the REPL. The differences from the JVM are listed under
  [Differences from the JVM implementation](#differences-from-the-jvm-implementation).

Contents:

1. [Getting started](#getting-started)
2. [Compiling programs with scmc](#compiling-programs-with-scmc)
3. [Cross-compiling](#cross-compiling)
4. [scm-native: the REPL and interpreter](#scm-native-the-repl-and-interpreter)
5. [Debian packages of programs](#debian-packages-of-programs)
6. [Differences from the JVM implementation](#differences-from-the-jvm-implementation)
7. [Platforms](#platforms)
8. [Development](#development)
9. [How it works](#how-it-works)
10. [Performance](#performance)

## Getting started

There are two ways to get the compiler: install the `dabscm-native` package, or run
`scmc` from this repository. Both compile the same way.

### From the package (Debian and Ubuntu, x86-64)

```sh
./builder.sh package-deb-native.scm        # in the repository root -> dist/dabscm-native_<VERSION>_amd64.deb
sudo apt install ./dist/dabscm-native_<VERSION>_amd64.deb
```

The package installs three commands:

| command | what it is |
|---|---|
| `scmc` | the compiler |
| `scm-native` | the native `scm`: a REPL, scripts, `-e`, `fmt` and `lint` |
| `scmc-deb` | packages a compiled program as a `.deb` |

It also installs the libraries, the runtime sources and Zig 0.17.1 under
`/usr/lib/dabscm-native` (about 400 MB). It can be installed next to the Java package
`dabscm`, which provides `/usr/bin/scm`.

### From the repository

You need Zig 0.17.1: unpack `zig-x86_64-linux-0.17.1` from ziglang.org/download, then put
it on the PATH or point `SCM_NATIVE_ZIG` at its `zig`. `zig version` must print `0.17.1`. The
compiler then runs on the Java or C# `scm`:

```sh
scm scm-native/scmc.scm hello.scm -o hello
```

To build the compiler itself as a native program (`-I` adds the compiler's own library
directory):

```sh
scm scm-native/scmc.scm scm-native/scmc.scm -I scm-native/compiler -o scm-native/build/scmc
scm scm-native/scmc.scm scm-native/tools/scm.scm -o scm-native/build/scm
```

A native `scmc` compiles a program with cached libraries in about a second, against about a
minute for `scmc` on the JVM. It finds the rest of `scm-native` through `SCM_NATIVE_DIR`, or
else as the parent of the directory its executable is in.

### A first program

```scheme
;; hello.scm
(import (scheme base) (scheme write) (scheme process-context))
(display "hello from ")
(display (car (command-line)))
(newline)
```

```sh
scmc hello.scm            # -> ./hello (-o names the executable)
./hello
```

The first compilation takes a few minutes. It compiles the runtime and every library the
program uses into objects, and later compilations reuse them. After that, compiling takes a
second or two, and a library is compiled again only when its source changes.

scmc usually prints a warning like this:

    scmc: warning: primitives not implemented in dabscm native yet: ... datum->syntax ...

The core library refers to these procedures, so almost every program gets the warning. It
matters only if the program calls one of them; that call is an error at run time.

## Compiling programs with scmc

```
scmc program.scm [-o output] [-O mode] [--target triple] [--strip] [-I dir]... [--emit-zig]
```

| option | meaning |
|---|---|
| `-o output` | the executable; the default is the program's name without `.scm` |
| `-O mode` | `ReleaseFast` (default), `ReleaseSafe` (Zig's safety checks in the runtime) or `Debug` |
| `--target triple` | cross-compile, see [Cross-compiling](#cross-compiling) |
| `--strip` | no debug information (for example hello: 3.6 MB instead of 22 MB) |
| `--cpu cpu` | a Zig CPU name: `native` (this machine) or `x86_64_v3`, ... The default is the target's baseline, which runs on every CPU of the architecture. `--cpu native` can be much faster for crypto: PBKDF2 with SHA-256 takes 117 ms instead of 716 ms with the SHA instructions (the JVM: about 200 ms) |
| `-I dir` | also search `dir` for libraries (repeatable) |
| `--emit-zig` | print the generated Zig instead of building |

**What gets compiled:** the program and every library it imports, directly or indirectly.
`scmc` finds each library at compile time and compiles it into the executable, so the
executable needs no library sources. A library `(app util)` is the file `app-util.sld`
or `app-util.scm`, as on the JVM. `scmc` searches these directories, in this order:

1. the program's directory
2. the `-I` directories
3. `scm-lib/libraries`, then the compiler's directory and `scm-native/lib` (the native
   implementations of a few libraries, such as `(scm native http)`)

So a project with its libraries next to the program, or in a `src` directory, compiles with
`scmc main.scm -I src`.

**Programs behave as on the JVM:**
- `command-line` and `exit` work as there, as do standard input and output, the
  environment, and the exit code of an uncaught error (with the JVM's message).
- **Exit code:** if the program's last form gives an integer, that is its exit code, as for
  `scm script.scm`; `set-exit-code!` takes precedence.
- **`script-name` and `script-arguments`** are bound: the executable and its arguments.
- **When libraries start:**
  - the libraries of the imports before the program's first definition or expression start
    before the program;
  - a library first imported later starts at that import, as on the JVM. So code before an
    import, such as loading a configuration or setting a value, is seen by the libraries
    that import brings in.
- Native `cond-expand` has the feature `dabscm-native`, along with the target's features:
  `gnu-linux`, `windows` or `darwin`, `unix` (Linux and macOS), `x86-64` or `arm64`, and the
  JVM's SRFI features.

**Environment variables used by `scmc`:**

| variable | meaning |
|---|---|
| `SCM_NATIVE_ZIG` | the `zig` to use. Default: the Zig an installation bundles, else `zig` on the PATH |
| `SCM_NATIVE_BUILD` | the build directory (objects, generated Zig, Zig's cache). Default: `scm-native/build` if writable, else `$XDG_CACHE_HOME/dabscm-native` (`~/.cache/dabscm-native`; `%LOCALAPPDATA%` on Windows) |
| `SCM_NATIVE_DIR` | the `scm-native` directory, for the native `scmc` and `scm` (the package's commands set it) |
| `SCM_NATIVE_CACHE_MB` | the size the objects of the build directory are kept to (default 4096; see below) |

Each version of a library and each target has its own objects, so every change of the
compiler or the runtime leaves the earlier ones behind. After a link, the objects it used are
marked as used, and at most once an hour the build directory is cleaned up: objects unused for
14 days are deleted, then the least recently used ones while the objects take more than
`SCM_NATIVE_CACHE_MB` MB (never one used within the last hour, which another compilation may be
about to link), the generated Zig sources whose object is gone, and Zig's cache of parsed
files (`zig-cache/z`) in the same way, kept to a quarter of that size. Deleting the directory
is safe; it only costs recompilation.

**Environment variables of compiled programs**, for debugging the runtime:

| variable | meaning |
|---|---|
| `SCM_NATIVE_GC_STATS=1` | at exit (also through `exit`): the numbers of collections, the old space and how much of it is used, large objects, the threads' nurseries and stacks, ended threads not yet freed, the ports and their buffers, the native objects; at each major collection the old space's size |
| `SCM_NATIVE_GC_VERIFY=1` | check for missing write barriers before each minor collection (slow) |
| `SCM_NATIVE_GC_STRESS=words[,major]` | GC stress mode (see [GC stress tests](#gc-stress-tests)): a collection after every `words` words allocated, every `major`th one major (default 100), dead memory poisoned |
| `SCM_NATIVE_SEGV=1` | a stack trace on a crash |
| `SCM_TLS_INSECURE=1` | no TLS certificate verification |
| `SSL_CERT_FILE` | the trusted CA certificates (default: the system's) |
| `SCM_TDS_DEBUG`, `SCM_SQL_BROWSER_PORT` | as on the JVM |

## Cross-compiling

`--target` builds for another system or architecture, from any host:

| target | result |
|---|---|
| `x86_64-linux-musl` | Linux x86-64, static (the default on Linux) |
| `aarch64-linux-musl` | Linux arm64, static (Raspberry Pi OS 64-bit, arm64 servers) |
| `x86_64-windows` | Windows x86-64 (`.exe`, name it with `-o app.exe`) |
| `aarch64-macos`, `x86_64-macos` | macOS on Apple silicon or Intel |

On a Windows or macOS host, the default target is that host.

An arm64 Linux executable can be run on x86-64 Linux with qemu (`sudo apt install
qemu-user`):

```sh
scmc app.scm -o app-arm64 --target aarch64-linux-musl
qemu-aarch64 ./app-arm64
```

## scm-native: the REPL and interpreter

`scm-native` (in the repository, `scm-native/build/scm`, built from `tools/scm.scm`) is
`scm` as a native program:

```sh
scm-native                     # the REPL: line editing, history in ~/.dabscm-history
scm-native -e '(+ 1 2)'        # print the value of an expression
scm-native script.scm arg ...  # run a script; it is interpreted, not compiled
scm-native fmt|lint|new-app    # the built-in tools, as on the JVM
```

The common libraries are compiled into it, so they load instantly. A script that imports
another library loads it from source and interprets it, which is slower than the JVM's JIT
for heavy work. A program that should run fast is better compiled with `scmc`.

`eval`, `environment` and `load` work in compiled programs too, through the same
interpreter. A program that imports `(scheme eval)` gets the expander compiled in. Libraries
it links are its own compiled ones. Libraries it does not link are loaded from source, over
the search path it was compiled with, or from the installation's `scm-lib` (`SCM_NATIVE_DIR`).

`load` without an environment evaluates in the program's own module, as on the JVM. So a
configuration file read with `(load "config.scm")` sets the program's variables: the
compiled program sees `(define db-host ...)` from the file as its own `db-host`. Inside code
that `eval` runs (a script interpreted by `scm-native`), `load` uses that code's environment.

## Debian packages of programs

`scmc-deb` (in the repository: `scm scm-native/tools/package-deb.scm`) packages a compiled
program:

```sh
scmc app.scm -o build/app --strip
scmc-deb --exe build/app --name app --version 1.0 \
    --description "one line" [--long "more text"] [--maintainer "Name <mail>"] \
    [--depends "pkg, pkg"] [--section utils] [--homepage url] \
    [--file src /usr/share/doc/app/README [mode]] ... [--out dist]
sudo apt install ./dist/app_1.0_amd64.deb
```

- **What it installs:** the program as `/usr/bin/<name>`; `--file` adds further files, with
  the destination as an absolute path and the mode in octal (default 644).
- **Package name:** `<name>_<version>_<arch>.deb`.
- **Architecture:** read from the executable, so a program compiled with `--target
  aarch64-linux-musl` gives an arm64 package.
- **Dependencies:** the executables are static, so `--depends` is needed only for other
  programs the application runs.

### Web applications

The web applications packaged with `(scm deb webapp)` (a `package-deb.scm` calling
`webapp-deb-main`) get a native package with `--native`:

```sh
scm package-deb.scm --native                       # scmc.scm of ../dabscm on scm
scm package-deb.scm --scmc /usr/bin/scmc           # the dabscm-native package's scmc
scm package-deb.scm --target aarch64-linux-musl    # an arm64 package
```

- **Programs:** every program in `bin/` (as the JVM package ships them) is compiled with
  `scmc --strip -I src` into `/opt/<pkg>/app/bin/<name>`, next to its source, so it finds
  the app's files as the script does.
- **No Java:** there is no `scm.jar` and no Java dependency. `/opt/<pkg>/bin/scm` runs the
  native program for `bin/<name>.scm`, so the app's systemd units, `<pkg>-admin` and the
  generated secret work unchanged.
- **Architecture:** taken from the executables, as in `<pkg>_<version>_amd64.deb`. Both
  packages use the same name, so one replaces the other.

dabplanner, for example, is a 7.7 MB package (20 MB installed); the JVM package is 2 MB but
needs a Java runtime.

## Differences from the JVM implementation

- **Strings hold Unicode code points:**
  - a character outside the BMP, such as `#\x1F600`, is one character (two UTF-16
    characters on the JVM);
  - JSON's `😀` reads as one character;
  - `char-foldcase` is Unicode simple case folding.
- **A program is compiled as a whole,** as R7RS defines programs. The JVM runs a program
  one top-level form at a time. So a continuation captured in a top-level form continues
  with the rest of the program here, but ends with that form on the JVM.
- **Regular expressions** support only the subset that java.util.regex and .NET have in
  common; patterns outside it are rejected, so a program does not depend on one host's
  dialect.
- **Not available:**
  - bytecode introspection: `(scm compile)`, `disassemble`, `compile`;
  - the syntax-object procedures `datum->syntax`, `syntax->datum`, `identifier?`,
    `generate-temporaries`, `bound-identifier=?` and `free-identifier=?`;
  - `current-module`.
- **Minor differences:**
  - `string->number` reads complex numbers;
  - the gzip reader's message for a truncated stream is "Unexpected end of ZLIB input
    stream".

Everything else should behave as on the JVM: values, printing, error messages (`Failed in
car: wrong argument type`), threads (SRFI 18, with JVM semantics), the HTTP server, and file
and process functions. A difference not listed here is a bug.

## Platforms

| platform | state |
|---|---|
| Linux x86-64 | the main platform; all tests |
| Windows 11 x86-64 | all tests, the native `scmc` and `scm`, and the REPL in a console (2026-11-23) |
| Linux arm64 | the test suites under qemu (2026-11-23) |
| macOS (arm64, x86-64) | cross-compiled only, not run yet |

On every tested platform, the library tests are clean in 110 of 111 files (`tests_geiser`
needs `current-module`). The core tests fail only in `tests_compiler` (bytecode
introspection), `tests_tspl3ed` (1 test) and `tests_vm` (1 test).

Windows notes:
- `.exe` names: pass `-o app.exe`.
- Ctrl+C and closing the console window are SIGINT and SIGTERM, for
  `server-install-shutdown-hook`.
- `directory-name` makes paths absolute as the JVM does there (the current drive, `\`
  separators).
- TLS uses the system's certificate store.

### Testing on another machine (Windows or macOS)

1. Install Zig 0.17.1 for the machine (`zig-x86_64-windows-0.17.1` or
   `zig-aarch64-macos-0.17.1` from ziglang.org/download) and put `zig` on the PATH.
2. On that machine, `scmc` runs on the Java or C# `scm` there: `scm scm-native/scmc.scm
   prog.scm -o prog.exe`. Try hello first, then a program with threads, then one with
   sockets.
3. Run the suites: `cd scm-native && scm lib-tests.scm` and `scm core-tests.scm`. Compare
   the results with [Platforms](#platforms).
4. On macOS, the parts never run yet are `os_macos.zig` (libproc) and the TLS certificate
   store (std's keychain scan).

## Development

### Tests

Run from `scm-native`, with `scmc` on the JVM:

```sh
scm test.scm [name ...]          # tests/*.scm: output and exit code against the JVM's
scm core-tests.scm [tests_r7rs ...]
scm lib-tests.scm [tests_scm_string ...]
scm lib-tests.scm --target aarch64-linux-musl --run-with qemu-aarch64   # arm64 under qemu
```

- **`core-tests.scm`** runs `scm-tests/core` with the JVM harness's assertions
  (`SchemeTests.runCoreTest`). It emulates the JVM's form-by-form evaluation for
  continuations.
- **`lib-tests.scm`** runs each file in `scm-tests/tests` as a program, in the tests
  directory, as `SchemeTests.runTestsTest` does. It prints the tests and failures of each
  file and keeps the executables of failing files only.
- **`--target` and `--run-with`** (both scripts) cross-compile and run the executables
  under a command such as qemu.
- **`--gc-stress spec`** (all three scripts) runs the executables in the GC stress mode,
  and **`-O mode`** (`core-tests.scm`, `lib-tests.scm`) builds them in another mode, for
  example `ReleaseSafe` (see [GC stress tests](#gc-stress-tests)).

The library tests compile about 125 programs, each about 95 MB with debug information. Run
them from a copy of the tree (for example `rsync` `scm-lib`, `scm-tests`, `VERSION` and
`scm-native` without `build` into `scm-native/build/snap`), so that edits made during a run
do not change it. Don't run them in `/tmp` if it is a tmpfs.

Native-only changes to `scm-lib` or `scm-tests` go behind `cond-expand (dabscm-native ...)`;
the Java and C# suites must still pass.

### Soak tests

```sh
scm soak.scm [name ...]                          # soak/*.scm, 10 rounds each
scm soak.scm --target x86_64-linux-gnu           # with the C allocator's bytes in use
scm soak.scm --rounds 40 --scale 4 -O ReleaseSafe sockets
```

Each scenario in `soak/` (sockets, HTTP, threads, processes, ports, JSON/XML/zip and the
other native objects, errors and `eval`, allocation) runs rounds of work that drops what it
makes, often without closing it. After each round a major collection runs (the native-only
primitive `gc-collect`), then a sample: the live heap, ports, native objects, threads (from
`gc-statistics`), open file descriptors and resident memory (Linux `/proc`). After three
warm-up rounds nothing may grow beyond a small limit, and the heap, the counts and the C
allocator's bytes may not grow in nearly every round (a small leak).

Built for glibc (`--target x86_64-linux-gnu`) the samples include `malloc-bytes`, the C
allocator's bytes in use (`mallinfo`). That tells a leak from fragmentation: the resident
memory shows both. musl's allocator (the default target) fragments more under some
patterns: freeing a file port's buffer at a collection while small allocations land in its
slot grew the resident memory without a leak.

### Differential tests

`difftest.scm` runs random cases on the JVM, C# and natively and compares the results:

```sh
scm difftest.scm [--seed n] [--time secs] [--rounds n] [--cases n] [numbers|reader|strings ...]
```

- **Cases** come from generators (numbers: arithmetic, conversion and printing on every kind
  of number; reader: random texts read to the end; strings: case mappings, comparisons,
  UTF-8, characters) and a seed; round k uses seed + k.
- **A value against an error, or different values,** is a divergence; errors with different
  messages are minor. An implementation that dies is reported for its case, and the rest run
  again.
- **The report,** `build/difftest/report-<seed>.txt`, groups the divergences by operation
  and pattern with a few examples each. On a disagreement R7RS decides first, then the JVM.

### GC stress tests

```sh
scm test.scm --gc-stress 100
scm core-tests.scm --gc-stress 100
scm lib-tests.scm --gc-stress 0,1000 tests_scm_json   # at every allocation
```

The collector is precise and moves objects, so a heap pointer the runtime holds in a Zig
local across an allocation, or an object it registers before allocating its heap object,
works until the allocation happens to collect. `SCM_NATIVE_GC_STRESS=words[,major]` makes
that happen everywhere: a collection after every `words` words allocated (0: at every
allocation check that allocates), every `major`th collection a major one (default 100;
1: all, which also moves every old object every time). After each collection the memory of
the dead nursery objects and flonums is poisoned (`0xdeaddeaddeaddeee`, a header of no
type), and allocation goes on above it instead of at the start of the nursery, so that a
stale pointer finds poison rather than a new object. The collector stops the program with
"gc stress: a pointer to a dead object" when it reaches one; a primitive that reads one sees
a value of no type. The old space a major collection leaves is poisoned before it is freed.

Minor collections are cheap; major ones copy the live data, so `major` sets most of the
cost: with `100`, `tests/gc.scm` takes 0.9 s instead of 0.02 s, and the library suite
runs about an hour; `0,1000` is thorough and slower. The scripts give the stress mode 20
times the normal timeout.

When the collector reaches a stale pointer it also says what it pointed to: the dead
object's type, and whether that collection copied it (a stale pointer to a live object) or
found it garbage (an object only the runtime held), and the object that held the pointer.

The stress mode found:

- opening a port registered the port with the collector before its port object was
  allocated, so a collection at that allocation freed the port (`tests/portgc.scm`);
- the port operations were leaf primitives, which compiled code calls directly while it
  keeps objects in locals, as for a call that never collects; on a socket port they can
  block, and another thread's collection then moved those objects (`tests/blockleaf.scm`).
  They are ordinary primitives now (about 10% slower in a loop of string port operations);
- `read-bytevector!` and `socket-close` used a heap object they had read before a socket
  operation that can block.

### Generated files

- `runtime/unicode.zig`: `tools/gen-unicode.scm`, from the Unicode Character Database.
- `runtime/library_exports.zig`: `tools/gen-library-exports.scm` on the JVM; regenerate it
  when library exports change.
- `runtime/primitive_docs.zig`: `tools/gen-primitive-docs.scm` on the JVM; regenerate it
  when primitives change.

### The dabscm-native package

`package-deb-native.scm` in the repository root:

```sh
./builder.sh package-deb-native.scm [--out dir] [--zig dir] [--no-build] [--allow-dirty]
```

- **What it builds:** `scmc`, `scm` and `scmc-deb`, stripped, into
  `scm-native/build/package` (`--no-build` packages those already there). It bundles the
  Zig from `--zig` (default `~/zig-x86_64-linux-0.17.1`).
- **Uncommitted changes:** a tree with them is refused unless `--allow-dirty` is given.
- **Installed layout:**

```
/usr/bin/scmc, scm-native, scmc-deb     wrappers that set SCM_NATIVE_DIR
/usr/lib/dabscm-native/scm-native/      bin/ and the runtime, lib, compiler, vendor, tools sources
/usr/lib/dabscm-native/scm-lib/         the Scheme libraries
/usr/lib/dabscm-native/zig/             Zig 0.17.1
/usr/share/doc/dabscm-native/           copyright, this README
```

## How it works

### Pipeline

```
program.scm + libraries (.sld)
  reader, expander          (scm native expand), (scm native syntax): sets of scopes,
                            syntax-rules, define-library, cond-expand; library.scm is (scm core)
  Core IR                   (scm native ast)
  optimizer                 (scm native optimize): primitives, records, inlining, folding
  A-normal form             (scm native anf)
  Zig code                  (scm native emit): one object per library
  zig build-obj / build-exe (scm native driver): objects cached by content hash, then linked
```

The compiler is written in Scheme in `compiler/`. It runs on the JVM, or natively as the
native `scmc`.

### Build structure

- **The runtime is one object** (`runtime/rtmain.zig`). It exports the runtime functions,
  every primitive (`scmp_<name>`, `scmv_<name>` for values) and the C `main`.
- **Every library and the program are objects of their own.**
  - Each owns its globals as `scml_<module>_g` and exports `scml_<module>_init` (its
    constants) and `scml_<module>_entry` (its body).
  - The program object lists the modules in initialization order (`scm_program_modules`)
    and the special globals the runtime needs (`scm_program_specials`).
- **Compiled code imports only `runtime/abi.zig`:** the value representation, the thread
  (an `extern struct`), inline fast paths, and the runtime functions as `extern`.
- **Names are numbered per module,** so a library's Zig code is the same for every program
  that uses it, and its object is shared.
- **The Zig command line does not cache,** so `build/objects/` holds the objects under the
  hash of everything that goes into them. The driver builds them in parallel, one process
  per core.
- **A module of more than 4 MB of Zig is split** (`compiler/scm-native-split.sld`) into parts of
  about 2 MB, compiled in parallel: LLVM's time grows faster than the size of a module (8.7 s
  per MB at 3 MB, 24 s per MB at 15 MB). The functions go into the parts in their order; a
  name another part uses is exported under `scmx_<module>_<name>` and declared `extern` there.
  Only test programs are this large (chibi's R7RS tests: 15.6 MB, 8 parts, about 90 s
  instead of 300).
- **`zig build-exe` only links** the objects with libc (statically, for musl).

### The runtime (`runtime/`)

| file | contents |
|---|---|
| `rt.zig` | values, the thread, the collector, control, multiple values, errors |
| `data.zig` | strings (Latin-1 or UTF-32 buffers), symbols, vectors, bytevectors, records, equality |
| `num.zig`, `tower.zig` | arithmetic: fixnums, flonums, bignums (`std.math.big.int`), rationals, complex numbers |
| `printer.zig`, `reader.zig` | `write`/`display` with datum labels, `read` |
| `ports.zig`, `chars.zig`, `unicode.zig` | ports, character classes, Unicode tables |
| `prims*.zig` | the primitives, named `@"%name"` for the Scheme name |
| `regex.zig`, `compress.zig`, `zip.zig`, `image.zig` | regular expressions, deflate/zlib/gzip (vendored zlib 1.3.1), zip, the image codec |
| `net.zig`, `rsa.zig`, `aes192.zig`, `tds.zig` | sockets and TLS (`std.crypto.tls.Client`), RSA, AES-192, SQL Server |
| `prims_thread.zig` | SRFI 18 |
| `os.zig`, `os_windows.zig`, `os_macos.zig` | the OS layer, the only user of version-sensitive `std` APIs |
| `abi.zig`, `exports.zig`, `rtmain.zig` | the interface to compiled code, the runtime object's root and `main` |

`lib/` holds Scheme libraries with native implementations: HTTP and WebSockets
(`scm-native-http.sld`) and the thread helpers it uses (`scm-native-tasks.sld`).

### Values and control

- **Values are tagged 64-bit words:** fixnums (63 bits), heap pointers, immediates, and
  characters as code points. Heap objects have a header word holding the type and the
  length.
- **Scheme does not use the machine stack.** Every procedure and every return point is a
  Zig function `fn (*Thread) callconv(.c) void`. Control passes with
  `@call(.always_tail, next, .{t})`, so tail calls are proper, there is no trampoline, and
  deep recursion only grows the Scheme stack.
- **Frames and allocation:**
  - A non-tail call saves the live values in a frame on the Scheme stack, and continues in
    a return block.
  - Each block reserves its heap words at its entry, so the collector never has to find
    Zig locals.
- **`call/cc`** copies the stack. A receiver that only calls its continuation directly
  gets an escape continuation, which cuts the stack back to a marker instead.
- **The optimizer and emitter:**
  - known calls jump directly to their code;
  - leaf primitives (`car`, `string-ref`, `display`, ...) are direct Zig calls;
  - hot primitives and record operations are open-coded;
  - named-`let` loops without non-tail calls become Zig `while` loops;
  - small global procedures are inlined across libraries.

### Memory

- **The collector is generational.** Each thread has a nursery of 8 MB; compiled code
  bump-allocates in it.
- **Minor collections** promote survivors into the old space. A write barrier keeps a
  remembered set of old objects that point into a nursery.
- **Major collections** copy everything live into a new old space, and sweep the
  large-object space (bignums, big vectors and strings).
- **All nurseries come from one reserved address range,** so "young" is one range check.
- **The old space** is kept at one and a half times the live data after a major collection
  (plus room for the nurseries); it shrinks again after a peak.
- **Native memory:** ports are freed when a collection finds their port object unreachable
  (a major collection, and a minor one for ports made since the last collection); a closed
  port frees its buffers at once. The reader's intermediate nodes and the temporary UTF-8
  copies of primitives use arenas that are reset after each datum or primitive call.
- **Native objects** (sockets, listeners, processes, file locks, zips, JSON and XML
  readers and objects, random-access files, the control structures of SRFI 18 threads,
  mutexes and condition variables) are freed the same way: a registry of records, marked
  when a collection reaches the object, finalized when it does not. Finalizers do not
  block: a socket is closed without flushing (as the JVM's cleaner drops what an
  unreachable stream holds), a running process is left running (only an ended one is
  freed), a mutex a running thread holds stays. A socket's ports live in slots of the
  socket object; the connection is freed when the socket and its ports are all gone, so a
  port kept without its socket still works. A JSON reader's tokens and objects are in one
  arena, freed when the reader and every object read from it are gone.

### Threads

- **Every SRFI 18 thread is an OS thread,** with its own nursery, Scheme stack and
  registers. Globals and the old space are shared, so a `set!` of a global is seen by every
  thread.
- **Semantics as on the JVM:**
  - mutexes are abandoned when their owner ends;
  - condition variables;
  - `thread-join!` with timeouts;
  - `thread-terminate!` ends the thread at its next procedure entry or loop head;
  - parameter objects have a value per thread;
  - threads are daemons.
- **Collections stop the world:**
  - every procedure entry and loop head is a safepoint;
  - a thread in a blocking call (a read, accept, sleep, or wait) counts as stopped.
- **The HTTP server** serves each connection on a thread, with `max-threads` at once,
  `max-queued` waiting and 503 beyond, as the JVM's pool.

### eval

`(scheme eval)` and `(scheme load)` are `(scm native eval)` natively: the expander, and a
closure-generating interpreter over Core IR whose procedures are ordinary procedures of the
program.
- **The expander state:** the compiler embeds it in the program (the libraries with their
  exports, globals and macros), so `eval` expands code against the linked libraries
  without their sources.
- **No cost otherwise:** programs without `eval` carry none of this.

## Performance

`bench/bench.scm`, per run: the JVM implementation with the JIT after warm-up, against
native, on x86-64 Linux. Times vary between runs by 10 to 20%.

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

Other measurements:
- **Tools:** native `scm fmt --diff` over the repository takes 3.5 s (about a minute on the
  JVM), and native `scm lint` over `scm-lib` 1.3 s (16 s).
- **Threads:** eight threads doing JSON, regular expressions, hash tables and bignums run
  about 6.5 times faster than on the JVM.

Startup takes about 1.5 ms for hello, against about 0.8 s on the JVM.

`spike/` holds the Phase 0 experiment that chose this model (hand-written Zig in the shape
the compiler emits). The implementation's history is in the git log (`git log --
scm-native`).
