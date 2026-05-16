# `(scm doc)`

Documentation access

## Exports

### `doc`

```
Syntax: (doc obj)
Library: (scm core)
Description: Prints documentation for obj to the current output port. obj may be
  a procedure, primitive, macro, or symbol naming one. Returns unspecified.
Example:
  (doc car) => prints documentation for car
```

### `procedure-doc`

```
Syntax: (procedure-doc obj)
Library: (scm core)
Description: Returns the documentation string for obj as a Scheme string, or #f
  if no documentation is available. obj may be a procedure, primitive, macro,
  or symbol naming one.
Example:
  (string? (procedure-doc car)) => #t
```

