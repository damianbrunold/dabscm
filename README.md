# dabscm

A Scheme R7RS interpreter with parallel implementations in C# (.NET 8) and
Java 11. The two implementations share a common `library.scm` and a common
set of `.sld` library files, kept in sync from a single source of truth.

## Features

- R7RS-small core
- Bytecode VM (tokenizer → compiler → VM) mirrored in C# and Java
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
- `documentation/` — generated API documentation
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

# Update documentation (needs an up-to-date scm-java/scm.jar)
./builder.sh update-documentation.scm

# Full rebuild: sync, build+test both, regenerate documentation
./builder.sh rebuild-all.scm
```

Do not run the C# and Java test suites in parallel — they share files and
directories in the temp folder and will collide.

Requirements:
- .NET 8 SDK (`dotnet`)
- JDK 11 or later (`java`, `javac`, `jar`)

## Running

After building, the C# executable is `scm` and the Java jar is `scm.jar`.

```bash
scm -e 'CODE'       # eval CODE with minimal imports
scm -b 'CODE'       # eval CODE with no imports (useful for debugging base)
scm -f 'CODE'       # eval CODE with full REPL imports
scm script.scm      # run a script (in `user program`, no auto-imports)
scm                 # start a REPL (in `user main`, REPL auto-imports)
```

## License

MIT — see [LICENSE](LICENSE). Third-party code and academic influences are
documented in [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
