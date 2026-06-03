## Overview

`(scm store)` is a small immutable, on-disk, indexed record store built on
`(scm random access)`. Each record has a dense integer key, an opaque payload
(any Scheme datum), and indexed fields — *scalar* fields (one value per record)
and *multi* fields (a set of values per record). You write a batch once, then run
random-access queries that never load the whole dataset.

## Writing

Declare the scalar and multi field names, add records (payload + field values),
and close:

```scheme
(import (scm store))

(define w (store-writer-open "people.store" '(city) '(tags)))
(store-writer-add! w '(("name" . "Ada"))
                     '((city . "Paris") (tags . ("x" "y"))))
(store-writer-add! w '(("name" . "Bob"))
                     '((city . "Rome")  (tags . ("y"))))
(store-writer-close w)
```

## Reading and querying

```scheme
(define s (store-open "people.store"))

(store-count s)              ;; => 2
(store-ref s 0)              ;; => (("name" . "Ada"))   the payload

;; queries are an AND of clauses: (eq f v), (in f (v ...)), (present f)
(store-query s '((eq city "Paris")))   ;; => (0)
(store-query s '((in tags ("y"))))     ;; => (0 1)

(store-close s)
```

`store-query` returns the matching record keys; fetch payloads with `store-ref`.
`store-page` / `store-page-records` help with paginated reads.
