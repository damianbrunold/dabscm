;; R7RS conformance points where the implementations differed: number
;; syntax (reader and string->number), the writer's quote abbreviations,
;; definitions in expression contexts and letrec variables used before
;; their initialization.

(import (scheme base)
        (scheme char)
        (scheme complex)
        (scheme eval)
        (scheme inexact)
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

(define (read-string-datum* s)
  (guard (e (#t 'error))
    (let ((p (open-input-string s)))
      (let loop ((acc '()))
        (let ((d (read p)))
          (if (eof-object? d) (reverse acc) (loop (cons d acc))))))))

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


;; --- found by the differential tests (scm-native/difftest.scm) ---

;; z close to w (each part within a relative 1e-12, or both equal)
(define (close? z w)
  (define (near a b)
    (or (= a b)
        (and (nan? a) (nan? b))
        (<= (abs (- a b)) (* 1e-12 (max 1 (abs a) (abs b))))))
  (and (near (real-part z) (real-part w)) (near (imag-part z) (imag-part w))))

(test-group "complex functions"
  (test-assert (close? (exp +i) (make-rectangular 0.5403023058681398 0.8414709848078965)))
  (test-assert (close? (log -1) (make-rectangular 0.0 3.141592653589793)))
  (test-assert (close? (log 1+i) (make-rectangular 0.34657359027997264 0.7853981633974483)))
  (test-assert (close? (sin 1+i) (make-rectangular 1.2984575814159773 0.6349639147847361)))
  (test-assert (close? (cos 1+i) (make-rectangular 0.8337300251311491 -0.9888977057628651)))
  (test-assert (close? (tan 1+i) (make-rectangular 0.2717525853195117 1.0839233273386946)))
  (test-assert (close? (asin 2) (make-rectangular 1.5707963267948966 -1.3169578969248166)))
  (test-assert (close? (acos 2) (make-rectangular 0.0 1.3169578969248166)))
  (test-assert (close? (atan +2i) (make-rectangular 1.5707963267948966 0.5493061443340549)))
  (test-assert (close? (sqrt 1+2i) (make-rectangular 1.272019649514069 0.7861513777574233)))
  (test-assert (close? (expt -1 0.5) (make-rectangular 6.123233995736766e-17 1.0)))
  (test-assert (close? (expt -8 1/3) (make-rectangular 1.0000000000000002 1.7320508075688772)))
  (test-equal -3+4i (expt 1+2i 2))
  (test-equal "real arguments in the real domain stay real" #t
              (and (real? (asin 0.5)) (real? (log 2)) (real? (sqrt 2)) (real? (atan 2))))
  (test-error (atan +i 1))
  (test-error (atan 1 +i)))

(test-group "exact results"
  (test-equal 1/27 (expt 1/3 3))
  (test-equal 9 (expt 1/3 -2))
  (test-equal -929/446 (expt -446/929 -1))
  (test-equal #f (exact? (sqrt 4611686018427387903)))
  (test-equal #f (exact? (sqrt 95855530006365444879066410924116)))
  (test-equal 2147483647 (sqrt 4611686014132420609))
  (test-equal 3/5 (sqrt 9/25))
  (test-equal #f (exact? (sqrt 2/3))))

(test-group "numerator and denominator of flonums"
  (test-equal "1.0" (w (denominator 0.0)))
  (test-equal "9.44473296573929e+21" (w (denominator 1e-7)))
  (test-equal "1.0" (w (numerator 0.5)))
  (test-equal "2.0" (w (denominator 0.5)))
  (test-error (numerator +inf.0))
  (test-error (denominator +nan.0)))

(test-group "number->string with a radix"
  (test-equal "1/6b14e9f812f366c35" (number->string 1/123456789012345678901 16))
  (test-equal "-1010001001" (number->string -649 2))
  (test-equal "-22145712670460675630521137" (number->string -85942423363967562981983 8))
  (test-equal "-123456789abcdef0123456789" (number->string #x-123456789abcdef0123456789 16)))

(test-group "make-rectangular and make-polar take reals"
  (test-error (make-rectangular 1 +i))
  (test-error (make-rectangular +i 1))
  (test-error (make-polar 1 +i)))

(test-group "gcd and lcm of inexact integers"
  (test-equal "1.0" (w (gcd 1e21 70119057158701821438962364699007639909)))
  (test-equal "0.0" (w (lcm 0.0 0.0)))
  (test-equal 0 (lcm 0 5))
  (test-equal "12.0" (w (lcm 4.0 6))))

(test-group "integer division with inexact operands"
  (test-equal "3.456629481269237e+16" (w (modulo 1e21 902495878795295404)))
  (test-equal "0.0" (w (quotient 0.0 -98765432109876543210)))
  (test-equal "0.0" (w (modulo -0.0 9060312629235379793577532464746830704343)))
  (test-equal '("0.0" "0.0") (call-with-values (lambda () (truncate/ -0.0 521)) (lambda (q r) (list (w q) (w r))))))

(test-group "signed zeros and IEEE division"
  (test-equal #t (= (make-rectangular 0 -0.0) 0.0))
  (test-equal #f (eqv? -0.0 0.0))
  (test-equal #f (equal? (make-rectangular 0.0 -0.0) (make-rectangular -0.0 0.0)))
  (test-equal "-0.5-0.0i" (w (- (make-rectangular 1/2 0.0))))
  (test-equal "-0.0+3.25i" (w (- (make-rectangular 0.0 -3.25))))
  (test-equal "0.5-0.0i" (w (inexact (make-rectangular 1/2 -0.0))))
  (test-equal "0.0+0.0i" (w (* -0.0 1/2-3/4i)))
  (test-equal "+inf.0" (w (/ 1 0.0)))
  (test-equal "-inf.0" (w (/ 1 -0.0)))
  (test-equal "+nan.0" (w (/ 0 0.0)))
  (test-error (/ 1.0 0))
  (test-equal "-inf.0" (w (log 0.1 1)))
  (test-equal "0.0" (w (log 1272.6026e-214 0.0))))

(test-group "complex numbers are not ordered"
  (test-equal "<: complex numbers are not ordered"
              (guard (e (#t (error-object-message e))) (< 1 +i))))

(test-group "read: delimiters and peculiar identifiers"
  (test-equal "(x41)" (w (read-string-datum* "x41;comment")))
  (test-equal "(912)" (w (read-string-datum* "912;")))
  (test-equal "(|e3#xsλ|)" (w (read-string-datum* "e3#xs\x3bb;;")))
  (test-equal "(|ln'|)" (w (read-string-datum* "ln'")))
  (test-equal "(`|+'a|)" (w (read-string-datum* "`+'a")))
  (test-equal "(|a,b|)" (w (read-string-datum* "a,b")))
  (test-equal "(|.lf#tl|)" (w (read-string-datum* ".lf#tl")))
  (test-equal "(#\\#)" (w (read-string-datum* "#\\#;")))
  (test-equal "(x |y z|)" (w (read-string-datum* "x|y z|")))
  (test-equal "(|+.E12| |-.fe3| |+.e|)" (w (read-string-datum* "+.E12 -.fe3 +.e")))
  (test-equal "(5000.0 500.0)" (w (read-string-datum* "5.e3 +.5e3")))
  (test-equal "(() '|1'|)" (w (read-string-datum* "(#!fold-case)'1'")))
  (test-equal "((a b))" (w (read-string-datum* "(a #!fold-case B)")))
  (test-equal "(16 16)" (w (read-string-datum* "#x#e10 #e#x10")))
  (test-equal '(#f #f) (map string->number '("#x#xb" "#e#e1")))
  (for-each (lambda (s) (test-equal s 'error (read-string-datum* s)))
            '("'" "`" "," ",@" "#;" "#!fold-case#e" "1e+x" "1.5E+\xe9;" "#x#xb" "#e#e1"
              "#12#" "(#1# #2=b)")))

(test-group "characters and strings"
  (test-equal #\x3c3 (char-foldcase #\x3c2))
  (test-equal "σ" (string-foldcase "\x3c2;"))
  (test-equal #\x130 (char-foldcase #\x130))
  (test-equal #\I (char-upcase #\x131))
  (test-equal #\i (char-downcase #\x130))
  (test-equal "I" (string-upcase "\x131;"))
  (test-equal #t (char-alphabetic? #\x2163))
  (test-equal #t (char-upper-case? #\x2163))
  (test-equal #t (char-whitespace? #\xa0))
  (test-equal #t (char-whitespace? #\x3000))
  (test-error (substring "" 1 1))
  (test-error (substring "abc" 2 1))
  (test-equal "" (substring "abc" 3 3)))

(test-group "+i and -i in any radix"
  (test-equal "(0-1i 0+1i 0.0-1.0i 0-1i)" (w (read-string-datum* "#b-i #x+i #i-i #o-I")))
  (test-equal "(0-1i 0+1i)" (w (map string->number '("#b-i" "#x+i"))))
  (test-equal 'error (read-string-datum* "#b+i1")))

(test-group "integer division of an exact integer beyond 2^53 by an inexact one"
  (test-equal 2.0 (modulo -97543732255733218 3.0))
  (test-equal -1.0 (remainder -97543732255733218 3.0)))

(test-group "exponent markers after a prefix"
  (test-equal "(100 120 100.0 150)" (w (read-string-datum* "#e1f2 #e12s1 #i1d2 #e1.5f2")))
  (test-equal (expt 10 113) (/ (read (open-input-string "#e10f112")) 1))
  (test-equal 'error (read-string-datum* "-9/i")))

(test-group "a complex number to an inexact integral power"
  (test-equal "8.3125-9.75i" (w (expt (make-rectangular -3.25 1.5) 2.0)))
  (test-equal "-11.0-2.0i" (w (expt 1+2i 3.0)))
  (test-equal "-0.12-0.16i" (w (expt 1+2i -2.0))))

(test-group "complex exp with a zero imaginary part"
  (test-equal "+inf.0+0.0i" (w (exp (make-rectangular +inf.0 0.0)))))

(test-end "r7rs-conformance")
