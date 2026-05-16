# `(scheme file)`

File-based port operations

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
Library: (scheme file)
Description: Takes a filename and returns a textual input port that reads characters from the named file. It is an error if the file cannot be opened.
Example:
  (define p (open-input-file "data.txt"))
  (read-char p) => first character of file
```

### `open-output-file`

```
Syntax: (open-output-file filename)
Library: (scheme file)
Description: Takes a filename and returns a textual output port that writes characters to the named file. The file is created or truncated. It is an error if the file cannot be opened.
Example:
  (define p (open-output-file "out.txt"))
  (write-char #\A p)
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

