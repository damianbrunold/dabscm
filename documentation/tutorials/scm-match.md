---
title: (scm match): pattern matching
part: libraries
order: 1003
libraries: (scm match)
summary: Patterns for literals, lists, dotted lists, vectors, repetition, predicates, and/or/not; match-lambda and match-let; destructuring JSON-like data; a symbolic differentiator.
---
# (scm match): pattern matching

`match` compares a value with patterns and runs the body of the first one
that fits, binding the parts the pattern names. It is Alex Shinn's widely
used matcher. The [macros and pattern matching](basics-11-macros.md)
chapter introduces it.

```scheme
(import (scheme base) (scm match))
```

## Patterns

| pattern | matches |
|---|---|
| `x` (a name) | anything, binding it to `x` |
| `_` | anything, without binding |
| `42`, `"text"`, `#t` | that literal (compared with `equal?`) |
| `'sym` | that symbol |
| `(p1 p2)` | a list of two elements matching `p1` and `p2` |
| `(p1 . rest)` | a pair: first element `p1`, the rest bound to `rest` |
| `(p ...)` | a list whose elements all match `p` |
| `#(p1 p2)` | a vector |
| `(? pred p)` | a value for which `pred` is true, then matching `p` |
| `(and p1 p2)`, `(or p1 p2)`, `(not p)` | combinations |

```scheme
(define (describe x)
  (match x
    (0 'zero)
    ((? number? n) (list 'number n))
    ('() 'empty)
    ((a) (list 'one a))
    ((a b) (list 'two a b))
    ((a . rest) (list 'many a (length rest)))
    (#(x y) (list 'vector2 x y))
    (_ 'other)))

(map describe (list 0 7 '() '(a) '(a b) '(a b c d) #(1 2) "s"))
;; => (zero (number 7) empty (one a) (two a b) (many a 3) (vector2 1 2) other)
```

Clauses are tried in order, so put specific patterns before general ones.

## Repetition

`...` after a pattern matches any number of elements and binds each
variable to a list:

```scheme
(match '((ada . 36) (alan . 41))
  (((names . ages) ...) (list names ages)))   ;; => ((ada alan) (36 41))

(match '(point 1 2 3)
  (('point coords ...) (apply + coords)))     ;; => 6

(match '(1 2 3 4)
  ((first second rest ...) rest))             ;; => (3 4)
```

## Predicates and combinations

```scheme
(define (classify n)
  (match n
    ((and (? integer?) (? positive?)) 'positive-integer)
    ((or 'yes 'y #t) 'yes)
    ((not (? number?)) 'not-a-number)
    (_ 'other-number)))

(map classify (list 5 'y "hi" -2.5)) ;; => (positive-integer yes not-a-number other-number)
```

`(and (? pred) x)` checks and binds at once; `(? pred x)` is the short
form.

## match-lambda and match-let

```scheme
(define area
  (match-lambda
    (('square s) (* s s))
    (('rect w h) (* w h))))

(map area '((square 3) (rect 2 5)))           ;; => (9 10)

(match-let (((x y) '(3 4))
            ((_ . tail) '(a b c)))
  (list (+ x y) tail))                         ;; => (7 (b c))
```

`match-lambda*` matches the whole argument list, which gives procedures
with several shapes of arguments.

## Destructuring JSON-like data

Parsed JSON is alists and vectors (see `(scm json simple)`), and patterns
can take it apart directly:

```scheme
(define order
  '(("id" . 4711)
    ("customer" . (("name" . "Ada") ("city" . "London")))
    ("items" . #("book" "pen"))))

(match order
  ((("id" . id) ("customer" . (("name" . name) _ ...)) ("items" . #(first _ ...)))
   (list id name first)))                      ;; => (4711 "Ada" "book")
```

Patterns like this depend on the order of the keys; for data from outside,
look keys up with `assoc` and match the values.

## Example: symbolic differentiation

Differentiate expressions in x, then simplify a little:

```scheme
(define (d e)
  (match e
    ((? number?) 0)
    ('x 1)
    ((? symbol?) 0)
    (('+ a b) `(+ ,(d a) ,(d b)))
    (('* a b) `(+ (* ,(d a) ,b) (* ,a ,(d b))))
    (('expt 'x (? number? n)) `(* ,n (expt x ,(- n 1))))))

(define (simplify e)
  (match e
    (('+ 0 b) (simplify b))
    (('+ a 0) (simplify a))
    (('* 0 _) 0)
    (('* _ 0) 0)
    (('* 1 b) (simplify b))
    (('* a 1) (simplify a))
    ((op a b) (let ((a2 (simplify a)) (b2 (simplify b)))
                (if (and (equal? a2 a) (equal? b2 b)) (list op a b) (simplify (list op a2 b2)))))
    (_ e)))

(simplify (d '(+ (* 3 x) 5)))                  ;; => 3
(simplify (d '(* x x)))                        ;; => (+ x x)
(simplify (d '(expt x 3)))                     ;; => (* 3 (expt x 2))
```

## Where next

- [Macros and pattern matching](basics-11-macros.md).
- Reference: `(scm match)`.
