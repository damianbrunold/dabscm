---
title: SRFI 125 and 128: comparators and hash tables
part: libraries
order: 125
libraries: (srfi 125) (srfi 128)
summary: Comparators (equality, ordering, hashing in one object), the predefined and compound comparators, comparator-based hash tables with mapping, pruning, interning, popping and set operations.
---
# SRFI 125 and 128: comparators and hash tables

A *comparator* (SRFI 128) bundles what you need to compare values of one
kind: a type test, equality, an ordering and a hash function. SRFI 125 hash
tables are made from a comparator and have a richer API than SRFI 69.

```scheme
(import (scheme base) (scheme char) (srfi 1) (srfi 125) (srfi 128)
        (only (srfi 132) list-sort))
```

## Comparators

```scheme
(define d (make-default-comparator))
(=? d "abc" "abc")                         ;; => #t
(<? d 1 2 3)                               ;; => #t
(<? d "b" "a")                             ;; => #f
(>=? d 5 5)                                ;; => #t
(comparator-test-type d 'sym)              ;; => #t
(integer? ((comparator-hash-function d) '(1 2))) ;; => #t
```

The default comparator handles booleans, characters, numbers, strings,
symbols, lists and vectors, and orders values of different types in a fixed
way.

A comparator of your own, for case-insensitive strings:

```scheme
(define ci (make-comparator string? string-ci=? string-ci<? string-ci-hash))
(=? ci "Zürich" "ZÜRICH")                  ;; => #t
(<? ci "apple" "Banana")                   ;; => #t
```

Compound comparators compare structures field by field:

```scheme
(define point (make-pair-comparator d d))
(<? point '(1 . 9) '(2 . 0))               ;; => #t
(<? point '(1 . 2) '(1 . 3))               ;; => #t
(define words (make-list-comparator ci list? null? car cdr))
(=? words '("a" "B") '("A" "b"))           ;; => #t
```

`comparator-if<=>` branches three ways:

```scheme
(define (compare a b)
  (comparator-if<=> d a b 'less 'equal 'greater))
(map compare '(1 2 3) '(2 2 2))            ;; => (less equal greater)
```

## Hash tables from comparators

```scheme
(define t (make-hash-table d))
(hash-table-set! t 'apples 3 'pears 0 'plums 7)
(hash-table-size t)                        ;; => 3
(hash-table-contains? t 'pears)            ;; => #t
(hash-table-ref t 'plums)                  ;; => 7
(hash-table-ref t 'kiwis (lambda () 0))    ;; => 0
(hash-table-ref t 'apples (lambda () 0) (lambda (v) (* v 10))) ;; => 30
(hash-table-empty? t)                      ;; => #f
```

`hash-table-set!` takes several key/value pairs. `hash-table-ref` takes a
"failure" thunk and a "success" procedure applied to the value.

A table with string keys ignoring case, from the comparator above:

```scheme
(define cities (hash-table ci "Zürich" 'zh "Bern" 'be))
(hash-table-ref/default cities "ZÜRICH" #f) ;; => zh
```

## Changing entries

```scheme
(hash-table-update!/default t 'apples (lambda (n) (+ n 1)) 0)
(hash-table-ref t 'apples)                 ;; => 4
(hash-table-intern! t 'figs (lambda () 5)) ;; => 5
(hash-table-intern! t 'figs (lambda () 99)) ;; => 5
(hash-table-delete! t 'pears 'nothing)     ;; => 1
(call-with-values (lambda () (hash-table-pop! t)) (lambda (k v) (symbol? k))) ;; => #t
(hash-table-size t)                        ;; => 2
```

`hash-table-intern!` returns the existing value, or stores and returns the
thunk's value: the building block of caches. `hash-table-delete!` returns
how many of the given keys were present. `hash-table-pop!` removes some
entry and returns its key and value.

## The whole table

```scheme
(define stock (hash-table d 'apples 3 'pears 0 'plums 7 'figs 0))
(hash-table-count (lambda (k v) (> v 0)) stock) ;; => 2
(list-sort (lambda (a b) (< (cdr a) (cdr b)))
           (filter (lambda (e) (> (cdr e) 0)) (hash-table->alist stock)))
;; => ((apples . 3) (plums . 7))
(hash-table-prune! (lambda (k v) (= v 0)) stock)
(hash-table-size stock)                    ;; => 2
(hash-table-map! (lambda (k v) (* v 2)) stock)
(hash-table-ref stock 'plums)              ;; => 14
(fold + 0 (hash-table-map->list (lambda (k v) v) stock)) ;; => 20
(hash-table-find (lambda (k v) (and (> v 10) k)) stock (lambda () #f)) ;; => plums
```

## Set operations

Hash tables can act as sets (or maps) and be combined:

```scheme
(define a (hash-table d 1 'a 2 'b 3 'c))
(define b (hash-table d 2 'x 4 'y))
(define (keys t) (list-sort < (hash-table-keys t)))
(keys (hash-table-union! (hash-table-copy a #t) b))        ;; => (1 2 3 4)
(keys (hash-table-intersection! (hash-table-copy a #t) b)) ;; => (2)
(keys (hash-table-difference! (hash-table-copy a #t) b))   ;; => (1 3)
(keys (hash-table-xor! (hash-table-copy a #t) b))          ;; => (1 3 4)
```

Each operation changes its first table, so the examples work on copies.

## Where next

- [SRFI 69](srfi-69.md), [hash tables and dictionaries](techniques-04-hash-tables.md).
- Reference: `(srfi 125)`, `(srfi 128)`.
