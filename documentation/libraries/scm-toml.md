# `(scm toml)`

TOML reading and writing

## Overview

`(scm toml)` reads and writes [TOML](https://toml.io) 1.0, mapping it to and from
ordinary Scheme data. `toml-parse` / `toml-read` turn a document into a value you
can walk; `toml->string` / `toml-write` serialize a value back to TOML text.

## Data mapping

- **table** — alist `(("key" . value) ...)`, order preserved; `'()` is the empty table
- **array** — vector `#(v ...)`
- **string** — string
- **integer** — exact integer
- **float** — inexact real
- **boolean** — `#t` / `#f`
- **date-time** — a `toml-datetime` record (kind + raw text)

Because tables are alists and arrays are vectors, the two never alias: any list
is a table, any vector an array.

## Reading

```scheme
(import (scm toml))

(toml-parse "title = \"TOML\"\n[owner]\nname = \"Tom\"")
;; => (("title" . "TOML") ("owner" ("name" . "Tom")))

(toml-ref (toml-parse "port = 8080") "port")   ;; => 8080
```

Use `toml-read` to parse straight from a port (e.g. a file), and `toml-ref` to
look a key up in a parsed table with an optional default.

## Writing

```scheme
(toml->string '(("a" . 1) ("t" ("b" . 2))))
;; => "a = 1\n\n[t]\nb = 2\n"
```

Scalar entries are emitted first, then nested tables as `[header]` sections and
arrays of tables as `[[header]]` sections. Parsed values round-trip back to
equivalent TOML.

## Date-times

TOML dates and times parse to a distinct `toml-datetime` record so they never
get confused with strings:

```scheme
(define dt (toml-ref (toml-parse "when = 1979-05-27T07:32:00Z") "when"))
(toml-datetime? dt)        ;; => #t
(toml-datetime-kind dt)    ;; => offset-date-time
(toml-datetime-text dt)    ;; => "1979-05-27T07:32:00Z"
```

`toml-write` emits a `toml-datetime` as its raw text, unquoted.


## Exports

### `make-toml-datetime`

*(no documentation)*

### `toml->string`

```
Syntax: (toml->string val)
Library: (scm toml)
Description: Returns TOML text for val (a table) as a string (see toml-write).
Example:
  (toml->string '(("a" . 1))) => "a = 1\n"
```

### `toml-datetime-kind`

*(no documentation)*

### `toml-datetime-text`

*(no documentation)*

### `toml-datetime?`

*(no documentation)*

### `toml-parse`

```
Syntax: (toml-parse str)
Library: (scm toml)
Description: Parses the TOML text in string str and returns its Scheme
  representation: tables as alists with string keys (order preserved),
  arrays as vectors, strings as strings, integers as exact integers, floats
  as inexact reals, booleans as #t/#f, and dates/times as toml-datetime
  values. The result of a whole document is always a table. Raises an error
  on malformed input.
Example:
  (toml-parse "title = \"TOML\"\n[owner]\nname = \"Tom\"")
    => (("title" . "TOML") ("owner" ("name" . "Tom")))
```

### `toml-read`

```
Syntax: (toml-read port)
Library: (scm toml)
Description: Reads the entire textual input port to a string and parses it
  as a single TOML document (see toml-parse). Returns the eof object if the
  port is empty.
Example:
  (toml-read (open-input-string "a = 1")) => (("a" . 1))
```

### `toml-ref`

```
Syntax: (toml-ref table key [default])
Library: (scm toml)
Description: Looks key (a string) up in table, a parsed TOML table (alist).
  Returns the associated value, or default if absent (or #f when no default
  is given).
Example:
  (toml-ref '(("a" . 1) ("b" . 2)) "b") => 2
  (toml-ref '(("a" . 1)) "z" 'missing) => missing
```

### `toml-write`

```
Syntax: (toml-write val port)
Library: (scm toml)
Description: Writes val to the output port as TOML text. val must be a table
  (an alist with string keys) using the representation documented for this
  library. Scalar entries are emitted first, then nested tables as [header]
  sections and arrays of tables as [[header]] sections.
Example:
  (toml-write '(("a" . 1) ("t" ("b" . 2))) (current-output-port))
    ; prints  a = 1\n\n[t]\nb = 2
```

