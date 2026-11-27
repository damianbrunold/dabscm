---
title: Sorting and searching
part: techniques
order: 5
libraries: (srfi 132) (srfi 95) (srfi 1) (srfi 133)
summary: Sorting lists and vectors, by keys and by several criteria, stable sorting, merging, binary search, finding the top n and the median.
---
# Sorting and searching

## Sorting lists and vectors

`list-sort` and `vector-sort` (SRFI 132) take a "less than" procedure
first and return a new sorted sequence:

```scheme
(import (scheme base) (scheme char) (srfi 1) (srfi 132)
        (only (srfi 133) vector-binary-search))

(list-sort < '(5 2 9 1))                    ;; => (1 2 5 9)
(list-sort > '(5 2 9 1))                    ;; => (9 5 2 1)
(list-sort string<? '("pear" "Apple" "fig")) ;; => ("Apple" "fig" "pear")
(list-sort string-ci<? '("pear" "Apple" "fig")) ;; => ("Apple" "fig" "pear")
(vector-sort < #(3 1 2))                    ;; => #(1 2 3)
```

`string<?` compares character codes, so all upper-case letters come before
lower-case ones; `string-ci<?` ignores case.

## Sorting by a key

Compare a part of each element. A list of cities with population and
canton:

```scheme
(define cities
  '(("Zürich" 421878 "ZH") ("Geneva" 203856 "GE") ("Basel" 173863 "BS")
    ("Lausanne" 140202 "VD") ("Bern" 134794 "BE") ("Winterthur" 114220 "ZH")))

(define (name c) (car c))
(define (population c) (cadr c))
(define (canton c) (caddr c))

(define (by key less?) (lambda (a b) (less? (key a) (key b))))

(map name (list-sort (by population <) cities))
;; => ("Winterthur" "Bern" "Lausanne" "Basel" "Geneva" "Zürich")
(map name (list-sort (by name string<?) cities))
;; => ("Basel" "Bern" "Geneva" "Lausanne" "Winterthur" "Zürich")
```

`by` builds a comparison from a key and an order, which keeps sort calls
readable.

## Several criteria

Sort by canton, and within a canton by population descending:

```scheme
(define (then-by . comparisons)
  (lambda (a b)
    (let loop ((cs comparisons))
      (cond ((null? cs) #f)
            (((car cs) a b) #t)
            (((car cs) b a) #f)
            (else (loop (cdr cs)))))))

(map name (list-sort (then-by (by canton string<?) (by population >)) cities))
;; => ("Bern" "Basel" "Geneva" "Lausanne" "Zürich" "Winterthur")
```

The combined comparison tries each criterion in turn and only goes to the
next one when two elements are equal on the current one.

## Stability

SRFI 132 sorts are *stable*: elements that compare equal keep their order.
So sorting twice, first by the minor key and then by the major one, gives
the same result as the combined sort:

```scheme
(map name (list-sort (by canton string<?)
                     (list-sort (by population >) cities)))
;; => ("Bern" "Basel" "Geneva" "Lausanne" "Zürich" "Winterthur")
```

## SRFI 95: sort with a key argument

SRFI 95 has the arguments the other way round and takes an optional key
procedure:

```scheme
(import (only (srfi 95) sort merge))

(sort '(3 1 2) <)                           ;; => (1 2 3)
(map name (sort cities > population))
;; => ("Zürich" "Geneva" "Basel" "Lausanne" "Bern" "Winterthur")
(merge '(1 4 7) '(2 3 9) <)                 ;; => (1 2 3 4 7 9)
```

## Searching

In a list, search from the start:

```scheme
(find (lambda (c) (string=? (canton c) "VD")) cities)
;; => ("Lausanne" 140202 "VD")
(list-index (lambda (c) (< (population c) 150000)) cities) ;; => 3
(filter (lambda (c) (string=? (canton c) "ZH")) cities)
;; => (("Zürich" 421878 "ZH") ("Winterthur" 114220 "ZH"))
```

In a *sorted* vector, binary search needs only about 20 comparisons for a
million elements. `vector-binary-search` (SRFI 133) takes a procedure that
returns a negative, zero or positive number, like a three-way comparison:

```scheme
(define primes #(2 3 5 7 11 13 17 19 23 29 31 37 41 43 47))

(vector-binary-search primes 23 -)          ;; => 8
(vector-binary-search primes 24 -)          ;; => #f
```

## Top n and the median

To find the largest few elements of a long list, sorting everything is
wasteful but simple; for a few thousand elements it is fine:

```scheme
(define (top n less? xs)
  (take (list-sort less? xs) (min n (length xs))))

(map name (top 3 (by population >) cities)) ;; => ("Zürich" "Geneva" "Basel")

(define (median xs)
  (let* ((v (list->vector (list-sort < xs)))
         (n (vector-length v)))
    (if (odd? n)
        (vector-ref v (quotient n 2))
        (/ (+ (vector-ref v (- (quotient n 2) 1)) (vector-ref v (quotient n 2))) 2))))

(median '(7 1 3))                           ;; => 3
(median '(7 1 3 10))                        ;; => 5
```

SRFI 132 also has `vector-find-median` and `vector-select!` for large
vectors, without a full sort.

## Removing duplicates while keeping order

```scheme
(delete-duplicates '(3 1 3 2 1))            ;; => (3 1 2)
(delete-duplicates (map canton cities))     ;; => ("ZH" "GE" "BS" "VD" "BE")
```

## Where next

- [Iteration patterns](techniques-06-iteration.md).
- [SRFI 132](srfi-132.md), [SRFI 95](srfi-95.md), [SRFI 133](srfi-133.md).
