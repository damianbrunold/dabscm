# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

dabscm is a Scheme R7RS interpreter with dual implementations in C# (.NET 8)
and Java (11). The two implementations share a single `library.scm` and a
single set of `.sld` library files, kept in sync from a source of truth.

## Build Commands

```bash
# Sync library and test files from source-of-truth to both implementations
./builder.sh update-scheme-files.scm

# Full C# build + test
./builder.sh build-and-test-scm-csharp.scm

# C# only build
./builder.sh build-scm-csharp.scm

# C# only test
./builder.sh test-scm-csharp.scm

# Full Java build + test
./builder.sh build-and-test-scm-java.scm

# Java only build
./builder.sh build-scm-java.scm

# Java only test
./builder.sh test-scm-java.scm

# Update documentation (requires an up-to-date scm-java/scm.jar)
./builder.sh update-documentation.scm

# Full rebuild: sync all files, build and test both, update documentation
./builder.sh rebuild-all.scm
```

Never run C# and Java build/tests in parallel: the tests use the same files/directories in the temp folder and running them in parallel may lead to test failures.

The build system is Scheme-based: `builder.sh` calls `java -jar scm-bootstrap.jar` which executes `.scm` build scripts.

## Library Source of Truth

**Always edit `.sld` and `library.scm` files in `scm-lib/`** — never directly in the implementation directories. After editing, run `update-scheme-files.scm` to sync to both:
- C#: `scm-csharp/scheme/`
- Java: `scm-java/src/main/scheme/`

Tests live in `scm-tests/` and are similarly synced.

## Architecture

The interpreter is a **bytecode VM** with three layers:

1. **Tokenizer → Compiler → VM** pipeline (mirrored in C# and Java)
2. **Module system**: `scm core` (all C# primitives auto-bound + `library.scm`) is the bootstrap module. R7RS libraries (`scheme base`, `scheme char`, etc.) and custom extensions (`scm list`, `scm string`, etc.) are `.sld` files loaded on demand.
3. **User namespaces**: `user main` (REPL, many auto-imports) vs `user program` (scripts, no auto-imports)

Key C# files in `scm-csharp/scheme/`:
- `Expander.cs` — expands macros using sets-of-scopes algorithm
- `Compiler.cs` — compiles Scheme to bytecode
- `Primitives.cs` — 150+ built-in C# primitives
- `Modules.cs` — module/library system
- `VM.cs` — stack-based virtual machine
- `Tokenizer.cs` — lexer
- `Opcode.cs` — VM instruction set
- `SyntaxObject.cs`, `SyntaxRulesTransformer.cs` — macro system

Parallel Java files are in `scm-java/src/main/scheme/`.

Always try to do changes in parallel for C# and Java, as much as possible. Try to prevent the further divergence of the code bases.

Use only features from .NET 8 and Java 11.

## Critical Invariants

- `library.scm` (scm core) must contain: `*module-search-path*` (looked up directly by `ModulePath.cs`).
- `(%primitive "name")` accepts both symbols and strings.

## Preferred libraries

When writing code, prefer (scheme ...) and (srfi ...) libraries. E.g. instead
of using (scm list) use (srfi 1), instead of (scm string) use (srfi 13).

## Tests

~4500 test assertions across suites in `scm-tests/`, organized into three categories:

**Core tests** (`scm-tests/core/`):
- `tests_r7rs.scm` — R7RS conformance (priority for R7RS features)
- `tests_tspl3ed.scm` — TSPL3 examples
- `tests_general.scm` — general Scheme features, control flow, string utilities
- `tests_compiler.scm` — bytecode optimization and compiler correctness
- `tests_library.scm` — module system and import specifications
- `tests_syntax_rules.scm` — syntax-rules and macro hygiene
- `tests_srfi_64.scm` — SRFI 64 test framework tests

**Additional tests** (`scm-tests/tests/`):
- SRFI conformance: `tests_srfi_{1,2,13,14,18,19,26,28,39,69,95,98,111,125,128,132,133,151,158}.scm`
- Feature tests: `tests_bignum.scm`, `tests_chibi_r7rs_tests.scm`, `tests_crypto.scm`, `tests_excel.scm`, `tests_glob.scm`, `tests_match.scm`, `tests_net.scm`, `tests_odf_spreadsheet.scm`, `tests_odf_writer.scm`, `tests_terminal.scm`, `tests_word.scm`

**Failure tests** (`scm-tests/failures/`):
- Output-comparison tests (`.scm` + `.expected` pairs) for error handling: call stacks, macro errors, import errors, eval errors

## Manual tests

A good way to perform manual tests is using the -e and -b options:

- `scm -e 'some code'` executes the scheme code 'some code' in a REPL using minimal imports (only (scheme base) and (scheme write)).
- `scm -b 'some code'` executes the scheme code 'some code' in a REPL using no imports at all. This is very useful if the base library has a problem.
- `scm -f 'some code'` executes the scheme code 'some code' in a REPL using the full REPL imports.

Here scm is an alias for the scm-csharp executable. In analogy, scmj would be an alias for the scm-java executable.

## Documentation

The API is documented using info() member functions (for primitives) and
docstrings (for lambdas and defmacros). If you add new functions or macros
always add documentation too. Look to other documentation for format and
contents.
