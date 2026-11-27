---
title: (scm store): an indexed record store
part: libraries
order: 1012
libraries: (scm store)
summary: Writing a batch of records with indexed fields, random access by key, queries with eq/in/present, counting, paging and distinct values; a product catalogue.
---
# (scm store): an indexed record store

`(scm store)` writes a batch of records to one file, with indexes on chosen
fields, and then answers queries by reading only what they need. It suits
data that is produced once and queried many times: results of a batch job,
an exported catalogue, a log archive. Files stay small in memory however
large they are.

```scheme
(import (scheme base) (scheme cxr) (scm store) (scm fs))

(define path (join-path (mktempdir '(prefix . "store")) "catalogue.store"))
```

## Writing

A writer is opened with the names of the *scalar* fields (one value per
record) and *multi* fields (a set of values per record). Each record has a
payload, any Scheme datum, and its field values as strings:

```scheme
(define products
  '(("p1" "Kettle" "kitchen" 39 ("electric" "steel"))
    ("p2" "Teapot" "kitchen" 25 ("ceramic"))
    ("p3" "Desk lamp" "office" 45 ("electric" "led"))
    ("p4" "Notebook" "office" 4 ())
    ("p5" "Toaster" "kitchen" 59 ("electric"))))

(define w (store-writer-open path '(category) '(tags)))
(for-each (lambda (p)
            (store-writer-add! w
                               `((id . ,(car p)) (name . ,(cadr p)) (price . ,(cadddr p)))
                               `((category . ,(caddr p)) (tags . ,(list-ref p 4)))))
          products)
(store-writer-close w)
```

Records get keys 0, 1, 2, … in the order they are added; `store-writer-add!`
returns the key.

## Reading

```scheme
(define s (store-open path))
(store-count s)                             ;; => 5
(store-ref s 2)                             ;; => ((id . "p3") (name . "Desk lamp") (price . 45))
(store-field-values s 'category)            ;; => ("kitchen" "office")
(store-field-values s 'tags)                ;; => ("ceramic" "electric" "led" "steel")
```

`store-field-values` lists the distinct values of a field, for example to
offer filter choices.

## Queries

A query is a list of clauses, all of which must hold:

| clause | matches records whose field … |
|---|---|
| `(eq field value)` | has the value |
| `(in field (v1 v2 ...))` | has one of the values |
| `(present field)` | has any value |

```scheme
(store-query s '((eq category "kitchen")))  ;; => (0 1 4)
(store-query s '((in tags ("electric"))))   ;; => (0 2 4)
(store-query s '((eq category "kitchen") (in tags ("electric")))) ;; => (0 4)
(store-query s '((present tags)))           ;; => (0 1 2 4)
(store-count-matching s '((eq category "office"))) ;; => 2
(map (lambda (k) (cdr (assq 'name (store-ref s k))))
     (store-query s '((in tags ("electric" "ceramic")))))
;; => ("Kettle" "Teapot" "Desk lamp" "Toaster")
```

Queries return keys in ascending order; fetch the records with `store-ref`.

## Paging

```scheme
(store-page s '((eq category "kitchen")) 0 2) ;; => (0 1)
(store-page s '((eq category "kitchen")) 2 2) ;; => (4)
(store-page s '() 3 10)                     ;; => (3 4)
```

`store-page` skips and limits without building the full result, which is
what a web page listing the records needs. `store-page-records` returns the
payloads directly.

```scheme
(store-close s)
```

## When to use it

- The data is written once (or rebuilt from scratch) and read often.
- Queries are by equality and membership on a few fields.
- A database server would be overkill, or the file should travel with a
  job's results.

For data that changes record by record, use a database (see
`(scm database postgres)`).

## Where next

- Reference: `(scm store)`, `(scm random access)`.
