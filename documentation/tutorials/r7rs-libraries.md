---
title: "The R7RS libraries: eval, read, load, time, complex numbers and more"
part: libraries
order: 1047
libraries: (scheme complex) (scheme cxr) (scheme eval) (scheme load) (scheme read) (scheme repl) (scheme time) (scheme r5rs) (scheme inexact) (scm math)
summary: Which standard library holds what; complex numbers; car/cdr combinations; evaluating data as code in chosen environments, a calculator with a whitelist; reading data and configuration files with read; loading code; the interaction environment; clocks and timing; R5RS compatibility; the constants and helpers of (scm math).
---
# The R7RS libraries

R7RS splits the standard procedures into libraries, so a program imports
what it uses. Most of them appear throughout these tutorials; this
chapter is the map, and covers the ones that have no chapter of their
own.

| library | holds | see |
|---|---|---|
| `(scheme base)` | the core: numbers, lists, strings, vectors, control, records, errors | [basics](basics-02-values.md) |
| `(scheme char)` | character classes, case conversion | [characters](techniques-02-characters.md) |
| `(scheme write)`, `(scheme read)` | `display`, `write`; `read` | below |
| `(scheme file)` | opening files, `file-exists?`, `delete-file` | [files](techniques-03-files.md) |
| `(scheme process-context)` | `command-line`, `exit`, environment variables | [command-line programs](techniques-09-command-line.md) |
| `(scheme inexact)` | `sin`, `sqrt`, `exp`, `log`, `nan?` … | below |
| `(scheme complex)` | complex numbers | below |
| `(scheme cxr)` | `caddr` and the other three- and four-letter accessors | below |
| `(scheme lazy)` | `delay`, `force`, `make-promise` | [continuations and laziness](basics-12-continuations.md) |
| `(scheme case-lambda)` | `case-lambda` | [procedures](basics-03-procedures.md) |
| `(scheme eval)`, `(scheme repl)` | `eval`, `environment`, `interaction-environment` | below |
| `(scheme load)` | `load` | below |
| `(scheme time)` | `current-second`, `current-jiffy` | below |
| `(scheme r5rs)` | everything of R5RS, for old code | below |

```scheme
(import (scheme base) (scheme complex) (scheme cxr) (scheme eval) (scheme file)
        (scheme inexact) (scheme load) (scheme read) (scheme repl) (scheme time)
        (scheme write) (scm fs) (scm math))
```

## Numbers: inexact and complex

`(scheme inexact)` has the functions of floating-point maths:

```scheme
(sqrt 16)                                   ;; => 4
(sqrt 2.25)                                 ;; => 1.5
(exp 0)                                     ;; => 1.0
(/ (round (* 1000 (sin 1))) 1000)           ;; => 0.841
(log 100 10)                                ;; => 2.0
(nan? (/ 0.0 0.0))                          ;; => #t
```

`sqrt` of an exact square stays exact; the others return inexact numbers. Complex numbers are written
`3+4i`, or made from parts; `(scheme complex)` takes them apart:

```scheme
(define z (make-rectangular 3 4))
z                                           ;; => 3+4i
(list (real-part z) (imag-part z) (magnitude z)) ;; => (3 4 5.0)
(* +i +i)                                   ;; => -1
(sqrt -4)                                   ;; => 0.0+2.0i
(/ (round (* 1000 (angle 1+i))) 1000)       ;; => 0.785
```

The magnitude of 3+4i is the length of the arrow from 0 to (3, 4); the
angle of 1+i is 45 degrees, π/4. `(scm math)` adds the constants and a
few helpers:

```scheme
(list PI E)                                 ;; => (3.141592653589793 2.718281828459045)
(factorial 20)                              ;; => 2432902008176640000
(factorial 25)                              ;; => 15511210043330985984000000
(map sign '(-5 0 2.5))                      ;; => (-1 0 1)
```

Integers have no size limit, so `factorial` does not overflow.

## Accessors: (scheme cxr)

`cadr` and the other two-letter combinations are in `(scheme base)`;
the three- and four-letter ones are in `(scheme cxr)`. Read the letters
from right to left: `caddr` is the car of the cdr of the cdr, the third
element:

```scheme
(define order '("ada" ("Sencha" 2) ("Assam" 1)))
(caddr order)                               ;; => ("Assam" 1)
(caadr order)                               ;; => "Sencha"
(cadadr order)                              ;; => 2
```

Past two letters, names often read better: `(list-ref order 2)`, or a
record.

## Code as data: eval

`eval` runs a datum as code, in an *environment* that says which
bindings it may use. `environment` makes one from library names:

```scheme
(eval '(+ 1 2) (environment '(scheme base))) ;; => 3
(eval '(string-upcase "tea") (environment '(scheme base) '(scheme char))) ;; => "TEA"
(eval '(string-upcase "tea") (environment '(scheme base))) ;; => error
```

The last fails because `string-upcase` is not in `(scheme base)`. An
environment is also a fence: an expression from outside, a formula in a
spreadsheet or a pricing rule in a configuration file, can only use
what it is given. A calculator that allows arithmetic and nothing else:

```scheme
(define allowed '(+ - * / min max round))

(define (safe-expression? x)
  (cond ((number? x) #t)
        ((pair? x) (and (memq (car x) allowed) (list? x) (every-safe? (cdr x))))
        (else #f)))
(define (every-safe? xs) (or (null? xs) (and (safe-expression? (car xs)) (every-safe? (cdr xs)))))

(define (calculate text)
  (let ((x (read (open-input-string text))))
    (if (safe-expression? x)
        (eval x (environment '(scheme base)))
        (error "not allowed" text))))

(calculate "(* 2 (+ 3 4))")                 ;; => 14
(calculate "(round (/ 7 2))")               ;; => 4
(calculate "(delete-file \"orders.csv\")")  ;; => error
```

The check before `eval` is what makes it safe: even `(scheme base)`
holds procedures that should not run on untrusted input. Prefer data
over code where possible; `eval` is for the cases where users really
write expressions.

## Reading data: read

`read` parses one datum from a port: the same syntax as code, but
nothing runs. It is the simplest way to store Scheme data in files:

```scheme
(define p (open-input-string "(tea \"Sencha\" (kg 2)) 42 #(1 2) done"))
(list (read p) (read p) (read p) (read p))  ;; => ((tea "Sencha" (kg 2)) 42 #(1 2) done)
(eof-object? (read p))                      ;; => #t
```

A configuration file as a list of settings, read with `read`, is safe
in a way that loading it as code is not:

```scheme
(define dir (mktempdir '(prefix . "r7rs")))
(define config-file (join-path dir "shop.conf"))
(call-with-output-file config-file
  (lambda (out) (write-string "((port 8080) (shops \"Zurich\" \"Bern\") (vat 0.081))\n" out)))

(define config (call-with-input-file config-file read))
(cadr (assq 'port config))                  ;; => 8080
(cdr (assq 'shops config))                  ;; => ("Zurich" "Bern")
```

## Loading code: load

`load` reads a file and evaluates its forms, as if they were written at
that point of the program. Without an environment it uses the
program's own top level, which `(interaction-environment)` from
`(scheme repl)` also names:

```scheme
(call-with-output-file (join-path dir "pricing.scm")
  (lambda (out) (write '(define (with-vat chf) (* chf 1.081)) out)))

(load (join-path dir "pricing.scm"))
(eval '(with-vat 100) (interaction-environment)) ;; => 108.1
(rm dir 'recursive)
```

`load` suits plug-ins and scripts that extend a program. For code of
your own, libraries (`define-library` and `import`) are better: they
are checked when the program starts and say what they export ([libraries
and programs](basics-10-libraries.md)).

## Time: (scheme time)

```scheme
(real? (current-second))                    ;; => #t
(exact-integer? (current-jiffy))            ;; => #t

(define (time-it thunk)                     ; seconds a thunk takes
  (let ((start (current-jiffy)))
    (thunk)
    (/ (- (current-jiffy) start) (jiffies-per-second))))
(>= (time-it (lambda () (let loop ((i 0)) (when (< i 10000) (loop (+ i 1)))))) 0) ;; => #t
```

`current-second` is the wall-clock time in seconds since 1970, with a
fraction; `current-jiffy` counts ticks of an unspecified clock that
never jumps, the right one for measuring durations. Dates, time zones
and formatting are in [dates and times](techniques-07-dates.md).

## R5RS code

`(scheme r5rs)` exports everything of the previous standard, including
`null-environment` and `scheme-report-environment`, so old programs run
with one import:

```scheme no-test
(import (scheme r5rs))
(display (eval '(* 4 4) (scheme-report-environment 5)))
(newline)
```

## Where next

- [Libraries and programs](basics-10-libraries.md) for `import` and
  `define-library`, [macros](basics-11-macros.md) for code that writes
  code without `eval`.
- Reference: the pages of each `(scheme …)` library, and `(scm math)`.
