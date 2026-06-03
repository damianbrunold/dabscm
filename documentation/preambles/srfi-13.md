## Overview

SRFI-13 is the string library: searching, prefixes/suffixes, padding and trimming,
case-aware operations, and predicate-driven scanning. It's the preferred toolkit
for string manipulation (over `(scm string)`, which adds regex on top).

## Common uses

```scheme
(import (srfi 13))

(string-index "hello" #\l)        ;; => 2
(string-prefix? "he" "hello")     ;; => #t
(string-pad "5" 3 #\0)            ;; => "005"
(string-trim-both "  hi  ")       ;; => "hi"
(string-join '("a" "b" "c") "-")  ;; => "a-b-c"
```

Note the trim family: `string-trim` trims the left, `string-trim-right` the right,
and `string-trim-both` both ends. Many procedures accept a char, char-set, or
predicate as the criterion.
