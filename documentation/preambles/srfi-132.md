## Overview

SRFI-132 is the sort library for lists and vectors: stable sorting, merging,
in-place variants, plus selection utilities (find the nth element, the median, or
take the smallest k) without fully sorting.

## Common uses

```scheme
(import (srfi 132))

(list-sort < '(3 1 2))            ;; => (1 2 3)
(vector-sort < (vector 3 1 2))    ;; => #(1 2 3)
```

`list-sort!` / `vector-sort!` sort in place, `list-merge` / `vector-merge` merge
sorted sequences, and `vector-select!` / `vector-find-median` provide order
statistics.
