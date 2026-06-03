## Overview

`(scheme write)` writes Scheme values to output ports. `display` produces
human-readable output (no string quotes), `write` produces machine-readable output
(re-readable, with quotes and escapes), and `newline` emits a line break.

## Common uses

```scheme
(import (scheme base) (scheme write))

(display "hi\n")          ;; prints: hi
(write "hi")             ;; prints: "hi"   (with quotes)
(write '(1 "two" #\c))   ;; prints: (1 "two" #\c)
(newline)
```

`write-shared` and `write-simple` control how shared/cyclic structure is printed
(with or without datum labels).
