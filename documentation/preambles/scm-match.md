## Overview

`(scm match)` is a pattern-matching library: `match` tests a value against a
series of patterns and evaluates the body of the first that fits, binding pattern
variables along the way. There are also `match-lambda`, `match-let`, and friends.

## Common uses

```scheme
(import (scm match))

(match 42
  (0 'zero)
  (x x))                        ;; => 42  (x binds the value)

(match '(1 2 3)
  ((a b c) (+ a b c)))          ;; => 6

(match (cons 1 2)
  ((x . y) (list y x)))         ;; => (2 1)

(match '(1 2 3)
  ((first . rest) rest))        ;; => (2 3)
```

Patterns include literals, the wildcard `_`, variables, and pair/list
destructuring. `match-lambda` builds a procedure that matches its argument, and
`match-let` / `match-let*` / `match-letrec` destructure in bindings.
