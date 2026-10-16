# `(srfi 194)`

SRFI-194 — Random data generators: uniform and non-uniform distributions as generators

## Overview

SRFI-194 provides random data generators: SRFI-158 generators (thunks) that
produce random integers, reals, complex numbers, booleans, characters, strings
and vectors following uniform and non-uniform distributions (normal,
exponential, geometric, Poisson, binomial, Zipf, categorical, points on
spheres and in balls). The randomness comes from SRFI-27 random sources.

## Common uses

```scheme
(import (srfi 158) (srfi 194))

(define die (make-random-integer-generator 1 7))
(generator->list die 5)                       ;; => e.g. (3 6 1 1 4)

(define heights (make-normal-generator 175.0 7.0))
(heights)                                     ;; => e.g. 181.3...

(generator->list (make-random-string-generator 8 "abcdef") 3)
```

Each generator captures `current-random-source` (initially SRFI-27's
`default-random-source`) when it is created. Bind it to get reproducible or
independent data:

```scheme
(import (srfi 27))
(define s (make-random-source))
(random-source-pseudo-randomize! s 42 0)
(define g (with-random-source s (lambda () (make-random-real-generator 0.0 1.0))))
```

`make-random-source-generator` yields a series of independent, deterministic
random sources, and `gsampling` interleaves several generators at random.


## Exports

### `clamp-real-number`

```
Syntax: (clamp-real-number lower-bound upper-bound value)
Library: (srfi 194)
Description: Returns value clamped to the closed interval
  [lower-bound, upper-bound].  Not a generator.  Mixing exact and inexact
  arguments may give surprising results.
Example:
  (clamp-real-number 0.0 1.0 1.5) => 1.0
```

### `current-random-source`

*(no documentation)*

### `gsampling`

```
Syntax: (gsampling generator ...)
Library: (srfi 194)
Description: Returns a generator that, on each call, picks one of the given
  generators with equal probability and returns its next value.  Exhausted
  generators are dropped; once all are exhausted (or none were given) it
  returns an end-of-file object.
Example:
  (length (generator->list (gsampling (generator 1 2) (generator 3)))) => 3
```

### `make-ball-generator`

```
Syntax: (make-ball-generator n)
       (make-ball-generator axes)
Library: (srfi 194)
Description: Returns a generator of points uniformly distributed inside an
  n-dimensional unit ball (n a positive exact integer), or inside the
  ellipsoid with the axis lengths in the vector axes.  Each point is a
  vector of inexact reals.
Example:
  (vector-length ((make-ball-generator 2))) => 2
```

### `make-bernoulli-generator`

```
Syntax: (make-bernoulli-generator p)
Library: (srfi 194)
Description: Returns a generator of 1 with probability p and 0 with
  probability 1 - p, where 0 <= p <= 1.
Example:
  ((make-bernoulli-generator 1)) => 1
```

### `make-binomial-generator`

```
Syntax: (make-binomial-generator n p)
Library: (srfi 194)
Description: Returns a generator of exact integers in [0, n] with a binomial
  distribution: the number of successes in n Bernoulli(p) trials.  n must
  be a positive exact integer and 0 <= p <= 1.
Example:
  ((make-binomial-generator 10 1)) => 10
```

### `make-categorical-generator`

```
Syntax: (make-categorical-generator weights-vector)
Library: (srfi 194)
Description: Returns a generator of exact integers in [0, n), where n is
  the length of weights-vector, returning i with probability proportional
  to the i-th weight.  Weights must be positive numbers.
Example:
  ((make-categorical-generator #(0.0001 1000))) => 1
```

### `make-ellipsoid-generator`

```
Syntax: (make-ellipsoid-generator axes)
Library: (srfi 194)
Description: Returns a generator of points uniformly distributed on the
  surface of the ellipsoid whose axis lengths are given by the vector axes
  of positive finite reals.  Each point is a vector of inexact reals.
Example:
  (vector-length ((make-ellipsoid-generator #(1.0 2.0 3.0)))) => 3
```

### `make-exponential-generator`

```
Syntax: (make-exponential-generator mean)
Library: (srfi 194)
Description: Returns a generator of inexact reals with an exponential
  distribution with the given (finite, positive) mean.
Example:
  (positive? ((make-exponential-generator 2.0))) => #t
```

### `make-geometric-generator`

```
Syntax: (make-geometric-generator p)
Library: (srfi 194)
Description: Returns a generator of exact positive integers with a geometric
  distribution: the number of Bernoulli(p) trials up to and including the
  first success, 0 < p <= 1.  The mean is 1/p.
Example:
  ((make-geometric-generator 1)) => 1
```

### `make-normal-generator`

*(no documentation)*

### `make-poisson-generator`

```
Syntax: (make-poisson-generator L)
Library: (srfi 194)
Description: Returns a generator of exact non-negative integers with a
  Poisson distribution with mean and variance L (a finite positive real).
Example:
  (exact-integer? ((make-poisson-generator 4.5))) => #t
```

### `make-random-boolean-generator`

```
Syntax: (make-random-boolean-generator)
Library: (srfi 194)
Description: Returns a generator of #t and #f with equal probability.
Example:
  (boolean? ((make-random-boolean-generator))) => #t
```

### `make-random-char-generator`

```
Syntax: (make-random-char-generator string)
Library: (srfi 194)
Description: Returns a generator of characters drawn uniformly from string.
  Repeated characters are proportionally more likely.  string must not be
  empty.
Example:
  (char? ((make-random-char-generator "abc"))) => #t
```

### `make-random-integer-generator`

```
Syntax: (make-random-integer-generator lower-bound upper-bound)
Library: (srfi 194)
Description: Returns a generator of exact integers uniformly distributed in
  [lower-bound, upper-bound).  Both bounds must be exact integers and the
  interval must not be empty.
Example:
  (<= 1 ((make-random-integer-generator 1 7)) 6) => #t
```

### `make-random-polar-generator`

*(no documentation)*

### `make-random-real-generator`

```
Syntax: (make-random-real-generator lower-bound upper-bound)
Library: (srfi 194)
Description: Returns a generator of inexact reals uniformly distributed in
  [lower-bound, upper-bound].  The bounds must be finite reals with
  lower-bound < upper-bound.
Example:
  (<= 1.0 ((make-random-real-generator 1.0 2.0)) 2.0) => #t
```

### `make-random-rectangular-generator`

```
Syntax: (make-random-rectangular-generator real-lower-bound real-upper-bound
                                           imag-lower-bound imag-upper-bound)
Library: (srfi 194)
Description: Returns a generator of inexact complex numbers uniformly
  distributed in the closed rectangle with the given bounds for the real and
  the imaginary part.
Example:
  (let ((z ((make-random-rectangular-generator -1.0 1.0 -1.0 1.0))))
    (<= -1.0 (imag-part z) 1.0)) => #t
```

### `make-random-s16-generator`

```
Syntax: (make-random-s16-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-2^15, 2^15 - 1].
Example:
  (<= -32768 ((make-random-s16-generator)) 32767) => #t
```

### `make-random-s32-generator`

```
Syntax: (make-random-s32-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-2^31, 2^31 - 1].
Example:
  (< ((make-random-s32-generator)) (expt 2 31)) => #t
```

### `make-random-s64-generator`

```
Syntax: (make-random-s64-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-2^63, 2^63 - 1].
Example:
  (< ((make-random-s64-generator)) (expt 2 63)) => #t
```

### `make-random-s8-generator`

```
Syntax: (make-random-s8-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-128, 127].
Example:
  (<= -128 ((make-random-s8-generator)) 127) => #t
```

### `make-random-source-generator`

```
Syntax: (make-random-source-generator i)
Library: (srfi 194)
Description: Returns a generator of fresh SRFI 27 random sources.  The n-th
  source returned (counting from 0) is a new random source pseudo-randomized
  with (random-source-pseudo-randomize! source i n), so the sources are
  deterministic and independent of each other.
Example:
  (let ((g (make-random-source-generator 0)))
    (random-source? (g))) => #t
```

### `make-random-string-generator`

```
Syntax: (make-random-string-generator k string)
Library: (srfi 194)
Description: Returns a generator of strings made of characters drawn
  uniformly from string, with lengths uniformly distributed in [0, k).
Example:
  (< (string-length ((make-random-string-generator 5 "ab"))) 5) => #t
```

### `make-random-u1-generator`

```
Syntax: (make-random-u1-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers 0 or 1.
Example:
  (<= 0 ((make-random-u1-generator)) 1) => #t
```

### `make-random-u16-generator`

```
Syntax: (make-random-u16-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 2^16 - 1].
Example:
  (<= 0 ((make-random-u16-generator)) 65535) => #t
```

### `make-random-u32-generator`

```
Syntax: (make-random-u32-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 2^32 - 1].
Example:
  (< ((make-random-u32-generator)) (expt 2 32)) => #t
```

### `make-random-u64-generator`

```
Syntax: (make-random-u64-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 2^64 - 1].
Example:
  (< ((make-random-u64-generator)) (expt 2 64)) => #t
```

### `make-random-u8-generator`

```
Syntax: (make-random-u8-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 255].
Example:
  (<= 0 ((make-random-u8-generator)) 255) => #t
```

### `make-sphere-generator`

```
Syntax: (make-sphere-generator n)
Library: (srfi 194)
Description: Returns a generator of points uniformly distributed on the
  surface of the unit n-sphere, as vectors of n+1 inexact reals.  n must be
  a positive exact integer.
Example:
  (vector-length ((make-sphere-generator 2))) => 3
```

### `make-zipf-generator`

*(no documentation)*

### `with-random-source`

```
Syntax: (with-random-source random-source thunk)
Library: (srfi 194)
Description: Calls thunk with current-random-source bound to the SRFI 27
  random-source.  Generators created inside thunk draw from that source.
Example:
  (let ((s (make-random-source)))
    (random-source-pseudo-randomize! s 0 1)
    (with-random-source s
      (lambda () ((make-random-integer-generator 0 10)))))  => 0..9
```

