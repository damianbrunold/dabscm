# `(srfi 48)`

SRFI-48 — Intermediate format strings: display, write, numeric bases, pretty-print

## Exports

### `format`

```
Syntax: (format fmt obj ...)
Syntax: (format dest fmt obj ...)
Library: (srfi 48)
Description: Formats a string (SRFI-48 intermediate format strings).
  When dest is omitted or #f, returns the formatted string.
  When dest is #t, writes to the current output port.
  When dest is an output port, writes to that port.
  Directives: ~a (display), ~s (write), ~w (write-shared),
  ~d (decimal), ~x (hex), ~o (octal), ~b (binary), ~c (char),
  ~y (pretty-print), ~f (fixed float with ~W,Df),
  ~? or ~k (recursive format), ~% (newline), ~n (newline),
  ~& (freshline), ~t (tab), ~_ (space), ~~ (tilde), ~h (help).
  Width/alignment: ~10a (right-align in 10), ~-10a (left-align).
Example:
  (format "~a is ~d" "answer" 42) => "answer is 42"
  (format #t "~a~%" "hello")  ; prints hello and newline
  (format "~x" 255) => "ff"
```

