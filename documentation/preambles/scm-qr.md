## Overview

`(scm qr)` is a pure-Scheme QR-code encoder (ISO/IEC 18004). `qr-encode` builds a
QR matrix from a string; render it to PNG, SVG, or ASCII, or inspect the matrix
directly. It supports versions 1–40 and error-correction levels L/M/Q/H.

## Common uses

```scheme
(import (scm qr) (scm png))

(define m (qr-encode "https://example.org"))   ;; a QR matrix

(write-png-file "qr.png" (qr->png m))          ;; PNG file
(qr->svg m 4 4)                                ;; => SVG string
(display (qr->ascii m))                         ;; print to the terminal
```

Pass an error-correction level as a trailing argument to `qr-encode`
(`'L`, `'M`, `'Q`, `'H`; default `'M`). The matrix accessors (`qr-matrix-size`,
`qr-matrix-ref`, `qr-matrix-version`, …) expose the raw modules.
