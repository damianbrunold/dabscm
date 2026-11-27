---
title: SRFI 133: vectors
part: libraries
order: 133
libraries: (srfi 133)
summary: Constructing, copying and appending vectors, iterating and folding, searching (index, any, every, binary search), partitioning, cumulating, in-place updates; a moving average and a game-of-life step.
---
# SRFI 133: vectors

SRFI 133 is the vector counterpart of SRFI 1. Many of its names
(`vector-map`, `vector-fill!`, `vector-copy`, …) are also in `(scheme
base)`, so import only what you need from it to keep imports unambiguous.

```scheme
(import (scheme base)
        (only (srfi 133)
              vector-unfold vector-concatenate vector-append-subvectors
              vector-reverse-copy vector-empty? vector= vector-count vector-cumulate
              vector-fold vector-fold-right vector-map! vector-any vector-every
              vector-index vector-index-right vector-skip vector-binary-search
              vector-partition vector-swap! vector-reverse!
              reverse-vector->list reverse-list->vector))
```

## Constructing

```scheme
(vector-unfold (lambda (i) (* i i)) 5)          ;; => #(0 1 4 9 16)
(vector-unfold (lambda (i x) (values x (* x 2))) 5 1) ;; => #(1 2 4 8 16)
(vector-concatenate '(#(1) #(2 3) #()))         ;; => #(1 2 3)
(vector-append-subvectors #(a b c) 0 2 #(x y z) 1 3) ;; => #(a b y z)
(vector-reverse-copy #(1 2 3 4))                ;; => #(4 3 2 1)
(reverse-list->vector '(1 2 3))                 ;; => #(3 2 1)
(vector-empty? #())                             ;; => #t
(vector= eq? #(a b) #(a b))                     ;; => #t
```

The second `vector-unfold` threads a seed: the procedure returns the
element and the next seed.

## Iterating and folding

```scheme
(vector-fold (lambda (acc x) (+ acc x)) 0 #(1 2 3))     ;; => 6
(vector-fold-right (lambda (acc x) (cons x acc)) '() #(1 2 3)) ;; => (1 2 3)
(vector-count even? #(1 2 3 4))                         ;; => 2
(vector-cumulate + 0 #(3 1 4 1 5))                      ;; => #(3 4 8 9 14)
(define v (vector 1 2 3))
(vector-map! (lambda (x) (* x 10)) v)
v                                                       ;; => #(10 20 30)
```

Unlike `fold` on lists, `vector-fold` passes the accumulator *first*.
`vector-cumulate` gives running results, here the running sums.

## Searching

```scheme
(vector-index even? #(1 3 4 5 6))              ;; => 2
(vector-index-right even? #(1 3 4 5 6))        ;; => 4
(vector-skip odd? #(1 3 4 5))                  ;; => 2
(vector-any (lambda (x) (and (> x 3) (* x x))) #(1 5 2)) ;; => 25
(vector-every positive? #(1 2 3))              ;; => #t
(vector-binary-search #(10 20 30 40) 30 -)     ;; => 2
```

`vector-binary-search` needs a sorted vector and a procedure returning a
negative, zero or positive number.

## Partitioning and rearranging

```scheme
(call-with-values (lambda () (vector-partition even? #(1 2 3 4 5)))
  list)                                        ;; => (#(2 4 1 3 5) 2)
(define w (vector 'a 'b 'c 'd))
(vector-swap! w 0 3)
w                                              ;; => #(d b c a)
(vector-reverse! w)
w                                              ;; => #(a c b d)
(reverse-vector->list #(1 2 3))                ;; => (3 2 1)
```

`vector-partition` returns a new vector with the matching elements first,
and how many there are.

## Example: a moving average

```scheme
(define (moving-average v n)
  (let* ((sums (vector-cumulate + 0 v))
         (len (vector-length v)))
    (vector-unfold
     (lambda (i)
       (let* ((end (+ i n -1))
              (before (if (= i 0) 0 (vector-ref sums (- i 1)))))
         (/ (- (vector-ref sums end) before) n)))
     (+ (- len n) 1))))

(moving-average #(10 20 30 40 50) 3)           ;; => #(20 30 40)
```

With the running sums, each average takes two lookups instead of n
additions.

## Example: one step of the game of life

A board as a vector of rows; a cell lives on with two or three neighbours,
and is born with exactly three:

```scheme
(define (cell board r c)
  (let ((rows (vector-length board)) (cols (vector-length (vector-ref board 0))))
    (if (and (< -1 r rows) (< -1 c cols)) (vector-ref (vector-ref board r) c) 0)))

(define (neighbours board r c)
  (let loop ((dr -1) (dc -1) (n 0))
    (cond ((> dr 1) n)
          ((> dc 1) (loop (+ dr 1) -1 n))
          ((and (= dr 0) (= dc 0)) (loop dr (+ dc 1) n))
          (else (loop dr (+ dc 1) (+ n (cell board (+ r dr) (+ c dc))))))))

(define (step board)
  (vector-unfold
   (lambda (r)
     (vector-unfold
      (lambda (c)
        (let ((n (neighbours board r c)) (alive (= 1 (cell board r c))))
          (if (or (= n 3) (and alive (= n 2))) 1 0)))
      (vector-length (vector-ref board 0))))
   (vector-length board)))

(define blinker #(#(0 0 0) #(1 1 1) #(0 0 0)))
(step blinker)                                 ;; => #(#(0 1 0) #(0 1 0) #(0 1 0))
(step (step blinker))                          ;; => #(#(0 0 0) #(1 1 1) #(0 0 0))
```

The "blinker" turns from horizontal to vertical and back.

## Where next

- [Vectors, bytevectors and other data](basics-06-data.md), [SRFI 132](srfi-132.md).
- Reference: `(srfi 133)`.
