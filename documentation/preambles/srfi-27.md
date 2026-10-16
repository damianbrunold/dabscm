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
