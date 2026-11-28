---
title: (scm json simple) and (scm json): JSON
part: libraries
order: 1015
libraries: (scm json simple) (scm json)
summary: The JSON-to-Scheme mapping, parsing and writing, pretty-printing, ports, safe lookups in nested documents, building API responses, merging configuration, streaming large and newline-delimited files.
---
# (scm json simple) and (scm json): JSON

- `(scm json simple)` parses a whole document into ordinary Scheme data
  and writes data back as JSON;
- `(scm json)` streams the top-level objects of a large file one by one.

The [structured data](techniques-08-structured-data.md) chapter has a first
look; this one goes further.

```scheme
(import (scheme base) (scheme char) (scheme write) (srfi 1)
        (scm json simple) (scm json))
```

## The mapping

| JSON | Scheme |
|---|---|
| object `{"a": 1}` | alist with string keys `(("a" . 1))`, in document order |
| array `[1, 2]` | vector `#(1 2)` |
| string | string |
| number | exact integer if integral, else inexact real |
| `true` / `false` | `#t` / `#f` |
| `null` | the symbol `null` |

```scheme
(json-parse "{\"name\": \"Ada\", \"born\": 1815, \"langs\": [\"en\", \"fr\"], \"died\": null}")
;; => (("name" . "Ada") ("born" . 1815) ("langs" . #("en" "fr")) ("died" . null))
(json-parse "[1, 2.5, 1e3, true]")         ;; => #(1 2.5 1000.0 #t)
(json-parse "{\"e\": {}, \"a\": []}")      ;; => (("e") ("a" . #()))
(json-parse "\"caf\\u00e9\"")             ;; => "café"
```

The empty object is the empty list, so `("e")` above is the pair
`("e" . ())`. Because objects are lists and arrays vectors, the two can
always be told apart.

## Looking things up

`json-ref` takes an object, a key and an optional default:

```scheme
(define release
  (json-parse "{\"tag\": \"v2.29\", \"author\": {\"login\": \"dab\"},
                \"assets\": [{\"name\": \"scm.deb\", \"size\": 5120},
                             {\"name\": \"scm.zip\", \"size\": 7340}]}"))

(json-ref release "tag")                   ;; => "v2.29"
(json-ref (json-ref release "author") "login") ;; => "dab"
(json-ref release "draft" #f)              ;; => #f
```

Deeply nested data reads better with a small path helper: strings index
objects, numbers index arrays, and a missing step gives the default:

```scheme
(define (json-path doc path . default)
  (let ((missing (if (pair? default) (car default) #f)))
    (let loop ((v doc) (path path))
      (cond ((null? path) v)
            ((and (string? (car path)) (list? v) (assoc (car path) v))
             => (lambda (e) (loop (cdr e) (cdr path))))
            ((and (exact-integer? (car path)) (vector? v)
                  (< -1 (car path) (vector-length v)))
             (loop (vector-ref v (car path)) (cdr path)))
            (else missing)))))

(json-path release '("assets" 1 "name"))   ;; => "scm.zip"
(json-path release '("assets" 5 "name") "?") ;; => "?"
(json-path release '("author" "email"))    ;; => #f
(map (lambda (a) (json-ref a "size")) (vector->list (json-ref release "assets")))
;; => (5120 7340)
```

## Writing

```scheme
(json->string '(("ok" . #t) ("count" . 3) ("items" . #("a" "b")) ("next" . null)))
;; => "{\"ok\":true,\"count\":3,\"items\":[\"a\",\"b\"],\"next\":null}"
(json->string "quote \" and newline\n")    ;; => "\"quote \\\" and newline\\n\""
(json->string 2.5)                          ;; => "2.5"

(display (json->pretty-string '(("name" . "demo") ("ports" . #(80 443)))))
;; prints: {
;; prints:   "name": "demo",
;; prints:   "ports": [
;; prints:     80,
;; prints:     443
;; prints:   ]
;; prints: }
```

Keys must be strings; a symbol key is an error, which catches the common
slip of writing `'((a . 1))`:

```scheme
(json->string '((a . 1)))                   ;; => error
```

`json-write` and `json-write-pretty` write to a port, `json-read` reads a
whole port:

```scheme
(define out (open-output-string))
(json-write '(("x" . 1)) out)
(get-output-string out)                     ;; => "{\"x\":1}"
(json-read (open-input-string "[1, 2, 3]")) ;; => #(1 2 3)
```

## Errors

Malformed input raises an error:

```scheme
(define (safe-parse text)
  (guard (e ((error-object? e) #f))
    (json-parse text)))

(safe-parse "{\"a\": 1}")                   ;; => (("a" . 1))
(safe-parse "{\"a\": 1,}")                  ;; => #f
(safe-parse "{bad")                         ;; => #f
```

Parse data from outside (requests, uploads) with such a guard and answer
with an error message instead of failing.

## Example: an API response

Records from a database as alists with symbol keys, turned into the JSON a
client expects, with camel-case keys and `null` for missing values:

```scheme
(define users
  '(((id . 1) (first-name . "Ada") (email . "ada@example.org"))
    ((id . 2) (first-name . "Alan") (email . #f))))

(define (camel s)
  (let loop ((cs (string->list s)) (up #f) (acc '()))
    (cond ((null? cs) (list->string (reverse acc)))
          ((char=? (car cs) #\-) (loop (cdr cs) #t acc))
          (else (loop (cdr cs) #f
                      (cons (if up (char-upcase (car cs)) (car cs)) acc))))))

(define (record->json r)
  (map (lambda (field)
         (cons (camel (symbol->string (car field)))
               (or (cdr field) 'null)))
       r))

(json->string `(("total" . ,(length users))
                ("users" . ,(list->vector (map record->json users)))))
;; => "{\"total\":2,\"users\":[{\"id\":1,\"firstName\":\"Ada\",\"email\":\"ada@example.org\"},{\"id\":2,\"firstName\":\"Alan\",\"email\":null}]}"
```

## Example: merging configuration

Defaults overridden by a user file, object by object:

```scheme
(define (json-merge base over)
  (if (and (list? base) (list? over))
      (append (map (lambda (b)
                     (let ((o (assoc (car b) over)))
                       (if o (cons (car b) (json-merge (cdr b) (cdr o))) b)))
                   base)
              (filter (lambda (o) (not (assoc (car o) base))) over))
      over))

(define defaults (json-parse "{\"port\": 8080, \"log\": {\"level\": \"info\", \"file\": \"app.log\"}}"))
(define user (json-parse "{\"log\": {\"level\": \"debug\"}, \"tls\": true}"))
(json->string (json-merge defaults user))
;; => "{\"port\":8080,\"log\":{\"level\":\"debug\",\"file\":\"app.log\"},\"tls\":true}"
```

Arrays (vectors) are replaced, not merged, which is what configuration
usually wants.

## Streaming with (scm json)

`(scm json simple)` reads the whole document into memory. For a file with
millions of records, `(scm json)` hands out one top-level object at a time:
the elements of a top-level array, or the objects of a newline-delimited
file (one JSON object per line, as log shippers write them):

```scheme
(define log-lines
  "{\"level\": \"info\", \"ms\": 12}
{\"level\": \"error\", \"ms\": 950}
{\"level\": \"info\", \"ms\": 40}
")

(define (slow-requests text limit)
  (let ((r (open-json-string text)))
    (let loop ((n 0))
      (let ((o (json-next-object r)))
        (if o
            (loop (if (> (json-attribute o 'ms) limit) (+ n 1) n))
            (begin (close-json r) n))))))

(slow-requests log-lines 30)                ;; => 2
```

```scheme
(define r (open-json-string "[{\"id\": 1, \"tags\": [\"a\", \"b\"], \"note\": null}, {\"id\": 2}]"))
(define first-object (json-next-object r))
(json-attribute first-object 'id)           ;; => 1
(json-attribute first-object 'tags)         ;; => ("a" "b")
(json-attribute first-object 'note)         ;; => ()
(json-attribute first-object 'size 0)       ;; => 0
(json-attribute (json-next-object r) "id")  ;; => 2
(json-next-object r)                        ;; => #f
(close-json r)
```

`json-attribute` reads a field of such an object, by symbol or string, with
an optional default. In this reader arrays come back as lists and `null` as
the empty list. `open-json-file` reads a file the same way, so memory use
stays flat however large the file is.

## Where next

- [Structured data](techniques-08-structured-data.md), [`(scm xml)`](scm-xml.md),
  `(scm net http client)` for fetching JSON.
- Reference: `(scm json simple)`, `(scm json)`.
