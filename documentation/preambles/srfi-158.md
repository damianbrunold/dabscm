## Overview

SRFI-158 provides generators and accumulators: lazy producers of values you can
compose into pipelines, and their dual, accumulators that collect values into a
result. Generators are plain procedures of no arguments that yield the next value
or an eof object.

## Common uses

```scheme
(import (srfi 158))

(generator->list (make-iota-generator 5))     ;; => (0 1 2 3 4)

(generator->list
  (gmap (lambda (x) (* x x))
        (list->generator '(1 2 3))))           ;; => (1 4 9)
```

Constructors include `generator`, `list->generator`, and `make-range-generator`;
combinators include `gmap`, `gfilter`, and `gtake`; and `generator->list` /
`generator-fold` consume them. Accumulators (`list-accumulator`,
`sum-accumulator`, …) gather values back up.
