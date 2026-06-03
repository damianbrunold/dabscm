## Overview

`(scheme base)` is the R7RS base library — the core of the language. It provides
the fundamental syntax (`define`, `lambda`, `let` and friends, `cond`, `case`,
`when`, `unless`, `do`, `quasiquote`, `define-record-type`, `parameterize`, …) and
the everyday procedures over pairs/lists, numbers, characters, strings, vectors,
bytevectors, symbols, control flow, and basic I/O (string ports, `read-line`,
`write-string`, …).

## Common uses

```scheme
(import (scheme base))

(define (square x) (* x x))
(square 5)                       ;; => 25

(map square '(1 2 3))            ;; => (1 4 9)
(let loop ((i 0) (acc '()))
  (if (= i 3) (reverse acc) (loop (+ i 1) (cons i acc))))   ;; => (0 1 2)
```

This is the library almost every program imports first. The other `(scheme …)`
libraries add specialized pieces (file I/O, inexact math, lazy evaluation, …) on
top of it.
