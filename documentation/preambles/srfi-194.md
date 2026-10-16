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
