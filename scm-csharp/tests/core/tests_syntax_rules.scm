(import (scheme base) (scheme cxr) (scm macro))

(test-group
  (define-syntax my-and
    (syntax-rules ()
      ((_) #t)
      ((_ e) e)
      ((_ e1 e2 ...) (if e1 (my-and e2 ...) #f))))
  (=> (my-and #t #t #t) #t)
  (=> (my-and #f #t) #f))

(test-group
  (define-syntax swap!
    (syntax-rules ()
      ((_ a b) (let ((tmp a)) (set! a b) (set! b tmp)))))
  (=> (let ((tmp 1) (y 2))
    (swap! tmp y)
    tmp) 2))

(test-group
  (=> ;; let-syntax (local macro)
  (let-syntax ((double (syntax-rules ()
                         ((_ x) (+ x x)))))
    (double 5)) 10))

(test-group
  (=> ;; letrec-syntax (recursive macro)
  (letrec-syntax ((my-or (syntax-rules ()
                           ((_) #f)
                           ((_ e) e)
                           ((_ e1 e2 ...)
                            (let ((t e1)) (if t t (my-or e2 ...)))))))
    (my-or #f #f 42)) 42))

(test-group
  (define-syntax my-cond
    (syntax-rules (else)
      ((_ (else e ...)) (begin e ...))
      ((_ (test e ...) rest ...)
       (if test (begin e ...) (my-cond rest ...)))))
  (=> (my-cond (#f 1) (#t 2) (else 3)) 2))

(test-group
  (=> ;; error-object? with non-error-object
  (error-object? 42) #f))

;; ---- Referential transparency tests ----

(test-group
  ;; Macro template references resolve to definition-site bindings,
  ;; not use-site bindings (referential transparency)
  (define-syntax my-cons
    (syntax-rules ()
      ((_ a b) (cons a b))))
  (=> (let ((cons +))
        (my-cons 1 2)) '(1 . 2)))

(test-group
  ;; Macro-introduced let doesn't capture use-site variable 'let'
  (define-syntax my-add
    (syntax-rules ()
      ((_ x y) (let ((tmp x)) (+ tmp y)))))
  (=> (let ((let 999))
        (my-add 3 4)) 7))

(test-group
  ;; Macro-introduced 'if' resolves correctly even when shadowed
  (define-syntax my-if-true
    (syntax-rules ()
      ((_ x) (if #t x #f))))
  (=> (let ((if 999))
        (my-if-true 42)) 42))

(test-group
  ;; Macro-introduced + resolves correctly even when shadowed
  (define-syntax my-inc
    (syntax-rules ()
      ((_ x) (+ x 1))))
  (=> (let ((+ -))
        (my-inc 10)) 11))

(test-group
  ;; Literal matching works correctly with renamed identifiers
  (define-syntax my-cond2
    (syntax-rules (else)
      ((_ (else e ...)) (begin e ...))
      ((_ (test e ...) rest ...)
       (if test (begin e ...) (my-cond2 rest ...)))))
  (=> (my-cond2 (#f 1) (else 42)) 42))

(test-group
  ;; Nested macro expansion preserves hygiene
  (define-syntax my-let1
    (syntax-rules ()
      ((_ x v body) (let ((x v)) body))))
  (define-syntax my-let2
    (syntax-rules ()
      ((_ x v body) (my-let1 x v body))))
  (=> (my-let2 z 10 (+ z 1)) 11))

;; ---- Internal definition context tests (R7RS 5.3.2) ----

(test-group
  ;; define-syntax in lambda body
  (=> (let ()
        (define-syntax double
          (syntax-rules () ((_ x) (+ x x))))
        (double 5))
      10))

(test-group
  ;; define-syntax followed by define using the macro
  (=> (let ()
        (define-syntax add1
          (syntax-rules () ((_ x) (+ x 1))))
        (define y (add1 5))
        y)
      6))

(test-group
  ;; mixed define and define-syntax in body
  (=> (let ()
        (define x 10)
        (define-syntax get-x
          (syntax-rules () ((_) x)))
        (get-x))
      10))

(test-group
  ;; internal defines inside let-syntax body (R7RS 4.3.1)
  (=> (let-syntax ((double (syntax-rules () ((_ x) (+ x x)))))
        (define y 5)
        (double y))
      10))

(test-group
  ;; letrec-syntax with cross-referencing macros
  (=> (letrec-syntax
        ((my-add (syntax-rules () ((_ x) (+ x 1))))
         (my-double (syntax-rules () ((_ x) (my-add (my-add x))))))
        (my-double 3))
      5))
