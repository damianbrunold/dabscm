## Overview

`(scm source lint)` is the static checker behind `scm lint`. It reads a
file with [(scm source)](scm-source.md) and walks the code with a scope
analysis that knows the core and derived forms of R7RS. The global
environment is what the file imports, with the exports of built-in
libraries loaded and project libraries read statically from their `.sld`
files (`[format] library-path` in `scm-tools.toml`, plus the file's own
directory), and the file's own definitions.

Uses of macros the linter does not know are not looked into: every
identifier in them counts as used and none is reported as unbound, so they
cause no false positives. When an imported library cannot be resolved, or
the file includes, loads or requires other files, unbound identifiers are
not reported. The names the compiler inlines (`car`, `cadr`, `+`,
`vector-ref`, ...) count as bound in call position without an import, as
they are at run time.

Findings are printed as `file:line:column: severity: [rule] message`.
Run `scm lint --list-rules` for the full list. The main groups are:

| Group | Rules |
|---|---|
| Errors | `read-error`, `unbound-identifier`, `export-undefined`, `duplicate-definition`, `set-imported`, `arity-mismatch` (procedures and records defined in the file), `malformed-form` |
| Imports | `unused-import` (also redundant imports, whose used names all come from another import), `unused-only-name`, `import-conflict`, `duplicate-import`, `unsorted-imports` |
| Names | `unused-local`, `unused-definition`, `unused-parameter` (off), `shadowed-import` (off), `duplicate-export`, `unsorted-exports` |
| Forms | `definition-context`, `duplicate-case-datum`, `unreachable-clause`, `eq-literal` |
| Idioms (info) | `if-boolean`, `if-without-else`, `nested-if`, `cxr`, `null-compare`, `length-zero`, `append-list`, `redundant-call`, `begin-single`, `empty-let`, `eta-lambda`, `define-lambda` (off), `predicate-naming` (off) |
| Conventions | `missing-docstring`, `docstring-syntax-mismatch`, `docstring-library-mismatch` (exported procedures of the `docstring-libraries`, default `(scm ...)`), `library-file-name` |
| Text (info) | `line-too-long` (long strings and comments are exempt), `trailing-whitespace`, `tab-character`, `missing-final-newline`, `not-formatted` (with `--fmt-check`) |

## Command line

```bash
scm lint src/                      # all *.scm and *.sld below src
scm lint --fail-on warning .       # CI: exit 1 on warnings too
scm lint --disable cxr,eta-lambda app.sld
scm lint --enable unused-parameter --format json src/ > lint.json
scm lint --fmt-check .             # also report files scm fmt would change
```

Other options: `--width N`, `--exclude GLOB`, `--quiet`, `--list-rules`.
Settings come from the `[lint]` table of `scm-tools.toml` (`enable`,
`disable`, `docstring-libraries`, `exclude`). Exit codes: 0 ok, 1 findings
at the `--fail-on` level (default `error`), 2 usage error.

## Suppressing findings

```scheme
;; lint: disable if-without-else cxr      ; for the whole file

(if done? (finish)) ; lint: ignore        ; every rule on this line

; lint: ignore unused-local               ; this rule on the next line
(let ((unused (setup!))) (run))
```

Names starting with `_` are never reported as unused.

## Common uses

```scheme
(import (scm source lint))

(define findings (lint-file "src/app.sld"))
(display (lint-findings->text findings))

(for-each (lambda (f)
            (when (eq? (lint-finding-severity f) 'error)
              (display (lint-finding-message f))
              (newline)))
          (lint-string "(import (scheme base))\n(car (cdr x))\n" "x.scm"))
```
