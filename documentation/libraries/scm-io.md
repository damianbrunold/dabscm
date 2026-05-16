# `(scm io)`

Extended I/O — formatting, port utilities, property lists

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

