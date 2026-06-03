# `(scm png)`

PNG image writing — grayscale, RGB, and RGBA

## Exports

### `crc32`

```
Syntax: (crc32 bytevector [start [end]])
Library: (scm png)
Description: Computes the IEEE CRC-32 checksum (polynomial 0xEDB88320,
  as used by PNG, gzip, zip) of bytevector and returns it as an exact
  non-negative integer in [0, 2^32).
Example:
  (crc32 (string->utf8 "123456789")) => 3421780262
```

### `png-encode`

```
Syntax: (png-encode width height pixels color-type)
Library: (scm png)
Description: Encodes an 8-bit-per-sample image as a PNG bytevector.
  color-type is one of 0 (grayscale), 2 (RGB), 4 (grayscale+alpha), or
  6 (RGBA). pixels is a row-major bytevector of length
  width*height*samples-per-pixel.
Example:
  ;; 2x2 grayscale checkerboard
  (png-encode 2 2 (bytevector 0 255 255 0) 0)
```

### `png-encode-grayscale`

```
Syntax: (png-encode-grayscale width height pixels)
Library: (scm png)
Description: Encodes 8-bit grayscale pixels (one byte per pixel, 0=black,
  255=white) as a PNG bytevector.
Example:
  (png-encode-grayscale 2 1 (bytevector 0 255))
```

### `png-encode-rgb`

```
Syntax: (png-encode-rgb width height pixels)
Library: (scm png)
Description: Encodes 24-bit RGB pixels (three bytes per pixel in R,G,B
  order) as a PNG bytevector.
Example:
  (png-encode-rgb 1 1 (bytevector 255 0 0))   ; single red pixel
```

### `png-encode-rgba`

```
Syntax: (png-encode-rgba width height pixels)
Library: (scm png)
Description: Encodes 32-bit RGBA pixels (four bytes per pixel in R,G,B,A
  order) as a PNG bytevector.
Example:
  (png-encode-rgba 1 1 (bytevector 255 0 0 128))
```

### `write-png-file`

```
Syntax: (write-png-file path png-bytevector)
Library: (scm png)
Description: Writes a PNG bytevector (as produced by png-encode and
  friends) to the named file.
Example:
  (write-png-file "out.png" (png-encode-grayscale 1 1 (bytevector 0)))
```

