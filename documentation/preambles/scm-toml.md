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
