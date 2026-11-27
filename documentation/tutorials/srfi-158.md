---
title: SRFI 158: generators and accumulators
part: libraries
order: 158
libraries: (srfi 158)
summary: Making generators from data, ranges, unfolds and coroutines; transforming, filtering, combining and grouping them; consuming them; accumulators; a streaming log analysis.
---
# SRFI 158: generators and accumulators

A *generator* is a procedure without arguments that returns a new value on
each call and an end-of-file object when it is exhausted. An *accumulator*
is the opposite: you call it with values, and with an end-of-file object to
get the result. Both process data one item at a time, without building
intermediate lists. The [continuations, generators and laziness](basics-12-continuations.md)
chapter introduces them.

```scheme
(import (scheme base) (scheme char) (srfi 158))
```

## Making generators

```scheme
(generator->list (generator 1 2 3))                ;; => (1 2 3)
(generator->list (list->generator '(a b)))         ;; => (a b)
(generator->list (vector->generator #(1 2 3) 1))   ;; => (2 3)
(generator->list (string->generator "abc"))        ;; => (#\a #\b #\c)
(generator->list (make-iota-generator 4 10 5))     ;; => (10 15 20 25)
(generator->list (make-range-generator 0 1 1/4))   ;; => (0 1/4 1/2 3/4)
(generator->list (gtake (circular-generator 'on 'off) 5)) ;; => (on off on off on)
(generator->list (make-unfold-generator (lambda (s) (> s 100)) (lambda (s) s)
                                        (lambda (s) (* s 3)) 1))
;; => (1 3 9 27 81)
```

`make-coroutine-generator` writes a generator as a procedure that calls
`yield`, which is natural for walking nested data:

```scheme
(define (leaves tree)
  (make-coroutine-generator
   (lambda (yield)
     (let walk ((t tree))
       (cond ((null? t) #f)
             ((pair? t) (walk (car t)) (walk (cdr t)))
             (else (yield t)))))))

(generator->list (leaves '(1 (2 (3 4)) ((5)))))   ;; => (1 2 3 4 5)
```

## Transforming

```scheme
(define (g) (make-iota-generator 10))
(generator->list (gmap (lambda (x) (* x x)) (g)))  ;; => (0 1 4 9 16 25 36 49 64 81)
(generator->list (gfilter odd? (g)))               ;; => (1 3 5 7 9)
(generator->list (gremove odd? (g)))               ;; => (0 2 4 6 8)
(generator->list (gtake (g) 3))                    ;; => (0 1 2)
(generator->list (gdrop (g) 7))                    ;; => (7 8 9)
(generator->list (gtake-while (lambda (x) (< x 3)) (g))) ;; => (0 1 2)
(generator->list (gdrop-while (lambda (x) (< x 7)) (g))) ;; => (7 8 9)
(generator->list (gdelete 3 (generator 1 3 2 3)))  ;; => (1 2)
(generator->list (gdelete-neighbor-dups (generator 1 1 2 2 1))) ;; => (1 2 1)
(generator->list (gindex (generator 'a 'b 'c 'd) (generator 0 2))) ;; => (a c)
(generator->list (gselect (generator 'a 'b 'c) (generator #t #f #t))) ;; => (a c)
```

## Combining

```scheme
(generator->list (gappend (generator 1 2) (generator 3))) ;; => (1 2 3)
(generator->list (gcons* 'start (generator 1 2)))  ;; => (start 1 2)
(generator->list (gmap + (generator 1 2 3) (generator 10 20 30))) ;; => (11 22 33)
(generator->list (gmerge < (generator 1 4 7) (generator 2 3 9))) ;; => (1 2 3 4 7 9)
(generator->list (gflatten (generator '(1 2) '() '(3))))  ;; => (1 2 3)
(generator->list (ggroup (make-iota-generator 7) 3))      ;; => ((0 1 2) (3 4 5) (6))
```

`ggroup` cuts a generator into chunks, which is handy for batch processing.

## Consuming

```scheme
(generator-fold + 0 (make-iota-generator 5))           ;; => 10
(generator-count even? (make-iota-generator 10))       ;; => 5
(generator-find (lambda (x) (> (* x x) 50)) (make-range-generator 0)) ;; => 8
(generator-any (lambda (x) (and (> x 3) x)) (generator 1 5 2)) ;; => 5
(generator-every number? (generator 1 2))              ;; => #t
(generator->vector (generator 1 2 3))                  ;; => #(1 2 3)
(generator->string (generator #\h #\i))                ;; => "hi"
(generator-map->list (lambda (x) (* x 2)) (generator 1 2)) ;; => (2 4)
(let ((total 0))
  (generator-for-each (lambda (x) (set! total (+ total x))) (generator 1 2 3))
  total)                                               ;; => 6
```

`generator-find` stops at the first match, so it works even on the endless
`make-range-generator`.

## Accumulators

```scheme
(define (feed acc . values)
  (for-each acc values)
  (acc (eof-object)))

(feed (list-accumulator) 1 2 3)                    ;; => (1 2 3)
(feed (reverse-list-accumulator) 1 2 3)            ;; => (3 2 1)
(feed (vector-accumulator) 'a 'b)                  ;; => #(a b)
(feed (string-accumulator) #\o #\k)                ;; => "ok"
(feed (sum-accumulator) 1 2 3)                     ;; => 6
(feed (product-accumulator) 2 3 4)                 ;; => 24
(feed (count-accumulator) 'x 'y)                   ;; => 2
(feed (make-accumulator max 0 (lambda (m) m)) 3 9 4) ;; => 9
```

`make-accumulator` builds one from a combining procedure, an initial value
and a finisher.

## Example: streaming log analysis

Count error lines per hour in a log, reading line by line from a port and
never holding the whole file:

```scheme
(define log-text
  "09:12 INFO start
09:40 ERROR disk
10:05 ERROR net
10:07 INFO ok
10:59 ERROR net
11:30 INFO stop")

(define (port->line-generator port)
  (lambda () (read-line port)))

(define (errors-per-hour port)
  (let ((counts (list-accumulator)))
    (generator-for-each
     (lambda (hour-and-count) (counts hour-and-count))
     (count-runs
      (gmap (lambda (line) (substring line 0 2))
            (gfilter (lambda (line) (string-contains? line "ERROR"))
                     (port->line-generator port)))))
    (counts (eof-object))))

;; (h h h k) -> generator of (h . 3) (k . 1): counts of consecutive equal items
(define (count-runs gen)
  (let ((pending (gen)))
    (lambda ()
      (if (eof-object? pending)
          pending
          (let loop ((n 1))
            (let ((next (gen)))
              (if (and (not (eof-object? next)) (equal? next pending))
                  (loop (+ n 1))
                  (let ((result (cons pending n)))
                    (set! pending next)
                    result))))))))

(define (string-contains? s part)
  (let loop ((i 0))
    (and (<= (+ i (string-length part)) (string-length s))
         (or (string=? part (substring s i (+ i (string-length part))))
             (loop (+ i 1))))))

(errors-per-hour (open-input-string log-text))     ;; => (("09" . 1) ("10" . 2))
```

The pipeline reads, filters, maps and groups lazily: each line is read only
when the next result is needed.

## Where next

- [Iteration patterns](techniques-06-iteration.md), [SRFI 27 and 194](srfi-27.md)
  (random generators).
- Reference: `(srfi 158)`.
