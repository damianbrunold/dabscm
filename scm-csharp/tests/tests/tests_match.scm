(import (scheme base)
        (scm test)
        (scm match))

(test-runner-factory scm-test-runner)

(test-begin "match")

;; --- Basic patterns ---

(test-group "basic patterns"
  ;; pattern variable
  (test-equal 42 (match 42 (x x)))
  ;; wildcard
  (test-equal 'ok (match 42 (_ 'ok)))
  ;; literal number
  (test-equal 'yes (match 42 (42 'yes)))
  ;; literal string
  (test-equal 'yes (match "hi" ("hi" 'yes)))
  ;; literal boolean
  (test-equal 'yes (match #t (#t 'yes) (#f 'no)))
  (test-equal 'no (match #f (#t 'yes) (#f 'no)))
  ;; literal character
  (test-equal 'yes (match #\a (#\a 'yes) (_ 'no))))

;; --- Quoted datum ---

(test-group "quoted datum"
  (test-equal 'yes (match 'foo ('foo 'yes) (_ 'no)))
  (test-equal 'yes (match 'bar ('foo 'no) ('bar 'yes)))
  ;; empty list
  (test-equal 'empty (match '() (() 'empty) (_ 'other))))

;; --- List patterns ---

(test-group "list patterns"
  ;; fixed-length list
  (test-equal 6 (match '(1 2 3) ((a b c) (+ a b c))))
  ;; single element
  (test-equal 42 (match '(42) ((x) x)))
  ;; nested list
  (test-equal '(1 2 3 4) (match '((1 2) (3 4))
                     (((a b) (c d)) (list a b c d))))
  ;; deeply nested
  (test-equal 6 (match '(1 (2 (3)))
            ((a (b (c))) (+ a b c)))))

;; --- Dotted pair / rest patterns ---

(test-group "dotted pair / rest patterns"
  (test-equal '(2 3) (match '(1 2 3)
                 ((a . rest) rest)))
  (test-equal '(1 2 (3)) (match '(1 2 3)
                     ((a b . rest) (list a b rest))))
  ;; actual pair (not a list)
  (test-equal '(a b) (match (cons 'a 'b)
                 ((x . y) (list x y)))))

;; --- Multiple clauses / fallthrough ---

(test-group "multiple clauses / fallthrough"
  ;; first match wins
  (test-equal 'five (match 5
                (5 'five)
                (x 'other)))
  ;; fallthrough to second clause
  (test-equal 3 (match '(1 2)
            ((a b c) 'three)
            ((a b) (+ a b))))
  ;; fallthrough to third
  (test-equal "hello" (match "hello"
                  (42 'num)
                  (#t 'bool)
                  (x x))))

;; --- Predicate patterns ---

(test-group "predicate patterns"
  ;; (? pred)
  (test-equal 'num (match 42
               ((? number?) 'num)
               (_ 'other)))
  (test-equal 'other (match "hi"
                 ((? number?) 'num)
                 (_ 'other)))
  ;; (? pred pat) — guard + bind
  (test-equal 84 (match 42
             ((? number? x) (* x 2))))
  ;; pred fails -> fallthrough
  (test-equal "hi!" (match "hi"
                ((? number? x) 'num)
                (x (string-append x "!")))))

;; --- Boolean combinators ---

(test-group "boolean combinators"
  ;; and: all must match
  (test-equal 42 (match 42
             ((and (? number?) x) x)))
  (test-equal 'pos-num (match 42
                   ((and (? number?) (? positive?)) 'pos-num)
                   (_ 'other)))
  ;; or: any matches (no bindings from or)
  (test-equal 'ok (match 42
              ((or (? string?) (? number?)) 'ok)
              (_ 'fail)))
  (test-equal 'other (match #t
                 ((or 1 2 3) 'num)
                 (_ 'other)))
  ;; not: pattern must not match
  (test-equal 'ok (match 42
              ((not #f) 'ok)))
  (test-equal 'is-false (match #f
                    ((not #f) 'not-false)
                    (_ 'is-false))))

;; --- Field accessor ---

(test-group "field accessor"
  (test-equal 1 (match '(1 2 3)
            ((= car x) x)))
  (test-equal '(2 3) (match '(1 2 3)
                 ((= cdr x) x)))
  (test-equal 16 (match 4
             ((= (lambda (x) (* x x)) y) y))))

;; --- Ellipsis patterns ---

(test-group "ellipsis patterns"
  ;; match entire list
  (test-equal '(1 2 3) (match '(1 2 3) ((x ...) x)))
  ;; empty list with ellipsis
  (test-equal '() (match '() ((x ...) x)))
  ;; fixed prefix + ellipsis
  (test-equal '(2 3 4) (match '(1 2 3 4) ((1 x ...) x)))
  ;; multiple vars in sub-pattern
  (test-equal '((a b c) (1 2 3)) (match '((a 1) (b 2) (c 3))
                              (((k v) ...) (list k v)))))

;; --- Quasiquote patterns ---

(test-group "quasiquote patterns"
  (test-equal 7 (match '(point 3 4)
            (`(point ,x ,y) (+ x y))))
  (test-equal 'world (match '(hello world)
                 (`(hello ,who) who)))
  ;; mixed literal and variable
  (test-equal 2 (match '(1 2 3)
            (`(1 ,b 3) b))))

;; --- match-lambda ---

(test-group "match-lambda"
  (test-equal 7 ((match-lambda ((a b) (+ a b))) '(3 4)))
  (test-equal 'zero ((match-lambda
                 (0 'zero)
                 (x 'other)) 0)))

;; --- match-lambda* ---

(test-group "match-lambda*"
  (test-equal 7 ((match-lambda* ((a b) (+ a b))) 3 4))
  (test-equal 30 ((match-lambda*
              ((x) x)
              ((x y) (+ x y))) 10 20)))

;; --- match-let ---

(test-group "match-let"
  (test-equal 3 (match-let (((a b) '(1 2))) (+ a b)))
  (test-equal 10 (match-let (((a b) '(1 2))
                       ((c d) '(3 4)))
             (+ a b c d))))

;; --- match-let* ---

(test-group "match-let*"
  (test-equal 3 (match-let* (((a b) '(1 2))
                       ((c) (list (+ a b))))
            c)))

;; --- Practical examples ---

(test-group "expression evaluator"
  ;; Simple expression evaluator
  (define (eval-expr e)
    (match e
      ((? number? n) n)
      (('+ a b) (+ (eval-expr a) (eval-expr b)))
      (('* a b) (* (eval-expr a) (eval-expr b)))))
  (test-equal 5 (eval-expr 5))
  (test-equal 7 (eval-expr '(+ 3 4)))
  (test-equal 14 (eval-expr '(* 2 (+ 3 4)))))

(test-group "list utilities with match"
  ;; List utilities with match
  (define (my-length lst)
    (match lst
      (() 0)
      ((_ . rest) (+ 1 (my-length rest)))))
  (test-equal 0 (my-length '()))
  (test-equal 3 (my-length '(a b c))))

(test-group "tree flattening"
  ;; Tree flattening
  (define (flatten lst)
    (match lst
      (() '())
      (((? pair? head) . rest)
       (append (flatten head) (flatten rest)))
      ((head . rest)
       (cons head (flatten rest)))))
  (test-equal '(1 2 3 4 5 6) (flatten '(1 (2 (3 4) 5) 6))))

(test-end "match")
