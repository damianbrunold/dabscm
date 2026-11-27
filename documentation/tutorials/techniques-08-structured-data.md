---
title: Structured data: JSON, XML, TOML, CSV
part: techniques
order: 8
libraries: (scm json simple) (scm xml) (scm toml) (scm csv) (scm data io) (scm data frame)
summary: Parsing and writing JSON, walking parsed data, reading XML with a pull parser, TOML configuration files, CSV lines and CSV files as data frames.
---
# Structured data: JSON, XML, TOML, CSV

All four formats map to ordinary Scheme data, so once a document is parsed
you work with alists, vectors, strings and numbers.

```scheme
(import (scheme base) (scheme file) (scheme write) (srfi 1)
        (scm json simple) (scm xml) (scm toml) (scm csv)
        (scm fs) (scm data io) (scm data frame))
```

## JSON

`(scm json simple)` maps JSON objects to alists with string keys, arrays to
vectors, `null` to the symbol `null`:

```scheme
(define doc
  (json-parse "{\"name\": \"dabscm\", \"version\": [2, 28, 1],
                \"tags\": [\"scheme\", \"r7rs\"], \"license\": null}"))

doc
;; => (("name" . "dabscm") ("version" . #(2 28 1)) ("tags" . #("scheme" "r7rs")) ("license" . null))
(json-ref doc "name")                       ;; => "dabscm"
(vector->list (json-ref doc "tags"))        ;; => ("scheme" "r7rs")
(json-null? (json-ref doc "license"))       ;; => #t
(json-ref doc "homepage" "none")            ;; => "none"
```

Arrays are vectors and objects are lists, so the two can never be confused.
Writing goes the other way:

```scheme
(json->string '(("ok" . #t) ("items" . #(1 2 3)) ("next" . null)))
;; => "{\"ok\":true,\"items\":[1,2,3],\"next\":null}"
(json->string #())                          ;; => "[]"
(json->string '())                          ;; => "{}"
```

### Example: summarising API data

A typical JSON response, a list of records. Total the order values per
customer:

```scheme
(define orders
  (json-parse "[{\"customer\": \"ada\", \"total\": 30.5},
                {\"customer\": \"alan\", \"total\": 12},
                {\"customer\": \"ada\", \"total\": 9.5}]"))

(define (sum-by key value records)
  (fold (lambda (r acc)
          (let* ((k (json-ref r key)) (e (assoc k acc)))
            (if e
                (begin (set-cdr! e (+ (cdr e) (json-ref r value))) acc)
                (cons (cons k (json-ref r value)) acc))))
        '()
        (vector->list records)))

(reverse (sum-by "customer" "total" orders)) ;; => (("ada" . 40.0) ("alan" . 12))
(json->string (reverse (sum-by "customer" "total" orders)))
;; => "{\"ada\":40.0,\"alan\":12}"
```

The result alist is itself valid JSON data, so `json->string` writes it
directly.

## XML

`(scm xml)` is a *pull parser*: you call `xml-read` to advance to the next
node and ask about the current node. It handles large files without loading
them completely:

```scheme
(define feed "<catalog>
  <book id=\"b1\" year=\"1965\"><title>Dune</title></book>
  <book id=\"b2\" year=\"1984\"><title>Neuromancer</title></book>
</catalog>")

(define (book-titles xml)
  (let ((r (open-xml-string xml)))
    (let loop ((acc '()))
      (if (xml-read-to r "title")
          (loop (cons (xml-value r) acc))
          (begin (close-xml r) (reverse acc))))))

(book-titles feed)                          ;; => ("Dune" "Neuromancer")
```

`xml-read-to` skips ahead to the next element with the given name, and
`xml-value` reads its text. When you need several kinds of nodes, walk all
of them with `xml-read` and look at each one:

```scheme

(define (book-years xml)
  (let ((r (open-xml-string xml)))
    (let loop ((acc '()))
      (if (xml-read r)
          (loop (if (and (eq? (xml-node-type r) 'element) (equal? (xml-name r) "book"))
                    (cons (cons (xml-attribute r "id")
                                (string->number (xml-attribute r "year")))
                          acc)
                    acc))
          (begin (close-xml r) (reverse acc))))))

(book-years feed)                           ;; => (("b1" . 1965) ("b2" . 1984))
```

For HTML, `(scm html parser)` builds a tree (SXML) instead, and
`(scm html builder)` writes HTML from such trees.

## TOML

TOML is a good format for configuration files. Tables become alists, arrays
vectors:

```scheme
(define config
  (toml-parse "title = \"Shop\"
[server]
port = 8080
hosts = [\"a.example\", \"b.example\"]

[database]
url = \"postgres://localhost/shop\"
pool = 4"))

(toml-ref (toml-ref config "server") "port") ;; => 8080
(vector-length (toml-ref (toml-ref config "server") "hosts")) ;; => 2
(toml-ref (toml-ref config "database") "pool" 1) ;; => 4
(toml-ref config "debug" #f)                ;; => #f

(toml->string '(("name" . "demo") ("limits" ("max" . 10))))
;; => "name = \"demo\"\n\n[limits]\nmax = 10\n"
```

Defaults through the optional third argument of `toml-ref` make
configuration code short: every setting has an obvious fallback.

## CSV

For one line, `csv-line->fields` splits at a separator and removes quotes:

```scheme
(csv-line->fields "ada,\"Lovelace\",1815" ",") ;; => #("ada" "Lovelace" "1815")
(csv-line->fields "a; b ;c" ";" 'trim)      ;; => #("a" "b" "c")
```

For whole files, `read-csv` from `(scm data io)` handles everything RFC 4180
allows (quoted separators, doubled quotes, line breaks in fields), detects
the separator, and infers column types. The result is a *data frame*:

```scheme
(define dir (mktempdir '(prefix . "csv")))
(define path (join-path dir "people.csv"))

(call-with-output-file path
  (lambda (out)
    (display "name;born;city\n" out)
    (display "\"Lovelace, Ada\";1815;London\n" out)
    (display "Turing;1912;London\n" out)
    (display "Hopper;1906;\"New York\"\n" out)))

(define people (read-csv path))
(df-nrow people)                            ;; => 3
(df-names people)                           ;; => (name born city)
(vector-ref (df-column people 'name) 0)     ;; => "Lovelace, Ada"
(df-column people 'born)                    ;; => #(1815 1912 1906)
(df-row people 2)                           ;; => ((name . "Hopper") (born . 1906) (city . "New York"))

(rm dir 'recursive)
```

The semicolon was detected, the quoted comma stayed inside its field, and
the `born` column became numbers. The [data tutorial](scm-data.md) shows
what to do with frames: filtering, grouping, summarising, plotting and
writing to Excel.

## Where next

- [Command-line programs](techniques-09-command-line.md).
- `(scm json simple)`, `(scm json)` for streaming, `(scm xml)`, `(scm toml)`,
  `(scm data io)`.
