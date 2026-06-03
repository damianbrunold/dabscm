## Overview

`(scm compression)` provides raw in-memory compression and decompression of
bytevectors in three formats: DEFLATE, zlib, and gzip. Each format has a matching
`*-compress` / `*-decompress` pair.

## Common uses

```scheme
(import (scm compression))

(define data (string->utf8 "hello hello hello"))
(define packed (deflate-compress data))
(utf8->string (deflate-decompress packed))   ;; => "hello hello hello"
```

Use `zlib-compress` / `zlib-decompress` for zlib-wrapped streams and
`gzip-compress` / `gzip-decompress` for the gzip container format. For whole-file
archives and external tools see `(scm archive)`.
