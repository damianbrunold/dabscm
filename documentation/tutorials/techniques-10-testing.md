---
title: Testing your code
part: techniques
order: 10
libraries: (scm test) (srfi 64)
summary: Writing tests with (scm test) and SRFI 64, groups, equality and approximate checks, testing errors and output, test layout, running tests on all three implementations.
---
# Testing your code

`(scm test)` is SRFI 64, the standard Scheme test library, with a test
runner that prints a compact summary. A test file is an ordinary program:

```scheme no-test
(import (scheme base) (scm test) (myapp prices))

(test-runner-factory scm-test-runner)
(test-begin "prices")

(test-equal "net to gross" 108.1 (with-vat 100))
(test-assert "positive" (> (with-vat 1) 0))
(test-error "negative amount" (with-vat -1))

(test-end "prices")
```

```sh
$ scm tests/test-prices.scm
  prices                       3 OK
```

The program's exit status is non-zero when a test fails, so build scripts
and CI can rely on it.

## The checks

```scheme
(import (scheme base) (scheme write) (scheme inexact) (scm test))

(test-runner-factory scm-test-runner)
(test-begin "checks")

(test-equal "equal? comparison" '(1 2 3) (list 1 2 3))
(test-eqv "eqv? comparison" 42 (* 6 7))
(test-assert "any true value" (memq 'b '(a b c)))
(test-approximate "floating point" 3.14159 (* 4 (atan 1)) 0.00001)
(test-error "must raise" (vector-ref (vector) 0))
(test-error "a specific kind" error-object? (error "boom"))
```

`test-equal` is the workhorse: give it the expected value first and the
expression second. A name in front makes failures easy to find. For
floating-point results, `test-approximate` with a tolerance avoids
surprises from rounding.

## Groups

`test-group` gives a block of checks a name, which appears in failure
messages:

```scheme
(define (fizzbuzz n)
  (cond ((= 0 (modulo n 15)) "FizzBuzz")
        ((= 0 (modulo n 3)) "Fizz")
        ((= 0 (modulo n 5)) "Buzz")
        (else (number->string n))))

(test-group "fizzbuzz"
  (test-equal "1" (fizzbuzz 1))
  (test-equal "Fizz" (fizzbuzz 9))
  (test-equal "Buzz" (fizzbuzz 10))
  (test-equal "FizzBuzz" (fizzbuzz 30)))
```

## Testing output

Code that prints can be tested by redirecting the output port into a
string:

```scheme
(define (greet name) (display "Hello, ") (display name) (display "!"))

(define (output-of thunk)
  (let ((p (open-output-string)))
    (parameterize ((current-output-port p)) (thunk))
    (get-output-string p)))

(test-equal "Hello, Ada!" (output-of (lambda () (greet "Ada"))))
```

Better still is to separate computing from printing, as the
[command-line](techniques-09-command-line.md) chapter does: procedures that
return strings or take a port are easy to test.

## Testing with files

Use a temporary directory and remove it at the end, so tests can run in
parallel and leave nothing behind:

```scheme
(import (scheme file) (scm fs))

(define (read-lines path)
  (call-with-input-file path
    (lambda (in)
      (let loop ((acc '()))
        (let ((l (read-line in)))
          (if (eof-object? l) (reverse acc) (loop (cons l acc))))))))

(define dir (mktempdir '(prefix . "test")))
(call-with-output-file (join-path dir "in.txt")
  (lambda (out) (display "x\ny\n" out)))
(test-equal '("x" "y") (read-lines (join-path dir "in.txt")))
(rm dir 'recursive)
```

```scheme
(test-end "checks")
```

## Layout and running

```text
myapp/
  myapp/prices.sld
  tests/
    test-prices.scm
    test-orders.scm
```

Run each test file with `scm`, `scmcs` and, compiled, with `scmc`, to be
sure the code works on all three implementations:

```sh
$ for f in tests/test-*.scm; do scm "$f" || exit 1; done
$ scmc tests/test-prices.scm -o /tmp/t && /tmp/t
```

Write tests while you write the code. Every example in these tutorials is
itself a test: the documentation build turns each tutorial into a test
program, and dabscm's test suites run it on the JVM, .NET and native.

## Where next

- [Concurrency](techniques-11-concurrency.md).
- `(scm test)`, [SRFI 64](srfi-64.md).
