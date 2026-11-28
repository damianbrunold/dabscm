# `(scm qr)`

QR code encoding — PNG, SVG, and ASCII output

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


## Exports

### `qr->ascii`

```
Syntax: (qr->ascii matrix)
Library: (scm qr)
Description: Renders a qr-matrix using two-character cells suitable for
  terminal preview. Each module becomes '  ' (light) or '##' (dark).
  Adds a 1-module quiet zone.
Example:
  (display (qr->ascii (qr-encode "hi")))
```

### `qr->png`

```
Syntax: (qr->png matrix [module-px [quiet-modules]])
Library: (scm qr)
Description: Renders a qr-matrix as an 8-bit grayscale PNG bytevector.
  module-px is the side length in pixels of one module (default 8).
  quiet-modules is the border width in modules (default 4, per spec).
Example:
  (write-png-file "qr.png" (qr->png (qr-encode "hello")))
```

### `qr->svg`

```
Syntax: (qr->svg matrix [module-px [quiet-modules]])
Library: (scm qr)
Description: Renders a qr-matrix as an SVG string. module-px sets the
  width/height attribute scale (default 8 px per module). quiet-modules
  is the border in modules (default 4).
Example:
  (display (qr->svg (qr-encode "hi")))
```

### `qr-encode`

```
Syntax: (qr-encode data [ec-level [version]])
Library: (scm qr)
Description: Encodes data as a QR code and returns a qr-matrix record.
  data may be a string (encoded as UTF-8) or a bytevector. ec-level
  defaults to 'M and must be one of 'L 'M 'Q 'H. version defaults to
  the smallest version that fits.
Example:
  (qr->svg (qr-encode "https://example.org") 4 4)
```

### `qr-matrix-ec-level`

```
Syntax: (qr-matrix-ec-level qm)
Library: (scm qr)
Description: Returns the error-correction level of the QR code qm as a
  number: 0 for L, 1 for M, 2 for Q, 3 for H (about 7, 15, 25 and 30 %
  of the code may be damaged); qr-encode accepts these numbers as levels
  too.
Example:
  (qr-matrix-ec-level (qr-encode "hello" 'H)) => 3
```

### `qr-matrix-mask`

```
Syntax: (qr-matrix-mask qm)
Library: (scm qr)
Description: Returns the mask pattern (0 to 7) that qr-encode chose for the
  QR code qm, the one with the lowest penalty score.
Example:
  (qr-matrix-mask (qr-encode "hello")) => 0
```

### `qr-matrix-ref`

```
Syntax: (qr-matrix-ref qm y x)
Library: (scm qr)
Description: Returns 1 if the module in row y and column x of the QR code
  qm is dark, 0 if it is light; rows and columns count from 0 at the top
  left, without the quiet zone.
Example:
  (qr-matrix-ref (qr-encode "hello") 0 0) => 1   ; a finder pattern
```

### `qr-matrix-size`

```
Syntax: (qr-matrix-size qm)
Library: (scm qr)
Description: Returns the number of modules along each side of the QR code
  qm, without the quiet zone: 21 for version 1, 4 more for each version.
Example:
  (qr-matrix-size (qr-encode "hello")) => 21
```

### `qr-matrix-version`

```
Syntax: (qr-matrix-version qm)
Library: (scm qr)
Description: Returns the version (1 to 40) of the QR code qm, the smallest
  that holds its data at its error-correction level unless qr-encode was
  given one.
Example:
  (qr-matrix-version (qr-encode "hello")) => 1
```

### `qr-matrix?`

```
Syntax: (qr-matrix? x)
Library: (scm qr)
Description: Returns #t if x is a QR code made by qr-encode, #f otherwise.
Example:
  (qr-matrix? (qr-encode "hello")) => #t
```

