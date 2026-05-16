# `(srfi 133)`

SRFI-133 — Vector libraries

## Exports

### `list->vector`

```
Syntax: (list->vector list)
Library: (scheme base)
Description: Returns a newly created vector initialized to the elements of
  the argument list.
Example:
  (list->vector '(a b c)) => #(a b c)
  (list->vector '())      => #()
```

### `make-vector`

```
Syntax: (make-vector k) (make-vector k fill)
Library: (scheme base)
Description: Returns a newly allocated vector of k elements. If fill is given, every element is initialized to fill; otherwise each element is 0.
Example:
  (make-vector 3 0) => #(0 0 0)
  (make-vector 3 'a) => #(a a a)
```

### `reverse-list->vector`

```
Syntax: (reverse-list->vector list)
Library: (srfi 133)
Description: Returns a newly allocated vector whose elements are the
  elements of list in reverse order.
Example:
  (reverse-list->vector '(a b c)) => #(c b a)
```

### `reverse-vector->list`

```
Syntax: (reverse-vector->list vec)
       (reverse-vector->list vec start)
       (reverse-vector->list vec start end)
Library: (srfi 133)
Description: Returns a list of the elements of vec between start and end
  in reverse order.
Example:
  (reverse-vector->list '#(a b c d e) 1 4) => (d c b)
```

### `string->vector`

```
Syntax: (string->vector string)
       (string->vector string start)
       (string->vector string start end)
Library: (scheme base)
Description: Returns a newly created vector initialized to the elements of
  the string between start and end. start defaults to 0 and end defaults to
  the length of the string.
Example:
  (string->vector "abc")     => #(#\a #\b #\c)
  (string->vector "abc" 1)   => #(#\b #\c)
  (string->vector "abc" 1 2) => #(#\b)
```

### `vector`

```
Syntax: (vector obj ...)
Library: (scheme base)
Description: Returns a newly allocated vector whose elements contain the given arguments.
Example:
  (vector 1 2 3) => #(1 2 3)
  (vector 'a 'b 'c) => #(a b c)
```

### `vector->list`

```
Syntax: (vector->list vector)
Library: (scheme base)
Description: Returns a newly allocated list containing the elements of vector in order. Optional start and end indices (zero-based, exclusive end) may be supplied to convert a subrange.
Example:
  (vector->list #(a b c)) => (a b c)
  (vector->list #(a b c d) 1 3) => (b c)
```

### `vector->string`

```
Syntax: (vector->string vector)
       (vector->string vector start)
       (vector->string vector start end)
Library: (scheme base)
Description: Returns a newly allocated string of the objects contained in the
  elements of vector between start and end. It is an error if any element is
  not a character. start defaults to 0 and end defaults to the length of the
  vector.
Example:
  (vector->string #(#\a #\b #\c))     => "abc"
  (vector->string #(#\a #\b #\c) 1)   => "bc"
  (vector->string #(#\a #\b #\c) 1 2) => "b"
```

### `vector-any`

```
Syntax: (vector-any pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the first true value returned by pred applied to
  corresponding elements, or #f if pred returns #f for all elements.
Example:
  (vector-any even? '#(1 2 3)) => #t
  (vector-any even? '#(1 3 5)) => #f
```

### `vector-append`

```
Syntax: (vector-append vector ...)
Library: (scheme base)
Description: Returns a newly allocated vector whose elements are the
  concatenation of the elements of the given vectors. With no arguments,
  returns an empty vector.
Example:
  (vector-append '#(a b) '#(c d)) => #(a b c d)
  (vector-append '#(a) '#() '#(b c)) => #(a b c)
```

### `vector-append-subvectors`

```
Syntax: (vector-append-subvectors vec1 start1 end1 ...)
Library: (srfi 133)
Description: Returns a vector that contains every element of each vec from
  start to end in order. The arguments alternate between vectors and
  start/end index pairs.
Example:
  (vector-append-subvectors '#(a b c d e) 0 2 '#(f g h) 1 3)
    => #(a b g h)
```

### `vector-binary-search`

```
Syntax: (vector-binary-search vec value cmp)
Library: (srfi 133)
Description: Performs binary search on a sorted vector. cmp is a procedure
  of two arguments that returns a negative integer if the first is less,
  zero if equal, and positive if greater. Returns the index of the matching
  element or #f.
Example:
  (vector-binary-search '#(1 3 5 7 9) 5
    (lambda (a b) (- a b))) => 2
```

### `vector-concatenate`

```
Syntax: (vector-concatenate list-of-vectors)
Library: (srfi 133)
Description: Appends each vector in list-of-vectors. Equivalent to
  (apply vector-append list-of-vectors).
Example:
  (vector-concatenate '(#(a b) #(c d))) => #(a b c d)
```

### `vector-copy`

```
Syntax: (vector-copy vec)
       (vector-copy vec start)
       (vector-copy vec start end)
       (vector-copy vec start end fill)
Library: (srfi 133)
Description: Returns a newly allocated copy of the elements of vec between
  start and end. If end is greater than the length of vec, the additional
  elements are set to fill.
Example:
  (vector-copy '#(a b c d e) 1 3) => #(b c)
  (vector-copy '#(a b c) 0 5 'x) => #(a b c x x)
```

### `vector-copy!`

```
Syntax: (vector-copy! to at from)
       (vector-copy! to at from start)
       (vector-copy! to at from start end)
Library: (scheme base)
Description: Copies the elements of vector from between start and end to
  vector to, starting at at. The order in which elements are copied is
  unspecified, except that if the source and destination overlap, copying
  takes place as if the source is first copied into a temporary vector and
  then into the destination. start defaults to 0 and end defaults to the
  length of from.
Example:
  (let ((v (vector 1 2 3 4 5)))
    (vector-copy! v 1 '#(10 11 12) 1 3)
    v) => #(1 11 12 4 5)
```

### `vector-count`

```
Syntax: (vector-count pred vec1 vec2 ...)
Library: (srfi 133)
Description: Counts the number of indices i for which (pred vec1[i] vec2[i]
  ...) returns true. The count is over the minimum length of the vectors.
Example:
  (vector-count even? '#(1 2 3 4 5)) => 2
```

### `vector-cumulate`

```
Syntax: (vector-cumulate f knil vec)
Library: (srfi 133)
Description: Returns a newly allocated vector where element i is the result
  of applying f to the cumulated value and element i, starting with knil.
  Like a running fold stored in a vector.
Example:
  (vector-cumulate + 0 '#(1 2 3 4)) => #(1 3 6 10)
```

### `vector-empty?`

```
Syntax: (vector-empty? vec)
Library: (srfi 133)
Description: Returns #t if vec has length 0, #f otherwise.
Example:
  (vector-empty? '#()) => #t
  (vector-empty? '#(1)) => #f
```

### `vector-every`

```
Syntax: (vector-every pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the last true value returned by pred if pred returns
  true for all corresponding elements, or #f as soon as pred returns #f.
  Returns #t for empty vectors.
Example:
  (vector-every even? '#(2 4 6)) => #t
  (vector-every even? '#(2 3 6)) => #f
```

### `vector-fill!`

```
Syntax: (vector-fill! vec fill)
       (vector-fill! vec fill start)
       (vector-fill! vec fill start end)
Library: (srfi 133)
Description: Stores fill in every element of vec between start (inclusive,
  default 0) and end (exclusive, default length).
Example:
  (let ((v (vector 1 2 3 4 5)))
    (vector-fill! v 0 1 4)
    v) => #(1 0 0 0 5)
```

### `vector-fold`

```
Syntax: (vector-fold kons knil vec1 vec2 ...)
Library: (srfi 133)
Description: Left fold over vectors. kons is called as (kons index state
  val1 val2 ...) for each index from 0 to length-1, where length is the
  minimum length of the given vectors.
Example:
  (vector-fold (lambda (i sum x) (+ sum x)) 0 '#(1 2 3)) => 6
```

### `vector-fold-right`

```
Syntax: (vector-fold-right kons knil vec1 vec2 ...)
Library: (srfi 133)
Description: Right fold over vectors. kons is called as (kons index state
  val1 val2 ...) for each index from length-1 down to 0.
Example:
  (vector-fold-right (lambda (i tail x) (cons x tail)) '() '#(a b c))
    => (a b c)
```

### `vector-for-each`

```
Syntax: (vector-for-each proc vector1 vector2 ...)
Library: (scheme base)
Description: It is an error if proc does not accept as many arguments as
  there are vectors. Applies proc element-wise to the elements of the vectors
  for its side effects, in order from the first element to the last. The
  return value is unspecified.
Example:
  (vector-for-each display '#(a b c)) ; displays abc
```

### `vector-index`

```
Syntax: (vector-index pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the index of the first element for which (pred vec1[i]
  vec2[i] ...) returns true, or #f if no such element exists.
Example:
  (vector-index even? '#(1 2 3 4)) => 1
  (vector-index odd? '#(2 4 6)) => #f
```

### `vector-index-right`

```
Syntax: (vector-index-right pred vec1 vec2 ...)
Library: (srfi 133)
Description: Like vector-index, but searches from right to left, returning
  the index of the last matching element.
Example:
  (vector-index-right even? '#(1 2 3 4)) => 3
```

### `vector-length`

```
Syntax: (vector-length v)
Library: (scheme base)
Description: Returns the number of elements in vector v.
Example:
  (vector-length #(1 2 3)) => 3
  (vector-length (vector)) => 0
```

### `vector-map`

```
Syntax: (vector-map proc vector1 vector2 ...)
Library: (scheme base)
Description: It is an error if proc does not accept as many arguments as
  there are vectors and return a single value. Applies proc element-wise to
  the elements of the vectors and returns a vector of the results. The
  dynamic order in which proc is applied to the elements is unspecified.
Example:
  (vector-map + '#(1 2 3) '#(4 5 6)) => #(5 7 9)
  (vector-map cadr '#((a b) (d e) (g h))) => #(b e h)
```

### `vector-map!`

```
Syntax: (vector-map! f vec1 vec2 ...)
Library: (srfi 133)
Description: Like vector-map, but stores the results in vec1, mutating it
  in place. Returns unspecified.
Example:
  (let ((v (vector 1 2 3)))
    (vector-map! (lambda (x) (* x x)) v)
    v) => #(1 4 9)
```

### `vector-partition`

```
Syntax: (vector-partition pred vec)
Library: (srfi 133)
Description: Returns two values: a vector of elements satisfying pred, and
  a vector of elements not satisfying pred, both in their original order.
Example:
  (call-with-values (lambda () (vector-partition even? '#(1 2 3 4 5)))
    list) => (#(2 4) #(1 3 5))
```

### `vector-ref`

```
Syntax: (vector-ref v k)
Library: (scheme base)
Description: Returns the element at index k in vector v. If k is out of range and a default is provided, returns the default instead of signalling an error.
Example:
  (vector-ref #(a b c) 1) => b
  (vector-ref #(a b c) 5 'none) => none
```

### `vector-reverse!`

```
Syntax: (vector-reverse! vec)
       (vector-reverse! vec start)
       (vector-reverse! vec start end)
Library: (srfi 133)
Description: Reverses the elements of vec in place between start and end.
Example:
  (let ((v (vector 1 2 3 4 5)))
    (vector-reverse! v 1 4)
    v) => #(1 4 3 2 5)
```

### `vector-reverse-copy`

```
Syntax: (vector-reverse-copy vec)
       (vector-reverse-copy vec start)
       (vector-reverse-copy vec start end)
Library: (srfi 133)
Description: Returns a newly allocated vector containing the elements of vec
  between start and end in reverse order.
Example:
  (vector-reverse-copy '#(a b c d e) 1 4) => #(d c b)
```

### `vector-reverse-copy!`

```
Syntax: (vector-reverse-copy! to at from)
       (vector-reverse-copy! to at from start)
       (vector-reverse-copy! to at from start end)
Library: (srfi 133)
Description: Copies elements from the vector from between start and end in
  reverse order into the vector to, starting at index at.
Example:
  (let ((v (vector 'x 'x 'x 'x 'x)))
    (vector-reverse-copy! v 1 '#(a b c) 0 3)
    v) => #(x c b a x)
```

### `vector-set!`

```
Syntax: (vector-set! v k obj)
Library: (scheme base)
Description: Stores obj in element k of vector v. It is an error if k is not a valid index of v.
Example:
  (let ((v (vector 1 2 3))) (vector-set! v 1 99) v) => #(1 99 3)
```

### `vector-skip`

```
Syntax: (vector-skip pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the index of the first element for which pred returns
  #f, or #f if pred is true for all elements.
Example:
  (vector-skip odd? '#(1 3 2 4)) => 2
```

### `vector-skip-right`

```
Syntax: (vector-skip-right pred vec1 vec2 ...)
Library: (srfi 133)
Description: Like vector-skip, but searches from right to left.
Example:
  (vector-skip-right odd? '#(1 3 2 4)) => 3
```

### `vector-swap!`

```
Syntax: (vector-swap! vec i j)
Library: (srfi 133)
Description: Swaps the elements at indices i and j in vec.
Example:
  (let ((v (vector 'a 'b 'c)))
    (vector-swap! v 0 2)
    v) => #(c b a)
```

### `vector-unfold`

```
Syntax: (vector-unfold f length seed ...)
Library: (srfi 133)
Description: Creates a vector of the given length by applying f to each index
  and the current seed values. f must return the element value followed by
  new seed values via multiple return values.
Example:
  (vector-unfold (lambda (i) i) 5) => #(0 1 2 3 4)
  (vector-unfold (lambda (i x) (values x (+ x 1))) 5 0) => #(0 1 2 3 4)
```

### `vector-unfold!`

```
Syntax: (vector-unfold! f vec start end seed ...)
Library: (srfi 133)
Description: Like vector-unfold, but stores the elements into vec between
  start (inclusive) and end (exclusive) rather than creating a new vector.
Example:
  (let ((v (make-vector 5 0)))
    (vector-unfold! (lambda (i) (* i i)) v 1 4)
    v) => #(0 1 4 9 0)
```

### `vector-unfold-right`

```
Syntax: (vector-unfold-right f length seed ...)
Library: (srfi 133)
Description: Like vector-unfold, but fills the vector from right to left,
  starting at index length-1 down to 0.
Example:
  (vector-unfold-right (lambda (i x) (values x (+ x 1))) 5 0)
    => #(4 3 2 1 0)
```

### `vector-unfold-right!`

```
Syntax: (vector-unfold-right! f vec start end seed ...)
Library: (srfi 133)
Description: Like vector-unfold-right, but stores the elements into vec
  between start and end rather than creating a new vector.
Example:
  (let ((v (make-vector 5 0)))
    (vector-unfold-right! (lambda (i) (* i i)) v 1 4)
    v) => #(0 1 4 9 0)
```

### `vector=`

```
Syntax: (vector= elt= vec ...)
Library: (srfi 133)
Description: Compares vectors element-wise using elt= as the element
  comparison procedure. Returns #t if all vectors have the same length and
  corresponding elements are equal according to elt=.
Example:
  (vector= eq? '#(a b c) '#(a b c)) => #t
  (vector= eq? '#(a b) '#(a b c)) => #f
```

### `vector?`

```
Syntax: (vector? obj)
Library: (scheme base)
Description: Returns #t if obj is a vector, #f otherwise.
Example:
  (vector? #(1 2 3)) => #t
  (vector? '(1 2 3)) => #f
```

