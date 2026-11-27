---
title: (scm list) and (scm macro): small helpers
part: libraries
order: 1002
libraries: (scm list) (scm macro)
summary: Property lists, removing neighbouring duplicates, splitting into odd and even positions, zipping into alists; pretty-printing data, expanding macros, conditional definitions.
---
# (scm list) and (scm macro): small helpers

Two small libraries with helpers that come up again and again.

```scheme
(import (scheme base) (scheme write) (scm list) (scm macro))
```

## Property lists

A *property list* is a list of flags and `(name value ...)` entries, a
compact way to write options:

```scheme
(define options '(verbose (level 3) (paths "/tmp" "/var") dry-run))

(get-property options 'level)             ;; => 3
(get-property options 'verbose)           ;; => verbose
(get-property options 'color)             ;; => #f
(get-property options 'color 'auto)       ;; => auto
(get-property-list options 'paths)        ;; => ("/tmp" "/var")
```

A bare symbol is a flag: asking for it returns the symbol itself, a true
value. `get-property` returns the first value of an entry,
`get-property-list` all of them.

## Neighbouring duplicates

`uniq`, `univ` and `unique` collapse runs of equal elements, compared with
`eq?`, `eqv?` and `equal?`, like the Unix `uniq` command:

```scheme
(uniq '(a a b b b a))                     ;; => (a b a)
(univ '(1 1 2 3 3))                       ;; => (1 2 3)
(unique '("x" "x" "y"))                   ;; => ("x" "y")
```

Sort first to remove all duplicates.

## Splitting and zipping

```scheme
(call-with-values (lambda () (split '(a 1 b 2 c 3))) list) ;; => ((a b c) (1 2 3))
(zip-alist '(name age) '("Ada" 36))       ;; => ((name . "Ada") (age . 36))
(rest '(1 2 3))                           ;; => (2 3)
```

`split` takes elements alternately, which turns a flat key/value list into
keys and values; `zip-alist` makes an alist from two lists of equal length.

```scheme
(define (plist->alist pl)
  (call-with-values (lambda () (split pl)) zip-alist))

(plist->alist '(host "localhost" port 5432)) ;; => ((host . "localhost") (port . 5432))
```

## Pretty-printing

`pretty-print` writes data or code indented over several lines, which helps
when looking at large nested structures:

```scheme
(pretty-print '(define (fact n) (if (= n 0) 1 (* n (fact (- n 1))))))
;; prints: (define (fact n) (if (= n 0) 1 (* n (fact (- n 1)))))
```

Short forms stay on one line; longer ones are broken and indented to fit 79
columns.

## Expanding macros

`macroexpand` shows what a macro use turns into, the fastest way to debug
your own macros:

```scheme no-test
(macroexpand '(when (> x 0) (display x)))
; => (if (> x 0) (begin (display x)))
```

## Conditional definitions

`define-if-not-bound` defines a name only if it does not exist yet, so a
file can provide a fallback for a procedure another library may already
provide:

```scheme no-test
(define-if-not-bound string-trim-both
  (lambda (s) ...))
```

## Where next

- [SRFI 1](srfi-1.md) for the full list library.
- Reference: `(scm list)`, `(scm macro)`.
