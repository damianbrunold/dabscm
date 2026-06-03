# `(scm test)`

Test framework — SRFI-64 runner with summary reporting

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


## Exports

### `last-run-failed-tests`

*(no documentation)*

### `last-run-total-tests`

*(no documentation)*

### `scm-test-runner`

*(no documentation)*

### `test-apply`

*(no documentation)*

### `test-approximate`

*(no documentation)*

### `test-assert`

*(no documentation)*

### `test-begin`

*(no documentation)*

### `test-end`

*(no documentation)*

### `test-eq`

*(no documentation)*

### `test-equal`

*(no documentation)*

### `test-eqv`

*(no documentation)*

### `test-error`

*(no documentation)*

### `test-expect-fail`

*(no documentation)*

### `test-group`

*(no documentation)*

### `test-group-with-cleanup`

*(no documentation)*

### `test-match-all`

*(no documentation)*

### `test-match-any`

*(no documentation)*

### `test-match-name`

*(no documentation)*

### `test-match-nth`

*(no documentation)*

### `test-read-eval-string`

*(no documentation)*

### `test-runner-factory`

*(no documentation)*

### `test-skip`

*(no documentation)*

### `test-with-runner`

*(no documentation)*

