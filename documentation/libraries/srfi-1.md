# `(srfi 1)`

SRFI-1 — List library: fold, any, every, take, drop, iota, lset ops

## Exports

### `alist-cons`

```
Syntax: (alist-cons key val alist)
Library: (srfi 1)
Description: Prepends a new (key . val) pair to alist and returns the extended association list.
Example:
  (alist-cons 'a 1 '((b . 2))) => ((a . 1) (b . 2))
```

### `alist-copy`

```
Syntax: (alist-copy alist)
Library: (srfi 1)
Description: Returns a shallow copy of alist with each pair freshly allocated. The keys and values
themselves are not copied.
Example:
  (alist-copy '((a . 1) (b . 2))) => ((a . 1) (b . 2))
```

### `alist-delete`

```
Syntax: (alist-delete key alist [=])
Library: (srfi 1)
Description: Returns a copy of alist with all entries whose car equals key removed.
Uses equal? by default; an optional = argument specifies the equality predicate.
Example:
  (alist-delete 'b '((a . 1) (b . 2) (b . 3))) => ((a . 1))
```

### `alist-delete!`

```
Syntax: (alist-delete! key alist [=])
Library: (srfi 1)
Description: Destructive version of alist-delete. May modify alist.
Example:
  (alist-delete! 'b (list (cons 'a 1) (cons 'b 2))) => ((a . 1))
```

### `any`

```
Syntax: (any pred lst1 ...)
Library: (srfi 1)
Description: Applies pred to successive elements of the lists. Returns the first true value
returned by pred, or #f if pred returns #f for all elements. Stops on the first true value.
Example:
  (any odd? '(2 4 5 6)) => #t
  (any odd? '(2 4 6)) => #f
  (any < '(1 2 3) '(2 3 4)) => #t
```

### `append`

```
Syntax: (append list1 ... obj)
Library: (scheme base)
Description: Returns a list consisting of the elements of the first list followed by the elements of the other lists. The last argument may be any object.
Example:
  (append '(x) '(y)) => (x y)
  (append '(a) '(b c d)) => (a b c d)
  (append '(a b) '() '(c)) => (a b c)
```

### `append!`

```
Syntax: (append! lst ...)
Library: (srfi 1)
Description: Destructively appends the given lists together by modifying the cdr of each list's last pair.
Returns the concatenated list.
Example:
  (append! (list 1 2) (list 3 4)) => (1 2 3 4)
```

### `append-map`

```
Syntax: (append-map f lst1 ...)
Library: (srfi 1)
Description: Maps f over lst(s) and appends all resulting lists. f must return a list for each element.
Example:
  (append-map (lambda (x) (list x (* x x))) '(1 2 3)) => (1 1 2 4 3 9)
```

### `append-map!`

```
Syntax: (append-map! f lst1 ...)
Library: (srfi 1)
Description: Destructive version of append-map.
Example:
  (append-map! (lambda (x) (list x (* x x))) '(1 2 3)) => (1 1 2 4 3 9)
```

### `append-reverse`

```
Syntax: (append-reverse rev-head tail)
Library: (srfi 1)
Description: Appends (reverse rev-head) to tail. More efficient than (append (reverse rev-head) tail).
Example:
  (append-reverse '(3 2 1) '(4 5)) => (1 2 3 4 5)
```

### `append-reverse!`

```
Syntax: (append-reverse! rev-head tail)
Library: (srfi 1)
Description: Destructive version of append-reverse. May modify rev-head.
Example:
  (append-reverse! (list 3 2 1) '(4 5)) => (1 2 3 4 5)
```

### `assoc`

```
Syntax: (assoc key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is equal? to key. Returns the first matching pair, or #f if none is found. An optional third argument may supply an alternative comparison procedure.
Example:
  (assoc "b" '(("a" 1) ("b" 2))) => (b 2)
  (assoc 2.0 '((1 a) (2 b)) =) => (2 b)
```

### `assq`

```
Syntax: (assq key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is eq? to key. Returns the first matching pair, or #f if none is found.
Example:
  (assq 'b '((a 1) (b 2) (c 3))) => (b 2)
  (assq 'd '((a 1) (b 2))) => #f
```

### `assv`

```
Syntax: (assv key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is eqv? to key. Returns the first matching pair, or #f if none is found. Similar to assq but uses eqv? for comparison.
Example:
  (assv 2 '((1 a) (2 b) (3 c))) => (2 b)
  (assv 5 '((1 a) (2 b))) => #f
```

### `break`

```
Syntax: (break pred lst)
Library: (srfi 1)
Description: Splits lst at the first element satisfying pred. Returns two values:
the longest initial prefix of elements not satisfying pred, and the remainder.
Example:
  (break odd? '(2 4 5 6)) => (2 4) and (5 6)
```

### `break!`

```
Syntax: (break! pred lst)
Library: (srfi 1)
Description: Destructive version of break. May modify lst.
Example:
  (break! odd? (list 2 4 5 6)) => (2 4) and (5 6)
```

### `caaaar`

```
Syntax: (caaaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car (car pair)))). Accesses the car of
four nested car operations on a pair structure.
Example:
  (caaaar '((((1 2) 3) 4) 5)) => 1
```

### `caaadr`

```
Syntax: (caaadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car (cdr pair)))). Accesses the car of
the car of the car of the cdr of a nested pair structure.
Example:
  (caaadr '(1 ((2 3) 4) 5)) => 2
```

### `caaar`

```
Syntax: (caaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car pair))). Accesses the car of the
car of the car of a nested pair structure.
Example:
  (caaar '(((1 2) 3) 4)) => 1
```

### `caadar`

```
Syntax: (caadar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr (car pair)))). Accesses the car of
the car of the cdr of the car of a nested pair structure.
Example:
  (caadar '((1 (2 3)) 4)) => 2
```

### `caaddr`

```
Syntax: (caaddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr (cdr pair)))). Accesses the car of
the car of the third tail of a nested pair structure.
Example:
  (caaddr '(1 2 (3 4) 5)) => 3
```

### `caadr`

```
Syntax: (caadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr pair))). Accesses the car of the
car of the cdr of a nested pair structure.
Example:
  (caadr '(1 (2 3) 4)) => 2
```

### `caar`

```
Syntax: (caar pair)
Library: (scheme base)
Description: Returns the car of the car of pair. Equivalent to (car (car pair)).
Example:
  (caar '((a b) c)) => a
```

### `cadaar`

```
Syntax: (cadaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car (car pair)))). Accesses the car of
the cdr of the car of the car of a nested pair structure.
Example:
  (cadaar '(((1 2) 3) 4)) => 2
```

### `cadadr`

```
Syntax: (cadadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car (cdr pair)))). Accesses the car of
the cdr of the car of the cdr of a nested pair structure.
Example:
  (cadadr '(1 (2 3) 4)) => 3
```

### `cadar`

```
Syntax: (cadar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car pair))). Accesses the car of the
cdr of the car of a nested pair structure.
Example:
  (cadar '((1 2) 3)) => 2
```

### `caddar`

```
Syntax: (caddar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr (car pair)))). Accesses the car of
the cdr of the cdr of the car of a nested pair structure.
Example:
  (caddar '((1 2 3) 4)) => 3
```

### `cadddr`

```
Syntax: (cadddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr (cdr pair)))). Returns the fourth
element of a list.
Example:
  (cadddr '(1 2 3 4 5)) => 4
```

### `caddr`

```
Syntax: (caddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr pair))). Returns the third element
of a list.
Example:
  (caddr '(1 2 3 4)) => 3
```

### `cadr`

```
Syntax: (cadr pair)
Library: (scheme base)
Description: Returns the car of the cdr of pair. Equivalent to (car (cdr pair)).
Example:
  (cadr '(a b c)) => b
```

### `car`

```
Syntax: (car pair)
Library: (scheme base)
Description: Returns the car of pair. It is an error if pair is not a pair.
Example:
  (car '(a b c)) => a
  (car '((a) b)) => (a)
```

### `car+cdr`

```
Syntax: (car+cdr p)
Library: (srfi 1)
Description: Returns two values: the car and cdr of pair p. Equivalent to (values (car p) (cdr p)).
Example:
  (car+cdr '(1 2 3)) => 1 and (2 3)
```

### `cdaaar`

```
Syntax: (cdaaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car (car pair)))). Accesses the cdr of
the car of the car of the car of a nested pair structure.
Example:
  (cdaaar '((((1 2) 3) 4) 5)) => (2)
```

### `cdaadr`

```
Syntax: (cdaadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car (cdr pair)))). Accesses the cdr of
the car of the car of the cdr of a nested pair structure.
Example:
  (cdaadr '(1 ((2 3) 4) 5)) => (3)
```

### `cdaar`

```
Syntax: (cdaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car pair))). Accesses the cdr of the
car of the car of a nested pair structure.
Example:
  (cdaar '(((1 2) 3) 4)) => (2)
```

### `cdadar`

```
Syntax: (cdadar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr (car pair)))). Accesses the cdr of
the car of the cdr of the car of a nested pair structure.
Example:
  (cdadar '((1 (2 3)) 4)) => (3)
```

### `cdaddr`

```
Syntax: (cdaddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr (cdr pair)))). Accesses the cdr of
the car of the third tail of a nested pair structure.
Example:
  (cdaddr '(1 2 (3 4) 5)) => (4)
```

### `cdadr`

```
Syntax: (cdadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr pair))). Accesses the cdr of the
car of the cdr of a nested pair structure.
Example:
  (cdadr '(1 (2 3) 4)) => (3)
```

### `cdar`

```
Syntax: (cdar pair)
Library: (scheme base)
Description: Returns the cdr of the car of pair. Equivalent to (cdr (car pair)).
Example:
  (cdar '((1 2) 3)) => (2)
```

### `cddaar`

```
Syntax: (cddaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car (car pair)))). Accesses the cdr of
the cdr of the car of the car of a nested pair structure.
Example:
  (cddaar '(((1 2 3) 4) 5)) => (3)
```

### `cddadr`

```
Syntax: (cddadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car (cdr pair)))). Accesses the cdr of
the cdr of the car of the cdr of a nested pair structure.
Example:
  (cddadr '(1 (2 3 4) 5)) => (4)
```

### `cddar`

```
Syntax: (cddar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car pair))). Accesses the cdr of the
cdr of the car of a nested pair structure.
Example:
  (cddar '((1 2 3) 4)) => (3)
```

### `cdddar`

```
Syntax: (cdddar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr (car pair)))). Accesses the cdr of
the cdr of the cdr of the car of a nested pair structure.
Example:
  (cdddar '((1 2 3 4) 5)) => (4)
```

### `cddddr`

```
Syntax: (cddddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr (cdr pair)))). Returns the tail of
a list starting after the fourth element.
Example:
  (cddddr '(1 2 3 4 5 6)) => (5 6)
```

### `cdddr`

```
Syntax: (cdddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr pair))). Returns the tail of a
list starting after the third element.
Example:
  (cdddr '(1 2 3 4 5)) => (4 5)
```

### `cddr`

```
Syntax: (cddr pair)
Library: (scheme base)
Description: Returns the cdr of the cdr of pair. Equivalent to (cdr (cdr pair)).
Example:
  (cddr '(1 2 3)) => (3)
```

### `cdr`

```
Syntax: (cdr pair)
Library: (scheme base)
Description: Returns the cdr of pair. It is an error if pair is not a pair.
Example:
  (cdr '((a) b c)) => (b c)
  (cdr '(1 . 2)) => 2
```

### `circular-list`

```
Syntax: (circular-list elt1 ...)
Library: (srfi 1)
Description: Creates a circular list from the given arguments by setting the cdr of the last
pair to point back to the beginning.
Example:
  (take (circular-list 1 2 3) 7) => (1 2 3 1 2 3 1)
```

### `circular-list?`

```
Syntax: (circular-list? x)
Library: (srfi 1)
Description: Returns #t if x is a circular list (one that contains a cycle).
Uses a fast/slow pointer technique to detect cycles.
Example:
  (circular-list? (circular-list 1 2 3)) => #t
  (circular-list? '(1 2 3)) => #f
```

### `concatenate`

```
Syntax: (concatenate lsts)
Library: (srfi 1)
Description: Appends all lists in lsts together into a single list. Equivalent to (apply append lsts).
Example:
  (concatenate '((1 2) (3 4) (5))) => (1 2 3 4 5)
  (concatenate '()) => ()
```

### `concatenate!`

```
Syntax: (concatenate! lsts)
Library: (srfi 1)
Description: Destructive version of concatenate.
Example:
  (concatenate! (list (list 1 2) (list 3 4))) => (1 2 3 4)
```

### `cons`

```
Syntax: (cons obj1 obj2)
Library: (scheme base)
Description: Returns a newly allocated pair whose car is obj1 and whose cdr is obj2.
Example:
  (cons 'a '()) => (a)
  (cons 'a '(b c)) => (a b c)
  (cons 1 2) => (1 . 2)
```

### `cons*`

```
Syntax: (cons* elt1 ... obj)
Library: (srfi 1)
Description: Like list* -- constructs a list from the given arguments, using the last argument as
the tail. With one argument, returns that argument.
Example:
  (cons* 1 2 3 '(4 5)) => (1 2 3 4 5)
  (cons* 1) => 1
```

### `count`

```
Syntax: (count pred lst1 ...)
Library: (srfi 1)
Description: Counts the number of elements in lst1 (and parallel elements in other lists) for which
pred returns true. With multiple lists, pred is applied to parallel elements.
Example:
  (count odd? '(1 2 3 4 5)) => 3
  (count < '(1 2 3) '(2 1 4)) => 2
```

### `delete`

```
Syntax: (delete x lst [=])
Library: (srfi 1)
Description: Returns lst with all elements equal to x removed. Uses equal? by default;
an optional = argument specifies the equality predicate.
Example:
  (delete 3 '(1 2 3 4 3)) => (1 2 4)
  (delete "b" '("a" "b" "c") string=?) => ("a" "c")
```

### `delete!`

```
Syntax: (delete! x lst [=])
Library: (srfi 1)
Description: Destructive version of delete. May modify lst.
Example:
  (delete! 3 (list 1 2 3 4 3)) => (1 2 4)
```

### `delete-duplicates`

```
Syntax: (delete-duplicates lst [=])
Library: (srfi 1)
Description: Returns lst with duplicate elements removed, preserving the first occurrence of each.
Uses equal? by default; an optional = argument specifies the equality predicate.
Example:
  (delete-duplicates '(1 2 1 3 2 4)) => (1 2 3 4)
```

### `delete-duplicates!`

```
Syntax: (delete-duplicates! lst [=])
Library: (srfi 1)
Description: Destructive version of delete-duplicates. May modify lst.
Example:
  (delete-duplicates! (list 1 2 1 3 2 4)) => (1 2 3 4)
```

### `dotted-list?`

```
Syntax: (dotted-list? x)
Library: (srfi 1)
Description: Returns #t if x is a dotted list (a finite list ending with a non-null, non-pair value).
A dotted list is one that is neither proper nor circular.
Example:
  (dotted-list? '(1 2 . 3)) => #t
  (dotted-list? '(1 2 3)) => #f
  (dotted-list? 5) => #t
```

### `drop`

```
Syntax: (drop lst n)
Library: (srfi 1)
Description: Returns all but the first n elements of lst.
Example:
  (drop '(1 2 3 4 5) 2) => (3 4 5)
  (drop '(1 2 3) 3) => ()
```

### `drop-right`

```
Syntax: (drop-right lst n)
Library: (srfi 1)
Description: Returns all but the last n elements of lst.
Example:
  (drop-right '(1 2 3 4 5) 2) => (1 2 3)
  (drop-right '(1 2 3) 3) => ()
```

### `drop-right!`

```
Syntax: (drop-right! lst n)
Library: (srfi 1)
Description: Destructive version of drop-right. May modify lst to return all but the last n elements.
Example:
  (drop-right! (list 1 2 3 4 5) 2) => (1 2 3)
```

### `drop-while`

```
Syntax: (drop-while pred lst)
Library: (srfi 1)
Description: Drops leading elements of lst that satisfy pred, returning the remainder.
Example:
  (drop-while even? '(2 4 5 6)) => (5 6)
  (drop-while even? '(2 4 6)) => ()
```

### `eighth`

```
Syntax: (eighth lst)
Library: (srfi 1)
Description: Returns the eighth element of lst.
Example:
  (eighth '(a b c d e f g h)) => h
```

### `every`

```
Syntax: (every pred lst1 ...)
Library: (srfi 1)
Description: Applies pred to successive elements of the lists. Returns #t (or the last pred result)
if pred returns true for all elements, or #f as soon as pred returns #f.
Example:
  (every odd? '(1 3 5)) => #t
  (every odd? '(1 2 5)) => #f
  (every < '(1 2 3) '(2 3 4)) => #t
```

### `fifth`

```
Syntax: (fifth lst)
Library: (srfi 1)
Description: Returns the fifth element of lst.
Example:
  (fifth '(a b c d e)) => e
```

### `filter`

```
Syntax: (filter pred lst)
Library: (srfi 1)
Description: Returns a list of all elements in lst that satisfy pred, in order.
Example:
  (filter odd? '(1 2 3 4 5)) => (1 3 5)
```

### `filter!`

```
Syntax: (filter! pred lst)
Library: (srfi 1)
Description: Destructive version of filter. Modifies lst in place to retain only elements satisfying pred.
Example:
  (filter! odd? (list 1 2 3 4 5)) => (1 3 5)
```

### `filter-map`

```
Syntax: (filter-map f lst1 ...)
Library: (srfi 1)
Description: Maps f over the list(s) and returns a list of all non-#f results.
Example:
  (filter-map (lambda (x) (and (odd? x) (* x x))) '(1 2 3 4 5)) => (1 9 25)
```

### `find`

```
Syntax: (find pred lst)
Library: (srfi 1)
Description: Returns the first element of lst that satisfies pred, or #f if no such element exists.
Example:
  (find even? '(1 3 4 5)) => 4
  (find even? '(1 3 5)) => #f
```

### `find-tail`

```
Syntax: (find-tail pred lst)
Library: (srfi 1)
Description: Returns the first pair in lst whose car satisfies pred, or #f if no such pair exists.
Example:
  (find-tail even? '(1 3 4 5)) => (4 5)
  (find-tail even? '(1 3 5)) => #f
```

### `first`

```
Syntax: (first lst)
Library: (srfi 1)
Description: Returns the first element of list lst. Equivalent to car.
Example:
  (first '(a b c)) => a
```

### `fold`

```
Syntax: (fold kons knil lst1 ...)
Library: (srfi 1)
Description: Left-associative fold. Applies kons to each element and the accumulated value,
processing from left to right. kons receives (e1 ... acc) where acc starts as knil.
Example:
  (fold + 0 '(1 2 3)) => 6
  (fold cons '() '(1 2 3)) => (3 2 1)
```

### `fold-right`

```
Syntax: (fold-right kons knil lst1 ...)
Library: (srfi 1)
Description: Right-associative fold. Applies kons to each element and the accumulated result,
processing lists from right to left. kons receives (e1 ... acc).
Example:
  (fold-right cons '() '(1 2 3)) => (1 2 3)
  (fold-right + 0 '(1 2 3)) => 6
```

### `for-each`

```
Syntax: (for-each proc list1 list2 ...)
Library: (scheme base)
Description: The arguments to for-each are like the arguments to map, but
  for-each calls proc for its side effects rather than for its values. Unlike
  map, for-each is guaranteed to call proc on the elements of the lists in
  order from the first element(s) to the last. The return values of for-each
  are unspecified.
Example:
  (for-each display '(a b c))    ; displays abc
  (for-each + '(1 2 3) '(4 5 6)) ; calls +, side effects only
```

### `fourth`

```
Syntax: (fourth lst)
Library: (srfi 1)
Description: Returns the fourth element of lst.
Example:
  (fourth '(a b c d)) => d
```

### `iota`

```
Syntax: (iota count [start [step]])
Library: (srfi 1)
Description: Returns a list of count numbers starting at start (default 0) with increment step (default 1).
Example:
  (iota 5) => (0 1 2 3 4)
  (iota 5 1) => (1 2 3 4 5)
  (iota 5 0 2) => (0 2 4 6 8)
```

### `last`

```
Syntax: (last lst)
Library: (srfi 1)
Description: Returns the last element of lst. lst must be a non-empty proper list.
Example:
  (last '(1 2 3)) => 3
```

### `last-pair`

```
Syntax: (last-pair lst)
Library: (srfi 1)
Description: Returns the last pair (the final cons cell) of lst. lst must be a non-empty list.
Example:
  (last-pair '(1 2 3)) => (3)
  (last-pair '(1 2 . 3)) => (2 . 3)
```

### `length`

```
Syntax: (length list)
Library: (scheme base)
Description: Returns the number of elements in the proper list. It is an error if the list is not a proper list.
Example:
  (length '(a b c)) => 3
  (length '()) => 0
```

### `length+`

```
Syntax: (length+ lst)
Library: (srfi 1)
Description: Returns the length of lst if it is a proper or dotted list, or #f if lst is circular.
Example:
  (length+ '(1 2 3)) => 3
  (length+ '(1 2 . 3)) => 2
  (length+ (circular-list 1 2)) => #f
```

### `list`

*(no documentation)*

### `list-copy`

```
Syntax: (list-copy obj)
Library: (scheme base)
Description: Returns a newly allocated copy of the given list. Only the pairs
  themselves are copied; the cars of the result are the same (in the sense of
  eqv?) as the cars of list. If the last cdr of the list is not the empty
  list, the result is an improper list with the same final cdr as the
  argument.
Example:
  (list-copy '(a b c)) => (a b c)
  (list-copy '())      => ()
  (list-copy '(a b . c)) => (a b . c)
```

### `list-copy`

```
Syntax: (list-copy obj)
Library: (scheme base)
Description: Returns a newly allocated copy of the given list. Only the pairs
  themselves are copied; the cars of the result are the same (in the sense of
  eqv?) as the cars of list. If the last cdr of the list is not the empty
  list, the result is an improper list with the same final cdr as the
  argument.
Example:
  (list-copy '(a b c)) => (a b c)
  (list-copy '())      => ()
  (list-copy '(a b . c)) => (a b . c)
```

### `list-index`

```
Syntax: (list-index pred lst1 ...)
Library: (srfi 1)
Description: Returns the 0-based index of the first element in lst1 (and parallel elements in other lists)
for which pred returns true, or #f if no such element exists.
Example:
  (list-index even? '(1 3 4 5)) => 2
  (list-index < '(1 2 3) '(2 1 4)) => 0
```

### `list-ref`

```
Syntax: (list-ref list k)
Library: (scheme base)
Description: Returns the k-th element (zero-indexed) of list. It is an error if k is out of range.
Example:
  (list-ref '(a b c) 0) => a
  (list-ref '(a b c) 2) => c
```

### `list-tabulate`

```
Syntax: (list-tabulate n f)
Library: (srfi 1)
Description: Creates a list of n elements by applying f to each index 0, 1, ..., n-1 in order.
Example:
  (list-tabulate 5 (lambda (i) i)) => (0 1 2 3 4)
  (list-tabulate 4 (lambda (i) (* i i))) => (0 1 4 9)
```

### `list=`

```
Syntax: (list= = lst1 ...)
Library: (srfi 1)
Description: Returns #t if all lists are equal element-by-element using the = predicate.
Lists must have the same length. Returns #t if zero or one list is given.
Example:
  (list= eq? '(a b c) '(a b c)) => #t
  (list= = '(1 2 3) '(1 2 4)) => #f
```

### `lset-adjoin`

```
Syntax: (lset-adjoin = lst elt ...)
Library: (srfi 1)
Description: Adds each elt to lst if it is not already present (tested with =).
Returns the augmented list.
Example:
  (lset-adjoin eq? '(a b c) 'd 'a) => (d a b c)
```

### `lset-diff+intersection`

```
Syntax: (lset-diff+intersection = lst1 lst2 ...)
Library: (srfi 1)
Description: Returns two values: the set difference of lst1 minus the other sets, and the
intersection of lst1 with the union of the other sets (tested with =).
Example:
  (lset-diff+intersection eq? '(a b c d) '(b c)) => (a d) and (b c)
```

### `lset-diff+intersection!`

```
Syntax: (lset-diff+intersection! = lst1 lst2 ...)
Library: (srfi 1)
Description: Destructive version of lset-diff+intersection. May modify lis1.
Example:
  (lset-diff+intersection! eq? (list 'a 'b 'c 'd) '(b c)) => (a d) and (b c)
```

### `lset-difference`

```
Syntax: (lset-difference = lst1 lst2 ...)
Library: (srfi 1)
Description: Returns the difference of the sets: elements of lst1 that do not appear in any
of the other lists (tested with =).
Example:
  (lset-difference eq? '(a b c d) '(b c)) => (a d)
```

### `lset-difference!`

```
Syntax: (lset-difference! = lst1 lst2 ...)
Library: (srfi 1)
Description: Destructive version of lset-difference. May modify lis1.
Example:
  (lset-difference! eq? (list 'a 'b 'c 'd) '(b c)) => (a d)
```

### `lset-intersection`

```
Syntax: (lset-intersection = lst1 lst2 ...)
Library: (srfi 1)
Description: Returns the intersection of the given sets: elements of lst1 that appear in all
other lists (tested with =).
Example:
  (lset-intersection eq? '(a b c d) '(b c d e) '(c d e f)) => (c d)
```

### `lset-intersection!`

```
Syntax: (lset-intersection! = lst1 lst2 ...)
Library: (srfi 1)
Description: Destructive version of lset-intersection. May modify lis1.
Example:
  (lset-intersection! eq? (list 'a 'b 'c) '(b c d)) => (b c)
```

### `lset-union`

```
Syntax: (lset-union = lst ...)
Library: (srfi 1)
Description: Returns the union of the given sets (lists), using = to test element equality.
The result contains all elements that appear in at least one of the lists, without duplicates.
Example:
  (lset-union eq? '(a b c) '(b c d)) => (d a b c)
```

### `lset-union!`

```
Syntax: (lset-union! = lst ...)
Library: (srfi 1)
Description: Destructive version of lset-union. May modify the input lists.
Example:
  (lset-union! eq? (list 'a 'b) (list 'b 'c)) => (c a b)
```

### `lset-xor`

```
Syntax: (lset-xor = lst ...)
Library: (srfi 1)
Description: Returns the symmetric difference of the given sets: elements that appear in an odd
number of the lists (tested with =).
Example:
  (lset-xor eq? '(a b c d) '(b c d e)) => (e a)
```

### `lset-xor!`

```
Syntax: (lset-xor! = lst ...)
Library: (srfi 1)
Description: Destructive version of lset-xor. May modify the input lists.
Example:
  (lset-xor! eq? (list 'a 'b 'c) (list 'b 'c 'd)) => (d a)
```

### `lset<=`

```
Syntax: (lset<= = lst ...)
Library: (srfi 1)
Description: Subset test. Returns #t if every element of each list is contained in the next list
(tested with =). In other words, s1 is a subset of s2 is a subset of ...
Example:
  (lset<= eq? '(a b) '(a b c)) => #t
  (lset<= eq? '(a b c) '(a b)) => #f
```

### `lset=`

```
Syntax: (lset= = lst ...)
Library: (srfi 1)
Description: Returns #t if all given sets contain the same elements (tested with =).
Each pair of adjacent sets must be mutual subsets.
Example:
  (lset= eq? '(a b c) '(c b a)) => #t
  (lset= eq? '(a b c) '(a b)) => #f
```

### `make-list`

```
Syntax: (make-list k)
       (make-list k fill)
Library: (scheme base)
Description: Returns a newly allocated list of k elements. If a second
  argument is given, then each element is initialized to fill. Otherwise
  the initial contents of each element is unspecified (defaults to #f).
Example:
  (make-list 3)      => (#f #f #f)
  (make-list 3 'x)   => (x x x)
  (make-list 0)      => ()
```

### `make-list`

```
Syntax: (make-list k)
       (make-list k fill)
Library: (scheme base)
Description: Returns a newly allocated list of k elements. If a second
  argument is given, then each element is initialized to fill. Otherwise
  the initial contents of each element is unspecified (defaults to #f).
Example:
  (make-list 3)      => (#f #f #f)
  (make-list 3 'x)   => (x x x)
  (make-list 0)      => ()
```

### `map`

```
Syntax: (map proc list1 list2 ...)
Library: (scheme base)
Description: The lists must be lists, and proc must be a procedure taking as
  many arguments as there are lists and returning a single value. If more than
  one list is given and not all lists have the same length, map terminates when
  the shortest list runs out. Map applies proc element-wise to the elements of
  the lists and returns a list of the results, in order.
Example:
  (map cadr '((a b) (d e) (g h))) => (b e h)
  (map + '(1 2 3) '(4 5 6))      => (5 7 9)
```

### `map!`

```
Syntax: (map! f lst1 ...)
Library: (srfi 1)
Description: Destructive map. Applies f to each element of lst (and parallel elements of other lists)
and stores the result back in lst's pairs in place.
Example:
  (let ((l (list 1 2 3))) (map! (lambda (x) (* x x)) l) l) => (1 4 9)
```

### `map-in-order`

```
Syntax: (map-in-order f lst1 ...)
Library: (srfi 1)
Description: Like map, but guarantees left-to-right evaluation order.
Example:
  (map-in-order (lambda (x) (* x x)) '(1 2 3)) => (1 4 9)
```

### `member`

```
Syntax: (member obj list)
       (member obj list compare)
Library: (scheme base)
Description: Returns the first sublist of list whose car is obj, where the
  sublists of list are the non-empty lists returned by (list-tail list k) for
  k less than the length of list. If obj does not occur in list, #f is
  returned. The optional compare argument specifies the equality predicate to
  use; it defaults to equal?.
Example:
  (member 2 '(1 2 3))   => (2 3)
  (member 'd '(a b c))  => #f
  (member 2.0 '(1 2 3) =) => (2 3)
```

### `memq`

```
Syntax: (memq obj list)
Library: (scheme base)
Description: Returns the first sublist of list whose car is eq? to obj, or #f if no such sublist exists.
Example:
  (memq 'b '(a b c)) => (b c)
  (memq 'z '(a b c)) => #f
```

### `memv`

```
Syntax: (memv obj list)
Library: (scheme base)
Description: Returns the first sublist of list whose car is eqv? to obj, or #f if no such sublist exists.
Example:
  (memv 2 '(1 2 3)) => (2 3)
  (memv 5 '(1 2 3)) => #f
```

### `ninth`

```
Syntax: (ninth lst)
Library: (srfi 1)
Description: Returns the ninth element of lst.
Example:
  (ninth '(a b c d e f g h i)) => i
```

### `not-pair?`

```
Syntax: (not-pair? x)
Library: (srfi 1)
Description: Returns #t if x is not a pair, #f if it is. Complement of pair?.
Example:
  (not-pair? '()) => #t
  (not-pair? '(1 2)) => #f
  (not-pair? 5) => #t
```

### `null-list?`

```
Syntax: (null-list? lst)
Library: (srfi 1)
Description: Returns #t if lst is the empty list, #f if it is a pair.
Signals an error if lst is neither null nor a pair.
Example:
  (null-list? '()) => #t
  (null-list? '(1 2)) => #f
```

### `null?`

```
Syntax: (null? obj)
Library: (scheme base)
Description: Returns #t if obj is the empty list '(), otherwise returns #f.
Example:
  (null? '()) => #t
  (null? '(1 2)) => #f
```

### `pair-fold`

```
Syntax: (pair-fold f knil lst1 ...)
Library: (srfi 1)
Description: Folds f over the successive tails (pairs) of lst rather than its elements.
f receives the current tail and the accumulator; processes left to right.
Example:
  (pair-fold (lambda (pair acc) (cons (car pair) acc)) '() '(1 2 3)) => (3 2 1)
```

### `pair-fold-right`

```
Syntax: (pair-fold-right f knil lst1 ...)
Library: (srfi 1)
Description: Right-associative fold over successive tails (pairs) of lst.
f receives the current tail and the accumulated result; processes right to left.
Example:
  (pair-fold-right cons '() '(1 2 3)) => ((1 2 3) (2 3) (3))
```

### `pair-for-each`

```
Syntax: (pair-for-each proc lst1 ...)
Library: (srfi 1)
Description: Like for-each, but proc is called on successive tails (pairs) of the list(s) rather
than on individual elements.
Example:
  (pair-for-each (lambda (p) (display (car p))) '(1 2 3)) ; displays 1 2 3
```

### `pair?`

```
Syntax: (pair? obj)
Library: (scheme base)
Description: Returns #t if obj is a pair, otherwise returns #f.
Example:
  (pair? '(a b c)) => #t
  (pair? '()) => #f
  (pair? '(a . b)) => #t
  (pair? 7) => #f
```

### `partition`

```
Syntax: (partition pred lst)
Library: (srfi 1)
Description: Partitions lst into two lists: elements that satisfy pred and elements that do not.
Returns two values: the list of matching elements and the list of non-matching elements, both in order.
Example:
  (partition odd? '(1 2 3 4 5)) => (1 3 5) and (2 4)
```

### `partition!`

```
Syntax: (partition! pred lst)
Library: (srfi 1)
Description: Destructive version of partition. Splits lst in place into two lists: elements satisfying
pred and elements not satisfying pred. Returns two values.
Example:
  (partition! odd? (list 1 2 3 4 5)) => (1 3 5) and (2 4)
```

### `proper-list?`

```
Syntax: (proper-list? x)
Library: (srfi 1)
Description: Returns #t if x is a proper list (a finite list ending with the empty list).
Uses a fast/slow pointer technique to detect cycles.
Example:
  (proper-list? '(1 2 3)) => #t
  (proper-list? '(1 2 . 3)) => #f
  (proper-list? '()) => #t
```

### `reduce`

```
Syntax: (reduce f ridentity lst)
Library: (srfi 1)
Description: Like fold, but uses the first element of lst as the initial accumulator when lst is non-empty.
If lst is empty, returns ridentity.
Example:
  (reduce + 0 '(1 2 3)) => 6
  (reduce max 0 '(3 1 4 1 5)) => 5
  (reduce + 0 '()) => 0
```

### `reduce-right`

```
Syntax: (reduce-right f ridentity lst)
Library: (srfi 1)
Description: Like fold-right, but uses the last element of lst as the initial accumulator when lst is non-empty.
If lst is empty, returns ridentity.
Example:
  (reduce-right + 0 '(1 2 3)) => 6
  (reduce-right cons '() '(1 2 3)) => (1 2 3)
  (reduce-right + 0 '()) => 0
```

### `remove`

```
Syntax: (remove pred lst)
Library: (srfi 1)
Description: Returns a list of all elements in lst that do not satisfy pred (complement of filter).
Example:
  (remove odd? '(1 2 3 4 5)) => (2 4)
```

### `remove!`

```
Syntax: (remove! pred lst)
Library: (srfi 1)
Description: Destructive version of remove. Modifies lst in place to remove all elements satisfying pred.
Example:
  (remove! odd? (list 1 2 3 4 5)) => (2 4)
```

### `reverse`

```
Syntax: (reverse list)
Library: (scheme base)
Description: Returns a newly allocated list containing the elements of list in reverse order.
Example:
  (reverse '(1 2 3)) => (3 2 1)
  (reverse '()) => ()
```

### `reverse!`

```
Syntax: (reverse! lst)
Library: (srfi 1)
Description: Destructively reverses lst in place by modifying the cdr pointers. Returns the reversed list.
Example:
  (reverse! (list 1 2 3)) => (3 2 1)
```

### `second`

```
Syntax: (second list)
Library: (srfi 1)
Description: Returns the second element of a list. Equivalent to (cadr list).
Example:
  (second '(a b c)) => b
  (second '(1 2 3)) => 2
```

### `set-car!`

```
Syntax: (set-car! pair obj)
Library: (scheme base)
Description: Stores obj in the car field of pair. It is an error if pair is not a pair.
Example:
  (define p (list 1 2 3))
  (set-car! p 'a)
  p => (a 2 3)
```

### `set-cdr!`

```
Syntax: (set-cdr! pair obj)
Library: (scheme base)
Description: Stores obj in the cdr field of pair. It is an error if pair is not a pair.
Example:
  (define p (list 1 2 3))
  (set-cdr! p '(b c))
  p => (1 b c)
```

### `seventh`

```
Syntax: (seventh lst)
Library: (srfi 1)
Description: Returns the seventh element of lst.
Example:
  (seventh '(a b c d e f g)) => g
```

### `sixth`

```
Syntax: (sixth lst)
Library: (srfi 1)
Description: Returns the sixth element of lst.
Example:
  (sixth '(a b c d e f)) => f
```

### `span`

```
Syntax: (span pred lst)
Library: (srfi 1)
Description: Splits lst at the first element not satisfying pred. Returns two values:
the longest initial prefix of elements satisfying pred, and the remainder.
Example:
  (span even? '(2 4 5 6)) => (2 4) and (5 6)
```

### `span!`

```
Syntax: (span! pred lst)
Library: (srfi 1)
Description: Destructive version of span. May modify lst.
Example:
  (span! even? (list 2 4 5 6)) => (2 4) and (5 6)
```

### `split-at`

```
Syntax: (split-at lst n)
Library: (srfi 1)
Description: Splits lst at index n. Returns two values: the first n elements and the remaining elements.
Example:
  (split-at '(1 2 3 4 5) 2) => (1 2) and (3 4 5)
```

### `split-at!`

```
Syntax: (split-at! lst n)
Library: (srfi 1)
Description: Destructive version of split-at. May modify lst.
Example:
  (split-at! (list 1 2 3 4 5) 2) => (1 2) and (3 4 5)
```

### `take`

```
Syntax: (take lst n)
Library: (srfi 1)
Description: Returns a fresh list of the first n elements of lst.
Example:
  (take '(1 2 3 4 5) 3) => (1 2 3)
  (take '(1 2 3) 0) => ()
```

### `take!`

```
Syntax: (take! lst n)
Library: (srfi 1)
Description: Destructive version of take. May modify lst to return the first n elements.
Example:
  (take! (list 1 2 3 4 5) 3) => (1 2 3)
```

### `take-right`

```
Syntax: (take-right lst n)
Library: (srfi 1)
Description: Returns the last n elements of lst.
Example:
  (take-right '(1 2 3 4 5) 2) => (4 5)
  (take-right '(1 2 3) 0) => ()
```

### `take-while`

```
Syntax: (take-while pred lst)
Library: (srfi 1)
Description: Returns the longest initial prefix of lst whose elements all satisfy pred.
Example:
  (take-while even? '(2 4 5 6)) => (2 4)
  (take-while even? '(1 2 3)) => ()
```

### `take-while!`

```
Syntax: (take-while! pred lst)
Library: (srfi 1)
Description: Destructive version of take-while. May modify lst.
Example:
  (take-while! even? (list 2 4 5 6)) => (2 4)
```

### `tenth`

```
Syntax: (tenth lst)
Library: (srfi 1)
Description: Returns the tenth element of lst.
Example:
  (tenth '(a b c d e f g h i j)) => j
```

### `third`

```
Syntax: (third lst)
Library: (srfi 1)
Description: Returns the third element of lst.
Example:
  (third '(a b c d)) => c
```

### `unfold`

```
Syntax: (unfold p f g seed [tail-gen])
Library: (srfi 1)
Description: Constructs a list by unfolding seed. p is the termination predicate; when (p seed) is true,
unfolding stops. f maps seed to the next list element, g maps seed to the next seed.
Optional tail-gen is called on the final seed to produce the tail (defaults to empty list).
Example:
  (unfold (lambda (n) (> n 5)) (lambda (n) n) (lambda (n) (+ n 1)) 1) => (1 2 3 4 5)
```

### `unfold-right`

```
Syntax: (unfold-right p f g seed [tail])
Library: (srfi 1)
Description: Constructs a list right-to-left by unfolding seed. p is the termination predicate;
f maps seed to an element, g maps seed to the next seed. Optional tail is the initial list
that elements are prepended to (defaults to empty list).
Example:
  (unfold-right zero? (lambda (n) n) (lambda (n) (- n 1)) 5) => (1 2 3 4 5)
```

### `unzip1`

```
Syntax: (unzip1 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns a list of the first elements of each sublist.
Example:
  (unzip1 '((1 a) (2 b) (3 c))) => (1 2 3)
```

### `unzip2`

```
Syntax: (unzip2 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns two values: the list of first elements and the list
of second elements from each sublist.
Example:
  (unzip2 '((1 a) (2 b) (3 c))) => (1 2 3) and (a b c)
```

### `unzip3`

```
Syntax: (unzip3 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns three values: the lists of first, second, and third
elements from each sublist.
Example:
  (unzip3 '((1 a x) (2 b y))) => (1 2) and (a b) and (x y)
```

### `unzip4`

```
Syntax: (unzip4 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns four values: the lists of first through fourth
elements from each sublist.
Example:
  (unzip4 '((1 a x p) (2 b y q))) => (1 2) and (a b) and (x y) and (p q)
```

### `unzip5`

```
Syntax: (unzip5 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns five values: the lists of first through fifth
elements from each sublist.
Example:
  (unzip5 '((1 a x p i) (2 b y q j))) => (1 2) and (a b) and (x y) and (p q) and (i j)
```

### `xcons`

```
Syntax: (xcons d a)
Library: (srfi 1)
Description: Constructs a pair with reversed argument order: (xcons d a) = (cons a d).
Useful for fold-based list construction where the accumulator comes first.
Example:
  (xcons '(2 3) 1) => (1 2 3)
  (fold xcons '() '(1 2 3)) => (3 2 1)
```

### `zip`

```
Syntax: (zip lst1 ...)
Library: (srfi 1)
Description: Interleaves multiple lists into a list of lists. Each element of the result is a list
of the corresponding elements from each input list. Stops at the shortest list.
Example:
  (zip '(1 2 3) '(a b c)) => ((1 a) (2 b) (3 c))
  (zip '(1 2) '(a b) '(x y)) => ((1 a x) (2 b y))
```

