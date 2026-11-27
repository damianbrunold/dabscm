---
title: Continuations, generators and laziness
part: basics
order: 12
libraries: (scheme base) (scheme lazy) (srfi 158)
summary: call/cc for early exit, generators that produce values on demand, lazy streams with delay and force.
---
# Continuations, generators and laziness

## Early exit with call/cc

`call-with-current-continuation` (short `call/cc`) passes "the rest of the
computation" to a procedure, as a procedure `k`. Calling `k` jumps back to
where `call/cc` was called, with the given value as its result. The most
common use is an early exit from a loop:

```scheme
(import (scheme base) (scheme lazy) (srfi 158))

(define (first-negative numbers)
  (call/cc
   (lambda (return)
     (for-each (lambda (x) (when (< x 0) (return x))) numbers)
     #f)))

(first-negative '(3 1 -4 1 -5))   ;; => -4
(first-negative '(1 2 3))         ;; => #f
```

The same with a product that stops at the first zero, so that a long list
is not multiplied in vain:

```scheme
(define (product numbers)
  (call/cc
   (lambda (return)
     (fold-left (lambda (acc x) (if (= x 0) (return 0) (* acc x))) 1 numbers))))

(define (fold-left f init xs)
  (if (null? xs) init (fold-left f (f init (car xs)) (cdr xs))))

(product '(1 2 3 4))              ;; => 24
(product '(5 0 7))                ;; => 0
```

Continuations can do much more (coroutines, backtracking), but in everyday
code an escape like this, or `guard` from the
[errors](basics-09-errors.md) chapter, is what you need.

## Generators

A *generator* (SRFI 158) is a procedure without arguments that returns the
next value each time it is called, and an end-of-file object when it is
exhausted. Generators produce values on demand, so they can describe long or
even infinite sequences:

```scheme
(define g (make-iota-generator 3))
(g)                               ;; => 0
(g)                               ;; => 1
(g)                               ;; => 2
(eof-object? (g))                 ;; => #t

(generator->list (make-iota-generator 5 10)) ;; => (10 11 12 13 14)
(generator->list (gmap (lambda (x) (* x x)) (make-iota-generator 5)))
;; => (0 1 4 9 16)
(generator->list (gtake (gfilter odd? (make-range-generator 1)) 4))
;; => (1 3 5 7)
```

`(make-range-generator 1)` counts 1, 2, 3, … forever; `gfilter` and `gtake`
make it finite. Nothing is computed before it is asked for.

`make-coroutine-generator` turns a procedure that "yields" values into a
generator. Here are the Fibonacci numbers below 100:

```scheme
(define fibs
  (make-coroutine-generator
   (lambda (yield)
     (let loop ((a 0) (b 1))
       (yield a)
       (loop b (+ a b))))))

(generator->list (gtake-while (lambda (x) (< x 100)) fibs))
;; => (0 1 1 2 3 5 8 13 21 34 55 89)
```

The *accumulators* of SRFI 158 are the opposite: you feed them values, and
call them with an end-of-file object to get the result:

```scheme
(define total (sum-accumulator))
(total 3)
(total 4)
(total (eof-object))              ;; => 7

(define words (list-accumulator))
(for-each words '(alpha beta))
(words (eof-object))              ;; => (alpha beta)
```

## Laziness: delay and force

`delay` wraps an expression in a *promise*, which is evaluated the first
time it is `force`d, and only once:

```scheme
(define evaluations 0)
(define p (delay (begin (set! evaluations (+ evaluations 1)) (* 6 7))))
evaluations                       ;; => 0
(force p)                         ;; => 42
(force p)                         ;; => 42
evaluations                       ;; => 1
```

Promises give you lazy lists, *streams*: a pair whose rest is a promise.
Only as much of the stream exists as has been looked at:

```scheme
(define (integers-from n)
  (cons n (delay (integers-from (+ n 1)))))

(define (stream-take s n)
  (if (= n 0) '() (cons (car s) (stream-take (force (cdr s)) (- n 1)))))

(define (stream-filter pred s)
  (if (pred (car s))
      (cons (car s) (delay (stream-filter pred (force (cdr s)))))
      (stream-filter pred (force (cdr s)))))

(define (sieve s)
  (cons (car s)
        (delay (sieve (stream-filter (lambda (x) (not (= 0 (remainder x (car s)))))
                                     (force (cdr s)))))))

(stream-take (sieve (integers-from 2)) 10)
;; => (2 3 5 7 11 13 17 19 23 29)
```

That is the sieve of Eratosthenes on the infinite list of integers. In
practice, generators are usually the simpler tool; streams are worth knowing
when you want to keep and revisit values.

## Where next

- That ends the basics. Continue with the [techniques](README.md#techniques):
  strings, files, hash tables and more.
- [SRFI 158](srfi-158.md) for all generator and accumulator operations.
