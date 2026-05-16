# `(srfi 158)`

SRFI-158 — Generators and accumulators: lazy sequences, composable pipelines, and value collectors

## Exports

### `bytevector->generator`

*(no documentation)*

### `bytevector-accumulator`

```
Syntax: (bytevector-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects bytes into a bytevector.
  Returns the bytevector when called with end-of-file.
Example:
  (let ((a (bytevector-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => #u8(1 2 3)
```

### `bytevector-accumulator!`

```
Syntax: (bytevector-accumulator! bv at)
Library: (srfi 158)
Description: Returns an accumulator that stores bytes into bv starting
  at index at. Returns bv when called with end-of-file.
Example:
  (let* ((bv (make-bytevector 5 0))
         (a (bytevector-accumulator! bv 1)))
    (a 10) (a 20) (a 30) (a (eof-object))) => #u8(0 10 20 30 0)
```

### `circular-generator`

```
Syntax: (circular-generator arg1 arg2 ...)
Library: (srfi 158)
Description: Returns an infinite generator that cycles through the given
  arguments repeatedly. At least one argument is required.
Example:
  (let ((g (circular-generator 1 2 3)))
    (list (g) (g) (g) (g) (g))) => (1 2 3 1 2)
```

### `count-accumulator`

```
Syntax: (count-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that counts the number of values
  accumulated. Returns the count when called with end-of-file.
Example:
  (let ((a (count-accumulator)))
    (a 'x) (a 'y) (a 'z) (a (eof-object))) => 3
```

### `gappend`

```
Syntax: (gappend gen ...)
Library: (srfi 158)
Description: Returns a generator that yields all values from the first
  generator, then all from the second, and so on.
Example:
  (generator->list (gappend (generator 1 2) (generator 3 4)))
    => (1 2 3 4)
```

### `gcombine`

```
Syntax: (gcombine proc seed gen gen2 ...)
Library: (srfi 158)
Description: Returns a generator. Each time it is called, it applies proc
  to the next values from the generators and the current seed. proc must
  return two values: the yielded value and the new seed.
Example:
  (generator->list (gcombine (lambda (x s) (values (* x x) (+ s x)))
                             0 (generator 1 2 3 4 5)))
    => (1 4 9 16 25)
```

### `gcons*`

```
Syntax: (gcons* item ... gen)
Library: (srfi 158)
Description: Returns a generator that yields each item, then yields the
  values from gen. The last argument must be a generator.
Example:
  (generator->list (gcons* 'a 'b (generator 1 2 3)))
    => (a b 1 2 3)
```

### `gdelete`

*(no documentation)*

### `gdelete-neighbor-dups`

*(no documentation)*

### `gdrop`

```
Syntax: (gdrop gen k)
Library: (srfi 158)
Description: Returns a generator that skips the first k values from gen,
  then yields the remaining values.
Example:
  (generator->list (gdrop (generator 1 2 3 4 5) 3)) => (4 5)
```

### `gdrop-while`

```
Syntax: (gdrop-while pred gen)
Library: (srfi 158)
Description: Returns a generator that skips values from gen while pred
  returns true, then yields all remaining values.
Example:
  (generator->list (gdrop-while (lambda (x) (< x 3))
    (generator 1 2 3 4 5))) => (3 4 5)
```

### `generator`

```
Syntax: (generator arg ...)
Library: (srfi 158)
Description: Returns a generator that yields each arg in order, then returns
  end-of-file on all subsequent calls.
Example:
  (let ((g (generator 1 2 3)))
    (list (g) (g) (g) (g))) => (1 2 3 #<eof>)
```

### `generator->list`

*(no documentation)*

### `generator->reverse-list`

*(no documentation)*

### `generator->string`

*(no documentation)*

### `generator->vector`

*(no documentation)*

### `generator->vector!`

```
Syntax: (generator->vector! vec at gen)
Library: (srfi 158)
Description: Fills vec starting at index at with values from gen. Returns
  the number of elements written.
Example:
  (let ((v (make-vector 5 0)))
    (generator->vector! v 1 (generator 'a 'b 'c))
    v) => #(0 a b c 0)
```

### `generator-any`

```
Syntax: (generator-any pred gen)
Library: (srfi 158)
Description: Returns the first true value of (pred val) for values from gen,
  or #f if pred returns false for all values. Consumes gen up to the first
  true result.
Example:
  (generator-any odd? (generator 2 4 6 7 8)) => #t
```

### `generator-count`

```
Syntax: (generator-count pred gen)
Library: (srfi 158)
Description: Returns the number of values from gen for which pred returns
  true. Consumes the entire generator.
Example:
  (generator-count even? (generator 1 2 3 4 5)) => 2
```

### `generator-every`

```
Syntax: (generator-every pred gen)
Library: (srfi 158)
Description: Returns the last true value of (pred val) for values from gen,
  or #t if the generator is empty. Returns #f as soon as pred returns false.
Example:
  (generator-every odd? (generator 1 3 5 7)) => #t
  (generator-every odd? (generator 1 3 4 5)) => #f
```

### `generator-find`

```
Syntax: (generator-find pred gen)
Library: (srfi 158)
Description: Returns the first value from gen for which pred returns true,
  or #f if no such value exists. Note: consumes values from gen up to and
  including the found value.
Example:
  (generator-find even? (generator 1 3 5 6 7)) => 6
```

### `generator-fold`

```
Syntax: (generator-fold proc seed gen gen2 ...)
Library: (srfi 158)
Description: Folds over generator values. proc is called with each generated
  value (or set of values from multiple generators) and the current
  accumulator, returning the new accumulator. Returns the final accumulator
  when any generator is exhausted.
Example:
  (generator-fold + 0 (generator 1 2 3 4 5)) => 15
  (generator-fold cons '() (generator 1 2 3)) => (3 2 1)
```

### `generator-for-each`

```
Syntax: (generator-for-each proc gen gen2 ...)
Library: (srfi 158)
Description: Applies proc to each value from gen (or sets of values from
  multiple generators) for side effects. Stops when any generator is
  exhausted.
Example:
  (let ((sum 0))
    (generator-for-each (lambda (x) (set! sum (+ sum x)))
      (generator 1 2 3 4 5))
    sum) => 15
```

### `generator-map->list`

```
Syntax: (generator-map->list proc gen gen2 ...)
Library: (srfi 158)
Description: Applies proc to each value from the generators and collects
  the results into a list. Stops when any generator is exhausted.
Example:
  (generator-map->list square (generator 1 2 3 4 5))
    => (1 4 9 16 25)
```

### `generator-unfold`

```
Syntax: (generator-unfold gen unfold arg ...)
Library: (srfi 158)
Description: Uses the unfold procedure to convert generator values into a
  data structure. Equivalent to (unfold eof-object? (lambda (x) x) (lambda
  (x) (gen)) (gen) args ...). The unfold argument must be compatible with
  SRFI 1 unfold.
Example:
  (generator-unfold (generator 1 2 3) unfold) ; requires (srfi 1)
```

### `gfilter`

```
Syntax: (gfilter pred gen)
Library: (srfi 158)
Description: Returns a generator that yields only values from gen for which
  pred returns true.
Example:
  (generator->list (gfilter odd? (generator 1 2 3 4 5))) => (1 3 5)
```

### `gflatten`

```
Syntax: (gflatten gen)
Library: (srfi 158)
Description: Returns a generator that yields elements from lists produced
  by gen. Each value from gen must be a list; their elements are yielded
  in order.
Example:
  (generator->list (gflatten (generator '(1 2) '() '(3 4 5))))
    => (1 2 3 4 5)
```

### `ggroup`

*(no documentation)*

### `gindex`

```
Syntax: (gindex value-gen index-gen)
Library: (srfi 158)
Description: Returns a generator that yields elements from value-gen at
  positions specified by index-gen. index-gen must yield monotonically
  increasing non-negative integers.
Example:
  (generator->list (gindex (generator 'a 'b 'c 'd 'e)
                           (generator 0 2 4))) => (a c e)
```

### `gmap`

```
Syntax: (gmap proc gen gen2 ...)
Library: (srfi 158)
Description: Returns a generator that applies proc to the values yielded
  by the given generators. With multiple generators, stops when any
  generator is exhausted.
Example:
  (generator->list (gmap + (generator 1 2 3) (generator 10 20 30)))
    => (11 22 33)
```

### `gmerge`

```
Syntax: (gmerge less-than gen1 gen2 ...)
Library: (srfi 158)
Description: Returns a generator that merges values from multiple sorted
  generators into a single sorted sequence using the less-than predicate.
Example:
  (generator->list (gmerge < (generator 1 3 5) (generator 2 4 6)))
    => (1 2 3 4 5 6)
```

### `gremove`

```
Syntax: (gremove pred gen)
Library: (srfi 158)
Description: Returns a generator that yields only values from gen for which
  pred returns false. Equivalent to (gfilter (lambda (x) (not (pred x))) gen).
Example:
  (generator->list (gremove odd? (generator 1 2 3 4 5))) => (2 4)
```

### `gselect`

```
Syntax: (gselect value-gen truth-gen)
Library: (srfi 158)
Description: Returns a generator that yields values from value-gen where
  truth-gen yields a true value. Both generators are advanced in lockstep.
Example:
  (generator->list (gselect (generator 'a 'b 'c 'd 'e)
                            (generator #t #f #t #f #t))) => (a c e)
```

### `gstate-filter`

```
Syntax: (gstate-filter proc seed gen)
Library: (srfi 158)
Description: Returns a generator that filters values from gen using stateful
  predicate proc. proc takes the current seed and a value, and returns two
  values: the new seed and a boolean. If the boolean is true, the value is
  yielded; otherwise it is skipped.
Example:
  (generator->list (gstate-filter
    (lambda (s v) (values (+ s 1) (even? s)))
    0 (generator 'a 'b 'c 'd 'e))) => (a c e)
```

### `gtake`

*(no documentation)*

### `gtake-while`

```
Syntax: (gtake-while pred gen)
Library: (srfi 158)
Description: Returns a generator that yields values from gen as long as pred
  returns true. Stops as soon as pred returns false.
Example:
  (generator->list (gtake-while (lambda (x) (< x 4))
    (generator 1 2 3 4 5))) => (1 2 3)
```

### `list->generator`

*(no documentation)*

### `list-accumulator`

```
Syntax: (list-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a list in
  order. Returns the list when called with end-of-file.
Example:
  (let ((a (list-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => (1 2 3)
```

### `make-accumulator`

```
Syntax: (make-accumulator kons knil finalizer)
Library: (srfi 158)
Description: Creates an accumulator. When called with a value, applies kons
  to the value and current state (initialized to knil). When called with
  end-of-file, applies finalizer to the state and returns the result.
Example:
  (let ((a (make-accumulator cons '() reverse)))
    (a 1) (a 2) (a 3) (a (eof-object))) => (1 2 3)
```

### `make-coroutine-generator`

```
Syntax: (make-coroutine-generator proc)
Library: (srfi 158)
Description: Creates a generator from a coroutine. proc is a procedure that
  takes a yield argument. When yield is called with a value, the generator
  returns that value and suspends. When called again, the coroutine resumes
  after the yield. When proc returns, the generator yields end-of-file.
Example:
  (generator->list (make-coroutine-generator
    (lambda (yield)
      (yield 1) (yield 2) (yield 3)))) => (1 2 3)
```

### `make-for-each-generator`

```
Syntax: (make-for-each-generator for-each obj)
Library: (srfi 158)
Description: Creates a generator from any collection by using a for-each
  procedure. for-each must accept a procedure and obj as arguments and
  apply the procedure to each element of obj.
Example:
  (generator->list (make-for-each-generator for-each '(a b c))) => (a b c)
  (generator->list (make-for-each-generator string-for-each "abc"))
    => (#\a #\b #\c)
```

### `make-iota-generator`

*(no documentation)*

### `make-range-generator`

*(no documentation)*

### `make-unfold-generator`

```
Syntax: (make-unfold-generator stop? mapper successor seed)
Library: (srfi 158)
Description: Creates a generator that unfolds a sequence. Starting from seed,
  if stop? returns true, the generator is done. Otherwise it yields
  (mapper seed), then updates seed to (successor seed) and repeats.
Example:
  (generator->list (make-unfold-generator
    (lambda (s) (> s 5))
    (lambda (s) (* s s))
    (lambda (s) (+ s 1))
    1)) => (1 4 9 16 25)
```

### `product-accumulator`

```
Syntax: (product-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that computes the product of accumulated
  values. Returns the product when called with end-of-file.
Example:
  (let ((a (product-accumulator)))
    (a 1) (a 2) (a 3) (a 4) (a (eof-object))) => 24
```

### `reverse-list-accumulator`

```
Syntax: (reverse-list-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a list in
  reverse order. Returns the reversed list when called with end-of-file.
Example:
  (let ((a (reverse-list-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => (3 2 1)
```

### `reverse-vector->generator`

*(no documentation)*

### `reverse-vector-accumulator`

```
Syntax: (reverse-vector-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a vector in
  reverse order. Returns the vector when called with end-of-file.
Example:
  (let ((a (reverse-vector-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => #(3 2 1)
```

### `string->generator`

*(no documentation)*

### `string-accumulator`

```
Syntax: (string-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects characters into a string.
  Returns the string when called with end-of-file.
Example:
  (let ((a (string-accumulator)))
    (a #\a) (a #\b) (a #\c) (a (eof-object))) => "abc"
```

### `sum-accumulator`

```
Syntax: (sum-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that computes the sum of accumulated
  values. Returns the sum when called with end-of-file.
Example:
  (let ((a (sum-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => 6
```

### `vector->generator`

*(no documentation)*

### `vector-accumulator`

```
Syntax: (vector-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a vector in
  order. Returns the vector when called with end-of-file.
Example:
  (let ((a (vector-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => #(1 2 3)
```

### `vector-accumulator!`

```
Syntax: (vector-accumulator! vec at)
Library: (srfi 158)
Description: Returns an accumulator that stores values into vec starting
  at index at. Returns vec when called with end-of-file.
Example:
  (let* ((v (make-vector 5 0))
         (a (vector-accumulator! v 1)))
    (a 'a) (a 'b) (a 'c) (a (eof-object))) => #(0 a b c 0)
```

