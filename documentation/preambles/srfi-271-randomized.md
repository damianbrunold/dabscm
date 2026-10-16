## Overview

The randomized random ports of SRFI-271: binary input ports delivering an
endless stream of cryptographically random bytes from the operating system's
secure random number generator. `(srfi 271)` exports the same procedures.

```scheme
(import (srfi 271 randomized))

(read-bytevector 32 (make-random-port))
```
