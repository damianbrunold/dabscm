# `(srfi 26)`

SRFI-26 — cut/cute: partial application via slot notation

## Overview

SRFI-26 provides `cut` and `cute`, compact syntax for partial application: write a
specialized procedure by marking the "holes" with `<>` instead of writing a full
lambda.

## Common uses

```scheme
(import (srfi 26))

(map (cut * 2 <>) '(1 2 3))        ;; => (2 4 6)
(map (cut cons <> '()) '(a b c))   ;; => ((a) (b) (c))

((cut + 1 <>) 10)                  ;; => 11
```

`<...>` collects the rest of the arguments. `cute` is like `cut` but evaluates the
non-hole subexpressions once, up front (useful when they're expensive or
effectful).


## Exports

### `cut`

```
Syntax: (cut f arg ...)
Library: (srfi 26)
Description: Specializes a procedure f by replacing some arguments with slots (<>).
Returns a lambda that accepts the slot arguments in order. Use <...> as a rest slot.
Non-<> arguments are re-evaluated on each call (unlike cute).
Example:
  (define add5 (cut + <> 5))
  (add5 3) => 8
  (define cons-star (cut cons <> '()))
  (cons-star 1) => (1)
```

### `cute`

```
Syntax: (cute f arg ...)
Library: (srfi 26)
Description: Like cut, but non-slot expressions are evaluated once when cute is
called, not at each invocation. Slots (<>) become lambda parameters; <...> is a rest slot.
Example:
  (define add-n (cute + <> (begin (display "eval") 5)))
  (add-n 3) => 8   ; "eval" is printed only once
```

