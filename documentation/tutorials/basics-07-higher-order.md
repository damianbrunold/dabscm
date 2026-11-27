---
title: Higher-order programming
part: basics
order: 7
libraries: (scheme base) (srfi 1) (srfi 26)
summary: Procedures that take and return procedures, closures, composition, cut, memoization, building a tiny validation library.
---
# Higher-order programming

A *higher-order* procedure takes procedures as arguments or returns one.
`map`, `filter` and `fold` are examples; this chapter shows how to write
your own.

## Returning procedures

```scheme
(import (scheme base) (srfi 1) (srfi 26))

(define (adder n) (lambda (x) (+ x n)))

(define add10 (adder 10))
(add10 5)                         ;; => 15
(map (adder 1) '(1 2 3))          ;; => (2 3 4)
```

`adder` returns a new procedure each time; each one remembers its own `n`.
That memory is the closure from the [procedures](basics-03-procedures.md)
chapter.

## Composition

Building a pipeline from small steps:

```scheme
(define (compose . fs)
  (if (null? fs)
      (lambda (x) x)
      (lambda (x) ((car fs) ((apply compose (cdr fs)) x)))))

(define (double x) (* 2 x))
(define (inc x) (+ x 1))

((compose double inc) 5)          ;; => 12
((compose inc double) 5)          ;; => 11
```

`(compose f g)` applies `g` first, then `f`, like mathematical composition.

## cut: partial application

`(srfi 26)` provides `cut`, which fills some arguments of a call now and
leaves the slots marked `<>` for later. It saves many small lambdas:

```scheme
(map (cut * 2 <>) '(1 2 3))       ;; => (2 4 6)
(map (cut - <> 1) '(5 6 7))       ;; => (4 5 6)
(filter (cut > <> 2) '(1 2 3 4))  ;; => (3 4)
((cut list 'a <> 'c) 'b)          ;; => (a b c)
```

`(cut * 2 <>)` means `(lambda (x) (* 2 x))`. `<...>` at the end stands for
any remaining arguments.

## Memoization

A procedure that remembers results it has already computed. This makes the
naive Fibonacci definition fast:

```scheme
(define (memoize f)
  (let ((cache '()))
    (lambda (n)
      (cond ((assv n cache) => cdr)
            (else (let ((v (f n)))
                    (set! cache (cons (cons n v) cache))
                    v))))))

(define fib
  (memoize
   (lambda (n)
     (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))))

(fib 30)                          ;; => 832040
(fib 90)                          ;; => 2880067194370816120
```

Without memoization `(fib 90)` would take longer than the age of the
universe; with it, 90 additions. For larger caches, use a hash table instead
of the alist.

## Example: a small validation library

Validators are procedures that take a value and return an error message or
`#f`. Combinators build complex validators from simple ones:

```scheme
(define (check pred message)
  (lambda (value) (if (pred value) #f message)))

(define (all-of . validators)
  (lambda (value)
    (let ((errors (filter-map (lambda (v) (v value)) validators)))
      (if (null? errors) #f errors))))

(define (field name validator)
  (lambda (record)
    (let ((r (validator (cdr (assq name record)))))
      (and r (cons name (if (list? r) r (list r)))))))

(define (form . fields)
  (lambda (record) (filter-map (lambda (f) (f record)) fields)))

(define validate-signup
  (form (field 'name (check (lambda (s) (> (string-length s) 0)) "required"))
        (field 'age (all-of (check integer? "not a number")
                            (check (lambda (n) (and (integer? n) (>= n 18)))
                                   "too young")))))

(validate-signup '((name . "Ada") (age . 36)))   ;; => ()
(validate-signup '((name . "") (age . 12)))
;; => ((name "required") (age "too young"))
```

Each piece is a few lines; together they describe the rules declaratively.
`filter-map` (SRFI 1) maps and keeps only the true results in one pass.

## Where next

- [Records](basics-08-records.md): giving data a proper shape.
- [SRFI 1](srfi-1.md) and [SRFI 26](srfi-26.md).
