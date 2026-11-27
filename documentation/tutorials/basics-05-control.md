---
title: Control flow and recursion
part: basics
order: 5
libraries: (scheme base)
summary: if, cond, case, when and unless; recursion, named let and tail calls; do loops.
---
# Control flow and recursion

## Choosing

`if` has a condition, a "then" and an optional "else" expression. `cond`
chains several conditions; the first true one wins:

```scheme
(import (scheme base) (scheme write))

(define (grade points)
  (cond ((>= points 90) 'excellent)
        ((>= points 75) 'good)
        ((>= points 50) 'pass)
        (else 'fail)))

(map grade '(95 80 50 12))       ;; => (excellent good pass fail)
```

`cond` has a lesser-known form, `=>`: it passes the test's value to a
procedure, which saves computing it twice:

```scheme
(define stock '((apples . 12) (pears . 0)))

(define (in-stock item)
  (cond ((assq item stock) => cdr)
        (else 0)))

(in-stock 'apples)               ;; => 12
(in-stock 'plums)                ;; => 0
```

`case` dispatches on a value compared with `eqv?`, good for symbols, numbers
and characters:

```scheme
(define (weekday-kind day)
  (case day
    ((sat sun) 'weekend)
    ((mon tue wed thu fri) 'workday)
    (else 'unknown)))

(weekday-kind 'sun)              ;; => weekend
(weekday-kind 'wed)              ;; => workday
```

`when` and `unless` run a body only if the condition holds, or does not.
Use them for side effects, where `if` would have no "else":

```scheme
(define (warn-if-low item)
  (when (< (in-stock item) 5)
    (display "low stock: ")
    (display item)))

(warn-if-low 'pears)             ;; prints: low stock: pears
```

## Recursion

A procedure that calls itself is the natural way to process a list: handle
the first element, recurse on the rest, stop at the empty list.

```scheme
(define (sum xs)
  (if (null? xs)
      0
      (+ (car xs) (sum (cdr xs)))))

(sum '(1 2 3 4))                 ;; => 10

(define (my-map f xs)
  (if (null? xs)
      '()
      (cons (f (car xs)) (my-map f (cdr xs)))))

(my-map (lambda (x) (* x x)) '(1 2 3)) ;; => (1 4 9)
```

## Tail calls and loops

A call that is the last thing a procedure does is a *tail call*. Scheme
guarantees that tail calls do not grow the stack, so a tail-recursive
procedure is a loop and runs in constant space, for a million iterations or
a billion:

```scheme
(define (sum-to n)
  (let loop ((i 1) (acc 0))
    (if (> i n)
        acc
        (loop (+ i 1) (+ acc i)))))

(sum-to 100)                     ;; => 5050
(sum-to 1000000)                 ;; => 500000500000
```

This is a *named let*: `loop` is a local procedure with the variables `i`
and `acc`, called right away with 1 and 0. Calling `loop` again starts the
next iteration with new values. The name `loop` is only a convention.

The `sum` above is not tail recursive (it adds after the recursive call
returns), so it uses stack space for each element. dabscm handles deep
recursion well, but the accumulator style is the safer habit for long
lists.

Collecting results in a loop: build the list backwards with `cons`, reverse
at the end.

```scheme
(define (evens-below n)
  (let loop ((i 0) (acc '()))
    (cond ((>= i n) (reverse acc))
          ((even? i) (loop (+ i 1) (cons i acc)))
          (else (loop (+ i 1) acc)))))

(evens-below 10)                 ;; => (0 2 4 6 8)
```

## A worked example: the Collatz sequence

Start with n; if it is even, halve it, otherwise take 3n + 1; stop at 1.
Nobody has proved that every start reaches 1, but all tested ones do:

```scheme
(define (collatz n)
  (let loop ((n n) (steps '()))
    (cond ((= n 1) (reverse (cons 1 steps)))
          ((even? n) (loop (quotient n 2) (cons n steps)))
          (else (loop (+ (* 3 n) 1) (cons n steps))))))

(collatz 6)                      ;; => (6 3 10 5 16 8 4 2 1)
(length (collatz 27))            ;; => 112

(define (longest-collatz-below limit)
  (let loop ((n 1) (best 1) (best-len 1))
    (if (>= n limit)
        (list best best-len)
        (let ((len (length (collatz n))))
          (if (> len best-len)
              (loop (+ n 1) n len)
              (loop (+ n 1) best best-len))))))

(longest-collatz-below 1000)     ;; => (871 179)
```

## do loops

`do` is the classic iteration form: variables with their start values and
step expressions, an end test with a result, and a body:

```scheme
(define (multiplication-row n)
  (do ((i 1 (+ i 1))
       (acc '() (cons (* n i) acc)))
      ((> i 5) (reverse acc))))

(multiplication-row 7)           ;; => (7 14 21 28 35)

(do ((i 1 (+ i 1))) ((> i 3))
  (display i)
  (display ";"))                 ;; prints: 1;2;3;
```

Named `let` is usually clearer than `do`, but `do` reads well for counting
loops with side effects.

## Where next

- [Vectors, bytevectors and other data](basics-06-data.md).
- [Iteration patterns](techniques-06-iteration.md) for folds, generators and
  vector loops.
