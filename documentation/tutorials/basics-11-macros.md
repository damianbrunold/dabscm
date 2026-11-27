---
title: Macros and pattern matching
part: basics
order: 11
libraries: (scheme base) (scm match)
summary: syntax-rules macros for new control forms, hygiene, recursive macros, and destructuring data with match.
---
# Macros and pattern matching

## Why macros

A procedure always evaluates its arguments first. Some forms must not: `if`
evaluates only one branch, `when` none if the condition is false. A *macro*
rewrites code before it runs, so you can add such forms yourself.

```scheme
(import (scheme base) (scheme write) (scm match))

(define-syntax swap!
  (syntax-rules ()
    ((_ a b)
     (let ((tmp a))
       (set! a b)
       (set! b tmp)))))

(define x 1)
(define y 2)
(swap! x y)
(list x y)                        ;; => (2 1)
```

`syntax-rules` lists patterns and templates. `_` stands for the macro's
name; `a` and `b` match whatever the user wrote, and the template is filled
in with it.

## Hygiene

The `tmp` in `swap!` cannot clash with a user's variable named `tmp`: the
macro system renames it. That is called *hygiene*:

```scheme
(define tmp 'mine)
(define other 'yours)
(swap! tmp other)
(list tmp other)                  ;; => (yours mine)
```

## Repetition with ...

`...` after a pattern matches zero or more items, and repeats in the
template. A `while` loop:

```scheme
(define-syntax while
  (syntax-rules ()
    ((_ condition body ...)
     (let loop ()
       (when condition
         body ...
         (loop))))))

(define i 0)
(define squares '())
(while (< i 5)
  (set! squares (cons (* i i) squares))
  (set! i (+ i 1)))
(reverse squares)                 ;; => (0 1 4 9 16)
```

## Several patterns and recursion

A macro can have several rules and expand into itself. `my-or` evaluates its
arguments until one is true, and evaluates each one only once:

```scheme
(define-syntax my-or
  (syntax-rules ()
    ((_) #f)
    ((_ e) e)
    ((_ e rest ...)
     (let ((t e))
       (if t t (my-or rest ...))))))

(my-or #f #f 3)                   ;; => 3
(my-or)                           ;; => #f
(let ((calls 0))
  (my-or (begin (set! calls (+ calls 1)) 'once) 'never)
  calls)                          ;; => 1
```

## A small DSL: unit tests in a table

Macros shine when they let you write data-like code. This one turns a table
of inputs and expected outputs into checks:

```scheme
(define-syntax check-table
  (syntax-rules (=>)
    ((_ f (arg ... => expected) ...)
     (list (equal? (f arg ...) expected) ...))))

(check-table +
  (1 2 => 3)
  (10 20 30 => 60)
  (=> 0))                         ;; => (#t #t #t)
```

`=>` is listed as a *literal*: it matches only itself.

Before writing a macro, check whether a procedure would do. Macros are for
new syntax (evaluation order, binding names, small languages), not for
speed.

## Pattern matching with match

`(scm match)` matches a value against patterns and binds the parts.
Destructuring with `car` and `cdr` becomes declarative:

```scheme
(define (describe shape)
  (match shape
    (('circle r) (list 'area (* 3 r r)))
    (('rect w h) (list 'area (* w h)))
    (('square s) (describe (list 'rect s s)))
    (_ 'unknown)))

(describe '(circle 2))            ;; => (area 12)
(describe '(square 3))            ;; => (area 9)
(describe '(triangle 1 2 3))      ;; => unknown
```

Quoted parts (`'circle`) must match literally, plain names bind, and `_`
matches anything. More patterns:

```scheme
(match '(1 2 3 4)
  ((first second . rest) (list first second rest)))
;; => (1 2 (3 4))

(match '(add 1 2 3)
  (('add n ...) (apply + n)))     ;; => 6

(match 15
  ((? even? n) (list 'even n))
  ((? odd? n) (list 'odd n)))     ;; => (odd 15)

(match '(point 3 4)
  (('point (? number? x) (? number? y)) (+ x y))
  (_ 'bad-point))                 ;; => 7
```

`(? pred name)` matches if the predicate accepts the value; `...` matches
the rest of a list like in `syntax-rules`.

### Example: an expression evaluator

`match` makes interpreters short. A tiny calculator language with
variables:

```scheme
(define (evaluate expr env)
  (match expr
    ((? number? n) n)
    ((? symbol? s) (cdr (assq s env)))
    (('+ a b) (+ (evaluate a env) (evaluate b env)))
    (('* a b) (* (evaluate a env) (evaluate b env)))
    (('let ((name value)) body)
     (evaluate body (cons (cons name (evaluate value env)) env)))))

(evaluate '(+ 1 (* 2 3)) '())     ;; => 7
(evaluate '(let ((x 5)) (* x (+ x 1))) '()) ;; => 30
(evaluate '(* rate 100) '((rate . 3/100))) ;; => 3
```

`match-lambda` creates a procedure that matches its argument, and
`match-let` destructures in bindings:

```scheme
(define area
  (match-lambda
    (('rect w h) (* w h))
    (('circle r) (* 3 r r))))

(map area '((rect 2 3) (circle 1))) ;; => (6 3)

(match-let (((name . age) '("Ada" . 36)))
  (string-append name " is " (number->string age))) ;; => "Ada is 36"
```

## Where next

- [Continuations, generators and laziness](basics-12-continuations.md).
- Reference: `syntax-rules` in `(scheme base)`, `(scm match)`, `(scm macro)`.
