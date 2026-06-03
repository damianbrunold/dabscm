# `(scm io)`

Extended I/O — formatting, port utilities, property lists

## Overview

`(scm io)` adds I/O conveniences on top of the R7RS ports: string/bytevector
capture, `format`-style output, and a few port utilities. Its `format` is shared
with SRFI-28 and SRFI-48.

## Common uses

Capture output into a string or bytevector:

```scheme
(import (scm io))

(call-with-output-string
  (lambda (p) (display "hi " p) (display 42 p)))    ;; => "hi 42"

(call-with-output-bytevector
  (lambda (p) (write-bytevector #u8(1 2 3) p)))     ;; => #u8(1 2 3)
```

Formatted strings — the first argument is the destination (`#f` for a string, or
a port):

```scheme
(format #f "~a + ~a = ~a" 1 2 3)    ;; => "1 + 2 = 3"
```

`read-chars` reads a fixed number of characters, `with-input-from-string` rebinds
the current input port, and `port-position` / `flush` round things out.


## Exports

### `call-with-input-string`

```
Syntax: (call-with-input-string str proc)
Library: (scm io)
Description: Opens a string input port on str and calls proc with it,
  returning the result of proc. The port is closed after proc returns,
  even if proc raises an error.
Example:
  (call-with-input-string "42" read) => 42
```

### `call-with-output-bytevector`

```
Syntax: (call-with-output-bytevector proc)
Library: (scm io)
Description: Calls proc with a fresh bytevector output port, then returns the
  accumulated output as a bytevector. The port is closed after proc returns,
  even if proc raises an error.
Example:
  (call-with-output-bytevector (lambda (p) (write-bytevector #u8(1 2 3) p)))
  => #u8(1 2 3)
```

### `call-with-output-string`

```
Syntax: (call-with-output-string proc)
Library: (scm io)
Description: Calls proc with a fresh string output port, then returns the
  accumulated output as a string. The port is closed after proc returns,
  even if proc raises an error.
Example:
  (call-with-output-string (lambda (p) (display "hello" p) (display " world" p)))
  => "hello world"
```

### `field-sep`

*(no documentation)*

### `file->lines`

```
Syntax: (file->lines path option ...)
Library: (scm io)
Description: Like read-file-lines, but returns #f if the file cannot be opened
  or read (for example it does not exist) instead of raising an error. Each
  option is passed on to open-input-file; supported options are an encoding
  (such as 'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to transparently
  inflate deflate-compressed input. The input port is always closed.
Example:
  (file->lines "hello.txt") => ("hello" "world")
  (file->lines "data.txt" 'latin-1) => ("...")
  (file->lines "missing.txt") => #f
```

### `file->string`

```
Syntax: (file->string path option ...)
Library: (scm io)
Description: Like read-file-string, but returns #f if the file cannot be opened
  or read (for example it does not exist) instead of raising an error. Each
  option is passed on to open-input-file; supported options are an encoding
  (such as 'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to transparently
  inflate deflate-compressed input. The input port is always closed.
Example:
  (file->string "hello.txt") => "hello\nworld\n"
  (file->string "data.txt" 'latin-1) => "..."
  (file->string "missing.txt") => #f
```

### `flush`

```
Syntax: (flush-output-port) (flush-output-port port)
Library: (scheme base)
Description: Flushes any buffered output in the given output port (or current output port if omitted).
Example:
  (flush-output-port)
```

### `format`

```
Syntax: (format dest fmt val ...)
Library: (scm io), (srfi 28), (srfi 48)
Description: Formats a string by substituting values for format
  directives in fmt.
  ~a  display (without quotes)
  ~s  write (with quotes)
  ~w  write with shared structure (datum labels)
  ~d  decimal integer
  ~x  hexadecimal integer (lowercase, signed)
  ~o  octal integer (signed)
  ~b  binary integer (signed)
  ~c  character
  ~y  pretty-print
  ~f  fixed-point float (~W,Df for width W and D decimal places)
  ~?  recursive format (takes format-string and arg-list)
  ~k  recursive format (alias for ~?)
  ~%  newline
  ~n  newline (alias)
  ~&  freshline (newline if not at start of line)
  ~t  tab
  ~_  space
  ~~  literal tilde
  ~h  help (display directive summary)
  Width/alignment: ~10a (right-align in 10), ~-10a (left-align).
  dest: #f (return string), #t (current output port), or a port.
Example:
  (format #f "~a + ~a = ~a" 1 2 3) => "1 + 2 = 3"
  (format #f "~d in hex is ~x" 255 255) => "255 in hex is ff"
```

### `line-sep`

*(no documentation)*

### `port-position`

```
Syntax: (port-position port)
Library: (scm core)
Description: Returns the current position of the textual input port as a list (filename line column).
Example:
  (define p (open-input-string "hello"))
  (port-position p) => ("{string}" 1 1)
```

### `read-chars`

```
Syntax: (read-chars n port)
Library: (scm io)
Description: Reads up to n characters from the textual input port and returns them as a string. Returns an end-of-file object if no characters are available.
Example:
  (define p (open-input-string "hello"))
  (read-chars 3 p) => "hel"
```

### `read-file-lines`

```
Syntax: (read-file-lines path option ...)
Library: (scm io)
Description: Reads the entire contents of the file at path and returns it as a
  list of strings, one per line, with line terminators removed. Each option is
  passed on to open-input-file; supported options are an encoding (such as
  'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to transparently inflate
  deflate-compressed input. If the file cannot be opened or read (for example
  it does not exist), an error is raised. Use file->lines for a variant that
  returns #f on error instead. The input port is always closed.
Example:
  (read-file-lines "hello.txt") => ("hello" "world")
  (read-file-lines "data.txt" 'latin-1) => ("...")
```

### `read-file-string`

```
Syntax: (read-file-string path option ...)
Library: (scm io)
Description: Reads the entire contents of the file at path and returns it as a
  string. Each option is passed on to open-input-file; supported options are
  an encoding (such as 'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to
  transparently inflate deflate-compressed input. If the file cannot be opened
  or read (for example it does not exist), an error is raised. Use file->string
  for a variant that returns #f on error instead. The input port is always
  closed.
Example:
  (read-file-string "hello.txt") => "hello\nworld\n"
  (read-file-string "data.txt" 'latin-1) => "..."
```

### `with-input-from-string`

```
Syntax: (with-input-from-string str thunk)
Library: (scm io)
Description: Temporarily redirects the current input port to a string input
  port opened on str, calls thunk with no arguments, then restores the
  original current input port and closes the string port. Returns the result
  of thunk. The port is restored even if thunk raises an error.
Example:
  (with-input-from-string "hello" read) => hello
```

