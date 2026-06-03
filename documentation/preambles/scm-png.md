## Overview

`(scm png)` is a minimal PNG writer: it turns raw 8-bit pixel data into a valid
PNG bytevector. It supports grayscale, RGB, grayscale+alpha, and RGBA, all at bit
depth 8, with one helper per color type plus a generic `png-encode`.

## Common uses

```scheme
(import (scm png))

;; a 2x1 grayscale image (one black pixel, one white)
(png-encode-grayscale 2 1 (bytevector 0 255))   ;; => a PNG bytevector

;; generic form: width height pixels color-type (0=gray, 2=RGB, 4=GA, 6=RGBA)
(png-encode 2 2 (bytevector 0 255 255 0) 0)
```

Write the bytevector to disk with `write-png-file`. Pixels are row-major,
top-to-bottom, with no padding; sample order within a pixel follows the color
type. `crc32` is exposed for callers that need it.
