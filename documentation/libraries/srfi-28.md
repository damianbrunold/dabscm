# `(srfi 28)`

SRFI-28 — Basic format strings

## Overview

SRFI-28 provides basic format strings: `format` builds a string by substituting
values into a template with simple directives — `~a` (display), `~s` (write), `~%`
(newline), and `~~` (a literal tilde).

## Common uses

```scheme
(import (srfi 28))

(format "~a-~a" 1 2)              ;; => "1-2"
(format "Hello, ~a!~%" "world")  ;; => "Hello, world!\n"
(format "~s" "quoted")           ;; => "\"quoted\""
```

For more directives (numeric bases, padding, pretty-printing) see SRFI-48, whose
`format` is compatible and adds a destination argument.


## Exports

### `format`

```
Syntax: (format format-string obj ...)
Library: (srfi 28)
Description: Returns a formatted string (SRFI-28 basic format strings).
  Directives: ~a (display), ~s (write), ~d (decimal), ~x (hex),
  ~o (octal), ~b (binary), ~c (char), ~f (fixed float with ~W,Df),
  ~? (recursive format), ~% (newline), ~n (newline), ~~ (tilde).
  Width/alignment: ~10a (right-align in 10), ~-10a (left-align).
Example:
  (format "~a is ~d" "answer" 42) => "answer is 42"
  (format "~x" 255) => "ff"
```

