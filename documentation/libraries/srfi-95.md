# `(srfi 95)`

SRFI-95 — Sorting and merging: polymorphic sort, merge with optional key

## Overview

SRFI-95 provides sorting and merging for lists and vectors with a polymorphic
`sort` (and the destructive `sort!`), plus `merge` and a key-extraction option.

## Common uses

```scheme
(import (srfi 95))

(sort '(3 1 2) <)                 ;; => (1 2 3)
(sort (vector 3 1 2) <)           ;; => #(1 2 3)

;; sort by a key
(sort '("bbb" "a" "cc") < string-length)   ;; => ("a" "cc" "bbb")

(merge '(1 3 5) '(2 4 6) <)       ;; => (1 2 3 4 5 6)
```

`sort` returns a new sequence; `sort!` may rearrange its argument in place. The
optional third argument to comparisons is a key procedure applied before comparing.


## Exports

### `merge`

```
Syntax: (merge list1 list2 less?)
       (merge list1 list2 less? key)
Library: (srfi 95)
Description: Merges two sorted lists into a single sorted list. Both input
lists must already be sorted according to less?. The merge is stable: equal
elements from list1 appear before those from list2. The input lists are not
modified. If key is provided, it is applied to each element before comparison.
Example:
  (merge '(1 3 5) '(2 4 6) <) => (1 2 3 4 5 6)
  (merge '((a . 1) (b . 3)) '((c . 2) (d . 4)) < cdr)
    => ((a . 1) (c . 2) (b . 3) (d . 4))
```

### `merge!`

```
Syntax: (merge! list1 list2 less?)
       (merge! list1 list2 less? key)
Library: (srfi 95)
Description: Destructively merges two sorted lists into a single sorted list
by reusing the cons cells of the input lists via set-cdr!. Both input lists
must already be sorted according to less?. The merge is stable. If key is
provided, it is applied to each element before comparison.
Example:
  (merge! (list 1 3 5) (list 2 4 6) <) => (1 2 3 4 5 6)
```

### `sort`

```
Syntax: (sort sequence less?)
       (sort sequence less? key)
Library: (srfi 95)
Description: Returns a new sequence containing the elements of sequence sorted
in non-decreasing order according to less?. The returned sequence is the same
type as the input (list, vector, or string). The original sequence is not
modified. The sort is stable. If key is provided, it is applied to each
element before comparison; the original elements (not the keys) appear in the
result.
Example:
  (sort '(3 1 4 1 5) <) => (1 1 3 4 5)
  (sort #(3 1 2) <) => #(1 2 3)
  (sort "cab" char<?) => "abc"
  (sort '((a . 2) (b . 1) (c . 2)) < cdr) => ((b . 1) (a . 2) (c . 2))
```

### `sort!`

```
Syntax: (sort! sequence less?)
       (sort! sequence less? key)
Library: (srfi 95)
Description: Sorts the elements of sequence in non-decreasing order according
to less?. This is a destructive variant that may modify the input sequence.
For vectors, the sort is performed in place. For lists, the cons cells may be
relinked. For strings, a new sorted string is returned (strings are immutable).
The sort is stable. If key is provided, it is applied to each element before
comparison; the original elements (not the keys) appear in the result.
Example:
  (sort! (list 3 1 4 1 5) <) => (1 1 3 4 5)
  (let ((v (vector 3 1 2))) (sort! v <) v) => #(1 2 3)
  (sort! '((a . 2) (b . 1)) < cdr) => ((b . 1) (a . 2))
```

### `sorted?`

```
Syntax: (sorted? sequence less?)
       (sorted? sequence less? key)
Library: (srfi 95)
Description: Returns #t if the elements of sequence are in non-decreasing
order according to the comparison procedure less?, #f otherwise. The sequence
may be a list, vector, or string. If key is provided, it is applied to each
element before comparison.
Example:
  (sorted? '(1 2 3) <) => #t
  (sorted? #(3 1 2) <) => #f
  (sorted? '((a . 1) (b . 2) (c . 3)) < cdr) => #t
```

