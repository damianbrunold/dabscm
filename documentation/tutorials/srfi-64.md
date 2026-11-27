---
title: SRFI 64: unit tests
part: libraries
order: 64
libraries: (srfi 64) (scm test)
summary: Test groups, the assertion forms, expected failures and skipped tests, cleanup, test runners and their counters, a custom runner that collects failures.
---
# SRFI 64: unit tests

SRFI 64 is the standard test library; `(scm test)` adds a runner with a
compact summary. The [testing](techniques-10-testing.md) chapter shows how to
organise tests; this one goes through the library.

```scheme
(import (scheme base) (scheme write) (srfi 64) (only (scm test) scm-test-runner))

(test-runner-factory scm-test-runner)
(test-begin "srfi-64 tour")
```

`test-begin` and `test-end` delimit a suite; the runner reports when the
outermost suite ends.

## Assertions

```scheme
(test-equal "equal?" '(1 2) (list 1 2))
(test-eqv "eqv?" 2.0 (/ 4.0 2))
(test-eq "eq?" 'a (car '(a b)))
(test-assert "true value" (string? "s"))
(test-approximate "within 0.01" 0.333 (/ 1.0 3) 0.01)
(test-error "any error" (car '()))
(test-error "an error object" error-object? (raise (make-error-like)))

(define (make-error-like)
  (guard (e (#t e)) (error "boom")))
```

Each form takes an optional name first. `test-error` with a predicate checks
the kind of exception.

## Groups and cleanup

```scheme
(test-group "arithmetic"
  (test-equal 4 (+ 2 2))
  (test-equal 0 (- 2 2)))

(define log '())
(test-group-with-cleanup "with a resource"
  (begin (set! log (cons 'opened log))
         (test-assert #t))
  (set! log (cons 'closed log)))
log                                   ;; => (closed opened)
```

`test-group-with-cleanup` runs its last expression even if the tests in it
raise, like `dynamic-wind`.

## Expected failures and skips

```scheme
(test-expect-fail 1)
(test-equal "known bug, issue 42" 3 (+ 1 1))

(test-skip "slow test")
(test-assert "slow test" (begin (car '()) #t))
```

`test-expect-fail` and `test-skip` take a count or a test name. An
expected failure is reported as `xfail`, not as a failure, so a known bug
does not break the build, and it turns into `xpass` when the bug is fixed.
A skipped test is not run at all.

## Runners

A *runner* counts results and reports them. The current runner's counters:

```scheme
(define r (test-runner-current))
(> (test-runner-pass-count r) 0)      ;; => #t
(test-runner-xfail-count r)           ;; => 1
(test-runner-skip-count r)            ;; => 1
```

### A custom runner

A runner built from `test-runner-null` with your own callbacks, here one
that collects the names of failing tests:

```scheme
(define (collecting-runner failures)
  (let ((r (test-runner-null)))
    (test-runner-on-test-end! r
      (lambda (runner)
        (when (eq? (test-result-kind runner) 'fail)
          (set-car! failures (cons (test-runner-test-name runner) (car failures))))))
    r))

(define failed (list '()))
(test-with-runner (collecting-runner failed)
  (test-begin "inner")
  (test-equal "ok" 1 1)
  (test-equal "broken" 1 2)
  (test-equal "also broken" 'a 'b)
  (test-end "inner"))
(reverse (car failed))                ;; => ("broken" "also broken")
```

`test-with-runner` runs its body with another runner and restores the
previous one, so this suite's own counts are unaffected. Runners like this
can write JUnit XML for a CI server or send results anywhere else.

```scheme
(test-end "srfi-64 tour")
```

## Where next

- [Testing your code](techniques-10-testing.md).
- Reference: `(srfi 64)`, `(scm test)`.
