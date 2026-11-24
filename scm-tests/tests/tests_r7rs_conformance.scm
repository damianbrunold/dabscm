;; R7RS conformance points where the implementations differed: number
;; syntax (reader and string->number), the writer's quote abbreviations,
;; definitions in expression contexts and letrec variables used before
;; their initialization.

(import (scheme base)
        (scheme complex)
        (scheme eval)
        (scheme read)
        (scheme write)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "r7rs-conformance")

;; the written form of a value (compares -0.0 and +nan.0 too)
(define (w x)
  (let ((p (open-output-string)))
    (write x p)
    (get-output-string p)))

(define (read-string-datum s)
  (guard (e (#t 'error))
    (let* ((p (open-input-string s))
           (v (read p)))
      (if (eof-object? (read p)) v (list 'more v)))))

;; (text written-value): string->number and read agree
(define numbers
  '(("42" "42") ("-17" "-17") ("+5" "5") ("1/2" "1/2") ("-3/6" "-1/2")
    ("1.5" "1.5") (".5" "0.5") ("5." "5.0") ("-0.0" "-0.0") ("1e3" "1000.0")
    ("1.5e-3" "0.0015")
    ("#e1.2" "6/5") ("#e1.5e2" "150") ("#e-0.125" "-1/8") ("#i1/3" "0.3333333333333333")
    ("#i5" "5.0") ("#x10" "16") ("#xFF" "255") ("#b101" "5") ("#o17" "15") ("#d10" "10")
    ("#x#e10" "16") ("#e#x10" "16") ("#x1/2" "1/2")
    ("1+2i" "1+2i") ("1-2i" "1-2i") ("+i" "0+1i") ("-i" "0-1i") ("+2i" "0+2i")
    ("1.5+0.5i" "1.5+0.5i") ("1/2+1/3i" "1/2+1/3i") ("1@0" "1.0+0.0i")
    ("#e1.5+2.5i" "3/2+5/2i") ("#i1+2i" "1.0+2.0i") ("#e1.5@0" "3/2")
    ("+inf.0" "+inf.0") ("-inf.0" "-inf.0") ("+nan.0" "+nan.0") ("-nan.0" "+nan.0")
    ("+inf.0i" "0.0+inf.0i") ("1+inf.0i" "1.0+inf.0i") ("-1.0-0.0i" "-1.0-0.0i")
    ("123456789012345678901234567890" "123456789012345678901234567890")))

(test-group "number syntax"
  (for-each (lambda (c)
              (test-equal (car c) (cadr c) (w (string->number (car c))))
              (test-equal (car c) (cadr c) (w (read-string-datum (car c)))))
            numbers))

(test-group "string->number: not numbers"
  (for-each (lambda (s) (test-equal s #f (string->number s)))
            '("abc" "" "+" "-" "." "1+" "1/0" "1/" " 42" "42 " "1e" "#e" "#x" "#xg"
              "#x1.8" "#b1.1" "1_000" "--1" "i" "1i" "2i")))

(test-group "string->number: radix"
  (test-equal 255 (string->number "ff" 16))
  (test-equal 255 (string->number "#xff" 10))
  (test-equal 5 (string->number "101" 2))
  (test-equal 1/2 (string->number "1/2" 16))
  (test-equal #f (string->number "1.5" 16)))

(test-group "read: errors"
  (for-each (lambda (s) (test-equal s 'error (read-string-datum s)))
            '("1/0" "1/" "#x1.8" "#b1.1" "1e")))

(test-group "complex numbers print the sign of -0.0"
  (test-equal "-1.0-0.0i" (w (make-rectangular -1.0 -0.0)))
  (test-equal "1.0+0.0i" (w (make-rectangular 1.0 0.0))))

(test-group "write: quote abbreviations only for two-element lists"
  (test-equal "'a" (w '(quote a)))
  (test-equal "`(a ,b ,@c)" (w '(quasiquote (a (unquote b) (unquote-splicing c)))))
  (test-equal "(quote . 3)" (w '(quote . 3)))
  (test-equal "(quote a b c)" (w '(quote a b c)))
  (test-equal "(quasiquote ,x y)" (w '(quasiquote (unquote x) y)))
  (test-equal "(unquote-splicing . z)" (w '(unquote-splicing . z)))
  (test-equal "(1 quote x)" (w '(1 . (quote x)))))

(define (raises? expr)
  (guard (e (#t #t))
    (eval expr (environment '(scheme base)))
    #f))

(test-group "definitions only at the top level and in bodies"
  (test-assert (raises? '(let () (if #t (begin (define q 1) q) 0))))
  (test-assert (raises? '(cond (#t (define q 1) q))))
  (test-assert (raises? '(let () (when #t (define q 1) q))))
  (test-equal 3 (eval '(let () (define a 1) (define b 2) (+ a b)) (environment '(scheme base))))
  (test-equal 4 (eval '(begin (define a 4) a) (environment '(scheme base)))))

(define (uninitialized thunk)
  (guard (e ((error-object? e) (list (error-object-message e) (error-object-irritants e))))
    (thunk)))

(test-group "letrec: a variable used before its initialization"
  (test-equal '("variable used before its initialization" (b))
              (uninitialized (lambda () (letrec ((a b) (b 1)) a))))
  (test-equal '("variable used before its initialization" (a))
              (uninitialized (lambda () (letrec ((a 1) (b a)) b))))
  (test-equal '("variable used before its initialization" (b))
              (uninitialized (lambda () (letrec* ((a b) (b 1)) a))))
  (test-equal '("variable used before its initialization" (y))
              (uninitialized (lambda () (define x y) (define y 2) x)))
  (test-equal 1 (letrec* ((a 1) (b a)) b))
  (test-equal 2 (let () (define x 1) (define y (+ x 1)) y))
  (test-equal 5 (letrec ((a (if #f b 5)) (b 1)) a))
  (test-equal #t (letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))
                          (odd? (lambda (n) (if (= n 0) #f (even? (- n 1))))))
                   (even? 10))))

(test-end "r7rs-conformance")
