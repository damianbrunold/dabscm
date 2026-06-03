## Overview

SRFI-64 is a Scheme API for test suites: bracket tests with `test-begin` /
`test-end`, assert with `test-equal` / `test-assert` / `test-error`, group with
`test-group`, and plug in test runners. This project's `(scm test)` wraps it with a
summary-reporting runner — import that for the usual workflow.

## Common uses

```scheme
(import (srfi 64))

(test-begin "arithmetic")
(test-equal 4 (+ 2 2))          ;; (test-equal expected actual)
(test-assert (> 3 2))
(test-error (vector-ref #(1) 5))
(test-end "arithmetic")
```

`test-group`, `test-eqv`/`test-eq`, `test-approximate`, and `test-skip` /
`test-expect-fail` round out the API, along with the `test-runner-*` machinery for
custom reporting.
