---
title: Hash tables and dictionaries
part: techniques
order: 4
libraries: (srfi 69) (srfi 125) (srfi 128) (scm dict)
summary: Creating tables with the right key equality, looking up, updating, counting and grouping, iterating, case-insensitive keys, alists versus hash tables, comparator tables, (scm dict).
---
# Hash tables and dictionaries

A hash table maps keys to values with fast lookup, however many entries it
holds. dabscm has three flavours:

| library | style | use when |
|---|---|---|
| `(srfi 69)` | classic, small API | most programs |
| `(srfi 125)` + `(srfi 128)` | comparator-based, rich API (map, prune, set operations) | you need the extra operations |
| `(scm dict)` | minimal dictionary with string or symbol keys | a quick map in a script |

This tutorial uses SRFI 69 and shows SRFI 125 at the end.

```scheme
(import (scheme base) (scheme char) (srfi 1) (srfi 69) (srfi 132))
```

## Creating and choosing the key equality

`make-hash-table` takes the equivalence the keys are compared with:

```scheme
(define phone (make-hash-table equal?))      ; any keys, compared by structure
(define by-id (make-hash-table eqv?))        ; numbers, characters
(define seen (make-hash-table eq?))          ; symbols, identity
(define ci (make-hash-table string-ci=?))    ; strings, ignoring case
```

`equal?` is the default and right for strings, lists and mixed keys. The
table hashes as its equivalence needs, so you do not have to pass a hash
function. Supported equivalences are `equal?`, `eqv?`, `eq?`, `string=?`,
`string-ci=?`, `char=?`, `char-ci=?` and `=`; another predicate is an error.

## Setting, getting, deleting

```scheme
(hash-table-set! phone "Ada" "555-1815")
(hash-table-set! phone "Alan" "555-1912")

(hash-table-ref/default phone "Ada" #f)      ;; => "555-1815"
(hash-table-ref/default phone "Grace" #f)    ;; => #f
(hash-table-ref phone "Alan")                ;; => "555-1912"
(hash-table-ref phone "Grace")               ;; => error
(hash-table-ref phone "Grace" (lambda () "unknown")) ;; => "unknown"
(hash-table-exists? phone "Ada")             ;; => #t
(hash-table-size phone)                      ;; => 2
(hash-table-delete! phone "Alan")
(hash-table-size phone)                      ;; => 1
```

`hash-table-ref` raises an error for a missing key unless you give it a
thunk to call instead; `hash-table-ref/default` returns the default. Use
the one that says what a missing key means in your program.

## Case-insensitive keys

```scheme
(hash-table-set! ci "Zürich" 'zh)
(hash-table-ref/default ci "ZÜRICH" #f)      ;; => zh
(hash-table-ref/default ci "zürich" #f)      ;; => zh
```

## Counting and grouping

`hash-table-update!/default` reads, changes and writes back a value in one
step, the core of every counting job:

```scheme
(define orders
  '((ada books 30) (alan games 15) (ada music 12) (grace books 22) (ada books 8)))

(define spent (make-hash-table eq?))
(for-each (lambda (o)
            (hash-table-update!/default spent (car o) (lambda (sum) (+ sum (caddr o))) 0))
          orders)

(list-sort (lambda (a b) (> (cdr a) (cdr b))) (hash-table->alist spent))
;; => ((ada . 50) (grace . 22) (alan . 15))
```

Grouping collects values in lists:

```scheme
(define (group-by key xs)
  (let ((t (make-hash-table equal?)))
    (for-each (lambda (x) (hash-table-update!/default t (key x) (lambda (l) (cons x l)) '()))
              xs)
    t))

(define by-category (group-by cadr orders))
(map car (hash-table-ref by-category 'books)) ;; => (ada grace ada)
(length (hash-table-ref by-category 'music))   ;; => 1
```

## Iterating

The order of entries in a hash table is not defined. Sort when the order
matters, as above.

```scheme
(define (symbol<? a b) (string<? (symbol->string a) (symbol->string b)))

(define stock (make-hash-table eq?))
(hash-table-set! stock 'apples 12)
(hash-table-set! stock 'pears 0)
(hash-table-set! stock 'plums 7)

(list-sort symbol<? (hash-table-keys stock)) ;; => (apples pears plums)
(fold + 0 (hash-table-values stock))         ;; => 19
(hash-table-fold stock (lambda (k v acc) (if (> v 0) (cons k acc) acc)) '())
; (plums apples) or (apples plums)
```

R7RS has no `symbol<?`, so the example defines one. The result of
`hash-table-fold` follows the table's order, so it may come out either way.
Sort when the order matters:

```scheme
(list-sort symbol<?
           (hash-table-fold stock (lambda (k v acc) (if (> v 0) (cons k acc) acc)) '()))
;; => (apples plums)

(hash-table-walk stock (lambda (k v) (when (= v 0) (hash-table-delete! stock k))))
(hash-table-size stock)                      ;; => 2
```

`hash-table-walk` calls a procedure for every entry; deleting the entry
being visited is safe.

## From and to alists

```scheme
(define colours (alist->hash-table '((red . "#f00") (green . "#0f0")) eq?))
(hash-table-ref colours 'green)              ;; => "#0f0"
(length (hash-table->alist colours))         ;; => 2
```

`alist->hash-table` keeps the first entry when a key appears twice, as an
alist lookup would.

## Memoization with a table

A table makes a fast cache. Counting the ways to climb n stairs taking one
or two steps at a time:

```scheme
(define ways
  (let ((cache (make-hash-table =)))
    (lambda (n)
      (or (hash-table-ref/default cache n #f)
          (let ((v (if (<= n 1) 1 (+ (ways (- n 1)) (ways (- n 2))))))
            (hash-table-set! cache n v)
            v)))))

(ways 10)                                    ;; => 89
(ways 100)                                   ;; => 573147844013817084101
```

## Alists or hash tables?

- An **alist** is simpler, keeps its order, is easy to print and to write
  as a literal, and is fast enough for a few dozen entries.
- A **hash table** stays fast with thousands of entries and supports
  in-place updates.

Many programs build data as alists and convert with `alist->hash-table` when
lookups become frequent.

## SRFI 125: comparators and more operations

SRFI 125 tables are made from a *comparator* (SRFI 128), which bundles
equality and hashing. Its operation names differ a little:

```scheme
(import (prefix (srfi 125) h:) (only (srfi 128) make-default-comparator))

(define t (h:make-hash-table (make-default-comparator)))
(h:hash-table-set! t 'a 1 'b 2 'c 3)
(h:hash-table-contains? t 'b)                ;; => #t
(h:hash-table-size t)                        ;; => 3
(h:hash-table-count (lambda (k v) (> v 1)) t) ;; => 2
(h:hash-table-prune! (lambda (k v) (odd? v)) t)
(list-sort symbol<? (h:hash-table-keys t))   ;; => (b)
(h:hash-table-intern! t 'd (lambda () 4))    ;; => 4
```

The `prefix` keeps the SRFI 125 names apart from SRFI 69's. Both work on the
same kind of table, so you can mix them.

## (scm dict)

A minimal dictionary API, for scripts:

```scheme
(import (scm dict))

(define d (make-dict))
(dict-put d "lang" "Scheme")
(dict-get d "lang")                          ;; => "Scheme"
(dict-contains d "year")                     ;; => #f
```

## Where next

- [Sorting and searching](techniques-05-sorting.md).
- Reference and tutorials: [SRFI 69](srfi-69.md), [SRFI 125](srfi-125.md),
  [SRFI 128](srfi-128.md).
