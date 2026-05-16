;; -------------------------------
;; simple macro, no hygiene needed

(define-syntax when
  (syntax-rules ()
    [(when test expr)
     (if test expr)]))

;; Test:
(when #t (display "hello"))

;; Expected expansion:
(if #t (display "hello"))

;; Expected output: "hello"

;; -------------------------------
;; Hygiene with introduced identifiers

(define-syntax unless
  (syntax-rules ()
    [(unless test expr)
     (if (not test) expr)]))

;; Test:
(let ([not #f])
  (unless #f (display "world")))

;; Expected expansion:
(if (not #f) (display "world"))

;; Expected output: "world"

;; -------------------------------
;; pattern matching

(define-syntax my-or
  (syntax-rules ()
    [(my-or) #f]
    [(my-or expr) expr]
    [(my-or expr1 expr2 ...)
     (let ([temp expr1])
       (if temp temp (my-or expr2 ...)))]))

;; Test:
(my-or #f #f "found")

;; Expected expansion:
(let ([temp #f])
  (if temp temp (let ([temp #f])
                  (if temp temp "found"))))

;; Expected output: "found"

;; Explanation:
;; Tests basic macro expansion with no hygiene concerns.

;; -------------------------------
;; Free identifiers in macro output

(define x 10)

(define-syntax get-x
  (syntax-rules ()
    [(get-x) x]))

;; Test:
(let ([x 20])
  (get-x))

;; Expected expansion:
(let ([x 20]) x)

;; Expected output: 20

;;Explanation:
;; The x in the macro output refers to the nearest binding,
;; demonstrating referential transparency.

;; -------------------------------
;; Macro-introduced bindings

(define-syntax with
  (syntax-rules ()
    [(with name value body)
     (let ([name value])
       body)]))

;; Test:
(let ([x 1])
  (with x 2 (+ x 10)))

;; Expected expansion:
(let ([x 1])
  (let ([x 2])
    (+ x 10)))

;; Expected output: 12

;; Explanation:
;; The macro-introduced x shadows the outer x only within its scope.

;; -------------------------------
;; Ellipsis in macro rules

(define-syntax list*
  (syntax-rules ()
    [(list* last) last]
    [(list* first rest ...)
     (cons first (list* rest ...))]))

;; Test:
(list* 1 2 3 '())

;; Expected expansion:
(cons 1 (cons 2 (cons 3 '())))

;; Expected output: (1 2 3)

;; Explanation:
;; Tests proper handling of ellipsis and recursive expansion.

;; -------------------------------
;; Macro defined in a library

;; In file "mylib.sls":
(define-library (mylib)
  (export my-when)
  (begin
    (define-syntax my-when
      (syntax-rules ()
        [(my-when test expr)
         (if test expr)]))))

;; In the REPL:
(import (mylib))
(my-when #t (display "library macro"))

;; Expected output: "library macro"

;; Explanation:
;; Tests that macros defined in libraries are expanded
;; correctly when imported.

;; -------------------------------
;; Macro using another macro from a library

;; In file "lib1.sls":
(define-library (lib1)
  (export unless)
  (begin
    (define-syntax unless
      (syntax-rules ()
        [(unless test expr)
         (if (not test) expr)]))))

;; In file "lib2.sls":
(define-library (lib2)
  (import (lib1))
  (export my-unless)
  (begin
    (define-syntax my-unless
      (syntax-rules ()
        [(my-unless test expr)
         (unless test expr)]))))

;; In the REPL:
(import (lib2))
(my-unless #f (display "cross-library"))

;; Expected expansion:
(if (not #f) (display "cross-library"))

;; Expected output: "cross-library"
;; Explanation:
;; Tests that macros can depend on other macros from
;; imported libraries.

;; -------------------------------
;; Macro defining another macro

(define-syntax define-alias
  (syntax-rules ()
    [(define-alias new old)
     (define-syntax new
       (syntax-rules ()
         [(new arg ...)
          (old arg ...)]))]))

;; Test:
(define-alias print display)
(print "macro-generated macro")

;; Expected expansion:
(define-syntax print
  (syntax-rules ()
    [(print arg ...)
     (display arg ...)]))
(print "macro-generated macro")

;; Expected output: "macro-generated macro"

;; Explanation:
;; Tests that macros can generate other macro definitions.

;; -------------------------------
;; Macro with internal state

(define counter 0)
(define-syntax next
  (syntax-rules ()
    [(next)
     (begin
       (set! counter (+ counter 1))
       counter)]))

;; Test:
(list (next) (next) (next))

;; Expected expansion:
(list
  (begin (set! counter (+ counter 1)) counter)
  (begin (set! counter (+ counter 1)) counter)
  (begin (set! counter (+ counter 1)) counter))

;; Expected output: (1 2 3)

;; Explanation:
;; Tests that macros can interact with top-level state
;; (though this is not hygienic, it is sometimes necessary).

;; -------------------------------
;; Nested patterns and ellipsis

(define-syntax for
  (syntax-rules ()
    [(for i in list body ...)
     (let loop ([lst list])
       (if (null? lst)
           'done
           (let ([i (car lst)])
             body ...
             (loop (cdr lst)))))]))

;; Test:
(for x in '(1 2 3)
     (display x))

;; Expected expansion:
(let loop ([lst '(1 2 3)])
  (if (null? lst)
      'done
      (let ([x (car lst)])
        (display x)
        (loop (cdr lst)))))

;; Expected output: 123

;; Explanation:
;; Tests complex pattern matching, recursion, and hygiene
;; in a loop-like macro.

;; -------------------------------
;; Macro using library-specific bindings

;; In file "lib3.sls":
(define-library (lib3)
  (export my-let)
  (begin
    (define-syntax my-let
      (syntax-rules ()
        [(my-let ([name value]) body ...)
         ((lambda (name) body ...) value)]))))

;; In the REPL:
(import (lib3))
(my-let ([x 100])
  (+ x 200))

;; Expected expansion:
((lambda (x) (+ x 200)) 100)

;; Expected output: 300

;; Explanation:
;; Tests that macros can use library-specific bindings and
;; expand correctly.

;; -------------------------------
;; Macro expanding to another macro

(define-syntax twice
  (syntax-rules ()
    [(twice expr)
     (begin expr expr)]))

(define-syntax run-twice
  (syntax-rules ()
    [(run-twice expr)
     (twice expr)]))

;; Test:
(run-twice (display "expand "))

;; Expected expansion:
(begin (display "expand ") (display "expand "))

;; Expected output: "expand expand "

;; Explanation:
;; Tests that macros can expand to other macros, which are
;; then expanded further.

;; -------------------------------
;; Macro with ill-formed output

(define-syntax bad
  (syntax-rules ()
    [(bad expr)
     (expr 1 2)])) ; Intentionally wrong: expr is not a procedure

;; Test:
(bad 3)

;; Expected: Syntax error during expansion (not runtime)
