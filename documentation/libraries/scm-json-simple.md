# `(scm json simple)`

## Exports

### `json->pretty-string`

```
Syntax: (json->pretty-string val)
Library: (scm json simple)
Description: Returns two-space-indented JSON text for val as a string
  (see json-write-pretty).
Example:
  (json->pretty-string '(("a" . 1))) => "{\n  \"a\": 1\n}"
```

### `json->string`

```
Syntax: (json->string val)
Library: (scm json simple)
Description: Returns compact JSON text for val as a string (see json-write).
Example:
  (json->string #(1 2 3)) => "[1,2,3]"
```

### `json-null?`

```
Syntax: (json-null? x)
Library: (scm json simple)
Description: Returns #t if x is the value json-parse produces for JSON null
  (the symbol 'null), #f otherwise.
Example:
  (json-null? (json-parse "null")) => #t
  (json-null? #f) => #f
```

### `json-parse`

```
Syntax: (json-parse str)
Library: (scm json simple)
Description: Parses the JSON text in string str and returns its Scheme
  representation: objects as alists with string keys (order preserved),
  arrays as vectors, strings as strings, integral numbers as exact
  integers and fractional ones as inexact reals, true/false as #t/#f,
  and null as the symbol 'null. Raises an error on malformed input.
Example:
  (json-parse "{\"a\": [1, 2.5, true, null]}")
    => (("a" . #(1 2.5 #t null)))
```

### `json-read`

```
Syntax: (json-read port)
Library: (scm json simple)
Description: Reads the entire textual input port to a string and parses it
  as a single JSON document (see json-parse). Returns the eof object if the
  port is empty.
Example:
  (json-read (open-input-string "[1, 2, 3]")) => #(1 2 3)
```

### `json-ref`

```
Syntax: (json-ref obj key [default])
Library: (scm json simple)
Description: Looks key (a string) up in obj, a parsed JSON object (alist).
  Returns the associated value, or default if absent (or #f when no default
  is given).
Example:
  (json-ref '(("a" . 1) ("b" . 2)) "b") => 2
  (json-ref '(("a" . 1)) "z" 'missing) => missing
```

### `json-write`

```
Syntax: (json-write val port)
Library: (scm json simple)
Description: Writes val to the output port as compact JSON (no insignificant
  whitespace). val must use the representation documented for this library
  (alists for objects, vectors for arrays, 'null for null).
Example:
  (json-write '(("a" . 1)) (current-output-port))  ; prints {"a":1}
```

### `json-write-pretty`

```
Syntax: (json-write-pretty val port)
Library: (scm json simple)
Description: Writes val to the output port as indented JSON using two spaces
  per level — byte-compatible with the common 2-space pretty style. Same
  value representation as json-write.
Example:
  (json-write-pretty '(("a" . 1)) (current-output-port))
    ; prints {\n  "a": 1\n}
```

