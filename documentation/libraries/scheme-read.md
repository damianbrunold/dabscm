# `(scheme read)`

Reading Scheme data from ports

## Exports

### `read`

```
Syntax: (read)
Library: (scheme read)
Description: Reads an external representation of a Scheme object from the given port and returns the object. If no more objects are available, an end-of-file object is returned. If port is omitted, the current input port is used.
Example:
  (define p (open-input-string "(a b c)"))
  (read p) => (a b c)
```

