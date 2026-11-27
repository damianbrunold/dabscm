---
title: SRFI 2, 8 and 26: small syntax helpers
part: libraries
order: 26
libraries: (srfi 2) (srfi 8) (srfi 26)
summary: and-let* for chains of lookups that may fail, receive for multiple values, cut and cute for partial application.
---
# SRFI 2, 8 and 26: small syntax helpers

Three small libraries that make everyday code shorter:

| library | form | for |
|---|---|---|
| `(srfi 2)` | `and-let*` | a chain of steps where any step may fail |
| `(srfi 8)` | `receive` | binding multiple return values |
| `(srfi 26)` | `cut`, `cute` | fixing some arguments of a procedure |

```scheme
(import (scheme base) (srfi 1) (srfi 2) (srfi 8) (srfi 26))
```

## and-let*: lookups that may fail

`and-let*` is `let*` that stops at the first `#f`. Each clause is either a
binding `(name expr)`, which stops if the value is `#f`, or a plain test
`(expr)`:

```scheme
(define config '((db . ((host . "localhost") (port . "5432")))))

(define (db-port cfg)
  (and-let* ((db (assq 'db cfg))
             (port (assq 'port (cdr db)))
             (n (string->number (cdr port)))
             ((< 0 n 65536)))
    n))

(db-port config)                          ;; => 5432
(db-port '((db . ((host . "x")))))       ;; => #f
(db-port '((db . ((port . "many")))))    ;; => #f
```

Without `and-let*`, this is a staircase of nested `let` and `if`; with it,
the steps read top to bottom and any missing piece gives `#f`.

## receive: multiple values

`receive` binds the values of an expression to names, like `let-values`
for a single expression:

```scheme
(receive (q r) (floor/ 17 5)
  (list q r))                             ;; => (3 2)

(receive (evens odds) (partition even? '(1 2 3 4 5))
  (list (length evens) (length odds)))    ;; => (2 3)

(receive (first . rest) (values 1 2 3)
  (list first rest))                      ;; => (1 (2 3))
```

The formals can end in a rest parameter, as in a `lambda`.

## cut and cute: partial application

`cut` creates a procedure from a call with "holes" marked `<>`:

```scheme
((cut + 1 <>) 41)                         ;; => 42
(map (cut * 2 <>) '(1 2 3))               ;; => (2 4 6)
(map (cut list 'x <> 'z) '(1 2))          ;; => ((x 1 z) (x 2 z))
(filter (cut string-prefix? "app" <>) '("apple" "pear" "applet"))
;; => ("apple" "applet")
((cut <> 3 4) +)                          ;; => 7
((cut list 1 <...>) 2 3)                  ;; => (1 2 3)
```

`<...>` at the end passes on any further arguments. The procedure position
can be a hole too (`(cut <> 3 4)`).

`cute` evaluates the fixed arguments once, when the procedure is made,
instead of at every call:

```scheme
(define counter 0)
(define (next!) (set! counter (+ counter 1)) counter)

(define f (cut list (next!) <>))
(list (f 'a) (f 'b))                      ;; => ((1 a) (2 b))
(define g (cute list (next!) <>))
(list (g 'a) (g 'b))                      ;; => ((3 a) (3 b))
```

Use `cute` when a fixed argument is expensive to compute or must not be
recomputed.

```scheme
(import (only (srfi 13) string-prefix?))
```

## Where next

- [Higher-order programming](basics-07-higher-order.md).
- Reference: `(srfi 2)`, `(srfi 8)`, `(srfi 26)`.
