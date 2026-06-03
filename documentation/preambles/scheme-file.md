## Overview

`(scheme file)` provides file-based ports: open files for input or output (textual
or binary), the `call-with-…` / `with-…` forms that manage a port's lifetime, and
file existence/deletion.

## Common uses

```scheme
(import (scheme base) (scheme file))

;; write a file
(call-with-output-file "greeting.txt"
  (lambda (p) (write-string "hello" p)))

;; read it back
(call-with-input-file "greeting.txt"
  (lambda (p) (read-line p)))        ;; => "hello"

(file-exists? "greeting.txt")        ;; => #t
(delete-file "greeting.txt")
```

`with-input-from-file` / `with-output-to-file` rebind the current ports for the
duration of a thunk; `open-binary-input-file` / `open-binary-output-file` open
byte streams.

## Non-standard extensions

As an extension, `open-input-file` and `open-output-file` accept optional symbol
arguments after the filename (strings are also accepted, but symbols read more
cleanly):

- an **encoding** name selects the character encoding (default `'utf-8`; also
  `'utf-8-bom`, `'latin-1` / `'iso-8859-1`, `'utf-16`, `'utf-16-le`)
- `'deflate` transparently DEFLATE-compresses output / decompresses input
- `'append` (output only) appends to the file instead of truncating it

```scheme
;; write a Latin-1 file in append mode
(open-output-file "log.txt" 'append 'latin-1)
```

The `call-with-…` / `with-…` forms accept the same options by passing a
`(filename option ...)` list in place of the filename:

```scheme
;; write and read back a compressed file
(call-with-output-file '("data.z" deflate)
  (lambda (p) (write-string "hello" p)))
(call-with-input-file '("data.z" deflate)
  (lambda (p) (read-line p)))         ;; => "hello"
```
