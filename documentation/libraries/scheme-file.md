# `(scheme file)`

File-based port operations

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


## Exports

### `call-with-input-file`

```
Syntax: (call-with-input-file filename proc)
Library: (scheme file)
Description: Opens the file named by filename for input and calls proc with the resulting input port
  as its sole argument. When proc returns, the port is closed automatically via dynamic-wind, even
  if a non-local exit occurs. Returns the value(s) returned by proc. filename may also be a list
  whose car is the filename and whose remaining elements are options passed to open-input-file.
Example:
  (call-with-input-file "data.txt"
    (lambda (port) (read port))) => <first datum from file>
```

### `call-with-output-file`

```
Syntax: (call-with-output-file filename proc)
Library: (scheme file)
Description: Opens the file named by filename for output and calls proc with the resulting output
  port as its sole argument. When proc returns, the port is closed automatically via dynamic-wind,
  even if a non-local exit occurs. Returns the value(s) returned by proc. filename may also be a
  list whose car is the filename and whose remaining elements are options passed to open-output-file.
Example:
  (call-with-output-file "out.txt"
    (lambda (port) (write 42 port))) => <unspecified>
```

### `close-input-port`

```
Syntax: (close-input-port port)
Library: (scheme base)
Description: Closes the input port, releasing any resources. It is an error to read from a closed port.
Example:
  (let ((p (open-input-file "data.txt")))
    (close-input-port p))
```

### `close-output-port`

```
Syntax: (close-output-port port)
Library: (scheme base)
Description: Closes the output port, flushing any buffered output and releasing resources.
Example:
  (let ((p (open-output-file "out.txt")))
    (close-output-port p))
```

### `delete-file`

```
Syntax: (delete-file filename)
Library: (scheme file)
Description: Deletes the named file. Returns unspecified if successful, #f if the file could not be deleted.
Example:
  (delete-file "temp.txt")
```

### `file-exists?`

```
Syntax: (file-exists? filename)
Library: (scheme file)
Description: Returns #t if the named file exists, otherwise returns #f.
Example:
  (file-exists? "/etc/hosts") => #t
  (file-exists? "/nonexistent") => #f
```

### `open-binary-input-file`

```
Syntax: (open-binary-input-file filename)
Library: (scheme file)
Description: Opens the named file for binary input and returns a binary input port. Raises a file-error if the file cannot be opened.
Example:
  (let ((p (open-binary-input-file "data.bin")))
    (read-u8 p))
```

### `open-binary-output-file`

```
Syntax: (open-binary-output-file filename)
Library: (scheme file)
Description: Opens the named file for binary output and returns a binary output port. Creates or truncates the file. Raises a file-error on failure.
Example:
  (let ((p (open-binary-output-file "out.bin")))
    (write-u8 42 p))
```

### `open-input-file`

```
Syntax: (open-input-file filename)
        (open-input-file filename option ...)
Library: (scheme file)
Description: Takes a filename and returns a textual input port that reads characters from the named file. It is an error if the file cannot be opened.
  As a non-standard extension, up to two optional arguments may follow the filename. They are symbols (strings are also accepted):
    - an encoding name selects the character encoding (default 'utf-8; also 'latin-1 / 'iso-8859-1, 'utf-16, 'utf-16-le)
    - 'deflate decompresses a DEFLATE-compressed file while reading (as written by open-output-file ... 'deflate)
Example:
  (define p (open-input-file "data.txt"))
  (read-char p) => first character of file
  (open-input-file "legacy.txt" 'latin-1)  ; decode as Latin-1
  (open-input-file "data.z" 'deflate)      ; read compressed input
```

### `open-output-file`

```
Syntax: (open-output-file filename)
        (open-output-file filename option ...)
Library: (scheme file)
Description: Takes a filename and returns a textual output port that writes characters to the named file. The file is created or truncated. It is an error if the file cannot be opened.
  As a non-standard extension, up to three optional arguments may follow the filename. They are symbols (strings are also accepted):
    - an encoding name selects the character encoding (default 'utf-8; also 'utf-8-bom, 'latin-1 / 'iso-8859-1, 'utf-16, 'utf-16-le)
    - 'deflate writes a DEFLATE-compressed stream (read it back with open-input-file ... 'deflate)
    - 'append appends to the file instead of truncating it
Example:
  (define p (open-output-file "out.txt"))
  (write-char #\A p)
  (open-output-file "log.txt" 'append 'latin-1)  ; append, Latin-1
  (open-output-file "data.z" 'deflate)           ; compressed output
```

### `with-input-from-file`

```
Syntax: (with-input-from-file filename thunk)
Library: (scheme file)
Description: Opens the file named by filename for input, makes it the current input port, and calls
  thunk with no arguments. When thunk returns, the original current input port is restored and the
  opened port is closed, both managed via dynamic-wind so they occur even on non-local exits.
  Returns the value(s) returned by thunk. filename may also be a list whose car is the filename
  and whose remaining elements are options passed to open-input-file.
Example:
  (with-input-from-file "data.txt"
    (lambda () (read))) => <first datum from file>
```

### `with-output-to-file`

```
Syntax: (with-output-to-file filename thunk)
Library: (scheme file)
Description: Opens the file named by filename for output, makes it the current output port, and
  calls thunk with no arguments. When thunk returns, the original current output port is restored
  and the opened port is closed, both managed via dynamic-wind so they occur even on non-local
  exits. Returns the value(s) returned by thunk. filename may also be a list whose car is the
  filename and whose remaining elements are options passed to open-output-file.
Example:
  (with-output-to-file "out.txt"
    (lambda () (display "hello"))) => <unspecified>
```

