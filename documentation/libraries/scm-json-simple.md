# `(scm json simple)`

High-level JSON codec — parse and serialize JSON as Scheme data

## Overview

`(scm json simple)` is a high-level JSON codec that maps JSON to and from
ordinary Scheme data. It complements the low-level streaming reader in
`(scm json)`: this one parses a whole document into a value you can walk, and —
unlike `(scm json)` — can also serialize a value back to JSON, with optional
pretty-printing.

## Data mapping

- **object** — alist `(("key" . value) ...)`, order preserved; `'()` is `{}`
- **array** — vector `#(v ...)`; `#()` is `[]`
- **string** — string
- **number** — exact integer when integral, else inexact real
- **true / false** — `#t` / `#f`
- **null** — the symbol `null` (test with `json-null?`)

Objects are alists and arrays are vectors so the two never alias.

## Parsing

```scheme
(import (scm json simple))

(json-parse "{\"a\": [1, 2.5, true, null]}")
;; => (("a" . #(1 2.5 #t null)))

(json-ref (json-parse "{\"port\": 8080}") "port")   ;; => 8080
```

Use `json-read` to parse from a port, and `json-ref` to look a key up in a parsed
object with an optional default.

## Serializing

```scheme
(json->string '(("x" . 1) ("y" . #(2 3))))
;; => "{\"x\":1,\"y\":[2,3]}"

(json->pretty-string '(("a" . 1)))
;; => "{\n  \"a\": 1\n}"
```

`json->string` is compact; `json->pretty-string` uses two-space indentation.
Both round-trip a parsed value back to equivalent JSON.


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

