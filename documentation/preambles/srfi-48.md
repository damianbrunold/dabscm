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
