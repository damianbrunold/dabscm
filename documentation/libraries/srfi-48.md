# `(srfi 48)`

SRFI-48 — Intermediate format strings: display, write, numeric bases, pretty-print

## Overview

SRFI-48 provides intermediate format strings — a richer `format` than SRFI-28. The
first argument is a destination (`#f` for a string, `#t` for the current output
port, or a port). Directives include `~a`/`~s`, numeric bases (`~d`, `~x`, `~o`,
`~b`), `~%` (newline), and pretty-printing.

## Common uses

```scheme
(import (srfi 48))

(format #f "~a + ~a = ~a" 1 2 3)    ;; => "1 + 2 = 3"
(format #f "hex: ~x" 255)           ;; => "hex: ff"
(format #t "to stdout~%")           ;; writes directly to stdout
```

Use `#f` to build a string, or a port/`#t` to write directly.


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

