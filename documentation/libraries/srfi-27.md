# `(srfi 27)`

SRFI-27 — Sources of random bits: random integers and reals, seedable random sources

## Overview

SRFI-27 provides sources of random bits: uniformly distributed random integers
and reals, drawn from *random sources* whose state can be saved, restored, and
deterministically seeded. The generator is Pierre L'Ecuyer's MRG32k3a (period
about 2^191), ported from the SRFI's reference implementation.

## Common uses

```scheme
(import (srfi 27))

(random-integer 6)          ;; => 0..5
(random-real)               ;; => a flonum strictly between 0 and 1
(random-integer (expt 10 30)) ;; arbitrarily large ranges work too
```

`default-random-source` starts in the same state on every run. For different
numbers each run, randomize it (from the operating system's cryptographic
random number generator):

```scheme
(random-source-randomize! default-random-source)
```

For reproducible, independent streams (e.g. one per thread, or per simulation
run), create your own sources and pseudo-randomize them:

```scheme
(define s (make-random-source))
(random-source-pseudo-randomize! s 1 0)     ;; stream (1, 0)
(define dice (random-source-make-integers s))
(dice 6)

(define saved (random-source-state-ref s))  ;; writable/readable state
(random-source-state-set! s saved)
```

Random sources are not synchronized; give each thread its own source. For
cryptographic purposes use `random-bytes` from `(scm crypto)` or the random
ports of `(srfi 271)` instead.


## Exports

### `default-random-source`

*(no documentation)*

### `make-random-source`

```
Syntax: (make-random-source)
Library: (srfi 27)
Description: Creates a new random source.  Every new source starts in the
  same state, so it yields the same sequence until it is randomized,
  pseudo-randomized or given another state.  The generator is L'Ecuyer's
  MRG32k3a.
Example:
  (let ((s (make-random-source)))
    ((random-source-make-integers s) 100)) => 85
```

### `random-integer`

```
Syntax: (random-integer n)
Library: (srfi 27)
Description: Returns the next uniformly distributed integer in
  {0, ..., n-1} from default-random-source.  n must be a positive exact
  integer.  default-random-source starts in a fixed state, so call
  (random-source-randomize! default-random-source) first for different
  numbers on every run.
Example:
  (< (random-integer 10) 10) => #t
```

### `random-real`

```
Syntax: (random-real)
Library: (srfi 27)
Description: Returns the next uniformly distributed flonum strictly between
  0 and 1 from default-random-source.
Example:
  (< 0 (random-real) 1) => #t
```

### `random-source-make-integers`

```
Syntax: (random-source-make-integers s)
Library: (srfi 27)
Description: Returns a procedure (rand n) that takes a positive exact
  integer n and returns the next uniformly distributed integer in
  {0, ..., n-1} from the random source s.  n may be arbitrarily large.
Example:
  (let ((rand (random-source-make-integers (make-random-source))))
    (< (rand 6) 6)) => #t
```

### `random-source-make-reals`

```
Syntax: (random-source-make-reals s)
       (random-source-make-reals s unit)
Library: (srfi 27)
Description: Returns a procedure of no arguments that returns the next
  uniformly distributed flonum strictly between 0 and 1 from the random
  source s.  The optional unit (0 < unit < 1) is the maximum spacing
  between possible results; smaller values than the default ~2.3e-10 draw
  several numbers per result.
Example:
  (let ((rand (random-source-make-reals (make-random-source))))
    (< 0 (rand) 1)) => #t
```

### `random-source-pseudo-randomize!`

```
Syntax: (random-source-pseudo-randomize! s i j)
Library: (srfi 27)
Description: Sets the random source s to the initial state of the
  (i, j)-th independent stream, where i and j are non-negative exact
  integers.  This is fully deterministic: use it to obtain reproducible yet
  independent streams, e.g. one per thread or per simulation run.  Streams
  are distinct for i, j < 2^28.
Example:
  (let ((a (make-random-source)) (b (make-random-source)))
    (random-source-pseudo-randomize! a 1 2)
    (random-source-pseudo-randomize! b 1 2)
    (= ((random-source-make-integers a) 1000000)
       ((random-source-make-integers b) 1000000))) => #t
```

### `random-source-randomize!`

```
Syntax: (random-source-randomize! s)
Library: (srfi 27)
Description: Sets the random source s to a truly random state, drawn from
  the operating system's cryptographic random number generator.
Example:
  (let ((s (make-random-source)))
    (random-source-randomize! s)
    (random-source? s)) => #t
```

### `random-source-state-ref`

```
Syntax: (random-source-state-ref s)
Library: (srfi 27)
Description: Returns the current state of the random source s as an
  external object (a list (lecuyer-mrg32k3a x10 x11 x12 x20 x21 x22)) that
  can be written, read back and passed to random-source-state-set!.
Example:
  (car (random-source-state-ref (make-random-source))) => lecuyer-mrg32k3a
```

### `random-source-state-set!`

```
Syntax: (random-source-state-set! s state)
Library: (srfi 27)
Description: Sets the state of the random source s to state, which must
  have been obtained from random-source-state-ref.
Example:
  (let* ((s (make-random-source))
         (rand (random-source-make-integers s))
         (st (random-source-state-ref s))
         (a (rand 1000000)))
    (random-source-state-set! s st)
    (= a (rand 1000000))) => #t
```

### `random-source?`

```
Syntax: (random-source? obj)
Library: (srfi 27)
Description: Returns #t if obj is a random source, #f otherwise.
Example:
  (random-source? default-random-source) => #t
```

