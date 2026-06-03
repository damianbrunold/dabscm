## Overview

SRFI-14 provides character sets: a `char-set` type with constructors, the standard
predefined sets, set algebra, and membership testing. Character sets pair naturally
with the predicate-driven operations in SRFI-13.

## Common uses

```scheme
(import (srfi 13) (srfi 14))

(char-set-contains? (char-set #\a #\e #\i #\o #\u) #\e)   ;; => #t
(string-count "banana" (char-set #\a))                    ;; => 3
```

Predefined sets include `char-set:alphabetic`, `char-set:numeric`,
`char-set:whitespace`, etc., and you can combine them with `char-set-union`,
`char-set-intersection`, and `char-set-complement`.
