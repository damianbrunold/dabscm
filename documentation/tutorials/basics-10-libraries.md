---
title: Libraries and programs
part: basics
order: 10
libraries: (scheme base) (scm module)
summary: Programs and imports, writing your own libraries with define-library, import variants (only, except, prefix, rename), search paths and project layout.
---
# Libraries and programs

## Programs import what they use

A program starts with `import`. Nothing is available that is not imported,
which keeps programs explicit and portable:

```scheme
(import (scheme base)
        (scheme write)
        (only (srfi 1) iota fold)
        (prefix (srfi 13) s13:))

(fold + 0 (iota 5))               ;; => 10
(s13:string-pad "7" 3 #\0)        ;; => "007"
```

The import set can be narrowed or adapted:

| form | effect |
|---|---|
| `(only lib a b)` | import only `a` and `b` |
| `(except lib a)` | everything but `a` |
| `(prefix lib p:)` | every name gets the prefix `p:` |
| `(rename lib (a b))` | import `a` under the name `b` |

They nest: `(prefix (only (srfi 13) string-pad) s:)` imports one name as
`s:string-pad`.

A program must not import one name from two libraries that define it
differently, and must not redefine an imported name. `(srfi 13)` and
`(srfi 69)` both export a `string-hash`, for instance, and `(scheme base)`
already has `square`. `scm` is lenient about this by default (the last
import wins), `scm --strict` reports it as an error, as R7RS asks. Use
`only` or `except` to import just what you need, and run your programs with
`--strict` now and then.

## Writing a library

A library lists what it exports and imports, then its definitions. Save
this as `geometry/shapes.sld`:

```scheme no-test
(define-library (geometry shapes)
  (export make-circle make-rect area perimeter)
  (import (scheme base))
  (begin
    (define-record-type shape
      (%make-shape kind a b)
      shape?
      (kind shape-kind) (a shape-a) (b shape-b))

    (define pi 3.141592653589793)

    (define (make-circle r) (%make-shape 'circle r #f))
    (define (make-rect w h) (%make-shape 'rect w h))

    (define (area s)
      (case (shape-kind s)
        ((circle) (* pi (shape-a s) (shape-a s)))
        ((rect) (* (shape-a s) (shape-b s)))))

    (define (perimeter s)
      (case (shape-kind s)
        ((circle) (* 2 pi (shape-a s)))
        ((rect) (* 2 (+ (shape-a s) (shape-b s))))))))
```

and use it from a program next to the `geometry` directory:

```scheme no-test
(import (scheme base) (scheme write) (geometry shapes))

(display (area (make-rect 3 4)))   ; 12
(newline)
```

Only the exported names are visible to the program: `%make-shape`,
`shape-kind` and `pi` stay private, so the library can change them later
without breaking anybody.

## How libraries are found

A library name maps to a file: `(geometry shapes)` is
`geometry/shapes.sld` or `geometry-shapes.sld`, searched in the directory of
the program, then in the search path. dabscm's own libraries use the second
form: `(scm data frame)` is `scm-data-frame.sld`.

`(scm module)` lets a program add directories to the search path before it
imports from them:

```scheme no-test
(import (scheme base) (scm module))
(module-search-path! (cons "lib" (module-search-path)))
(import (myapp config))
```

## Project layout

A typical small project:

```text
myapp/
  main.scm            the program
  myapp/config.sld    (myapp config)
  myapp/db.sld        (myapp db)
  tests/
    test-config.scm   a program importing (myapp config) and (scm test)
  scm-tools.toml      settings for scm fmt and scm lint
```

Keep each library small and focused on one thing; a library per file makes
the dependency graph visible in the import lists. `scm lint` reports unused
and conflicting imports, which keeps those lists honest.

## include

`include` pastes another file's text into a library body, useful for large
data tables or generated code:

```scheme no-test
(define-library (myapp tables)
  (export country-codes)
  (import (scheme base))
  (include "country-codes.scm"))
```

## Where next

- [Macros and pattern matching](basics-11-macros.md).
- [Testing your code](techniques-10-testing.md).
