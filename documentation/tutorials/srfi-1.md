---
title: SRFI 1: lists
part: libraries
order: 1
libraries: (srfi 1)
summary: The list library: constructing, selecting, folding, searching, deleting, association lists and lists as sets, with a small inventory example.
---
# SRFI 1: lists

SRFI 1 is the standard list library. It extends the few list procedures of
`(scheme base)` with about 150 more. This tutorial goes through them by
task; the [pairs and lists](basics-04-lists.md) chapter covers the basics.

```scheme
(import (scheme base) (scheme char) (srfi 1))
```

## Constructing

```scheme
(iota 4)                          ;; => (0 1 2 3)
(iota 4 10 5)                     ;; => (10 15 20 25)
(make-list 3 'x)                  ;; => (x x x)
(list-tabulate 5 (lambda (i) (* i i))) ;; => (0 1 4 9 16)
(cons* 1 2 '(3 4))                ;; => (1 2 3 4)
(xcons '(b c) 'a)                 ;; => (a b c)
(unfold (lambda (n) (> n 50)) (lambda (n) n) (lambda (n) (* n 2)) 1)
;; => (1 2 4 8 16 32)
```

`unfold` is the opposite of `fold`: it builds a list from a seed, with a
stop test, a value per step and a next-seed procedure.

## Selecting

```scheme
(define letters '(a b c d e f))
(first letters)                   ;; => a
(third letters)                   ;; => c
(take letters 2)                  ;; => (a b)
(drop letters 4)                  ;; => (e f)
(take-right letters 2)            ;; => (e f)
(drop-right letters 2)            ;; => (a b c d)
(last letters)                    ;; => f
(call-with-values (lambda () (split-at letters 3)) list)
;; => ((a b c) (d e f))
(take-while symbol? '(a b 1 c))   ;; => (a b)
(drop-while symbol? '(a b 1 c))   ;; => (1 c)
```

## Folding and mapping

```scheme
(fold + 0 '(1 2 3 4))             ;; => 10
(fold cons '() '(1 2 3))          ;; => (3 2 1)
(fold-right cons '() '(1 2 3))    ;; => (1 2 3)
(reduce max 0 '(3 8 2))           ;; => 8
(fold (lambda (x y acc) (+ acc (* x y))) 0 '(1 2 3) '(4 5 6)) ;; => 32
(append-map (lambda (x) (list x x)) '(a b)) ;; => (a a b b)
(filter-map (lambda (x) (and (even? x) (* x 10))) '(1 2 3 4)) ;; => (20 40)
(pair-fold (lambda (pair acc) (cons (length pair) acc)) '() '(a b c)) ;; => (1 2 3)
```

With several lists, `fold` passes one element of each, here for a dot
product. `pair-fold` hands the procedure the remaining list instead of the
element.

## Searching

```scheme
(find even? '(1 3 4 5 6))         ;; => 4
(find-tail even? '(1 3 4 5 6))    ;; => (4 5 6)
(any (lambda (x) (and (> x 2) (* x x))) '(1 2 3 4)) ;; => 9
(every positive? '(1 2 3))        ;; => #t
(list-index even? '(1 3 4))       ;; => 2
(count odd? '(1 2 3 4 5))         ;; => 3
(call-with-values (lambda () (span even? '(2 4 5 6))) list)
;; => ((2 4) (5 6))
(call-with-values (lambda () (break even? '(1 3 4 5))) list)
;; => ((1 3) (4 5))
```

`any` returns the first true value of the predicate, not just `#t`, which
makes it a search and a transformation at once.

## Deleting and partitioning

```scheme
(delete 3 '(1 3 2 3))             ;; => (1 2)
(remove even? '(1 2 3 4))         ;; => (1 3)
(filter even? '(1 2 3 4))         ;; => (2 4)
(delete-duplicates '(1 2 1 3 2)) ;; => (1 2 3)
(delete-duplicates '("a" "A" "b") (lambda (x y) (string=? (string-downcase x) (string-downcase y))))
;; => ("a" "b")
(call-with-values (lambda () (partition symbol? '(a 1 b 2))) list)
;; => ((a b) (1 2))
```

The procedures ending in `!` (`filter!`, `delete!`, `reverse!`, …) may
reuse the cells of their argument instead of copying. They are faster, but
the argument is destroyed: use them only on lists nobody else holds.

## Zipping

```scheme
(zip '(1 2 3) '(a b c))           ;; => ((1 a) (2 b) (3 c))
(call-with-values (lambda () (unzip2 '((1 a) (2 b)))) list)
;; => ((1 2) (a b))
(concatenate '((1 2) (3) () (4))) ;; => (1 2 3 4)
(append-reverse '(3 2 1) '(4 5))  ;; => (1 2 3 4 5)
```

## Association lists

```scheme
(define stock '((apple . 3) (pear . 0) (plum . 7)))
(alist-cons 'kiwi 2 stock)
;; => ((kiwi . 2) (apple . 3) (pear . 0) (plum . 7))
(alist-delete 'pear stock)        ;; => ((apple . 3) (plum . 7))
(alist-copy stock)                ;; => ((apple . 3) (pear . 0) (plum . 7))
```

`alist-cons` adds an entry in front, which shadows an older entry with the
same key, so an alist can record changes cheaply.

## Lists as sets

The `lset-` procedures treat lists as sets, with an equality predicate as
their first argument:

```scheme
(lset-union eq? '(a b c) '(b d))          ;; => (d a b c)
(lset-intersection eq? '(a b c) '(b c d)) ;; => (b c)
(lset-difference eq? '(a b c) '(b))       ;; => (a c)
(lset-adjoin eq? '(a b) 'c 'a)            ;; => (c a b)
(lset<= eq? '(a) '(a b))                  ;; => #t
(lset= eq? '(a b) '(b a))                 ;; => #t
```

For large sets, a hash table with the elements as keys is faster.

## Example: inventory changes

Compare two inventories and report what was added, removed and changed:

```scheme
(define before '((apple . 3) (pear . 5) (plum . 7)))
(define after '((apple . 3) (pear . 2) (fig . 4)))

(define (keys inv) (map car inv))

(define (inventory-diff old new)
  (let ((added (lset-difference eq? (keys new) (keys old)))
        (removed (lset-difference eq? (keys old) (keys new)))
        (changed (filter-map (lambda (entry)
                               (let ((o (assq (car entry) old)))
                                 (and o (not (= (cdr o) (cdr entry)))
                                      (list (car entry) (cdr o) (cdr entry)))))
                             new)))
    `((added ,@added) (removed ,@removed) (changed ,@changed))))

(inventory-diff before after)
;; => ((added fig) (removed plum) (changed (pear 5 2)))
```

## Where next

- [Iteration patterns](techniques-06-iteration.md), [sorting and searching](techniques-05-sorting.md).
- Reference: `(srfi 1)`.
