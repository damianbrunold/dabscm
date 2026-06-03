## Overview

`(scm string)` adds string operations that aren't in the SRFI-13 string library —
regular-expression matching and splitting, literal replace-all, and convenience
splitters. For standard, predicate-based string work prefer `(srfi 13)`; reach
for this library when you need regex or the line/field helpers.

## Common uses

Split on a regex (whitespace by default), or on a literal separator:

```scheme
(import (scm string))

(string-split "a b c")          ;; => ("a" "b" "c")
(string-split "a,b,c" ",")      ;; => ("a" "b" "c")
(string-split-char "a,b,,c" #\,);; => ("a" "b" "" "c")
(string-split-lines "a\nb\n")   ;; => ("a" "b" "")
```

Match a regular expression — the result is the full match followed by any groups,
or `#f`:

```scheme
(string-matches "abc123" "([a-z]+)([0-9]+)")  ;; => ("abc123" "abc" "123")
(string-matches "hello" "xyz")                ;; => #f
```

Replace every occurrence of a literal substring:

```scheme
(string-replace-all "a.b.c" "." "/")   ;; => "a/b/c"
```
