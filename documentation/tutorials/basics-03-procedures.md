---
title: Definitions and procedures
part: basics
order: 3
libraries: (scheme base) (scheme case-lambda)
summary: define, lambda, local bindings with let, let* and letrec, optional and rest arguments, case-lambda.
---
# Definitions and procedures

## Naming things with define

`define` gives a name to a value. With a list after it, it defines a
procedure:

```scheme
(import (scheme base) (scheme case-lambda))

(define vat-rate 81/1000)

(define (with-vat amount)
  (* amount (+ 1 vat-rate)))

(with-vat 100)          ;; => 1081/10
(inexact (with-vat 100)) ;; => 108.1
```

The exact rate `81/1000` keeps the computation exact, so no rounding errors
creep into money amounts until we decide to convert.

## lambda: procedures as values

`(define (f x) ...)` is shorthand for `(define f (lambda (x) ...))`. A
`lambda` expression creates a procedure without naming it, which is handy
when passing behaviour to another procedure:

```scheme
(define cube (lambda (x) (* x x x)))
(cube 3)                           ;; => 27
(map (lambda (x) (* x 10)) '(1 2 3)) ;; => (10 20 30)
((lambda (a b) (- a b)) 10 3)      ;; => 7
```

Procedures are values like numbers or strings: you can store them in lists,
pass them as arguments and return them as results. The
[higher-order programming](basics-07-higher-order.md) chapter makes much of
that.

## Local variables: let, let*, letrec

`let` binds names for the duration of its body. All values are computed
first, then bound, so one binding cannot see another:

```scheme
(define (circle-stats r)
  (let ((pi 3.14159)
        (r2 (* r r)))
    (list (* 2 pi r) (* pi r2))))

(circle-stats 2)                   ;; => (12.56636 12.56636)
```

`let*` binds one after the other, so later bindings can use earlier ones:

```scheme
(define (price-summary net)
  (let* ((vat (* net vat-rate))
         (gross (+ net vat)))
    (list net vat gross)))

(price-summary 200)                ;; => (200 81/5 1081/5)
```

`letrec` (and internal `define`s, which mean the same) let local procedures
refer to each other, for example for mutual recursion:

```scheme
(define (parity n)
  (define (even? n) (if (= n 0) #t (odd? (- n 1))))
  (define (odd? n) (if (= n 0) #f (even? (- n 1))))
  (if (even? n) 'even 'odd))

(parity 7)                         ;; => odd
(parity 10)                        ;; => even
```

Internal definitions are the usual way to give a procedure helpers that
nobody else needs.

## Optional and rest arguments

A dot before the last parameter collects any remaining arguments in a list:

```scheme
(define (average first . rest)
  (/ (apply + first rest) (+ 1 (length rest))))

(average 4)                        ;; => 4
(average 1 2 3 4)                  ;; => 5/2
```

`apply` calls a procedure with arguments taken from a list; together with
rest parameters it lets you forward any number of arguments.

A lambda with a single symbol instead of a parameter list takes all
arguments as a list:

```scheme
(define (count-args . args) (length args))
(count-args)                       ;; => 0
(count-args 'a 'b 'c)              ;; => 3
```

## Several arities: case-lambda

`case-lambda` picks the body by the number of arguments, which is the clean
way to write optional parameters with defaults:

```scheme
(define greeting
  (case-lambda
    ((name) (greeting name "Hello"))
    ((name word) (string-append word ", " name "!"))))

(greeting "Ada")                   ;; => "Hello, Ada!"
(greeting "Ada" "Welcome")         ;; => "Welcome, Ada!"
```

## Assignment

`set!` changes the value of an existing variable. Scheme programs use it
sparingly; most code computes new values instead of changing old ones. One
good use is a counter hidden inside a procedure:

```scheme
(define make-ticket-counter
  (lambda ()
    (let ((n 0))
      (lambda ()
        (set! n (+ n 1))
        n))))

(define next-ticket (make-ticket-counter))
(next-ticket)                      ;; => 1
(next-ticket)                      ;; => 2
(define other (make-ticket-counter))
(other)                            ;; => 1
```

Each call of `make-ticket-counter` creates a new `n`, and the returned
procedure keeps it alive: that is a *closure*. Closures are how Scheme hides
state without classes.

## Where next

- [Pairs and lists](basics-04-lists.md), the data structure Scheme is famous for.
- Reference: `(scheme base)` for `define`, `lambda`, `let`; `(scheme case-lambda)`.
