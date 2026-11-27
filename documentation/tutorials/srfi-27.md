---
title: SRFI 27 and 194: random numbers
part: libraries
order: 27
libraries: (srfi 27) (srfi 194)
summary: Random integers and reals, independent and reproducible random sources, distributions as generators (normal, exponential, Poisson, categorical, strings), shuffling, sampling and a Monte Carlo estimate.
---
# SRFI 27 and 194: random numbers

- `(srfi 27)` provides random integers and reals and *random sources*:
  independent generators that can be seeded for reproducible results.
- `(srfi 194)` builds on it with *generators* (SRFI 158 style) for many
  distributions.

The values in this tutorial are random, so the examples check properties
(ranges, reproducibility), not particular numbers.

```scheme
(import (scheme base) (srfi 1) (srfi 27) (srfi 132) (srfi 158) (srfi 194))
```

## Random integers and reals

```scheme
(define die (random-integer 6))           ; 0 to 5
(<= 0 die 5)                              ;; => #t
(define r (random-real))                  ; strictly between 0 and 1
(< 0 r 1)                                 ;; => #t
(define (roll) (+ 1 (random-integer 6)))
(every (lambda (x) (<= 1 x 6)) (list-tabulate 100 (lambda (i) (roll)))) ;; => #t
(integer? (random-integer (expt 10 30)))  ;; => #t
```

`random-integer` works for any size of range, also beyond fixnums.

## Reproducible sequences with a random source

The default source is seeded differently on each run. For tests and
simulations that must give the same results every time, make your own
source and seed it:

```scheme
(define (seeded seed)
  (let ((s (make-random-source)))
    (random-source-pseudo-randomize! s seed 0)
    s))

(define (draws source n)
  (let ((next (random-source-make-integers source)))
    (list-tabulate n (lambda (i) (next 100)))))

(equal? (draws (seeded 42) 5) (draws (seeded 42) 5)) ;; => #t
(equal? (draws (seeded 42) 5) (draws (seeded 43) 5)) ;; => #f
```

`random-source-make-integers` and `random-source-make-reals` return
procedures drawing from that source. Independent sources do not affect each
other, so two simulations in two threads stay reproducible.

## Shuffling and sampling

The Fisher–Yates shuffle picks a random position for each element:

```scheme
(define (shuffle lst source)
  (let ((v (list->vector lst))
        (next (random-source-make-integers source)))
    (do ((i (- (vector-length v) 1) (- i 1)))
        ((< i 1) (vector->list v))
      (let* ((j (next (+ i 1)))
             (t (vector-ref v i)))
        (vector-set! v i (vector-ref v j))
        (vector-set! v j t)))))

(define deck (iota 52))
(define shuffled (shuffle deck (seeded 7)))
(length shuffled)                         ;; => 52
(equal? (list-sort < shuffled) deck)     ;; => #t
(equal? shuffled (shuffle deck (seeded 7))) ;; => #t
```

## Distributions as generators

SRFI 194's constructors return generators: call them for the next value.
They use `current-random-source`, which `with-random-source` sets:

```scheme
(define dice (make-random-integer-generator 1 7))     ; 1 to 6
(every (lambda (x) (<= 1 x 6)) (generator->list (gtake dice 50))) ;; => #t

(define heights (make-normal-generator 170.0 8.0))   ; mean, deviation
(real? (heights))                                     ;; => #t

(define waits (make-exponential-generator 2.0))       ; mean 2
(every positive? (generator->list (gtake waits 20)))  ;; => #t

(define coin (make-bernoulli-generator 0.5))           ; 1 with probability 0.5, else 0
(every (lambda (x) (or (= x 0) (= x 1))) (generator->list (gtake coin 10))) ;; => #t

(define weather (make-categorical-generator #(0.7 0.2 0.1))) ; index 0, 1 or 2
(every (lambda (i) (and (memv i '(0 1 2)) #t)) (generator->list (gtake weather 30))) ;; => #t

(define code-chars (make-random-char-generator "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"))
(define (voucher) (list->string (generator->list (gtake code-chars 6))))
(string-length (voucher))                             ;; => 6
```

The voucher codes avoid the easily confused characters `0 O 1 I`.
`make-random-string-generator` would give strings of random length (up to
its first argument), not fixed-length codes.

Reproducible generators: give them a seeded source.

```scheme
(define (normal-sample seed n)
  (with-random-source (seeded seed)
    (lambda () (generator->list (gtake (make-normal-generator 0.0 1.0) n)))))

(equal? (normal-sample 1 5) (normal-sample 1 5))      ;; => #t
```

## Example: estimating π

Throw random points into the unit square and count those inside the
quarter circle; the share approaches π/4:

```scheme
(define (estimate-pi n source)
  (let ((next (random-source-make-reals source)))
    (let loop ((i 0) (inside 0))
      (if (= i n)
          (* 4.0 (/ inside n))
          (let ((x (next)) (y (next)))
            (loop (+ i 1) (if (<= (+ (* x x) (* y y)) 1.0) (+ inside 1) inside)))))))

(< 3.0 (estimate-pi 20000 (seeded 3)) 3.3)            ;; => #t
```

More points give a better estimate, but slowly: the error shrinks with the
square root of the number of points.

## Where next

- [SRFI 158](srfi-158.md) for working with generators.
- Reference: `(srfi 27)`, `(srfi 194)`.
