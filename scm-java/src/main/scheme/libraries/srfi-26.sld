(define-library (srfi 26)
  (import (scm core) (scheme base))
  (export cut cute)
  (begin
    ;; cut: specialize a procedure by replacing some arguments with slots.
    ;; <> marks a slot (becomes a lambda parameter in left-to-right order).
    ;; <...> marks a rest slot (becomes the lambda rest parameter).
    ;; Non-slot expressions are re-evaluated on each call.
    ;;
    ;; Based on the SRFI-26 reference implementation by Sebastian Egner.
    ;; Uses auxiliary macros that accumulate slots via syntax-rules.

    (define-syntax cut
      "Syntax: (cut f arg ...)
Library: (srfi 26)
Description: Specializes a procedure f by replacing some arguments with slots (<>).
Returns a lambda that accepts the slot arguments in order. Use <...> as a rest slot.
Non-<> arguments are re-evaluated on each call (unlike cute).
Example:
  (define add5 (cut + <> 5))
  (add5 3) => 8
  (define cons-star (cut cons <> '()))
  (cons-star 1) => (1)"
      (syntax-rules ()
        ((cut . slots-or-exprs)
         (cut-aux () () . slots-or-exprs))))

    (define-syntax cut-aux
      (syntax-rules (<> <...>)
        ;; No more arguments — build the lambda
        ((cut-aux (params ...) (args ...))
         (lambda (params ...) (args ...)))
        ;; Rest slot <...> — must be last
        ((cut-aux (params ...) (args ...) <...>)
         (lambda (params ... . rest-slot) (apply args ... rest-slot)))
        ;; Slot <> — generate a fresh parameter
        ((cut-aux (params ...) (args ...) <> . rest)
         (cut-aux (params ... x) (args ... x) . rest))
        ;; Non-slot expression — pass through literally
        ((cut-aux (params ...) (args ...) expr . rest)
         (cut-aux (params ...) (args ... expr) . rest))))

    ;; cute: like cut, but non-slot expressions are evaluated once at definition time.

    (define-syntax cute
      "Syntax: (cute f arg ...)
Library: (srfi 26)
Description: Like cut, but non-slot expressions are evaluated once when cute is
called, not at each invocation. Slots (<>) become lambda parameters; <...> is a rest slot.
Example:
  (define add-n (cute + <> (begin (display \"eval\") 5)))
  (add-n 3) => 8   ; \"eval\" is printed only once"
      (syntax-rules ()
        ((cute . slots-or-exprs)
         (cute-aux () () () . slots-or-exprs))))

    (define-syntax cute-aux
      (syntax-rules (<> <...>)
        ;; No more arguments — build let + lambda
        ((cute-aux (binds ...) (params ...) (args ...))
         (let (binds ...) (lambda (params ...) (args ...))))
        ;; Rest slot <...> — must be last
        ((cute-aux (binds ...) (params ...) (args ...) <...>)
         (let (binds ...) (lambda (params ... . rest-slot) (apply args ... rest-slot))))
        ;; Slot <> — generate a fresh parameter (no let binding needed)
        ((cute-aux (binds ...) (params ...) (args ...) <> . rest)
         (cute-aux (binds ...) (params ... x) (args ... x) . rest))
        ;; Non-slot expression — bind to a temp variable, evaluated once
        ((cute-aux (binds ...) (params ...) (args ...) expr . rest)
         (cute-aux (binds ... (t expr)) (params ...) (args ... t) . rest))))))
