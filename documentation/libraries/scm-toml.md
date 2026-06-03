# `(scm toml)`

TOML reading and writing

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

