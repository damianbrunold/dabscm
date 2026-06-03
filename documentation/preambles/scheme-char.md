## Overview

`(scheme char)` provides character and string operations that depend on Unicode
character classification: case conversion, case-insensitive comparison, and
predicates like alphabetic/numeric/whitespace.

## Common uses

```scheme
(import (scheme base) (scheme char))

(char-upcase #\a)            ;; => #\A
(char-alphabetic? #\7)       ;; => #f
(char-numeric? #\7)          ;; => #t
(char-ci=? #\A #\a)          ;; => #t
(string-upcase "Hello")      ;; => "HELLO"
(string-downcase "Hello")    ;; => "hello"
```

It also includes `char-foldcase` / `string-foldcase` for case-folding and the
`char-ci…?` family for case-insensitive ordering.
