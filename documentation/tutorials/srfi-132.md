---
title: SRFI 132 and 95: sorting
part: libraries
order: 132
libraries: (srfi 132) (srfi 95)
summary: Sorting lists and vectors, in place and stable, merging, deleting neighbouring duplicates, order statistics (selection and median), SRFI 95's key argument; a leaderboard.
---
# SRFI 132 and 95: sorting

SRFI 132 is the modern sort library: the comparison comes first, sorts are
stable, and there are in-place variants and order statistics. SRFI 95 is
the older interface with the sequence first and an optional key. The
[sorting and searching](techniques-05-sorting.md) chapter shows the common
patterns.

```scheme
(import (scheme base) (srfi 132) (only (srfi 95) sort merge sorted?))
```

## Lists and vectors

```scheme
(list-sort < '(3 1 2))                    ;; => (1 2 3)
(vector-sort < #(3 1 2))                  ;; => #(1 2 3)
(vector-sort < #(5 4 3 2 1) 1 4)          ;; => #(2 3 4)
(list-sorted? < '(1 2 2 3))               ;; => #t
(vector-sorted? > #(3 2 1))               ;; => #t

(define v (vector 4 2 5 1))
(vector-sort! < v)
v                                         ;; => #(1 2 4 5)
```

`vector-sort` with start and end sorts only that part (and returns only
it). The `!` variants sort in place. All SRFI 132 procedures take the
comparison first and the sequence second.

## Stability

Elements that compare equal keep their order. Sort people by age, and the
ones of the same age stay in their original order:

```scheme
(define people '(("Ada" 36) ("Alan" 41) ("Grace" 36) ("Edsger" 41)))
(map car (list-stable-sort (lambda (a b) (< (cadr a) (cadr b))) people))
;; => ("Ada" "Grace" "Alan" "Edsger")
```

`list-sort` is stable too in dabscm; `list-stable-sort` says so explicitly.

## Merging

```scheme
(list-merge < '(1 4 7) '(2 3 8))          ;; => (1 2 3 4 7 8)
(vector-merge < #(1 5) #(2 3))            ;; => #(1 2 3 5)
```

Merging two sorted sequences takes one pass, much less than sorting their
concatenation.

## Removing neighbouring duplicates

```scheme
(list-delete-neighbor-dups = '(1 1 2 3 3 3 1)) ;; => (1 2 3 1)
(list-delete-neighbor-dups = (list-sort < '(3 1 2 3 1))) ;; => (1 2 3)
(vector-delete-neighbor-dups eq? #(a a b b a)) ;; => #(a b a)
```

Sorting first and then deleting neighbouring duplicates removes all
duplicates in O(n log n).

## Order statistics

`vector-select!` finds the k-th smallest element without sorting the whole
vector; `vector-find-median` finds the median:

```scheme
(vector-select! < (vector 9 1 8 2 7 3) 0) ;; => 1
(vector-select! < (vector 9 1 8 2 7 3) 2) ;; => 3
(vector-find-median < #(9 1 8 2 7) 0)     ;; => 7
(vector-find-median < #(4 1 3 2) 0)       ;; => 5/2
```

For an even number of elements the median is the mean of the two middle
ones (the last argument is returned for an empty vector).

## SRFI 95: sequence first, with a key

```scheme
(sort '(3 1 2) <)                         ;; => (1 2 3)
(sort '("ccc" "a" "bb") < string-length)  ;; => ("a" "bb" "ccc")
(merge '(1 3) '(2) <)                     ;; => (1 2 3)
(sorted? '(1 2 3) <)                      ;; => #t
```

The key procedure is applied before comparing, so `(sort people < cadr)`
sorts by age without writing a comparison lambda.

## Example: a leaderboard

Rank players by score, highest first, ties sharing a rank:

```scheme
(define scores '(("ada" . 970) ("alan" . 820) ("grace" . 970) ("edsger" . 640)))

(define (ranking scores)
  (let loop ((rest (list-sort (lambda (a b) (> (cdr a) (cdr b))) scores))
             (i 1) (rank 1) (prev #f) (acc '()))
    (if (null? rest)
        (reverse acc)
        (let* ((s (cdar rest))
               (r (if (and prev (= s prev)) rank i)))
          (loop (cdr rest) (+ i 1) r s (cons (list r (caar rest) s) acc))))))

(ranking scores)
;; => ((1 "ada" 970) (1 "grace" 970) (3 "alan" 820) (4 "edsger" 640))
```

Because the sort is stable, "ada" stays ahead of "grace", who has the same
score, as in the input.

## Where next

- [Sorting and searching](techniques-05-sorting.md).
- Reference: `(srfi 132)`, `(srfi 95)`.
