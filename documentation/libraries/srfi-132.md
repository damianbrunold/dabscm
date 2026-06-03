# `(srfi 132)`

SRFI-132 — Sort libraries: list/vector sort, merge, select, median

## Overview

SRFI-132 is the sort library for lists and vectors: stable sorting, merging,
in-place variants, plus selection utilities (find the nth element, the median, or
take the smallest k) without fully sorting.

## Common uses

```scheme
(import (srfi 132))

(list-sort < '(3 1 2))            ;; => (1 2 3)
(vector-sort < (vector 3 1 2))    ;; => #(1 2 3)
```

`list-sort!` / `vector-sort!` sort in place, `list-merge` / `vector-merge` merge
sorted sequences, and `vector-select!` / `vector-find-median` provide order
statistics.


## Exports

### `list-delete-neighbor-dups`

```
Syntax: (list-delete-neighbor-dups = lis)
Library: (srfi 132)
Description: Returns a list with adjacent duplicate elements removed. Elements
are compared using the equality predicate =. The first element of each run of
equal elements is retained. The input list is not modified. Shares common tail
structure with the input when possible.
Example:
  (list-delete-neighbor-dups = '(1 1 2 3 3 3 4)) => (1 2 3 4)
  (list-delete-neighbor-dups = '()) => ()
```

### `list-delete-neighbor-dups!`

```
Syntax: (list-delete-neighbor-dups! = lis)
Library: (srfi 132)
Description: Destructively removes adjacent duplicate elements from lis by
relinking cons cells with set-cdr!. Elements are compared using =. The first
element of each run of equal elements is retained. Returns the modified list.
Example:
  (list-delete-neighbor-dups! = (list 1 1 2 3 3 3 4)) => (1 2 3 4)
```

### `list-merge`

```
Syntax: (list-merge < lis1 lis2)
Library: (srfi 132)
Description: Merges two sorted lists into a single sorted list. Both input
lists must already be sorted according to <. The merge is stable: elements
from lis1 are preferred over equal elements from lis2. The input lists are
not modified.
Example:
  (list-merge < '(1 3 5) '(2 4 6)) => (1 2 3 4 5 6)
  (list-merge < '(1 2) '(2 3)) => (1 2 2 3)
```

### `list-merge!`

```
Syntax: (list-merge! < lis1 lis2)
Library: (srfi 132)
Description: Merges two sorted lists into a single sorted list. Both input
lists must already be sorted according to <. This is a destructive variant
that may modify the cons cells of the input lists via set-cdr!.
Example:
  (list-merge! < (list 1 3 5) (list 2 4 6)) => (1 2 3 4 5 6)
```

### `list-sort`

```
Syntax: (list-sort < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to the comparison procedure <. The original list is not
modified. The sort is stable: equal elements maintain their relative order.
Example:
  (list-sort < '(3 1 4 1 5 9)) => (1 1 3 4 5 9)
  (list-sort string<? '("banana" "apple" "cherry")) => ("apple" "banana" "cherry")
```

### `list-sort!`

```
Syntax: (list-sort! < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to <. This is a linear-update variant that modifies the input
list's cons cells to avoid allocation.
Example:
  (list-sort! < '(3 1 4 1 5)) => (1 1 3 4 5)
```

### `list-sorted?`

```
Syntax: (list-sorted? < lis)
Library: (srfi 132)
Description: Returns #t if the elements of lis are in non-decreasing order
according to the comparison procedure <, #f otherwise. Returns #t for empty
and single-element lists.
Example:
  (list-sorted? < '(1 2 3)) => #t
  (list-sorted? < '(3 1 2)) => #f
  (list-sorted? < '()) => #t
```

### `list-stable-sort`

```
Syntax: (list-stable-sort < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to <. The sort is stable: equal elements maintain their
relative order. Equivalent to list-sort since the underlying merge sort
algorithm is stable.
Example:
  (list-stable-sort < '(3 1 4 1 5)) => (1 1 3 4 5)
```

### `list-stable-sort!`

```
Syntax: (list-stable-sort! < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to <. This is a stable, linear-update variant that modifies
the input list's cons cells to avoid allocation.
Example:
  (list-stable-sort! < '(3 1 4 1 5)) => (1 1 3 4 5)
```

### `vector-delete-neighbor-dups`

```
Syntax: (vector-delete-neighbor-dups = v)
       (vector-delete-neighbor-dups = v start)
       (vector-delete-neighbor-dups = v start end)
Library: (srfi 132)
Description: Returns a newly allocated vector with adjacent duplicate elements
removed from the range [start, end) of v. Elements are compared using =. The
first element of each run of equal elements is retained.
Example:
  (vector-delete-neighbor-dups = #(1 1 2 3 3 4)) => #(1 2 3 4)
  (vector-delete-neighbor-dups = #(1 2 3)) => #(1 2 3)
```

### `vector-delete-neighbor-dups!`

```
Syntax: (vector-delete-neighbor-dups! = v)
       (vector-delete-neighbor-dups! = v start)
       (vector-delete-neighbor-dups! = v start end)
Library: (srfi 132)
Description: Destructively compacts the range [start, end) of v by removing
adjacent duplicate elements. Elements are compared using =. The first element
of each run of equal elements is retained. Returns the new end index (an exact
integer), not a vector. Elements beyond the new end are unchanged.
Example:
  (let ((v (vector 1 1 2 3 3 4)))
    (vector-delete-neighbor-dups! = v)) => 4
```

### `vector-find-median`

```
Syntax: (vector-find-median < v knil)
       (vector-find-median < v knil mean)
Library: (srfi 132)
Description: Finds the median of the elements in vector v according to <.
If v is empty, returns knil. If v has an odd number of elements, returns the
middle element. If v has an even number of elements and mean is provided,
returns (mean a b) where a and b are the two middle elements; otherwise
returns the lower of the two. The original vector is not modified.
Example:
  (vector-find-median < #(3 1 4 1 5) 0) => 3
  (vector-find-median < #(3 1 4 5) 0 (lambda (a b) (/ (+ a b) 2))) => 7/2
```

### `vector-find-median!`

```
Syntax: (vector-find-median! < v knil)
       (vector-find-median! < v knil mean)
Library: (srfi 132)
Description: Finds the median of the elements in vector v according to <.
If v is empty, returns knil. If v has an odd number of elements, returns the
middle element. If v has an even number of elements and mean is provided,
returns (mean a b) where a and b are the two middle elements; otherwise
returns the lower of the two. This variant sorts v in place.
Example:
  (vector-find-median! < (vector 3 1 4 1 5) 0) => 3
  (vector-find-median! < (vector 3 1 4 5) 0 (lambda (a b) (/ (+ a b) 2))) => 7/2
```

### `vector-merge`

```
Syntax: (vector-merge < v1 v2)
       (vector-merge < v1 v2 start1)
       (vector-merge < v1 v2 start1 end1)
       (vector-merge < v1 v2 start1 end1 start2)
       (vector-merge < v1 v2 start1 end1 start2 end2)
Library: (srfi 132)
Description: Merges the elements of sorted vectors v1 (range [start1, end1))
and v2 (range [start2, end2)) into a newly allocated vector in non-decreasing
order according to <. Both input ranges must already be sorted. Elements from
v1 are preferred over equal elements from v2 (stable).
Example:
  (vector-merge < #(1 3 5) #(2 4 6)) => #(1 2 3 4 5 6)
```

### `vector-merge!`

```
Syntax: (vector-merge! < to from1 from2)
       (vector-merge! < to from1 from2 start)
       (vector-merge! < to from1 from2 start start1)
       (vector-merge! < to from1 from2 start start1 end1)
       (vector-merge! < to from1 from2 start start1 end1 start2)
       (vector-merge! < to from1 from2 start start1 end1 start2 end2)
Library: (srfi 132)
Description: Merges the sorted elements of from1 (range [start1, end1)) and
from2 (range [start2, end2)) into the vector to, starting at index start.
Both source ranges must be sorted according to <. The target range must not
overlap the source ranges. Returns an unspecified value.
Example:
  (let ((v (make-vector 6)))
    (vector-merge! < v #(1 3 5) #(2 4 6))
    v) => #(1 2 3 4 5 6)
```

### `vector-select!`

```
Syntax: (vector-select! < v k)
       (vector-select! < v k start)
       (vector-select! < v k start end)
Library: (srfi 132)
Description: Returns the k-th smallest element (zero-indexed) in the range
[start, end) of vector v, according to the comparison procedure <. May
rearrange elements within the range. Runs in O(n) average time.
Example:
  (vector-select! < (vector 3 1 4 1 5) 0) => 1
  (vector-select! < (vector 3 1 4 1 5) 2) => 3
  (vector-select! < (vector 3 1 4 1 5) 4) => 5
```

### `vector-separate!`

```
Syntax: (vector-separate! < v k)
       (vector-separate! < v k start)
       (vector-separate! < v k start end)
Library: (srfi 132)
Description: Rearranges the elements of v in the range [start, end) so that
the k smallest elements (according to <) are in positions [start, start+k).
The remaining elements are in positions [start+k, end) in unspecified order.
Returns an unspecified value.
Example:
  (let ((v (vector 5 3 1 4 2)))
    (vector-separate! < v 2)
    (let ((first-two (list (vector-ref v 0) (vector-ref v 1))))
      (list-sort < first-two))) => (1 2)
```

### `vector-sort`

```
Syntax: (vector-sort < v)
       (vector-sort < v start)
       (vector-sort < v start end)
Library: (srfi 132)
Description: Returns a newly allocated vector containing the elements of v in
the range [start, end) sorted in non-decreasing order according to <. The
original vector is not modified. The sort is stable.
Example:
  (vector-sort < #(3 1 4 1 5)) => #(1 1 3 4 5)
  (vector-sort < #(5 3 1 4 2) 1 4) => #(1 3 4)
```

### `vector-sort!`

```
Syntax: (vector-sort! < v)
       (vector-sort! < v start)
       (vector-sort! < v start end)
Library: (srfi 132)
Description: Sorts the elements of vector v in the range [start, end) in
non-decreasing order according to <. The sort is performed in place. The sort
is stable. Returns an unspecified value. start defaults to 0 and end defaults
to the length of v.
Example:
  (let ((v (vector 3 1 4 1 5))) (vector-sort! < v) v) => #(1 1 3 4 5)
```

### `vector-sorted?`

```
Syntax: (vector-sorted? < v)
       (vector-sorted? < v start)
       (vector-sorted? < v start end)
Library: (srfi 132)
Description: Returns #t if the elements of v in the range [start, end) are in
non-decreasing order according to <, #f otherwise. start defaults to 0 and
end defaults to the length of v.
Example:
  (vector-sorted? < #(1 2 3)) => #t
  (vector-sorted? < #(3 1 2)) => #f
  (vector-sorted? < #(1 3 2 4) 2 4) => #t
```

### `vector-stable-sort`

```
Syntax: (vector-stable-sort < v)
       (vector-stable-sort < v start)
       (vector-stable-sort < v start end)
Library: (srfi 132)
Description: Returns a newly allocated vector containing the elements of v in
the range [start, end) sorted in non-decreasing order according to <. The
original vector is not modified. The sort is stable. Equivalent to vector-sort.
Example:
  (vector-stable-sort < #(3 1 4 1 5)) => #(1 1 3 4 5)
```

### `vector-stable-sort!`

```
Syntax: (vector-stable-sort! < v)
       (vector-stable-sort! < v start)
       (vector-stable-sort! < v start end)
Library: (srfi 132)
Description: Sorts the elements of vector v in the range [start, end) in
non-decreasing order according to <. The sort is performed in place and is
stable: equal elements maintain their relative order. Returns an unspecified
value. Equivalent to vector-sort!.
Example:
  (let ((v (vector 3 1 4 1 5))) (vector-stable-sort! < v) v) => #(1 1 3 4 5)
```

