---
title: "Developer tools: scm fmt, scm lint, (scm source), docs, REPL, profiling, reloading"
part: libraries
order: 1045
libraries: (scm source) (scm source format) (scm source lint) (scm doc) (scm repl) (scm geiser) (scm profiling) (scm reloader) (scm compile)
summary: Formatting code with scm fmt, checking it with scm lint and fixing what can be fixed, scm-tools.toml; reading source with comments kept as a syntax tree, cross references; docstrings at run time; REPL completion and Emacs with Geiser; finding slow procedures with the profiler; a development server that restarts on changes; looking at compiled code.
---
# Developer tools

dabscm comes with the tools a project needs besides the language:

- **Formatter:** `scm fmt`.
- **Linter:** `scm lint`.
- **Libraries underneath:** for tools of your own.
- **Documentation:** docstrings at run time.
- **Editors and the REPL:** completion and Geiser.
- **Profiler.**
- **Development reloader:** restarts a program when its files change.

```scheme
(import (scheme base) (scheme write)
        (scm source) (scm source format) (scm source lint) (scm doc))

(define messy "; prices\n(define (total items)   ; sum of prices\n  (if (null? items) 0\n  (+ (car (cdr (car items))) (total (cdr items)))))\n")
```

## scm fmt

`scm fmt` lays code out the way Emacs indents Scheme, within 78
columns, and sorts import and export lists:

```sh
scm fmt src/                # format every .scm and .sld below src, in place
scm fmt --check .           # CI: list files that are not formatted, exit 1 if any
scm fmt --diff app.scm      # show what would change
```

The same from Scheme, on text:

```scheme
(display (format-source-string messy))
;; prints: ; prices
;; prints: (define (total items) ; sum of prices
;; prints:   (if (null? items) 0 (+ (car (cdr (car items))) (total (cdr items)))))

(display (format-source-string "(import (scm fs) (scheme write) (scheme base))\n(define (f x)\n(if x\n1 2))"))
;; prints: (import (scheme base)
;; prints:         (scheme write)
;; prints:         (scm fs))
;; prints: (define (f x) (if x 1 2))
```

- Comments stay where they were; strings and docstrings are copied
  verbatim.
- A form that fits on one line goes on one line; `--keep-breaks` keeps
  the line breaks of the source and only redoes the indentation.
- Imports are sorted `(scheme …)`, `(srfi …)`, `(scm …)`, then the rest,
  unless reordering could change which binding a name gets.
- Every result is checked: it must read back to the same code, and
  formatting it again must change nothing. Otherwise the file is left
  alone.

## scm lint

`scm lint` finds mistakes and simplifications: unbound names, unused
imports and variables, wrong argument counts, unreachable clauses, and
idioms with a simpler form:

```scheme
(define findings (lint-string (string-append "(import (scheme base) (scheme char))\n" messy) "prices.scm"))
(display (lint-findings->text findings))
;; prints: prices.scm:1:23: warning: [unused-import] (scheme char) is imported but not used
;; prints: prices.scm:5:11: info: [cxr] use cdar
(map lint-finding-rule (lint-string "(import (scheme base))\n(define (empty? lst) (if (= (length lst) 0) #t #f))\n" "a.scm"))
;; => (if-boolean length-zero)
```

The findings have the `file:line:column` format compilers use, so
editors jump to them. `cdar` and not `cadar` is suggested because
`cadar` would need `(scheme cxr)`, which the file does not import.
Many findings can be corrected automatically:

```scheme
(define-values (fixed count) (lint-fix-string (string-append "(import (scheme base))\n" messy) "prices.scm"))
count                                       ;; => 1
(display fixed)
;; prints: (import (scheme base))
;; prints: ; prices
;; prints: (define (total items)   ; sum of prices
;; prints:   (if (null? items) 0
;; prints:   (+ (car (cdar items)) (total (cdr items)))))
```

```sh
scm lint src/                      # all files below src
scm lint --fail-on warning .       # CI: exit 1 on warnings too
scm lint --fix src/                # correct what can be corrected
scm lint --list-rules              # every rule with its id
```

Both tools read their settings from the nearest `scm-tools.toml`, so a
project configures them once:

```text
[format]
width = 100
library-path = ["src"]

[lint]
disable = ["cxr"]
enable = ["unused-parameter"]
```

## Reading source as a tree

`(scm source)` is the reader behind both tools. Unlike `read`, it keeps
comments, the exact spelling of every atom and all whitespace, so a
tool can change one place and write everything else back unchanged:

```scheme
(define tree (source-read-string messy))
(map cst-kind (cst-children tree))          ;; => (comment list)
(map (lambda (n) (list (cst-line n) (cst-col n))) (cst-children tree)) ;; => ((1 0) (2 0))
(equal? (cst->string tree) messy)           ;; => #t
(cst->datum (source-read-string "(a #;b c) ; done")) ;; => ((a c))
```

Read errors carry the file, line and column:

```scheme
(guard (e ((source-read-error-position e) => (lambda (pos) pos)))
  (source-read-string "(define (f x)" "f.scm"))
;; => ("f.scm" 1 0)
```

`source-xref` gives the cross references the linter computes: every
definition and use, and where each name is bound. Editor features like
"go to definition" and "rename" are built on it:

```scheme
(map (lambda (x) (list (xref-role x) (xref-name x) (xref-target x)))
     (source-xref "(import (scheme base))\n(define (f x) (car x))\n(f '(1))\n" "a.scm"))
;; => ((definition f (here 2 9)) (local-definition x (here 2 11)) (reference car (import (scheme base) car)) (reference x (here 2 11)) (reference f (here 2 9)))
```

## Docstrings at run time

A procedure's documentation string is available while the program runs:

```scheme
(display (procedure-doc 'car))
;; prints: Syntax: (car pair)
;; prints: Library: (scheme base)
;; prints: Description: Returns the car of pair. It is an error if pair is not a pair.
;; prints: Example:
;; prints:   (car '(a b c)) => a
;; prints:   (car '((a) b)) => (a)
```

Write docstrings in the same layout (`Syntax:`, `Library:`,
`Description:`, `Example:`) as the first thing in a `define` body; the
reference documentation of dabscm is generated from them, and `scm lint`
checks that exported procedures of `(scm …)` libraries have one.

## REPL and editors

`scm` without arguments starts a REPL with completion. `(scm repl)`
gives the same information to programs (on the JVM and .NET):

```scheme not-native
(import (scm repl))
(repl-completions "vector-m")               ;; => ("vector-map")
(repl-info-line 'car)                       ;; => "car : (car pair) -- Returns the car of pair. It is an error if pair is not a pair."
(and (member "define-record-type" repl-core-form-names) #t) ;; => #t
```

For Emacs, `(scm geiser)` implements the protocol of Geiser, the Scheme
mode with evaluation in a running REPL, completion, documentation in the
echo area and jumping to definitions:

```text
;; init.el, with geiser installed and emacs-geiser/ of the dabscm
;; repository on the load-path (emacs-geiser/README.md has the details)
(require 'geiser-dabscm)
;; then: M-x run-dabscm
```

The Emacs side is `emacs-geiser/geiser-dabscm.el` in the dabscm
repository; it starts `scm --geiser`, a REPL that loads `(scm geiser)`.

## Profiling

Which procedures take the time? `(scm profiling)` counts calls and
measures time per procedure of the libraries you name (on the JVM and
.NET):

```scheme not-native
(import (scheme char) (scm profiling))

(define (list-sort-by-name rows)            ; a small insertion sort by name
  (let insert-all ((rows rows) (out '()))
    (if (null? rows)
        out
        (insert-all (cdr rows)
                    (let insert ((out out))
                      (cond ((null? out) (list (car rows)))
                            ((string<? (car (car rows)) (car (car out))) (cons (car rows) out))
                            (else (cons (car out) (insert (cdr out))))))))))

(profile-reset!)
(profile-instrument! '((scheme char) string-upcase string-downcase))
(define (shout words) (map string-upcase words))
(do ((i 0 (+ i 1))) ((= i 100)) (shout '("sencha" "assam")) (string-downcase "TEA"))
(map (lambda (r) (list (car r) (cadr r))) (list-sort-by-name (profile-data)))
;; => (("(scheme char):string-downcase" 100) ("(scheme char):string-upcase" 200))
(profile-uninstrument!)
```


`profile-report` prints a table with calls, total and average
milliseconds and the share of the time:

```text
Profile Report
Name                                        Calls     Total ms     Avg ms      %
--------------------------------------------------------------------------------
(scheme char):string-upcase                   200        10.30       0.05  84.9%
(scheme char):string-downcase                 100         1.83       0.02  15.1%
```

Instrument a whole library of your own with `(profile-instrument! '((my
lib)))`.

## Restarting on changes

`(scm reloader)` runs a program and restarts it whenever one of its
files changes, the development server of the starter applications:

```scheme no-test
(import (scheme base) (scm reloader))

(supervise (list "scm" "bin/server.scm" "config.scm")
           (lambda () (cons "config.scm" (files-with-suffix "src" ".sld")))
           '((label . "dev-server")))
```

The watch list is re-read on every check, so new files are picked up. A
program that crashes is restarted after a growing pause, so an error
does not spin.

## Looking at compiled code

`(scm compile)` shows what the JVM and .NET interpreters run (dabscm
native compiles to machine code instead):

```scheme not-native
(import (scm compile))
(list (primitive? car) (macro? car) (lambda? (lambda (x) x))) ;; => (#t #f #t)
(symbol? (gensym))                          ;; => #t
```

```text
> (disassemble (lambda (x) (+ x 1)))
env: #(())
0:  ARGS 1
1:  LVAR_ADD_IMM 0 1
2:  RETURN
```

The adding of a constant to a local became a single instruction.

## Where next

- [Getting started](basics-01-getting-started.md) for the REPL and
  running programs, [testing](techniques-10-testing.md),
  [scaffold](scm-scaffold.md) for projects that use all of this.
- Reference: `(scm source)`, `(scm source format)`, `(scm source lint)`,
  `(scm doc)`, `(scm repl)`, `(scm profiling)`, `(scm reloader)`,
  `(scm compile)`.
