# `(srfi 26)`

SRFI-26 — cut/cute: partial application via slot notation

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

