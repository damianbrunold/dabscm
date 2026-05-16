# `(scm compression)`

Data compression and decompression

## Exports

### `deflate-compress`

```
Syntax: (deflate-compress bytevector [level])
Library: (scm compression)
Description: Compresses bytevector using raw DEFLATE (RFC 1951) and returns
  a bytevector. The optional level is an integer 0-9: 0 = no compression,
  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.
Example:
  (utf8->string (deflate-decompress (deflate-compress (string->utf8 "hello")))) => "hello"
```

### `deflate-decompress`

```
Syntax: (deflate-decompress bytevector)
Library: (scm compression)
Description: Decompresses a raw DEFLATE-compressed (RFC 1951) bytevector
  and returns the original bytevector.
Example:
  (utf8->string (deflate-decompress (deflate-compress (string->utf8 "hello")))) => "hello"
```

### `gzip-compress`

```
Syntax: (gzip-compress bytevector [level])
Library: (scm compression)
Description: Compresses bytevector using GZip format (RFC 1952) and returns
  a bytevector. The optional level is an integer 0-9: 0 = no compression,
  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.
Example:
  (utf8->string (gzip-decompress (gzip-compress (string->utf8 "hello")))) => "hello"
```

### `gzip-decompress`

```
Syntax: (gzip-decompress bytevector)
Library: (scm compression)
Description: Decompresses a GZip-compressed (RFC 1952) bytevector and returns
  the original bytevector.
Example:
  (utf8->string (gzip-decompress (gzip-compress (string->utf8 "hello")))) => "hello"
```

### `zlib-compress`

```
Syntax: (zlib-compress bytevector [level])
Library: (scm compression)
Description: Compresses bytevector using ZLib framing (RFC 1950) and returns
  a bytevector. The optional level is an integer 0-9: 0 = no compression,
  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.
Example:
  (utf8->string (zlib-decompress (zlib-compress (string->utf8 "hello")))) => "hello"
```

### `zlib-decompress`

```
Syntax: (zlib-decompress bytevector)
Library: (scm compression)
Description: Decompresses a ZLib-framed (RFC 1950) bytevector and returns
  the original bytevector.
Example:
  (utf8->string (zlib-decompress (zlib-compress (string->utf8 "hello")))) => "hello"
```

