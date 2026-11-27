---
title: Pairs and lists
part: basics
order: 4
libraries: (scheme base) (srfi 1)
summary: cons, car and cdr, building and taking apart lists, map, filter and fold, association lists, quasiquote.
---
# Pairs and lists

A list is a chain of *pairs*. `(cons a b)` makes a pair; `car` and `cdr`
take it apart. A list is a pair whose `cdr` is another list, ending in the
empty list `'()`:

```scheme
(import (scheme base) (srfi 1))

(cons 1 '())                 ;; => (1)
(cons 1 (cons 2 (cons 3 '()))) ;; => (1 2 3)
(list 1 2 3)                 ;; => (1 2 3)
(car '(1 2 3))               ;; => 1
(cdr '(1 2 3))               ;; => (2 3)
(cadr '(1 2 3))              ;; => 2
(null? '())                  ;; => #t
(pair? '(1))                 ;; => #t
```

`cadr` is "the `car` of the `cdr`": the second element. A pair whose `cdr`
is not a list prints with a dot: `(cons 1 2)` is `(1 . 2)`.

## Quote

A quoted list is data, not a call: `'(1 2 3)` is a list of three numbers,
while `(1 2 3)` would try to call `1` as a procedure. Quote is also how you
write symbols inside lists: `'(red green blue)`.

Quoted lists are constants; do not modify them. Use `list` when you need a
fresh list.

## Working with lists

```scheme
(length '(a b c))            ;; => 3
(append '(1 2) '(3) '(4 5))  ;; => (1 2 3 4 5)
(reverse '(1 2 3))           ;; => (3 2 1)
(list-ref '(a b c) 1)        ;; => b
(list-tail '(a b c d) 2)     ;; => (c d)
(member 3 '(1 2 3 4))        ;; => (3 4)
(member 9 '(1 2 3 4))        ;; => #f
```

`member` returns the rest of the list starting at the element, or `#f`, so
it works as a test and gives you the position at the same time.

## map, filter, fold

These three cover most loops over lists. Take a small shopping basket:

```scheme
(define basket
  '((apples 3 0.5) (bread 1 3.2) (cheese 2 6.9) (milk 2 1.6)))

(define (item-name i) (car i))
(define (item-count i) (cadr i))
(define (item-price i) (caddr i))
(define (item-total i) (* (item-count i) (item-price i)))

(map item-name basket)           ;; => (apples bread cheese milk)
(map item-total basket)          ;; => (1.5 3.2 13.8 3.2)
(filter (lambda (i) (> (item-total i) 3)) basket)
;; => ((bread 1 3.2) (cheese 2 6.9) (milk 2 1.6))
(fold + 0 (map item-total basket)) ;; => 21.7
```

- `map` applies a procedure to every element (to several lists in parallel
  if you give it several);
- `filter` (from `(srfi 1)`) keeps the elements a predicate accepts, and
  `remove` the others;
- `fold` combines the elements into one value: `(fold kons init list)`
  calls `(kons element accumulator)` for each element, left to right.

`fold` builds more than sums. Here it finds the most expensive item:

```scheme
(fold (lambda (i best) (if (> (item-total i) (item-total best)) i best))
      (car basket)
      (cdr basket))                ;; => (cheese 2 6.9)
```

More from `(srfi 1)`:

```scheme
(iota 5)                         ;; => (0 1 2 3 4)
(iota 5 1)                       ;; => (1 2 3 4 5)
(take '(a b c d e) 2)            ;; => (a b)
(drop '(a b c d e) 2)            ;; => (c d e)
(last '(1 2 3))                  ;; => 3
(delete-duplicates '(a b a c b)) ;; => (a b c)
(find (lambda (i) (eq? (item-name i) 'milk)) basket) ;; => (milk 2 1.6)
(any odd? '(2 4 5))              ;; => #t
(every odd? '(1 3 5))            ;; => #t
(count even? '(1 2 3 4))         ;; => 2
(call-with-values (lambda () (partition even? '(1 2 3 4 5))) list)
;; => ((2 4) (1 3 5))
```

`partition` returns two values, the matching and the other elements;
`call-with-values` passes both to `list`. See the
[SRFI 1](srfi-1.md) tutorial for the whole library.

## Association lists

A list of pairs works as a small dictionary, an *alist*:

```scheme
(define capitals '((fr . "Paris") (it . "Rome") (ch . "Bern")))

(assq 'it capitals)              ;; => (it . "Rome")
(cdr (assq 'ch capitals))        ;; => "Bern"
(assq 'de capitals)              ;; => #f
(define (capital-of code)
  (let ((entry (assq code capitals)))
    (if entry (cdr entry) "unknown")))
(capital-of 'fr)                 ;; => "Paris"
(capital-of 'de)                 ;; => "unknown"
```

`assq` compares keys with `eq?` (right for symbols), `assv` with `eqv?`
(numbers, characters) and `assoc` with `equal?` (strings, lists). Alists are
fine for a few dozen entries; for more, use a
[hash table](techniques-04-hash-tables.md).

## Quasiquote: templates for lists

Backquote builds a list from a template; `,` inserts a value and `,@`
splices a list in:

```scheme
(define n 3)
`(n is ,n)                       ;; => (n is 3)
`(1 ,@(iota 3 2) 5)              ;; => (1 2 3 4 5)
`(total ,(fold + 0 (map item-total basket))) ;; => (total 21.7)
```

Quasiquote is the easiest way to produce structured data, for example the
SXML that `(scm html builder)` turns into HTML.

## Lists versus vectors

Lists are cheap to grow at the front and to walk from start to end, but
finding element `n` takes `n` steps. When you need fast access by index, use
a [vector](basics-06-data.md).

## Where next

- [Control flow and recursion](basics-05-control.md): writing your own list functions.
- [SRFI 1](srfi-1.md): the full list library.
- Reference: `(scheme base)`, `(srfi 1)`.
