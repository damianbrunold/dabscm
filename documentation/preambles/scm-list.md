## Overview

`(scm list)` is a small grab-bag of list helpers that complement the much larger
SRFI-1 list library. For general higher-order list work (fold, map variants,
filter, take/drop, …) prefer `(srfi 1)`; this library adds a few extras such as
deduplication, partitioning by position, and alist zipping.

## Common uses

Remove duplicates (`uniq` collapses adjacent duplicates, `unique`/`univ` remove
all):

```scheme
(import (scm list))

(uniq   '(a a b b b c))      ;; => (a b c)
(unique '("a" "a" "b" "b"))  ;; => ("a" "b")
```

Split a list into its even- and odd-indexed elements (returns two values):

```scheme
(split '(a b c d e))   ;; => (a c e) and (b d)
```

Zip two lists into an association list:

```scheme
(zip-alist '(1 2 3) '(a b c))   ;; => ((1 . a) (2 . b) (3 . c))
```
