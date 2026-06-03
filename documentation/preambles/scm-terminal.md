## Overview

`(scm terminal)` controls the terminal: ANSI colors and text styles, cursor
movement, screen clearing, raw/echo modes, and password input. The SGR helpers
return escape-sequence strings you embed in output; the `with-…` forms manage
mode changes safely.

## Common uses

Colored, styled output (compose escape strings, then reset):

```scheme
(import (scm terminal))

(display (string-append (sgr-fg 'red) "error" (sgr-reset)))
(display (string-append (sgr-bold) "important" (sgr-reset)))
(display (string-append (sgr-fg 255 128 0) "orange" (sgr-reset)))  ;; 24-bit RGB
```

Cursor and screen control (these write the escape sequence directly):

```scheme
(clear-screen)
(cursor-position 1 1)   ;; move to row 1, column 1 (1-based)
```

Run a block with the terminal in raw mode, or read a password without echo:

```scheme
(with-terminal-raw (lambda () ...))
(define pw (read-password "Password: "))
```
