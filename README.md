# dabscm

A Scheme R7RS interpreter with parallel implementations in C# (.NET 10) and
Java 11. The two implementations share a common `library.scm` and a common
set of `.sld` library files, kept in sync from a single source of truth.

## Features

- R7RS-small core
- Bytecode VM (tokenizer → compiler → VM) mirrored in C# and Java
- A JIT that compiles hot procedures to JVM bytecode or .NET IL
- Module system with `scheme` (R7RS) and `scm` (extensions) libraries
- 22 SRFI implementations (1, 2, 8, 9, 13, 14, 18, 19, 26, 28, 39, 64, 69,
  95, 98, 111, 125, 128, 132, 133, 151, 158)
- Sets-of-scopes hygienic macro expander (Flatt, POPL 2016)
- ~4500 test assertions across R7RS, SRFI, and feature suites

## Layout

- `scm-lib/` — source of truth for `library.scm` and `.sld` library files
- `scm-tests/` — source of truth for tests (`core/`, `tests/`, `failures/`)
- `scm-csharp/` — C# implementation (`scheme/`, `repl/`, `tests/`)
- `scm-java/` — Java implementation
- `scm-native/` — native implementation: compiles programs to Zig and static executables (see `scm-native/README.md`)
- `documentation/` — generated API documentation (site, Word, Markdown) and the
  [tutorials](documentation/tutorials/README.md): Scheme basics, techniques
  and library guides, whose examples are run by the test suites
- `examples/` — example scripts
- `scm-bootstrap.jar` — bootstrap interpreter used by the build scripts

## Building

The build system is Scheme-based: `builder.sh` (or `builder.bat`) runs
`java -jar scm-bootstrap.jar` against a `.scm` build script.

```bash
# Sync library and test files from source-of-truth to both implementations
./builder.sh update-scheme-files.scm

# C#: build / test / build+test
./builder.sh build-scm-csharp.scm
./builder.sh test-scm-csharp.scm
./builder.sh build-and-test-scm-csharp.scm

# Java: build / test / build+test
./builder.sh build-scm-java.scm
./builder.sh test-scm-java.scm
./builder.sh build-and-test-scm-java.scm

# Native: scmc and scm in scm-native/build (needs Zig 0.17.1)
./builder.sh build-scm-native.scm           # compiler on scm-java/scm.jar
./builder.sh build-scm-native.scm --native  # compiler is the native scmc already built
./builder.sh build-scm-native.scm scmc      # only scmc (or scm); also --strip, -O mode

# Update documentation (needs an up-to-date scm-java/scm.jar)
./builder.sh update-documentation.scm

# Full rebuild: sync, build+test both, regenerate documentation
./builder.sh rebuild-all.scm
```

Do not run the C# and Java test suites in parallel — they share files and
directories in the temp folder and will collide.

Requirements:
- .NET 10 SDK (`dotnet`)
- JDK 11 or later (`java`, `javac`, `jar`)

### Debian package

```bash
./builder.sh build-and-test-scm-java.scm
./builder.sh package-deb-java.scm         # -> dist/dabscm_<VERSION>_all.deb
sudo apt install ./dist/dabscm_<VERSION>_all.deb
```

The package installs `/usr/bin/scm` (JVM options via `SCM_JAVA_OPTS`),
`/usr/share/dabscm/scm.jar` and the HTML documentation under
`/usr/share/doc/dabscm/html`, and pulls in a headless Java runtime. It
conflicts with Debian's unrelated `scm` package (same command name). The
builder (the `(scm deb)` library) is pure Scheme and needs no `dpkg-deb`. A tree with
uncommitted changes is refused unless `--allow-dirty` is given (version gets
`+dirty`); `--out <dir>` changes the output directory.

The HTML documentation has a package of its own, for publishing it on a web
server:

```bash
./builder.sh update-documentation.scm     # regenerate documentation/site, then commit
./builder.sh package-deb-docs.scm         # -> dist/dabscm-docs_<VERSION>_all.deb
sudo apt install ./dist/dabscm-docs_<VERSION>_all.deb
```

It installs the committed `documentation/site` under `/var/www/dabscm`
(`--root <dir>` for another directory); an upgrade replaces the site and
removes pages that no longer exist. The web server is configured separately,
for example in nginx `location /dabscm/ { alias /var/www/dabscm/; }`.
`--out` and `--allow-dirty` work as for the other packages.

The native implementation has a package of its own, which can be installed next
to the Java one:

```bash
./builder.sh package-deb-native.scm       # -> dist/dabscm-native_<VERSION>_amd64.deb
sudo apt install ./dist/dabscm-native_<VERSION>_amd64.deb
```

It installs `scmc` (the compiler), `scm-native` (the native REPL and
interpreter, with fmt and lint), `scmc-deb` (packages a compiled program as a
`.deb`), the runtime sources and libraries under `/usr/lib/dabscm-native`, and
the Zig 0.17.1 that `scmc` compiles with (`--zig <dir>`, default
`~/zig-x86_64-linux-0.17.1`). It builds the three programs first (`--no-build`
packages those in `scm-native/build/package`). `scmc` keeps its objects in
`~/.cache/dabscm-native`; the first compilation of a program builds the
libraries it uses (a few minutes), later ones take seconds.

## Running

After building, the C# executable is `scm` and the Java jar is `scm.jar`.

```bash
scm -e 'CODE'       # eval CODE with minimal imports
scm -b 'CODE'       # eval CODE with no imports (useful for debugging base)
scm -f 'CODE'       # eval CODE with full REPL imports
scm script.scm      # run a script (in `user program`, no auto-imports)
scm                 # start a REPL (in `user main`, REPL auto-imports)
```

### Built-in tools

Besides scripts, `scm` runs a few tools written in Scheme and shipped in
the jar / executable (a script file of the same name takes precedence):

```bash
scm fmt src/            # format *.scm / *.sld files in place
scm fmt --check src/    # list files that would change (exit 1 if any)
scm fmt --diff app.sld  # show the changes as a unified diff
scm lint src/           # report problems as file:line:col: severity: [rule] message
scm lint --list-rules   # the rules and whether they are on by default
scm new-app ...         # a new application from a starter
```

`scm fmt` lays code out with Emacs scheme-mode indentation within 78
columns (`--keep-breaks` keeps the existing line breaks), sorts imports
((scheme ...), (srfi ...), (scm ...), others) and exports, and never
changes what the code reads as. `scm lint` checks unbound and unused
names, unused and conflicting imports, arity, malformed forms,
non-idiomatic code and the docstring conventions. Both read their
settings from the nearest `scm-tools.toml`; see `(scm source format)` and
`(scm source lint)` in the documentation.

### JIT

Both implementations compile a procedure to the platform's own code
(JVM bytecode, .NET IL) once the interpreter has called it 100 times; the
JVM or .NET JIT then compiles it like any other code. Long-running
programs (servers, large batch runs) gain the most, short runs hardly at
all. It is controlled by system properties (Java) or environment
variables (C#):

| Java | C# | |
|---|---|---|
| `-Dscm.jit=off` | `SCM_JIT=off` | interpreter only |
| `-Dscm.jit.threshold=0` | `SCM_JIT_THRESHOLD=0` | compile on the first call |
| `-Dscm.jit.stats=true` | `SCM_JIT_STATS=true` | print counters at exit |
| `-Dscm.jit.debug=true` | `SCM_JIT_DEBUG=true` | report compiled/rejected code |

```bash
java -Dscm.jit=off -jar scm.jar script.scm
SCM_JIT=off scm script.scm
```

The generated code is verified Java 11 class files, or IL in a dynamic
assembly, loaded by the platform's standard mechanisms. No native code
is generated by dabscm itself and no runtime flags are needed.

## License

MIT — see [LICENSE](LICENSE). Third-party code and academic influences are
documented in [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
