## Overview

`(scm test)` is the project's test framework: a SRFI-64 test runner
(`scm-test-runner`) with concise summary reporting, re-exporting the SRFI-64 API
(`test-begin`, `test-equal`, `test-assert`, `test-group`, …). It's what the test
suites under `scm-tests/` use.

## Common uses

```scheme
(import (scm test))

(test-runner-factory scm-test-runner)

(test-begin "arithmetic")
(test-equal 4 (+ 2 2))
(test-assert (> 3 2))
(test-error (/ 1 0))
(test-end "arithmetic")
```

Group related checks with `test-group`. After a run, `last-run-total-tests` and
`last-run-failed-tests` report the totals (handy for build scripts). See `(srfi 64)`
for the full assertion and runner API.
