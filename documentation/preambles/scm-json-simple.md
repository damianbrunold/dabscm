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
