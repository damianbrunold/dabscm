# `(scm bytevector)`

Multi-byte integers and IEEE floats in bytevectors, either byte order

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


## Exports

### `bytevector-ieee-double-ref`

```
Syntax: (bytevector-ieee-double-ref bv k endianness)
Library: (scm bytevector)
Description: Returns the IEEE 754 double-precision float stored at byte index k of bv,
  an exact integer None. The 8 bytes at k must lie within bv;
  endianness is the symbol big or little.
Example:
  (bytevector-ieee-double-ref #u8(0 0 0 0 0 0 240 63) 0 'little) => 1.0
```

### `bytevector-ieee-double-set!`

```
Syntax: (bytevector-ieee-double-set! bv k n endianness)
Library: (scm bytevector)
Description: Stores the exact integer n, which must be None, as
  an IEEE 754 double-precision float at byte index k of bv. The 8 bytes at k must lie
  within bv; endianness is the symbol big or little.
Example:
  (let ((bv (make-bytevector 8 0))) (bytevector-ieee-double-set! bv 0 1.0 'big) bv) => #u8(63 240 0 0 0 0 0 0)
```

### `bytevector-ieee-single-ref`

```
Syntax: (bytevector-ieee-single-ref bv k endianness)
Library: (scm bytevector)
Description: Returns the IEEE 754 single-precision float stored at byte index k of bv,
  as an inexact real. The 4 bytes at k must lie within bv;
  endianness is the symbol big or little.
Example:
  (bytevector-ieee-single-ref #u8(0 0 128 63) 0 'little) => 1.0
```

### `bytevector-ieee-single-set!`

```
Syntax: (bytevector-ieee-single-set! bv k x endianness)
Library: (scm bytevector)
Description: Stores the real x as an IEEE 754 single-precision float at byte index k of bv
  (rounded to the nearest representable value). The 4 bytes at k
  must lie within bv; endianness is the symbol big or little.
Example:
  (let ((bv (make-bytevector 4 0))) (bytevector-ieee-single-set! bv 0 1.0 'big) bv) => #u8(63 128 0 0)
```

### `bytevector-s16-ref`

```
Syntax: (bytevector-s16-ref bv k endianness)
Library: (scm bytevector)
Description: Returns the signed 16-bit integer stored at byte index k of bv,
  an exact integer in [-32768, 32767]. The 2 bytes at k must lie within bv;
  endianness is the symbol big or little.
Example:
  (bytevector-s16-ref #u8(255 255) 0 'big) => -1
```

### `bytevector-s16-set!`

```
Syntax: (bytevector-s16-set! bv k n endianness)
Library: (scm bytevector)
Description: Stores the exact integer n, which must be in [-32768, 32767], as
  an signed 16-bit integer at byte index k of bv. The 2 bytes at k must lie
  within bv; endianness is the symbol big or little.
Example:
  (let ((bv (make-bytevector 2 0))) (bytevector-s16-set! bv 0 -2 'little) bv) => #u8(254 255)
```

### `bytevector-s32-ref`

```
Syntax: (bytevector-s32-ref bv k endianness)
Library: (scm bytevector)
Description: Returns the signed 32-bit integer stored at byte index k of bv,
  an exact integer in [-2147483648, 2147483647]. The 4 bytes at k must lie within bv;
  endianness is the symbol big or little.
Example:
  (bytevector-s32-ref #u8(255 255 255 255) 0 'little) => -1
```

### `bytevector-s32-set!`

```
Syntax: (bytevector-s32-set! bv k n endianness)
Library: (scm bytevector)
Description: Stores the exact integer n, which must be in [-2147483648, 2147483647], as
  an signed 32-bit integer at byte index k of bv. The 4 bytes at k must lie
  within bv; endianness is the symbol big or little.
Example:
  (let ((bv (make-bytevector 4 0))) (bytevector-s32-set! bv 0 -1 'big) bv) => #u8(255 255 255 255)
```

### `bytevector-u16-ref`

```
Syntax: (bytevector-u16-ref bv k endianness)
Library: (scm bytevector)
Description: Returns the unsigned 16-bit integer stored at byte index k of bv,
  an exact integer in [0, 65535]. The 2 bytes at k must lie within bv;
  endianness is the symbol big or little.
Example:
  (bytevector-u16-ref #u8(1 2) 0 'little) => 513
```

### `bytevector-u16-set!`

```
Syntax: (bytevector-u16-set! bv k n endianness)
Library: (scm bytevector)
Description: Stores the exact integer n, which must be in [0, 65535], as
  an unsigned 16-bit integer at byte index k of bv. The 2 bytes at k must lie
  within bv; endianness is the symbol big or little.
Example:
  (let ((bv (make-bytevector 2 0))) (bytevector-u16-set! bv 0 513 'big) bv) => #u8(2 1)
```

### `bytevector-u32-ref`

```
Syntax: (bytevector-u32-ref bv k endianness)
Library: (scm bytevector)
Description: Returns the unsigned 32-bit integer stored at byte index k of bv,
  an exact integer in [0, 4294967295]. The 4 bytes at k must lie within bv;
  endianness is the symbol big or little.
Example:
  (bytevector-u32-ref #u8(0 0 1 0) 0 'big) => 256
```

### `bytevector-u32-set!`

```
Syntax: (bytevector-u32-set! bv k n endianness)
Library: (scm bytevector)
Description: Stores the exact integer n, which must be in [0, 4294967295], as
  an unsigned 32-bit integer at byte index k of bv. The 4 bytes at k must lie
  within bv; endianness is the symbol big or little.
Example:
  (let ((bv (make-bytevector 4 0))) (bytevector-u32-set! bv 0 256 'little) bv) => #u8(0 1 0 0)
```

### `latin1->string`

```
Syntax: (latin1->string bv [start [end]])
Library: (scm bytevector)
Description: Decodes the bytes of bv (or its range from start to end)
as ISO-8859-1 (Latin-1): each byte becomes the character with the same
code. Never fails.
Example:
  (latin1->string (bytevector #x61 #xE4)) => "a\xE4;"
```

### `string->latin1`

```
Syntax: (string->latin1 s [replacement [start [end]]])
Library: (scm bytevector)
Description: Encodes the string s (or its range from start to end) as
ISO-8859-1 (Latin-1) and returns a bytevector. A character above #xFF
(a surrogate pair counts as one character) is an error unless
replacement is given: a byte value 0-255 written in its place.
Example:
  (string->latin1 "a\xE4;") => #u8(97 228)
  (string->latin1 "a\x20AC;" 63) => #u8(97 63)
```

### `utf8-valid?`

```
Syntax: (utf8-valid? bv [start [end]])
Library: (scm bytevector)
Description: Returns #t if the bytes of bv (or its range from start to
end) are well-formed UTF-8, #f otherwise. Use it to decide whether
utf8->string would replace any bytes with U+FFFD, for example to tell
UTF-8 files from Latin-1 ones.
Example:
  (utf8-valid? (bytevector #xC3 #xA4)) => #t
  (utf8-valid? (bytevector #xE4)) => #f
```

