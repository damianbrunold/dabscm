---
title: Iteration patterns
part: techniques
order: 6
libraries: (scheme base) (srfi 1) (srfi 133) (srfi 158)
summary: Choosing between map, for-each, fold, named let and do; looping over vectors, strings and ranges; several sequences at once; generators for pipelines; running totals and sliding windows.
---
# Iteration patterns

Scheme has no single `for` loop. Instead there is a small family of
constructs, each the clearest choice for one kind of loop.

```scheme
(import (scheme base) (scheme char) (scheme write) (srfi 1) (srfi 158)
        (only (srfi 133) vector-fold))
```

## Which construct?

| you want to | use |
|---|---|
| transform every element | `map`, `vector-map`, `string-map` |
| do something with every element | `for-each`, `vector-for-each` |
| combine all elements into one value | `fold`, `reduce`, `vector-fold` |
| keep some elements | `filter`, `remove`, `partition` |
| loop with state, stop early, or build something unusual | named `let` |
| count with side effects | `do` |
| produce values lazily, step by step | generators (SRFI 158) |

## Ranges

`iota` makes a list of numbers, the usual stand-in for a counting loop:

```scheme
(iota 5)                                    ;; => (0 1 2 3 4)
(iota 5 1)                                  ;; => (1 2 3 4 5)
(iota 4 0 5)                                ;; => (0 5 10 15)
(map (lambda (i) (* i i)) (iota 5 1))       ;; => (1 4 9 16 25)
(fold + 0 (iota 101))                       ;; => 5050
```

## Several sequences at once

`map` and `for-each` take several lists and walk them in step:

```scheme
(map + '(1 2 3) '(10 20 30))                ;; => (11 22 33)
(map list '(a b c) '(1 2 3))                ;; => ((a 1) (b 2) (c 3))
(map (lambda (name score) (string-append name ": " (number->string score)))
     '("Ada" "Alan") '(97 92))              ;; => ("Ada: 97" "Alan: 92")
```

To number the elements, zip them with a range:

```scheme
(map cons (iota 3 1) '(gold silver bronze)) ;; => ((1 . gold) (2 . silver) (3 . bronze))
```

## fold and reduce

`fold` walks left to right with an accumulator. It can return anything:

```scheme
(fold + 0 '(1 2 3))                         ;; => 6
(fold cons '() '(1 2 3))                    ;; => (3 2 1)
(fold (lambda (x acc) (if (> x acc) x acc)) 0 '(3 9 2)) ;; => 9
(reduce max #f '(3 9 2))                    ;; => 9
(reduce max #f '())                         ;; => #f
(fold-right cons '() '(1 2 3))              ;; => (1 2 3)
```

`reduce` is `fold` that starts with the first element; its second argument
is returned for an empty list. `fold-right` works from the end and keeps
the order when building lists.

### Running totals

A fold that collects every intermediate value:

```scheme
(define (running-totals xs)
  (reverse (fold (lambda (x acc) (cons (+ x (if (null? acc) 0 (car acc))) acc))
                 '()
                 xs)))

(running-totals '(5 3 8 1))                 ;; => (5 8 16 17)
```

## Named let for everything else

When a loop must stop early, carry several values, or walk two things at a
different pace, a named `let` is the most direct. Merging two sorted lists:

```scheme
(define (merge-sorted a b)
  (let loop ((a a) (b b) (acc '()))
    (cond ((null? a) (append (reverse acc) b))
          ((null? b) (append (reverse acc) a))
          ((< (car a) (car b)) (loop (cdr a) b (cons (car a) acc)))
          (else (loop a (cdr b) (cons (car b) acc))))))

(merge-sorted '(1 4 9) '(2 3 10 11))        ;; => (1 2 3 4 9 10 11)
```

### Sliding windows

Averages over the last n values, as used for smoothing measurements:

```scheme
(define (windows n xs)
  (let loop ((xs xs) (acc '()))
    (if (< (length xs) n)
        (reverse acc)
        (loop (cdr xs) (cons (take xs n) acc)))))

(windows 3 '(1 2 3 4 5))                    ;; => ((1 2 3) (2 3 4) (3 4 5))
(map (lambda (w) (/ (fold + 0 w) (length w))) (windows 3 '(10 20 30 40 50)))
;; => (20 30 40)
```

## Vectors and strings

Vectors and strings have their own loop procedures, and index loops when the
position matters:

```scheme
(vector-map (lambda (x) (* x 2)) #(1 2 3))  ;; => #(2 4 6)
(vector-fold (lambda (acc x) (+ acc x)) 0 #(1 2 3)) ;; => 6
(string-map char-upcase "abc")              ;; => "ABC"

(define (vector-swap! v i j)
  (let ((t (vector-ref v i)))
    (vector-set! v i (vector-ref v j))
    (vector-set! v j t)))

(define (vector-reverse! v)
  (do ((i 0 (+ i 1))
       (j (- (vector-length v) 1) (- j 1)))
      ((>= i j) v)
    (vector-swap! v i j)))

(vector-reverse! (vector 1 2 3 4 5))        ;; => #(5 4 3 2 1)
```

Note the argument order: SRFI 133's `vector-fold` passes the accumulator
*first*, `fold` on lists passes it last.

## Generators for pipelines

A generator produces values one at a time, so a pipeline of generator steps
never builds intermediate lists. That matters when the input is large or
endless:

```scheme
(define (squares-of-odd-numbers-below n)
  (generator->list
   (gmap (lambda (x) (* x x))
         (gfilter odd? (make-iota-generator n)))))

(squares-of-odd-numbers-below 10)           ;; => (1 9 25 49 81)

(generator-fold + 0 (gtake (make-range-generator 1) 100)) ;; => 5050

(generator->list (gtake (gmap (lambda (x) (* x 3)) (make-range-generator 1)) 5))
;; => (3 6 9 12 15)
```

`list->generator`, `vector->generator` and `string->generator` turn existing
data into generators, and SRFI 158's accumulators collect the results.

## Where next

- [Dates and times](techniques-07-dates.md).
- [SRFI 1](srfi-1.md), [SRFI 133](srfi-133.md), [SRFI 158](srfi-158.md).
