# `(scheme write)`

Writing and displaying values to ports

## Exports

### `display`

```
Syntax: (display obj) (display obj port)
Library: (scheme write)
Description: Writes a human-readable representation of obj to the current output port or the given port. Strings are written without quotes; characters are written without the #\ prefix.
Example:
  (display "hello") => hello
  (display #\a) => a
```

### `newline`

```
Syntax: (newline) (newline port)
Library: (scheme write)
Description: Writes a newline character to the current output port or to the given port.
Example:
  (newline)
  (newline (open-output-string))
```

### `write`

```
Syntax: (write obj port?)
Library: (scheme write)
Description: Writes a machine-readable representation of obj to the given port, or the current output port. Strings are written with quotes and special characters escaped.
Example:
  (write '(1 "two" #\3)) => (1 "two" #\3)
  (write 'hello) => hello
```

### `write-shared`

```
Syntax: (write-shared obj port?)
Library: (scheme write)
Description: Writes obj to the given port using datum labels (#N= and #N#) to represent all shared and cyclic structure.
Example:
  (let ((x (list 1 2))) (write-shared x)) => (1 2)
  (write-shared '#0=(a . #0#)) => #0=(a . #0#)
```

### `write-simple`

```
Syntax: (write-simple obj port?)
Library: (scheme write)
Description: Writes obj to the given port without performing shared-structure detection, making it faster but unable to handle cyclic data.
Example:
  (write-simple '(1 2 3)) => (1 2 3)
  (write-simple "hello") => "hello"
```

