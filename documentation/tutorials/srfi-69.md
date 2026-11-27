---
title: SRFI 69: hash tables
part: libraries
order: 69
libraries: (srfi 69)
summary: The whole SRFI 69 API: creating tables with an equivalence, reading, updating, walking and folding, copying and merging, conversions, the hash functions; an LRU-free cache and an index.
---
# SRFI 69: hash tables

The [hash tables](techniques-04-hash-tables.md) chapter shows the common
tasks. This tutorial lists the whole SRFI 69 API with an example for each
part.

```scheme
(import (scheme base) (scheme char) (srfi 69) (srfi 132))
```

## Creating

```scheme
(define t (make-hash-table))                          ; equal? keys
(define ids (make-hash-table eqv?))
(define words (make-hash-table string-ci=? string-ci-hash))
(define nums (make-hash-table =))
(hash-table? t)                                       ;; => #t
((hash-table-equivalence-function ids) 2 2.0)         ;; => #f
(eq? (hash-table-hash-function words) string-ci-hash) ;; => #t
```

The supported equivalences: `equal?`, `eqv?`, `eq?`, `string=?`,
`string-ci=?`, `char=?`, `char-ci=?` and `=`. A table made with `=` treats
`1` and `1.0` as the same key:

```scheme
(hash-table-set! nums 1 'one)
(hash-table-ref/default nums 1.0 #f)                  ;; => one
```

## Reading

```scheme
(hash-table-set! t "a" 1)
(hash-table-set! t '(x y) 2)
(hash-table-ref t "a")                                ;; => 1
(hash-table-ref t '(x y))                             ;; => 2
(hash-table-ref t "zzz" (lambda () 'none))            ;; => none
(hash-table-ref/default t "zzz" 0)                    ;; => 0
(hash-table-exists? t "a")                            ;; => #t
(hash-table-size t)                                   ;; => 2
```

## Updating

```scheme
(hash-table-update! t "a" (lambda (v) (* v 10)))
(hash-table-ref t "a")                                ;; => 10
(hash-table-update! t "b" (lambda (v) (+ v 1)) (lambda () 0))
(hash-table-ref t "b")                                ;; => 1
(hash-table-update!/default t "c" (lambda (v) (cons 'x v)) '())
(hash-table-ref t "c")                                ;; => (x)
(hash-table-delete! t '(x y))
(hash-table-exists? t '(x y))                         ;; => #f
```

`hash-table-update!` with a thunk handles a missing key like
`hash-table-update!/default` with a default value.

## The whole table

```scheme
(list-sort string<? (hash-table-keys t))              ;; => ("a" "b" "c")
(length (hash-table-values t))                        ;; => 3
(hash-table-fold t (lambda (k v n) (+ n 1)) 0)        ;; => 3
(define seen '())
(hash-table-walk t (lambda (k v) (set! seen (cons k seen))))
(list-sort string<? seen)                             ;; => ("a" "b" "c")
(list-sort (lambda (a b) (string<? (car a) (car b))) (hash-table->alist t))
;; => (("a" . 10) ("b" . 1) ("c" x))
```

## Copying and merging

```scheme
(define defaults (alist->hash-table '((color . "blue") (size . 10)) eq?))
(define user (alist->hash-table '((size . 12)) eq?))
(define settings (hash-table-merge! (hash-table-copy defaults #t) user))
(hash-table-ref settings 'size)                       ;; => 12
(hash-table-ref settings 'color)                      ;; => "blue"
(hash-table-ref defaults 'size)                       ;; => 10
```

`hash-table-merge!` copies the entries of the second table into the first,
overwriting equal keys, and returns the first; merging into a copy leaves
the defaults untouched.

## Hash functions

```scheme
(= (hash '(1 "a")) (hash (list 1 "a")))               ;; => #t
(= (string-ci-hash "Hello") (string-ci-hash "HELLO")) ;; => #t
(< (string-hash "key" 64) 64)                         ;; => #t
(integer? (hash-by-identity 'sym))                    ;; => #t
```

All take an optional bound, which is useful for bucketing data yourself.

## Example: an inverted index

Map each word to the documents that contain it, then answer queries:

```scheme
(define docs
  '((1 . "the quick brown fox") (2 . "the lazy dog") (3 . "quick brown dogs")))

(define (words-of s)
  (let loop ((cs (string->list s)) (cur '()) (acc '()))
    (cond ((null? cs) (reverse (if (null? cur) acc (cons (list->string (reverse cur)) acc))))
          ((char-alphabetic? (car cs)) (loop (cdr cs) (cons (car cs) cur) acc))
          (else (loop (cdr cs) '() (if (null? cur) acc (cons (list->string (reverse cur)) acc)))))))

(define index (make-hash-table string-ci=?))

(for-each (lambda (doc)
            (for-each (lambda (word)
                        (hash-table-update!/default index word
                          (lambda (ids) (if (memv (car doc) ids) ids (cons (car doc) ids)))
                          '()))
                      (words-of (cdr doc))))
          docs)

(define (filter-ids keep? ids)
  (cond ((null? ids) '())
        ((keep? (car ids)) (cons (car ids) (filter-ids keep? (cdr ids))))
        (else (filter-ids keep? (cdr ids)))))

(define (search . terms)
  (let loop ((terms terms) (result #f))
    (if (null? terms)
        (list-sort < (or result '()))
        (let ((ids (hash-table-ref/default index (car terms) '())))
          (loop (cdr terms)
                (if result (filter-ids (lambda (id) (memv id ids)) result) ids))))))

(search "quick")                                      ;; => (1 3)
(search "QUICK" "brown")                              ;; => (1 3)
(search "the" "dog")                                  ;; => (2)
(search "cat")                                        ;; => ()
```

The `string-ci=?` table makes the search case-insensitive without changing
the words.

## Where next

- [SRFI 125](srfi-125.md) for comparator-based tables with more operations.
- [Hash tables and dictionaries](techniques-04-hash-tables.md), reference `(srfi 69)`.
