---
title: SRFI 9, 39, 98 and 111: small SRFIs
part: libraries
order: 111
libraries: (srfi 9) (srfi 39) (srfi 98) (srfi 111)
summary: Boxes as mutable cells, parameters for dynamically scoped settings, environment variables, and records (SRFI 9).
---
# SRFI 9, 39, 98 and 111: small SRFIs

Four small SRFIs whose features are also part of R7RS or close to it:

| library | provides | also in |
|---|---|---|
| `(srfi 111)` | boxes: `box`, `unbox`, `set-box!` | |
| `(srfi 39)` | parameters: `make-parameter`, `parameterize` | `(scheme base)` |
| `(srfi 98)` | `get-environment-variable(s)` | `(scheme process-context)` |
| `(srfi 9)` | `define-record-type` | `(scheme base)` |

Importing them by SRFI number documents where a feature comes from and
helps code that also runs on older Schemes.

```scheme
(import (scheme base) (scheme write) (srfi 111))
```

## Boxes

A box is a mutable cell holding one value. It is the explicit way to share
something changeable, for example a counter passed to several procedures:

```scheme
(define hits (box 0))
(define (record-hit! b) (set-box! b (+ (unbox b) 1)))
(record-hit! hits)
(record-hit! hits)
(unbox hits)                              ;; => 2
(box? hits)                               ;; => #t
```

Where a closure would hide the state, a box makes it visible in the
argument list: anyone reading `(record-hit! hits)` sees that `hits` can
change.

## Parameters

A parameter is a procedure returning its current value; `parameterize`
changes the value for the extent of its body, also for procedures called
from there, and restores it afterwards (even after an error):

```scheme
(define indent (make-parameter 0))

(define (show line)
  (string-append (make-string (indent) #\space) line))

(show "top")                              ;; => "top"
(parameterize ((indent 4))
  (list (show "nested")
        (parameterize ((indent 8)) (show "deeper"))))
;; => ("    nested" "        deeper")
(show "top again")                        ;; => "top again"
```

A converter procedure checks or transforms values as they are set:

```scheme
(define precision (make-parameter 2 (lambda (x) (if (and (integer? x) (>= x 0)) x
                                                   (error "precision: bad value" x)))))
(parameterize ((precision 4)) (precision)) ;; => 4
(parameterize ((precision -1)) 'never)    ;; => error
```

Parameters suit settings that many procedures consult but few change: the
output port (`current-output-port` is one), a log level, a locale, the
indentation of a pretty-printer.

## Environment variables

```scheme
(import (only (srfi 98) get-environment-variable get-environment-variables))

(string? (get-environment-variable "PATH")) ;; => #t
(get-environment-variable "NOT_SET_ANYWHERE_42") ;; => #f
(pair? (get-environment-variables))       ;; => #t
```

`get-environment-variables` returns an alist of name/value strings.

## Records

SRFI 9 is `define-record-type`, the same as in `(scheme base)`; see the
[records](basics-08-records.md) chapter.

## Where next

- [Records](basics-08-records.md), [errors and exceptions](basics-09-errors.md)
  (parameters are restored on errors, like `dynamic-wind`).
- Reference: `(srfi 111)`, `(srfi 39)`, `(srfi 98)`, `(srfi 9)`.
