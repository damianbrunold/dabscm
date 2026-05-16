(import (scheme base) (scheme char) (scheme read) (scheme write) (scheme file) (scheme inexact) (scheme lazy) (scheme cxr) (scheme process-context) (scheme time) (scm core) (scm io) (scm fs) (scm compile))

(test-group
  (define x 28)
  (=> x 28))

(test-group
  (=> (quote a) 'a)
  (=> (quote #(a b c)) '#(a b c))
  (=> (quote (+ 1 2)) '(+ 1 2)))

(test-group
  (=> 'a 'a)
  (=> '#(a b c) '#(a b c))
  (=> '() '())
  (=> '(+ 1 2) '(+ 1 2))
  (=> '(quote a) ''a)
  (=> ''a ''a))

(test-group
  (=> '145932 145932)
  (=> 145932 145932)
  (=> '"abc" "abc")
  (=> "abc" "abc")
  (=> '#(a 10) '#(a 10))
  (=> #(a 10) '#(a 10))
  (=> '#t #t)
  (=> #t #t))

(test-group
  (=> (+ 3 4) 7))

(test-group
  (=> ((if #f + *) 3 4) 12))

(test-group
  (=> (lambda (x) (+ x x)) "#<lambda>"))

(test-group
  (=> ((lambda (x) (+ x x)) 4) 8))

(test-group
  (define reverse-subtract
    (lambda (x y) (- y x)))
  (=> (reverse-subtract 7 10) 3))

(test-group
  (define add4
    (let ((x 4))
      (lambda (y) (+ x y))))
  (=> (add4 6) 10))

(test-group
  (=> ((lambda x x) 3 4 5 6) '(3 4 5 6))
  (=> ((lambda (x y . z) z)
   3 4 5 6) '(5 6)))

(test-group
  (=> (if (> 3 2) 'yes 'no) 'yes)
  (=> (if (> 2 3) 'yes 'no) 'no)
  (=> (if (> 3 2)
      (- 3 2)
      (+ 3 2)) 1))

(test-group
  (define x 2)
  (=> (+ x 1) 3)
  (set! x 4)
  (=> (+ x 1) 5))

(test-group
  (=> (cond ((> 3 2) 'greater)
        ((< 3 2) 'less)) 'greater)
  (=> (cond ((> 3 3) 'greater)
        ((< 3 3) 'less)
        (else 'equal)) 'equal)
  (=> (cond ((assv 'b '((a 1) (b 2))) => cadr)
        (else #f)) 2))

(test-group
  (=> ; cond => evaluates test exactly once (R7RS §4.2.1)
  (let ((count 0))
    (cond ((begin (set! count (+ count 1)) (if (= count 1) 42 #f)) => (lambda (x) x))
          (else 'wrong))
    count) 1))

(test-group
  (define-record-type point
    (make-point x y)
    point?
    (x point-x)
    (y point-y set-point-y!))
  (define-record-type rect
    (make-rect w h)
    rect?
    (w rect-width)
    (h rect-height))
  (define-record-type unit
    (make-unit)
    unit?)
  (=> (point? (make-point 3 4)) #t)
  (=> (point? 'not-a-point) #f)
  (=> (point-x (make-point 3 4)) 3)
  (=> (point-y (make-point 3 4)) 4)
  (=> (let ((p (make-point 1 2)))
    (set-point-y! p 99)
    (point-y p)) 99)
  (=> (rect? (make-point 3 4)) #f)
  (=> (point? (make-rect 3 4)) #f)
  (=> (rect-width (make-rect 5 10)) 5)
  (=> (unit? (make-unit)) #t)
  (=> (unit? (make-point 1 2)) #f))

(test-group
  (import (scheme base) (scheme lazy) (scheme inexact))
  (=> (square 5) 25)
  (=> (boolean=? #t #t #t) #t)
  (=> (boolean=? #t #f) #f)
  (=> (exact-integer? 3) #t)
  (=> (exact-integer? 3.0) #f)
  (=> (floor-quotient 5 2) 2)
  (=> (floor-remainder 5 2) 1)
  (=> (floor-quotient -5 2) -3)
  (=> (floor-remainder -5 2) 1)
  (=> (truncate-quotient 5 2) 2)
  (=> (truncate-remainder -5 2) -1)
  (=> (append) '())
  (=> (list-copy '(1 2 3)) '(1 2 3))
  (=> (let ((lst (list 1 2 3))) (list-set! lst 1 99) lst) '(1 99 3))
  (=> (map + '(1 2) '(3 4)) '(4 6))
  (=> (string->list "hello" 1 3) '(#\e #\l))
  (=> (string-copy "hello" 1 3) "el")
  (=> (vector-copy #(1 2 3 4) 1 3) '#(2 3))
  (=> (string->vector "abc") '#(#\a #\b #\c))
  (=> (vector->string #(#\h #\i)) "hi")
  (=> (vector-append #(1 2) #(3 4)) '#(1 2 3 4))
  (=> (vector-map + #(1 2 3) #(4 5 6)) '#(5 7 9))
  (=> (let ((p (make-parameter 10)))
    (list (p)
          (parameterize ((p 20)) (p))
          (p))) '(10 20 10))
  (=> (promise? (delay 42)) #t)
  (=> (force (delay 42)) 42)
  (=> (let ((p (delay-force (delay 99))))
    (force p)) 99)
  (=> (eof-object? (eof-object)) #t)
  (=> (port? (current-input-port)) #t)
  (=> (nan? 1.0) #f)
  (=> (finite? 1.5) #t)
  (=> (finite? 100) #t)
  (=> (infinite? 1.0) #f)
  (=> ;; Exception handling (R7RS 6.11)
  (with-exception-handler
    (lambda (exn) 42)
    (lambda () (+ 1 2))) 3)
  (=> (call-with-current-continuation
    (lambda (k)
      (with-exception-handler
        (lambda (exn) (k 99))
        (lambda () (raise 'oops))))) 99)
  (=> (call-with-current-continuation
    (lambda (k)
      (with-exception-handler
        (lambda (exn) (k (error-object-message exn)))
        (lambda () (error "bad!" 1 2))))) "bad!")
  (=> (call-with-current-continuation
    (lambda (k)
      (with-exception-handler
        (lambda (exn) (k (error-object-irritants exn)))
        (lambda () (error "bad!" 1 2))))) '(1 2))
  (=> (error-object? (call-with-current-continuation
    (lambda (k)
      (with-exception-handler k (lambda () (error "oops")))))) #t)
  (=> (guard (exn
          ((string? (error-object-message exn))
           (error-object-message exn)))
    (error "hello" 1 2)) "hello")
  (=> (guard (exn
          (#t 'caught))
    (+ 1 1)) 2)
  (=> (guard (exn
          ((equal? exn 'foo) 'got-foo))
    (raise 'foo)) 'got-foo)
  (=> (with-exception-handler
    (lambda (exn) (* exn 2))
    (lambda () (+ 1 (raise-continuable 3)))) 7)
  (=> (error-object? (call-with-current-continuation
    (lambda (k)
      (with-exception-handler k (lambda () (error "r" 1)))))) #t)
  (=> (error-object-message (call-with-current-continuation
    (lambda (k)
      (with-exception-handler k (lambda () (error "msg" 1 2)))))) "msg"))

(test-group)

(test-group
  (import (scheme base) (scheme char) (scheme eval) (scheme process-context) (scheme load))
  (=> (symbol=? 'foo 'foo) #t)
  (=> (symbol=? 'foo 'bar) #f)
  (=> (symbol=? 'a 'a 'a) #t))

(test-group
  (import (scheme base))
  (=> (make-list 3) '(#f #f #f))
  (=> (make-list 3 0) '(0 0 0))
  (=> (make-list 0) '()))

(test-group
  (import (scheme base) (scheme char))
  (=> (string-map char-upcase "hello") "HELLO")
  (=> (string-map (lambda (c) c) "abcde") "abcde"))

(test-group
  (import (scheme base))
  (=> (let ((acc '()))
    (string-for-each (lambda (c) (set! acc (cons c acc))) "ih")
    acc) '(#\h #\i)))

(test-group
  (import (scheme char))
  (=> (char-foldcase #\A) #\a)
  (=> (char-foldcase #\a) #\a))

(test-group
  (import (scheme char))
  (=> (string-foldcase "HELLO") "hello")
  (=> (string-foldcase "Hello") "hello"))

(test-group
  (import (scheme char))
  (=> (digit-value #\0) 0)
  (=> (digit-value #\9) 9)
  (=> (digit-value #\5) 5)
  (=> (digit-value #\a) #f))

(test-group
  (import (scheme process-context))
  (=> (list? (get-environment-variables)) #t))

(test-group
  (import (scheme process-context))
  (=> (list? (command-line)) #t))

(test-group
  (import (scheme eval) (scheme base))
  (=> (eval '(+ 1 2) (environment '(scheme base))) 3))

(test-group
  (import (scheme load))
  (=> (procedure? load) #t))

(test-group
  (import (scheme write) (scm io))
  (=> (call-with-output-string (lambda (p) (write-simple "hello" p))) "\"hello\""))

(test-group
  (import (scheme write) (scm io))
  (=> (call-with-output-string (lambda (p) (write-simple '(1 2 3) p))) "(1 2 3)"))

(test-group
  (import (scheme write) (scm io))
  (=> (call-with-output-string (lambda (p) (write '(1 2 3) p))) "(1 2 3)"))

(test-group
  (import (scheme write) (scm io))
  (=> (call-with-output-string (lambda (p) (write "hello" p))) "\"hello\""))

(test-group
  (import (scheme write) (scm io) (scheme base))
  (=> (let ((x (list 1 2 3)))
    (set-cdr! (cddr x) x)
    (string? (call-with-output-string (lambda (p) (write x p))))) #t))

(test-group
  (import (scheme write) (scm io) (scheme base))
  (=> (let* ((x (list 1))
         (y (list x x)))
    (string? (call-with-output-string (lambda (p) (write-shared y p))))) #t))

;; let* with internal definitions (R7RS 5.3.2)
(test-group
  (=> (let* ((a 1) (b 2)) (define c (+ a b)) c) 3)
  (=> (let* () (define x 42) x) 42)
  (=> (let* ((a 10)) (define b (* a 2)) (+ a b)) 30)
  (=> (let* ((x 1)) (define a x) (define b (+ a 1)) (+ a b)) 3))

(test-group
  (import (scheme write) (scm io) (scheme base))
  (=> (let ((x (list 1)))
    (set-cdr! x x)
    (string? (call-with-output-string (lambda (p) (write-shared x p))))) #t))

(test-group
  (import (scheme read) (scheme base))
  (=> (car (read (open-input-string "#0=(1 2 3)"))) 1))

(test-group
  (import (scheme load) (scheme eval) (scheme base) (scheme file))
  (=> (let ((tmp (string-append (special-folder-temp) "/scm-load-env-test.scm")))
    (call-with-output-file tmp
      (lambda (p) (display "(define load-env-test-val 77)" p)))
    (load tmp (environment '(scheme base)))
    (eval 'load-env-test-val (environment '(scheme base)))) 77))

(test-group
  (import (scheme read) (scheme base))
  (=> (let ((x (read (open-input-string "(#0=(1 2) #0#)"))))
    (eq? (car x) (cadr x))) #t))

(test-group
  (import (scheme read) (scheme base))
  (=> (let ((x (read (open-input-string "#0=(1 . #0#)"))))
    (eq? x (cdr x))) #t))

(test-group
  (import (scheme read) (scheme write) (scheme base) (scm io))
  (=> (let* ((x (list 1))
         (_ (set-cdr! x x))
         (s (call-with-output-string (lambda (p) (write x p))))
         (y (read (open-input-string s))))
    (eq? y (cdr y))) #t))

(test-group
  (import (scheme base))
  (=> (abs 5) 5)
  (=> (abs -3) 3)
  (=> (abs 0) 0))

(test-group
  (import (scheme base))
  (=> (min 1 2 3) 1)
  (=> (max 1 2 3) 3)
  (=> (min 3 1 2) 1)
  (=> (max 1.5 2) 2)
  (=> (min 1.5 2) 1.5))

(test-group
  (import (scheme base))
  (=> (floor 3.7) 3.0)
  (=> (floor -3.2) -4.0)
  (=> (ceiling 3.2) 4.0)
  (=> (ceiling -3.7) -3.0)
  (=> (round 3.5) 4.0)
  (=> (round 2.5) 2.0)
  (=> (round -2.5) -2.0)
  (=> (truncate 3.7) 3.0)
  (=> (truncate -3.7) -3.0)
  (=> (floor 3) 3)
  (=> (ceiling 3) 3))

(test-group
  (import (scheme base))
  (=> (exact 1.0) 1)
  (=> (exact 3.0) 3)
  (=> (inexact 3) 3.0)
  (=> (inexact 0) 0.0)
  (=> (exact 1/3) 1/3)
  (=> (inexact? 3.0) #t)
  (=> (exact? 3) #t)
  (=> (exact? 1/3) #t))

(test-group
  (import (scheme base))
  (=> (zero? 0) #t)
  (=> (zero? 1) #f)
  (=> (positive? 3) #t)
  (=> (positive? -1) #f)
  (=> (negative? -2) #t)
  (=> (negative? 0) #f))

(test-group
  (import (scheme base))
  (=> (even? 4) #t)
  (=> (even? 3) #f)
  (=> (odd? 3) #t)
  (=> (odd? 0) #f)
  (=> (even? 0) #t)
  (=> (even? -2) #t))

(test-group
  (import (scheme base))
  (=> (expt 2 10) 1024)
  (=> (expt 2 0) 1)
  (=> (expt 0 0) 1)
  (=> (expt 3 3) 27))

(test-group
  (import (scheme base))
  (=> (gcd 12 8) 4)
  (=> (gcd) 0)
  (=> (gcd 5) 5)
  (=> (gcd 10 4 2) 2)
  (=> (lcm 4 6) 12)
  (=> (lcm) 1)
  (=> (lcm 6) 6)
  (=> (lcm 4 6 10) 60))

(test-group
  (import (scheme base))
  (=> (number->string 10) "10")
  (=> (number->string 255 16) "ff")
  (=> (number->string 8 2) "1000")
  (=> (number->string 8 8) "10"))

(test-group
  (import (scheme base))
  (=> (string->number "10") 10)
  (=> (string->number "ff" 16) 255)
  (=> (string->number "1000" 2) 8)
  (=> (string->number "not-a-number") #f))

(test-group
  (import (scheme base))
  (=> (call-with-values (lambda () (floor/ 5 2)) list) '(2 1))
  (=> (call-with-values (lambda () (floor/ -5 2)) list) '(-3 1))
  (=> (call-with-values (lambda () (truncate/ 5 2)) list) '(2 1))
  (=> (call-with-values (lambda () (truncate/ -5 2)) list) '(-2 -1)))

(test-group
  (import (scheme base) (scheme inexact))
  (=> (call-with-values (lambda () (exact-integer-sqrt 14)) list) '(3 5))
  (=> (call-with-values (lambda () (exact-integer-sqrt 9)) list) '(3 0))
  (=> (call-with-values (lambda () (exact-integer-sqrt 0)) list) '(0 0)))

(test-group
  (import (scheme base))
  (=> 1/3 1/3)
  (=> (+ 1/3 1/6) 1/2)
  (=> (* 2 1/3) 2/3)
  (=> (numerator 1/3) 1)
  (=> (denominator 1/3) 3)
  (=> (exact? 1/3) #t)
  (=> (rational? 1/3) #t))

(test-group
  (import (scheme base))
  (=> (numerator 5) 5)
  (=> (denominator 5) 1))

(test-group
  (import (scheme base))
  (=> (eq? 'a 'a) #t)
  (=> (eq? '() '()) #t)
  (=> (eq? #t #t) #t)
  (=> (eqv? 42 42) #t)
  (=> (eqv? #\a #\a) #t)
  (=> (eqv? '() '()) #t)
  (=> (equal? '(1 2 3) '(1 2 3)) #t)
  (=> (equal? "abc" "abc") #t)
  (=> (equal? #(1 2) #(1 2)) #t)
  (=> (equal? '(1 2) '(1 3)) #f))

(test-group
  (import (scheme base))
  (=> (integer? 3) #t)
  (=> (integer? 3.0) #t)
  (=> (integer? 3.5) #f)
  (=> (real? 3.0) #t)
  (=> (real? 3) #t)
  (=> (rational? 3) #t)
  (=> (rational? 3.0) #t)
  (=> (complex? 3) #t))

(test-group
  (import (scheme base))
  (=> (boolean? #t) #t)
  (=> (boolean? #f) #t)
  (=> (boolean? 0) #f))

(test-group
  (import (scheme base))
  (=> (procedure? car) #t)
  (=> (procedure? (lambda (x) x)) #t)
  (=> (procedure? 42) #f))

(test-group
  (import (scheme base))
  (=> (let ((r '()))
    (for-each (lambda (x) (set! r (cons x r))) '(1 2 3))
    r) '(3 2 1))
  (=> (let ((r '()))
    (for-each (lambda (x y) (set! r (cons (+ x y) r))) '(1 2) '(10 20))
    r) '(22 11)))

(test-group
  (import (scheme base))
  (=> (list-tail '(a b c d) 0) '(a b c d))
  (=> (list-tail '(a b c d) 2) '(c d))
  (=> (list-tail '(a b c d) 4) '()))

(test-group
  (import (scheme base))
  (=> (assq 'b '((a 1) (b 2) (c 3))) '(b 2))
  (=> (assq 'd '((a 1) (b 2))) #f)
  (=> (assv 2 '((1 a) (2 b) (3 c))) '(2 b))
  (=> (assoc "b" '(("a" 1) ("b" 2) ("c" 3))) '("b" 2))
  (=> (assoc "B" '(("a" 1) ("b" 2)) string-ci=?) '("b" 2)))

(test-group
  (import (scheme base) (scheme char))
  (=> (memq 'b '(a b c)) '(b c))
  (=> (memq 'd '(a b c)) #f)
  (=> (memv 2 '(1 2 3)) '(2 3))
  (=> (member 2 '(1 2 3)) '(2 3))
  (=> (member "b" '("a" "b" "c")) '("b" "c"))
  (=> (member "B" '("a" "b" "c") string-ci=?) '("b" "c")))

(test-group
  (import (scheme base))
  (=> (list->vector '(1 2 3)) '#(1 2 3))
  (=> (vector->list #(1 2 3)) '(1 2 3))
  (=> (vector->list #(1 2 3 4) 1) '(2 3 4))
  (=> (vector->list #(1 2 3 4) 1 3) '(2 3)))

(test-group
  (import (scheme base))
  (=> (apply + '(1 2 3)) 6)
  (=> (apply + 1 '(2 3)) 6)
  (=> (apply max '(3 1 2)) 3)
  (=> (apply string '(#\a #\b #\c)) "abc"))

(test-group
  (import (scheme base))
  (=> (string-length (make-string 5)) 5)
  (=> (make-string 3 #\x) "xxx")
  (=> (string #\h #\i) "hi"))

(test-group
  (import (scheme base))
  (=> (string-ref "hello" 0) #\h)
  (=> (string-ref "hello" 4) #\o)
  (=> (let ((s (string-copy "hello")))
    (string-set! s 0 #\H)
    s) "Hello"))

(test-group
  (import (scheme base))
  (=> (let ((s (make-string 3 #\a)))
    (string-fill! s #\b)
    s) "bbb")
  (=> (let ((dst (make-string 5 #\-)))
    (string-copy! dst 1 "abc")
    dst) "-abc-")
  (=> (let ((dst (make-string 5 #\-)))
    (string-copy! dst 1 "abcde" 1 3)
    dst) "-bc--"))

(test-group
  (import (scheme base))
  (=> (list->string '(#\h #\e #\l #\l #\o)) "hello")
  (=> (string->list "abc") '(#\a #\b #\c)))

(test-group
  (import (scheme base))
  (=> (string->symbol "hello") 'hello)
  (=> (symbol->string 'world) "world"))

(test-group
  (import (scheme base))
  (=> (string<? "abc" "abd") #t)
  (=> (string=? "abc" "abc" "abc") #t)
  (=> (string>? "b" "a") #t))

(test-group
  (import (scheme base))
  (=> (let ((v (make-vector 3 0)))
    (vector-fill! v 7)
    v) '#(7 7 7))
  (=> (let ((dst (make-vector 5 0)))
    (vector-copy! dst 1 #(1 2 3))
    dst) '#(0 1 2 3 0))
  (=> (let ((dst (make-vector 5 0)))
    (vector-copy! dst 1 #(1 2 3 4) 1 3)
    dst) '#(0 2 3 0 0)))

(test-group
  (import (scheme base))
  (=> (make-vector 3 0) '#(0 0 0))
  (=> (vector 10 20 30) '#(10 20 30)))

(test-group
  (import (scheme base))
  (=> (let ((r '()))
    (vector-for-each (lambda (x) (set! r (cons x r))) #(1 2 3))
    r) '(3 2 1)))

(test-group
  (import (scheme char))
  (=> (char->integer #\a) 97)
  (=> (char->integer #\A) 65)
  (=> (char->integer #\0) 48)
  (=> (integer->char 97) #\a)
  (=> (integer->char 65) #\A)
  (=> (char-alphabetic? #\a) #t)
  (=> (char-alphabetic? #\1) #f)
  (=> (char-numeric? #\5) #t)
  (=> (char-numeric? #\a) #f)
  (=> (char-whitespace? #\space) #t)
  (=> (char-whitespace? #\a) #f)
  (=> (char-upper-case? #\A) #t)
  (=> (char-upper-case? #\a) #f)
  (=> (char-lower-case? #\a) #t)
  (=> (char-lower-case? #\A) #f)
  (=> (char-upcase #\a) #\A)
  (=> (char-downcase #\A) #\a))

(test-group
  (import (scheme char))
  (=> (char-ci=? #\a #\A) #t)
  (=> (char-ci<? #\a #\B) #t)
  (=> (char-ci>? #\Z #\a) #t)
  (=> (char=? #\a #\a #\a) #t)
  (=> (char<? #\a #\b #\c) #t))

(test-group
  (import (scheme char))
  (=> (string-upcase "hello") "HELLO")
  (=> (string-downcase "WORLD") "world")
  (=> (string-ci=? "Hello" "hello") #t)
  (=> (string-ci<? "abc" "ABD") #t))

(test-group
  (import (scheme base))
  (=> (when #t 1 2 3) 3)
  (=> (unless #f 42) 42)
  (=> (when #f 99) (values))
  (=> (unless #t 99) (values)))

(test-group
  (import (scheme base))
  (=> (do ((i 0 (+ i 1))
       (s 0 (+ s i)))
      ((= i 5) s)) 10)
  (=> (do ((vec (make-vector 5))
       (i 0 (+ i 1)))
      ((= i 5) vec)
    (vector-set! vec i i)) '#(0 1 2 3 4)))

(test-group
  (import (scheme base))
  (=> (case 2
    ((1) 'one)
    ((2) 'two)
    ((3) 'three)) 'two)
  (=> (case 5
    ((1 2 3) 'small)
    (else 'big)) 'big)
  (=> (case (* 2 3)
    ((2 3 5 7) 'prime)
    ((1 4 6 8 9) 'composite)) 'composite)
  ;; case uses eqv? not equal? (R7RS 4.2.1)
  (=> (let ((x "hello")) (case x (("hello") 'yes) (else 'no))) 'no)
  ;; case with => syntax (R7RS 4.2.1)
  (=> (case (+ 1 1)
    ((1) 'one)
    ((2) => (lambda (x) (* x 10)))
    (else 'other)) 20))

(test-group
  (import (scheme base))
  (=> (let-values (((a b) (values 1 2))) (+ a b)) 3)
  (=> (let-values (((a b c) (values 10 20 30))) (* a b c)) 6000)
  (=> (let*-values (((a b) (values 1 2))
                ((c) (+ a b)))
    c) 3))

(test-group
  (import (scheme base))
  (=> (call-with-values (lambda () (values 1 2)) +) 3)
  (=> (call-with-values (lambda () (values 4 5)) *) 20)
  (=> (call-with-values (lambda () 42) (lambda (x) x)) 42))

(test-group
  (import (scheme base))
  (=> (let ((r '()))
    (dynamic-wind
      (lambda () (set! r (cons 'in r)))
      (lambda () (set! r (cons 'body r)))
      (lambda () (set! r (cons 'out r))))
    (reverse r)) '(in body out))
  (=> (let ((r '()))
    (call/cc (lambda (k)
      (dynamic-wind
        (lambda () (set! r (cons 'in r)))
        (lambda () (set! r (cons 'body r)) (k 'done))
        (lambda () (set! r (cons 'out r))))))
    (reverse r)) '(in body out)))

(test-group
  (import (scheme base) (scheme eval))
  ;; Regression: calling eval inside a dynamic-wind body must not corrupt
  ;; the outer VM's winder state. Previously VM.Current was set by the
  ;; nested eval VM and never restored, causing the after-thunk's
  ;; (cdr (%winders-get)) to fail.
  (=> (let ((r '()))
        (dynamic-wind
          (lambda () (set! r (cons 'in r)))
          (lambda ()
            (set! r (cons (eval '(+ 1 2) (environment '(scheme base))) r)))
          (lambda () (set! r (cons 'out r))))
        (reverse r)) '(in 3 out))
  ;; Nested eval that itself uses dynamic-wind should also work.
  (=> (let ((r '()))
        (dynamic-wind
          (lambda () (set! r (cons 'in r)))
          (lambda ()
            (eval '(dynamic-wind
                     (lambda () #f)
                     (lambda () #f)
                     (lambda () #f))
                  (environment '(scheme base)))
            (set! r (cons 'body r)))
          (lambda () (set! r (cons 'out r))))
        (reverse r)) '(in body out)))

(test-group
  (import (scheme base))
  (=> (cond-expand (r7rs 'yes)) 'yes)
  (=> (cond-expand (else 'fallback)) 'fallback)
  (=> (list? (features)) #t)
  (=> (if (member 'r7rs (features)) 'has-r7rs 'no) 'has-r7rs)
  (=> (not (eq? #f (memq 'scm (features)))) #t)
  (=> (cond-expand (scm 'yes) (else 'no)) 'yes)
  (=> (not (eq? #f (memq 'srfi-1 (features)))) #t)
  (=> (cond-expand (srfi-1 'yes) (else 'no)) 'yes)
  (=> (cond-expand ((library (srfi 1)) 'yes) (else 'no)) 'yes)
  (=> (cond-expand ((library (no such lib)) 'yes) (else 'no)) 'no)
  (=> (procedure? include-ci) #t))

(test-group
  (import (scheme base))
  (=> (read-char (open-input-string "abc")) #\a)
  (=> (peek-char (open-input-string "abc")) #\a)
  (=> (let ((p (open-input-string "ab")))
    (peek-char p)
    (read-char p)) #\a)
  (=> (eof-object? (read-char (open-input-string ""))) #t))

(test-group
  (import (scheme base))
  (=> (read-line (open-input-string "hello\nworld")) "hello")
  (=> (let ((p (open-input-string "hi")))
    (read-line p)) "hi"))

(test-group
  (import (scheme base) (scm io))
  (=> (call-with-output-string (lambda (p) (write-char #\A p))) "A")
  (=> (call-with-output-string (lambda (p) (write-char #\a p) (write-char #\b p))) "ab")
  (=> (call-with-output-string (lambda (p) (write-string "hello" p))) "hello")
  (=> (call-with-output-string (lambda (p) (write-string "hello" p 1 3))) "el"))

(test-group
  (import (scheme base))
  (=> (read-string 3 (open-input-string "hello")) "hel")
  (=> (read-string 5 (open-input-string "hi")) "hi")
  (=> (eof-object? (read-string 3 (open-input-string ""))) #t))

(test-group
  (import (scheme base))
  (=> (char-ready? (open-input-string "abc")) #t))

(test-group
  (import (scheme base))
  (=> (input-port? (open-input-string "x")) #t)
  (=> (output-port? (open-output-string)) #t)
  (=> (input-port? (open-output-string)) #f)
  (=> (textual-port? (open-input-string "x")) #t)
  (=> (binary-port? (open-input-bytevector #u8(1 2 3))) #t)
  (=> (binary-port? (open-input-string "x")) #f))

(test-group
  (import (scheme base))
  (=> (let ((p (open-input-string "x")))
    (input-port-open? p)) #t)
  (=> (let ((p (open-input-string "x")))
    (close-input-port p)
    (input-port-open? p)) #f)
  (=> (let ((p (open-output-string)))
    (output-port-open? p)) #t)
  (=> (let ((p (open-output-bytevector)))
    (close-output-port p)
    (output-port-open? p)) #f))

(test-group
  (import (scheme base))
  (=> (let ((p (open-input-string "abc")))
    (close-port p)
    (input-port-open? p)) #f)
  (=> (call-with-port (open-input-string "hi")
    (lambda (p) (read-char p))) #\h))

(test-group
  (import (scheme base))
  (=> (let ((p (open-output-string)))
    (flush-output-port p)
    #t) #t))

(test-group
  (import (scheme base))
  (=> (let ((p (open-output-string)))
    (write-char #\h p)
    (write-char #\i p)
    (get-output-string p)) "hi"))

(test-group
  (import (scheme base))
  (=> (bytevector? #u8(1 2 3)) #t)
  (=> (bytevector-length #u8(1 2 3)) 3)
  (=> (bytevector-u8-ref #u8(10 20 30) 1) 20)
  (=> (let ((bv (make-bytevector 3 0)))
    (bytevector-u8-set! bv 1 99)
    bv) #u8(0 99 0))
  (=> (make-bytevector 3) #u8(0 0 0))
  (=> (make-bytevector 3 7) #u8(7 7 7))
  (=> (bytevector 1 2 3) #u8(1 2 3))
  (=> (bytevector-append #u8(1 2) #u8(3 4)) #u8(1 2 3 4)))

(test-group
  (import (scheme base))
  (=> (bytevector-copy #u8(1 2 3 4 5)) #u8(1 2 3 4 5))
  (=> (bytevector-copy #u8(1 2 3 4 5) 1) #u8(2 3 4 5))
  (=> (bytevector-copy #u8(1 2 3 4 5) 1 3) #u8(2 3)))

(test-group
  (import (scheme base))
  (=> (let ((bv (make-bytevector 5 0)))
    (bytevector-copy! bv 1 #u8(10 20 30))
    bv) #u8(0 10 20 30 0)))

(test-group
  (import (scheme base))
  (=> (utf8->string (string->utf8 "hello")) "hello")
  (=> (utf8->string (string->utf8 "abc") 1) "bc")
  (=> (bytevector? (string->utf8 "hi")) #t))

(test-group
  (import (scheme base))
  (=> (let ((p (open-input-bytevector #u8(65 66 67))))
    (read-u8 p)) 65)
  (=> (let ((p (open-input-bytevector #u8(65 66 67))))
    (peek-u8 p)
    (read-u8 p)) 65)
  (=> (let ((p (open-output-bytevector)))
    (write-u8 42 p)
    (write-u8 99 p)
    (get-output-bytevector p)) #u8(42 99))
  (=> (let ((p (open-input-bytevector #u8(1 2 3 4 5))))
    (read-bytevector 3 p)) #u8(1 2 3))
  (=> (eof-object? (read-u8 (open-input-bytevector #u8()))) #t))

(test-group
  (import (scheme base))
  (=> (let ((p (open-output-bytevector)))
    (write-bytevector #u8(1 2 3 4 5) p 1 3)
    (get-output-bytevector p)) #u8(2 3)))

(test-group
  (import (scheme inexact))
  (=> (sin 0.0) 0.0)
  (=> (cos 0.0) 1.0)
  (=> (tan 0.0) 0.0))

(test-group
  (import (scheme inexact) (scheme base))
  (=> (asin 0.0) 0.0)
  (=> (acos 1.0) 0.0)
  (=> (< (abs (- (atan 1.0 1.0) 0.7853981633974483)) 0.0000000001) #t))

(test-group
  (import (scheme inexact) (scheme base))
  (=> (exp 0.0) 1.0)
  (=> (log 1.0) 0.0)
  (=> (sqrt 4.0) 2.0)
  (=> (sqrt 0.0) 0.0)
  (=> (< (abs (- (log 8.0 2.0) 3.0)) 0.0000000001) #t))

(test-group
  (import (scheme inexact))
  (=> (infinite? +inf.0) #t)
  (=> (infinite? -inf.0) #t)
  (=> (nan? +nan.0) #t)
  (=> (finite? +inf.0) #f))

(test-group
  (import (scheme time))
  (=> (number? (current-second)) #t)
  (=> (>= (current-second) 0) #t)
  (=> (integer? (current-jiffy)) #t)
  (=> (= (jiffies-per-second) 1000000) #t))

(test-group
  (import (scheme lazy))
  (=> (promise? (make-promise (lambda () 42))) #t)
  (=> (force (make-promise (lambda () 42))) 42)
  (=> (let ((count 0))
    (let ((p (make-promise (lambda () (set! count (+ count 1)) count))))
      (force p)
      (force p)
      count)) 1))

(test-group
  (import (scheme cxr))
  (=> (caaar '(((1 2) 3) 4)) 1)
  (=> (caadr '(1 (2 3) 4)) 2)
  (=> (cadar '((1 2) 3)) 2)
  (=> (caddr '(1 2 3 4)) 3)
  (=> (cdaar '(((1 2) 3) 4)) '(2))
  (=> (cdadr '(1 (2 3) 4)) '(3))
  (=> (cddar '((1 2 3) 4)) '(3))
  (=> (cdddr '(1 2 3 4)) '(4)))

(test-group
  (import (scheme cxr))
  (=> (cadddr '(1 2 3 4 5)) 4)
  (=> (cddddr '(1 2 3 4 5)) '(5))
  (=> (caaddr '(1 2 (3 4))) 3)
  (=> (cadadr '(1 (2 3) 4)) 3))

(test-group
  (import (scheme file) (scheme base))
  (=> (let ((tmp (join-path (special-folder-temp) "scm-r7rs-test-file.txt")))
    (call-with-output-file tmp (lambda (p) (display "hello" p)))
    (call-with-input-file tmp (lambda (p) (read-line p)))) "hello"))

(test-group
  (import (scheme file) (scheme base))
  (=> (let ((tmp (join-path (special-folder-temp) "scm-r7rs-test-wif.txt")))
    (with-output-to-file tmp (lambda () (display "world")))
    (with-input-from-file tmp (lambda () (read-line (current-input-port))))) "world"))

(test-group
  (import (scheme file) (scheme base))
  (=> (let ((tmp (join-path (special-folder-temp) "scm-r7rs-test-binary.bin")))
    (let ((out (open-binary-output-file tmp)))
      (write-u8 42 out)
      (write-u8 99 out)
      (close-output-port out))
    (let ((in (open-binary-input-file tmp)))
      (let ((a (read-u8 in))
            (b (read-u8 in)))
        (close-input-port in)
        (list a b)))) '(42 99)))

(test-group
  (import (scheme file) (scheme base))
  (=> (let ((tmp (join-path (special-folder-temp) "scm-r7rs-test-exist.txt")))
    (call-with-output-file tmp (lambda (p) (display "x" p)))
    (let ((exists-before (file-exists? tmp)))
      (delete-file tmp)
      (list exists-before (file-exists? tmp)))) '(#t #f)))

(test-group
  (import (scm fs) (scheme base))
  (=> (let* ((tmp (join-path (special-folder-temp) "scm-delete-dir-test"))
         (sub (join-path tmp "subdir"))
         (f   (join-path sub "file.txt")))
    (make-directory tmp)
    (make-directory sub)
    (call-with-output-file f (lambda (p) (display "x" p)))
    (let ((exists-before (directory-exists? tmp)))
      (delete-directory tmp)
      (list exists-before (directory-exists? tmp)))) '(#t #f)))

(test-group
  (import (scheme repl) (scheme eval) (scheme base))
  (=> (procedure? interaction-environment) #t))

(test-group
  (import (scheme base))
  (=> `(1 ,@(list 2 3) 4) '(1 2 3 4))
  (=> (let ((x '(a b)))
    `(1 ,@x 2)) '(1 a b 2))
  (=> `(,(+ 1 2) ,@(map (lambda (x) (* x 2)) '(1 2 3))) '(3 2 4 6)))

(test-group
  (import (scheme base))
  (=> (letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))
           (odd?  (lambda (n) (if (= n 0) #f (even? (- n 1))))))
    (list (even? 4) (odd? 3))) '(#t #t))
  (=> (letrec* ((x 1) (y (+ x 1))) y) 2))

(test-group
  (import (scheme base))
  (=> (and) #t)
  (=> (and 1 2 3) 3)
  (=> (and 1 #f 3) #f)
  (=> (or) #f)
  (=> (or #f #f 42) 42)
  (=> (or 1 2 3) 1))

(test-group
  (import (scheme base))
  (=> (read-error?
    (call/cc (lambda (k)
      (with-exception-handler k
        (lambda () (read (open-input-string "#!"))))))) #t)
  (=> (file-error?
    (call/cc (lambda (k)
      (with-exception-handler k
        (lambda () (open-input-file "/no/such/file/exists.scm")))))) #t))

(test-group
  (import (scheme base))
  (=> (guard (e (#t (error-object? e)))
    (syntax-error "intentional" 42)) #t))

(test-group
  (import (scheme base))
  (=> #true #t)
  (=> #false #f))

(test-group
  (import (scheme base))
  (=> #b1010 10)
  (=> #o17 15)
  (=> #xFF 255)
  (=> #d42 42)
  (=> #e1.5 3/2)
  (=> #i3 3.0)
  (=> #e#b101 5)
  (=> #b#e101 5)
  (=> #i1/2 0.5))

(test-group
  (import (scheme base))
  (=> (+ 1 #;2 3) 4)
  (=> (list 1 #;2 3) '(1 3)))

(test-group
  (import (scheme base))
  (=> (+ 1 #| this is a block comment |# 2) 3)
  (=> (+ #| nested #| block |# comment |# 1 2) 3))

(test-group
  (import (scheme base))
  (=> (rational? 1) #t)
  (=> (rational? 1/2) #t)
  (=> (rational? 1.0) #t)
  (=> (rational? 1.5) #t)
  (=> (rational? +inf.0) #f)
  (=> (rational? +nan.0) #f))

(test-group
  (import (scheme base))
  (=> (denominator 1.5) 2.0)
  (=> (numerator 1.5) 3.0)
  (=> (denominator 1.0) 1.0)
  (=> (numerator 1.0) 1.0)
  (=> (denominator -1.5) 2.0)
  (=> (numerator -1.5) -3.0))

(test-group
  (import (scheme base))
  (define p-test (make-parameter 1))
  (call/cc (lambda (k) (parameterize ((p-test 2)) (k 'escape))))
  (=> (p-test) 1))
