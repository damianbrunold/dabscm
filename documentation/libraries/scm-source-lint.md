# `(scm source lint)`

Static checker behind scm lint — bindings, imports, arity, idioms, conventions

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
`disable`, `docstring-libraries`, `definers`, `exclude`). Exit codes: 0 ok,
1 findings at the `--fail-on` level (default `error`), 2 usage error.

The linter does not expand macros it does not know. A project macro that
defines a name, like `(define-command (name args ...) ...)`, can be listed
in `definers`: the name given as its first argument, `name` or
`(name . args)`, then counts as defined in the library or body, so
exporting it is not reported by `export-undefined`. Such names are not
reported by `unused-definition`, since they are often only used by
reference, e.g. as quoted symbols.

## Suppressing findings

```scheme
;; lint: disable if-without-else cxr      ; for the whole file

(if done? (finish)) ; lint: ignore        ; every rule on this line

; lint: ignore unused-local               ; this rule on the next line
(let ((unused (setup!))) (run))
```

Names starting with `_` are never reported as unused.

## Cross references

`source-xref` returns what the scope analysis of the linter knows about
the names of a file, for editor features such as jump to definition and
find references. Each xref record has a role, the name and its position
(line from 1, column from 0) and a target saying where the name is bound:

| Role | Meaning |
|---|---|
| `definition` | a top-level definition (also by a configured definer macro) |
| `local-definition` | a parameter or local binding |
| `reference` | a use the analysis resolved |
| `mention` | a name inside a macro use the linter cannot look into; usually a reference, but it may be a pattern variable or a name the macro binds |
| `quoted` | a symbol in quoted data, such as a command name in a keymap |
| `export` | a name in the export list |

The target is `(here line col)` for a binding in the file (for a
definition its own position), `(import library name)` for an import,
naming the library that originally defines it (through re-exports and
renames), or `#f`. All uses of one binding have equal targets, so the
references to a definition of a project are the entries whose target
names its library and name, or its position in its own file.

```scheme
(for-each (lambda (x)
            (write (list (xref-role x) (xref-name x) (xref-target x)))
            (newline))
          (source-xref "(import (scheme base))\n(define (f x) (car x))\n"
                       "a.scm"))
;; (definition f (here 2 9))
;; (local-definition x (here 2 11))
;; (reference car (import (scheme base) car))
;; (reference x (here 2 11))
```

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


## Exports

### `lint-command`

```
Syntax: (lint-command args)
Library: (scm source lint)
Description: Runs `scm lint` with the list of argument strings args (the
  command line after "lint") and returns the exit code. See `scm lint
  --help`.
Example:
  (lint-command '("src")) => 0
```

### `lint-file`

```
Syntax: (lint-file path [options])
Library: (scm source lint)
Description: Checks the Scheme source file at path, like lint-string;
  options default to (lint-options path).
Example:
  (lint-findings->text (lint-file "src/app.sld"))
```

### `lint-finding-col`

*(no documentation)*

### `lint-finding-file`

*(no documentation)*

### `lint-finding-line`

*(no documentation)*

### `lint-finding-message`

*(no documentation)*

### `lint-finding-rule`

*(no documentation)*

### `lint-finding-severity`

*(no documentation)*

### `lint-finding?`

*(no documentation)*

### `lint-findings->json`

```
Syntax: (lint-findings->json findings)
Library: (scm source lint)
Description: Formats a list of findings as a JSON array of objects with
  the keys file, line, column (both from 1), severity, rule and message.
Example:
  (lint-findings->json '()) => "[]"
```

### `lint-findings->text`

```
Syntax: (lint-findings->text findings)
Library: (scm source lint)
Description: Formats a list of findings one per line as
  file:line:column: severity: [rule] message (line and column from 1),
  the format compilers use, so editors can jump to the places.
Example:
  (lint-findings->text (lint-string "(define (f x) 1)" "a.scm"))
    => ""
```

### `lint-options`

```
Syntax: (lint-options path [overrides])
Library: (scm source lint)
Description: Returns the linter options for the file path: the defaults,
  overridden by the [lint] table (and the width and library-path of the
  [format] table) of the nearest scm-tools.toml, overridden by the alist
  overrides. Keys: enable and disable (lists of rule id symbols, added to
  or removed from the rules enabled by default), width (78),
  docstring-libraries (list of first parts of library names whose
  exported procedures need docstrings, default ("scm")), definers
  (list of symbols: macros that define the name given as their first
  argument, as (definer name ...) or (definer (name . args) ...), such as
  a project's own define-command; default ()), library-path
  (directories with the .sld files of project libraries) and fmt-check
  (#f; #t adds the not-formatted rule).
Example:
  (cdr (assq 'width (lint-options "src/a.sld"))) => 78
```

### `lint-rules`

```
Syntax: (lint-rules)
Library: (scm source lint)
Description: Returns the linter's rules as a list of (id severity
  enabled-by-default? description), id and severity being symbols.
Example:
  (car (lint-rules))
    => (read-error error #t "the file cannot be read ...")
```

### `lint-string`

```
Syntax: (lint-string text file [options])
Library: (scm source lint)
Description: Checks the Scheme source text (named file in the findings
  and used to find sibling libraries) and returns the findings, a list of
  lint-finding records sorted by position. options is an alist as
  returned by lint-options (missing keys take the defaults). Accessors:
  lint-finding-rule, lint-finding-severity, lint-finding-file,
  lint-finding-line (from 1), lint-finding-col (from 0),
  lint-finding-message.
Example:
  (map lint-finding-rule
       (lint-string "(import (scheme base))\n(define (f x) (car (cdr x)))\n"
                    "a.scm"))
    => (cxr)
```

### `source-xref`

```
Syntax: (source-xref text file [options])
Library: (scm source lint)
Description: Returns the cross references of the Scheme source text (file
  names it and is used to find sibling libraries), from the scope
  analysis of the linter: a list of xref records sorted by position, or
  #f when the text cannot be read. options are as for lint-string (the
  library-path and definers matter). Accessors: xref-role, xref-name (a
  symbol), xref-line (from 1), xref-col (from 0), xref-kind and
  xref-target. Roles: definition (a top-level definition of the file),
  local-definition (a parameter or local binding), reference (a resolved
  use), mention (a name inside a macro use the linter cannot look into;
  possibly not a reference), quoted (a symbol in quoted data) and export
  (a name in an export list). xref-kind is the kind of a definition
  (define, macro, record-type, record, definer, local, param, loop) and #f
  otherwise. xref-target is where the name is bound: (here line col) for
  a definition in the text (the definition's own position for a
  definition), (import library name) for an import (the library that
  originally defines it, and its name there), or #f when it is unbound or
  quoted. Uses of one binding have equal targets.
Example:
  (map (lambda (x) (list (xref-role x) (xref-name x) (xref-target x)))
       (source-xref "(import (scheme base))\n(define (f x) (car x))\n"
                    "a.scm"))
    => ((definition f (here 2 9))
        (local-definition x (here 2 11))
        (reference car (import (scheme base) car))
        (reference x (here 2 11)))
```

### `xref-col`

*(no documentation)*

### `xref-kind`

*(no documentation)*

### `xref-line`

*(no documentation)*

### `xref-name`

*(no documentation)*

### `xref-role`

*(no documentation)*

### `xref-target`

*(no documentation)*

### `xref?`

*(no documentation)*

