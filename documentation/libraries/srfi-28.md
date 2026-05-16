# `(srfi 28)`

SRFI-28 — Basic format strings

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

