---
title: Errors and exceptions
part: basics
order: 9
libraries: (scheme base) (scheme write)
summary: Raising errors, catching them with guard, error objects, raise with any value, cleaning up with dynamic-wind.
---
# Errors and exceptions

## Raising an error

`error` stops the computation with a message and optional *irritants*,
values that explain what went wrong:

```scheme
(import (scheme base) (scheme write))

(define (parse-age text)
  (let ((n (string->number text)))
    (cond ((not n) (error "parse-age: not a number" text))
          ((< n 0) (error "parse-age: negative" n))
          (else n))))

(parse-age "42")                  ;; => 42
(parse-age "forty")               ;; => error
```

Without a handler, the program ends and prints the message, the irritants
and where it happened.

## Catching errors with guard

`guard` catches what is raised in its body. Its clauses look like `cond`:
the variable is bound to the raised object, the first matching clause
handles it:

```scheme
(define (safe-parse-age text)
  (guard (e ((error-object? e)
             (string-append "invalid: " (error-object-message e))))
    (parse-age text)))

(safe-parse-age "42")             ;; => 42
(safe-parse-age "forty")          ;; => "invalid: parse-age: not a number"
(safe-parse-age "-3")             ;; => "invalid: parse-age: negative"
```

`error-object-message` and `error-object-irritants` take the error apart:

```scheme
(guard (e (#t (list (error-object-message e) (error-object-irritants e))))
  (parse-age "-3"))
;; => ("parse-age: negative" (-3))
```

Errors from the system are error objects too:

```scheme
(guard (e ((error-object? e) 'caught))
  (car '()))                      ;; => caught

(guard (e ((error-object? e) 'caught))
  (vector-ref (vector 1 2) 5))    ;; => caught
```

If no clause matches, the object is raised again, to the next `guard`
outside.

## Raising any value

`raise` can raise any value, not only error objects. That makes custom
signals easy:

```scheme
(define (find-first pred xs)
  (guard (e ((and (pair? e) (eq? (car e) 'found)) (cdr e)))
    (for-each (lambda (x) (when (pred x) (raise (cons 'found x)))) xs)
    #f))

(find-first even? '(1 3 4 5 6))   ;; => 4
(find-first even? '(1 3 5))       ;; => #f
```

`for-each` has no way to stop early; raising and catching a value gives it
one. (For real searches, `find` from SRFI 1 is simpler; the point is the
technique.)

## Retrying

A handler can do something smarter than give up. Here a lookup falls back to
a default and logs the problem:

```scheme
(define prices '((apple . 0.5) (bread . 3.2)))

(define (price item)
  (let ((p (assq item prices)))
    (if p (cdr p) (error "no price" item))))

(define (price-or-default item)
  (guard (e ((error-object? e)
             (display "warning: ")
             (display (error-object-message e))
             (display " ")
             (write (car (error-object-irritants e)))
             0))
    (price item)))

(price-or-default 'bread)         ;; => 3.2
(price-or-default 'cake)          ;; prints: warning: no price cake
```

## Cleaning up: dynamic-wind

`dynamic-wind` runs a "before" and an "after" thunk around a body, and the
"after" runs however the body is left: normally, through an error, or by a
continuation. That is the place to release resources:

```scheme
(define log '())
(define (note x) (set! log (cons x log)))

(guard (e (#t (note 'handled)))
  (dynamic-wind
    (lambda () (note 'open))
    (lambda () (note 'work) (error "disk full") (note 'never))
    (lambda () (note 'close))))

(reverse log)                     ;; => (open work close handled)
```

The file procedures `call-with-input-file` and `call-with-output-file` close
their port for you, also on errors, so you rarely need `dynamic-wind` for
files.

## Errors in other threads and jobs

- In a thread (SRFI 18), an error that is not caught ends the thread;
  `thread-join!` then raises it in the joining thread.
- Running out of memory is an error object too, on all implementations, so a
  long-running server can catch it, fail one job and continue.

## Where next

- [Libraries and programs](basics-10-libraries.md).
- Reference: `guard`, `raise`, `error-object?` in `(scheme base)`.
