# `(scm source format)`

Source formatter behind scm fmt — Emacs indentation, import/export sorting

## Overview

`(scm source format)` is the formatter behind `scm fmt`. It reads a file
with [(scm source)](scm-source.md), sorts the import and export lists and
lays the code out again within a line width (78 by default) using Emacs
scheme-mode indentation:

- a form that fits on the rest of its line stays on one line, unless it
  is a body form with several body expressions, a `cond` or `case` with
  several clauses, a `let` whose bindings are calls, or an import/export
  list with several entries;
- body forms (`define...`, `lambda`, the `let` family, `when`, `case`,
  `do`, ...) keep their distinguished arguments on the first line and
  indent the body by 2; distinguished arguments that must break go to +4;
- other calls keep the first argument on the operator's line and align
  the rest under it (leading atom arguments share that line while they
  fit), or put all arguments at +1 when the operator is too long;
- data (quoted lists, vectors, lists headed by a non-symbol) aligns under
  the first element, atoms are filled up to the width;
- comments stay where they are: end-of-line comments at the end of their
  line, others on lines of their own at the code's indentation; one blank
  line is kept wherever the source had one or more;
- strings, here-strings, block comments and atoms are copied verbatim and
  never split, so docstrings keep their layout; `[ ]` become `( )`.

With `keep-breaks` (`scm fmt --keep-breaks`) the line breaks of the source
are kept and only the indentation is redone; lines still too long are
broken.

Imports are grouped as `(scheme ...)`, `(srfi ...)` (numerically),
`(scm ...)`, then everything else, each group sorted by library name;
exports are sorted alphabetically. Comments in such a list split it into
groups sorted separately. Because the last import of a name wins, the
imports are only reordered when every name imported more than once denotes
the same binding everywhere; otherwise the list is left as it is and a
note says why (for example `string-hash comes from both (srfi 13) and
(srfi 69)`).

Every result is checked before it is used: it must read back to the same
datums as the input and formatting it again must not change it. If either
check fails, the formatter raises an "internal formatter error" and the
file is not written.

## Command line

```bash
scm fmt src/                # format in place, report the changed files
scm fmt --check .           # CI: list files that would change, exit 1 if any
scm fmt --diff lib.sld      # unified diff instead of writing
scm fmt --keep-breaks app.scm
scm fmt - < in.scm > out.scm   # filter (editor integration)
```

Options: `--width N`, `--no-sort`, `--no-sort-imports`,
`--no-sort-exports`, `--keep-brackets`, `--exclude GLOB`, `--quiet`.
Settings come from the `[format]` table of `scm-tools.toml` (see
[(scm source)](scm-source.md)). Exit codes: 0 ok, 1 files would change
(`--check`/`--diff`) or a file could not be read, 2 usage error, 3 internal
formatter error.

## Common uses

```scheme
(import (scm source format))

(format-source-string "(define (f x)\n(if x\n1 2))")
;; => "(define (f x) (if x 1 2))\n"

(format-source-string src '((width . 100) (keep-breaks . #t)
                            (indent ("with-db-tx" . 1))))

(format-file! "src/app.sld")   ;; => #t if the file changed
```

Indentation rules for your own forms (the `indent` option or
`[format.indent]`) are a number N, a body form with N distinguished
arguments like Emacs's `scheme-indent-function`, or the name of a built-in
rule: `define`, `lambda`, `let`, `do`, `receive`, `cond`, `case`,
`clauses`, `guard`, `rules`, `import` or `call`. Forms named `define...`,
`with-...` and `call-with-...` get body indentation by default.


## Exports

### `fmt-command`

```
Syntax: (fmt-command args)
Library: (scm source format)
Description: Runs `scm fmt` with the list of argument strings args (the
  command line after "fmt") and returns the exit code. See `scm fmt
  --help` for the options.
Example:
  (fmt-command '("--check" "src")) => 0
```

### `format-file!`

```
Syntax: (format-file! path [options])
Library: (scm source format)
Description: Formats the file at path in place (see format-source-string
  for options; by default format-options of path) and returns #t if its
  text changed, #f if it was already formatted. The file is only written
  when the text changes.
Example:
  (format-file! "src/app.sld") => #t
```

### `format-options`

```
Syntax: (format-options path [overrides])
Library: (scm source format)
Description: Returns the formatter options for the file path: the
  defaults, overridden by the [format] table of the nearest
  scm-tools.toml (see tools-config in (scm source)), overridden by the
  alist overrides. Keys: width (integer, 78), keep-breaks (#f),
  sort-imports (#t), sort-exports (#t), keep-brackets (#f), indent (an
  alist of form name string to indent rule, see format-source-string)
  and library-path (directories searched for the .sld files of imported
  project libraries, relative paths taken from the config's directory).
Example:
  (cdr (assq 'width (format-options "src/a.sld" '((width . 100)))))
    => 100
```

### `format-source-string`

```
Syntax: (format-source-string str [options])
Library: (scm source format)
Description: Formats the Scheme source text str and returns the new text.
  options is an alist (see format-options; missing keys take the
  defaults): width, keep-breaks, sort-imports, sort-exports,
  keep-brackets, indent and library-path. indent adds or overrides
  indentation rules: an alist of form name (string) to a number N (a body
  form with N distinguished arguments, like Emacs scheme-indent-function)
  or a symbol naming a built-in rule: define, lambda, let, do, receive,
  cond, case, clauses, guard, rules, import or call.
  Raises an error with the position when str cannot be read, and an
  error starting "internal formatter error" when the result would not
  read back to the same datums or would change when formatted again.
Example:
  (format-source-string "(define (f x)\n(if x\n1 2))")
    => "(define (f x) (if x 1 2))\n"
```

### `sort-source-declarations`

```
Syntax: (sort-source-declarations cst options file)
Library: (scm source format)
Description: Returns a copy of the CST file node cst with the import and
  export lists of its define-library forms and top-level imports sorted
  the way scm fmt sorts them (see format-source-string for options;
  sort-imports and sort-exports are honoured). Imports whose order could
  matter are left alone. Returns two values: the new node and a list of
  notes (line col message) about import lists left unsorted. file names
  the source, for finding sibling libraries.
Example:
  (sort-source-declarations (source-read-string "(import (scm io) (scheme base))")
                            '() "<string>")
```

### `source-diff`

```
Syntax: (source-diff old new name)
Library: (scm source format)
Description: Returns a unified diff (3 lines of context) from the text
  old to the text new, with name in the --- / +++ header lines, or ""
  if the texts are equal.
Example:
  (source-diff "a\nb\n" "a\nc\n" "x.scm")
    => "--- x.scm\n+++ x.scm (formatted)\n@@ -1,2 +1,2 @@\n a\n-b\n+c\n"
```

