## Overview

`(scm bytevector)` reads and writes multi-byte numbers inside bytevectors:
16- and 32-bit integers, signed and unsigned, and IEEE 754 single and
double floats. The names and arguments follow R6RS `(rnrs bytevectors)`;
the byte order is the symbol `big` or `little`, and the index is a byte
index, not aligned to the size.

## Common uses

Decoding binary file formats, such as the header of an ESRI shapefile:

```scheme
(import (scheme base) (scheme file) (scm bytevector))

(define bv (call-with-port (open-binary-input-file "map.shp")
             (lambda (p) (read-bytevector 100 p))))
(bytevector-u32-ref bv 0 'big)           ;; => 9994, the file code
(bytevector-s32-ref bv 32 'little)       ;; => 5, polygons
(bytevector-ieee-double-ref bv 36 'little) ;; => the bounding box's xmin
```
