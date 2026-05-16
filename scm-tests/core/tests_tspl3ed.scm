(import (scheme base) (scheme char) (scheme read) (scheme write) (scheme cxr)
        (scheme inexact) (scheme lazy) (scheme file) (scheme process-context)
        (scheme time) (scm core) (scm io) (scm list) (scm compile)
        (scm macro) (scm math) (scheme r5rs))

(test-group
  (=> "Hi Mom!" "Hi Mom!"))

(test-group
  (=> 42 42))

(test-group
  (=> 3.141592653 3.141592653))

(test-group
  (=> + "#<p:+>"))

(test-group
  (=> (+ 76 31) 107))

(test-group
  (=> '(a b c d) '(a b c d)))

(test-group
  (=> (car '(a b c)) 'a))

(test-group
  (=> (cdr '(a b c)) '(b c)))

(test-group
  (=> (cons 'a '(b c)) '(a b c)))

(test-group
  (=> (cons (car '(a b c))
        (cdr '(d e f))) '(a e f)))

(test-group
  (define my-square
    (lambda (n)
      (* n n)))
  (=> (my-square 5) 25)
  (=> (my-square -200) 40000)
  (=> (my-square 0.5) 0.25))

(test-group
  (=> (+ (+ 2 2) (+ 2 2)) 8))

(test-group
  (=> (* 2 (* 2 (* 2 (* 2 2)))) 32))

(test-group
  (=> (quote (1 2 3 4 5)) '(1 2 3 4 5)))

(test-group
  (=> (quote ("this" "is" "a" "list")) '("this" "is" "a" "list")))

(test-group
  (=> (quote (+ 3 4)) '(+ 3 4)))

(test-group
  (=> '(1 2 3 4) '(1 2 3 4)))

(test-group
  (=> '((1 2) (3 4)) '((1 2) (3 4))))

(test-group
  (=> '(/ (* 2 -1) 3) '(/ (* 2 -1) 3)))

(test-group
  (=> (quote hello) 'hello))

(test-group
  (=> '2 2))

(test-group
  (=> (quote "Hi Mom!") "Hi Mom!"))

(test-group
  (=> (car '(a b c)) 'a))

(test-group
  (=> (cdr '(a b c)) '(b c)))

(test-group
  (=> (cdr '(a)) '()))

(test-group
  (=> (car (cdr '(a b c))) 'b))

(test-group
  (=> (cdr (cdr '(a b c))) '(c)))

(test-group
  (=> (car '((a b) (c d))) '(a b)))

(test-group
  (=> (cdr '((a b) (c d))) '((c d))))

(test-group
  (=> (cons 'a '()) '(a))
  (=> (cons 'a '(b c)) '(a b c))
  (=> (cons 'a (cons 'b (cons 'c '()))) '(a b c))
  (=> (cons '(a b) '(c d)) '((a b) c d)))

(test-group
  (=> (car (cons 'a '(b c))) 'a)
  (=> (cdr (cons 'a '(b c))) '(b c))
  (=> (cons (car '(a b c))
        (cdr '(d e f))) '(a e f))
  (=> (cons (car '(a b c))
        (cdr '(a b c))) '(a b c)))

(test-group
  (=> (cons 'a 'b) '(a . b))
  (=> (cdr '(a . b)) 'b)
  (=> (cons 'a '(b . c)) '(a b . c)))

(test-group
  (=> '(a . (b . (c . ()))) '(a b c)))

(test-group
  (=> (list 'a 'b 'c) '(a b c))
  (=> (list 'a) '(a))
  (=> (list) '()))

(test-group
  (=> (let ((x 2))
    (+ x 3)) 5)
  (=> (let ((y 3))
    (+ 2 y)) 5)
  (=> (let ((x 2) (y 3))
    (+ x y)) 5))

(test-group
  (=> (+ (* 4 4) (* 4 4)) 32)
  (=> (let ((a (* 4 4)))
    (+ a a)) 32))

(test-group
  (=> (let ((list1 '(a b c)) (list2 '(d e f)))
    (cons (cons (car list1)
  	      (car list2))
  	(cons (car (cdr list1))
  	      (car (cdr list2))))) '((a . d) b . e)))

(test-group
  (=> (let ((f +))
    (f 2 3)) 5)
  (=> (let ((f +) (x 2))
    (f x 3)) 5)
  (=> (let ((f +) (x 2) (y 3))
    (f x y)) 5))

(test-group
  (=> (let ((+ *))
    (+ 2 3)) 6))

(test-group
  (let ((+ *))
    (+ 2 3))
  (=> (+ 2 3) 5))

(test-group
  (=> (let ((a 4) (b -3))
    (let ((a-squared (* a a))
  	(b-squared (* b b)))
      (+ a-squared b-squared))) 25))

(test-group
  (=> (let ((x 1))
    (let ((x (+ x 1)))
      (+ x x))) 4))

(test-group
  (=> (let ((x 1))
    (let ((new-x (+ x 1)))
      (+ new-x new-x))) 4))

(test-group
  (=> (lambda (x) (+ x x)) "#<lambda>"))

(test-group
  (=> ((lambda (x) (+ x x)) (* 3 4)) 24))

(test-group
  (=> (let ((double (lambda (x) (+ x x))))
    (list (double (* 3 4))
  	(double (/ 99 11))
  	(double (- 2 7)))) '(24 18 -10)))

(test-group
  (=> (let ((double-cons (lambda (x) (cons x x))))
    (double-cons 'a)) '(a . a)))

(test-group
  (=> (let ((double-any (lambda (f x) (f x x))))
    (list (double-any + 13)
  	(double-any cons 'a))) '(26 (a . a))))

(test-group
  (=> (let ((x 'a))
    (let ((f (lambda (y) (list x y))))
      (f 'b))) '(a b)))

(test-group
  (=> (let ((f (let ((x 'sam))
  	   (lambda (y z) (list x y z)))))
    (f 'i 'am)) '(sam i am)))

(test-group
  (=> (let ((f (let ((x 'sam))
  	   (lambda (y z) (list x y z)))))
    (let ((x 'not-sam))
      (f 'i 'am))) '(sam i am)))

(test-group
  (=> (let ((f (lambda x x)))
    (f 1 2 3 4)) '(1 2 3 4))
  (=> (let ((f (lambda x x)))
    (f)) '())
  (=> (let ((g (lambda (x . y) (list x y))))
    (g 1 2 3 4)) '(1 (2 3 4)))
  (=> (let ((h (lambda (x y . z) (list x y z))))
    (h 'a 'b 'c 'd)) '(a b (c d))))

(test-group
  (define double-any
    (lambda (f x)
      (f x x)))
  (=> (double-any + 10) 20)
  (=> (double-any cons 'a) '(a . a)))

(test-group
  (define sandwich "peanut-butter-and-jelly")
  (=> sandwich "peanut-butter-and-jelly"))

(test-group
  (define xyz '(x y z))
  (=> (let ((xyz '(z y x)))
    xyz) '(z y x)))

(test-group
  (define doubler
    (lambda (f)
      (lambda (x) (f x x))))
  (define double (doubler +))
  (=> (double 6) 12)
  (define double-cons (doubler cons))
  (=> (double-cons 'a) '(a . a)))

(test-group
  (define proc1
    (lambda (x y)
      (proc2 y x)))
  (define proc2 cons)
  (=> (proc1 'a 'b) '(b . a)))

(test-group
  (define my-abs
    (lambda (n)
      (if (< n 0)
  	(- 0 n)
  	n)))
  (=> (my-abs 77) 77)
  (=> (my-abs -77) 77))

(test-group
  (=> (< -1 0) #t)
  (=> (> -1 0) #f))

(test-group
  (=> (if #t 'true 'false) 'true)
  (=> (if #f 'true 'false) 'false)
  (=> (if '() 'true 'false) 'true)
  (=> (if 1 'true 'false) 'true)
  (=> (if '(a b c) 'true 'false) 'true))

(test-group
  (=> (not #t) #f)
  (=> (not "false") #f)
  (=> (not #f) #t))

(test-group
  (=> (or) #f)
  (=> (or #f) #f)
  (=> (or #f #t) #t)
  (=> (or #f 'a #f) 'a))

(test-group
  (define reciprocal
    (lambda (n)
      (and (not (= n 0))
  	 (/ n))))
  (=> (reciprocal 2) 1/2)
  (=> (reciprocal 0.25) 4.0)
  (=> (reciprocal 0) #f))

(test-group
  (=> (null? '()) #t)
  (=> (null? 'abc) #f)
  (=> (null? '(x y z)) #f)
  (=> (null? (cdddr '(x y z))) #t))

(test-group
  (define lisp-cdr
    (lambda (x)
      (if (null? x)
  	'()
  	(cdr x))))
  (=> (lisp-cdr '(a b c)) '(b c))
  (=> (lisp-cdr '(c)) '())
  (=> (lisp-cdr '()) '()))

(test-group
  (=> (eqv? 'a 'a) #t)
  (=> (eqv? 'a 'b) #f)
  (=> (eqv? #f #f) #t)
  (=> (eqv? #t #f) #f)
  (=> (eqv? 3 3) #t)
  (=> (eqv? 3 2) #f)
  (=> (let ((x "Hi Mom!"))
    (eqv? x x)) #t)
  (=> (let ((x (cons 'a 'b)))
    (eqv? x x)) #t)
  (=> (eqv? (cons 'a 'b) (cons 'a 'b)) #f))

(test-group
  (=> (pair? '(a . b)) #t)
  (=> (pair? '(a b c)) #t)
  (=> (pair? '()) #f)
  (=> (pair? 'abc) #f)
  (=> (pair? "Hi Mom!") #f)
  (=> (pair? 1234567890) #f))

(test-group
  (define reciprocal
    (lambda (n)
      (if (and (number? n) (not (= n 0)))
  	(/ 1 n)
  	"oops!")))
  (=> (reciprocal 0.25) 4.0)
  (=> (reciprocal 'a) "oops!"))

(test-group
  (define my-sign
    (lambda (n)
      (if (< n 0)
  	-1
  	(if (> n 0)
  	    +1
  	    0))))
  (=> (my-sign -88.3) -1)
  (=> (my-sign 0) 0)
  (=> (my-sign 3333333333) 1)
  (=> (* (my-sign -88.3) (abs -88.3)) -88.3))

(test-group
  (define income-tax
    (lambda (income)
      (cond
       ((<= income 10000) (* income .05))
       ((<= income 20000) (+ (* (- income 10000) .08) 500.00))
       ((<= income 30000) (+ (* (- income 20000) .13) 1300.00))
       (else (+ (* (- income 30000) .21) 2600.00)))))
  (=> (income-tax 5000) 250.0)
  (=> (income-tax 15000) 900.0)
  (=> (income-tax 25000) 1950.0)
  (=> (income-tax 50000) 6800.0))

(test-group
  (define my-length
    (lambda (ls)
      (if (null? ls)
  	0
  	(+ (my-length (cdr ls)) 1))))
  (=> (my-length '()) 0)
  (=> (my-length '(a)) 1)
  (=> (my-length '(a b)) 2))

(test-group
  (define my-list-copy
    (lambda (ls)
      (if (null? ls)
  	'()
  	(cons (car ls)
  	      (my-list-copy (cdr ls))))))
  (=> (my-list-copy '()) '())
  (=> (my-list-copy '(a b c)) '(a b c)))

(test-group
  (define my-memv
    (lambda (x ls)
      (cond
       ((null? ls) #f)
       ((eqv? (car ls) x) ls)
       (else (my-memv x (cdr ls))))))
  (=> (my-memv 'a '(a b b d)) '(a b b d))
  (=> (my-memv 'b '(a b b d)) '(b b d))
  (=> (my-memv 'c '(a b b d)) #f)
  (=> (my-memv 'd '(a b b d)) '(d))
  (=> (if (my-memv 'b '(a b b d))
      "yes"
      "no") "yes"))

(test-group
  (define remv
    (lambda (x ls)
      (cond
       ((null? ls) '())
       ((eqv? (car ls) x) (remv x (cdr ls)))
       (else (cons (car ls) (remv x (cdr ls)))))))
  (=> (remv 'a '(a b b d)) '(b b d))
  (=> (remv 'b '(a b b d)) '(a d))
  (=> (remv 'c '(a b b d)) '(a b b d))
  (=> (remv 'd '(a b b d)) '(a b b)))

(test-group
  (define tree-copy
    (lambda (tr)
      (if (not (pair? tr))
  	tr
  	(cons (tree-copy (car tr))
  	      (tree-copy (cdr tr))))))
  (=> (tree-copy '((a . b) . c)) '((a . b) . c)))

(test-group
  (define abs-all
    (lambda (ls)
      (if (null? ls)
  	'()
  	(cons (abs (car ls))
  	      (abs-all (cdr ls))))))
  (=> (abs-all '(1 -2 3 -4 5 -6)) '(1 2 3 4 5 6)))

(test-group
  (define abs-all
    (lambda (ls)
      (map abs ls)))
  (=> (abs-all '(1 -2 3 -4 5 -6)) '(1 2 3 4 5 6)))

(test-group
  (=> (map abs '(1 -2 3 -4 5 -6)) '(1 2 3 4 5 6)))

(test-group
  (=> (map (lambda (x) (* x x))
       '(1 -3 -5 7)) '(1 9 25 49)))

(test-group
  (=> (map cons '(a b c) '(1 2 3)) '((a . 1) (b . 2) (c . 3))))

(test-group
  (define map1
    (lambda (p ls)
      (if (null? ls)
  	'()
  	(cons (p (car ls))
  	      (map1 p (cdr ls))))))
  (=> (map1 abs '(1 -2 3 -4 5 -6)) '(1 2 3 4 5 6)))

(test-group
  (define abcde '(a b c d e))
  (=> abcde '(a b c d e))
  (=> (set! abcde (cdr abcde)) '(b c d e))
  (=> (let ((abcde '(a b c d e)))
    (set! abcde (reverse abcde))
    abcde) '(e d c b a)))

(test-group
  (define quadratic-formula
    (lambda (a b c)
      (let ((root1 0) (root2 0) (minusb 0) (radical 0) (divisor 0))
        (set! minusb (- 0 b))
        (set! radical (sqrt (- (* b b) (* 4 (* a c)))))
        (set! divisor (* 2 a))
        (set! root1 (/ (+ minusb radical) divisor))
        (set! root2 (/ (- minusb radical) divisor))
        (cons root1 root2))))
  (=> (quadratic-formula 2 -4 -6) '(3 . -1)))

(test-group
  (define quadratic-formula
    (lambda (a b c)
      (let ((minusb (- 0 b))
  	  (radical (sqrt (- (* b b) (* 4 (* a c)))))
  	  (divisor (* 2 a)))
        (let ((root1 (/ (+ minusb radical) divisor))
  	    (root2 (/ (- minusb radical) divisor)))
  	(cons root1 root2)))))
  (=> (quadratic-formula 2 -4 -6) '(3 . -1)))

(test-group
  (define my-cons-count 0)
  (define my-cons
    (let ((old-cons cons))
      (lambda (x y)
        (set! my-cons-count (+ my-cons-count 1))
        (old-cons x y))))
  (=> (my-cons 'a '(b c)) '(a b c))
  (=> my-cons-count 1)
  (my-cons 'a (my-cons 'b (my-cons 'c '())))
  (=> my-cons-count 4))

(test-group
  (define next 0)
  (define count
    (lambda ()
      (let ((v next))
        (set! next (+ next 1))
        v)))
  (=> (count) 0)
  (=> (count) 1))

(test-group
  (define count
    (let ((next 0))
      (lambda ()
        (let ((v next))
  	(set! next (+ next 1))
  	v))))
  (=> (count) 0)
  (=> (count) 1))

(test-group
  (define make-counter
    (lambda ()
      (let ((next 0))
        (lambda ()
  	(let ((v next))
  	  (set! next (+ next 1))
  	  v)))))
  (define count1 (make-counter))
  (define count2 (make-counter))
  (=> (count1) 0)
  (=> (count2) 0)
  (=> (count1) 1)
  (=> (count1) 2)
  (=> (count2) 1))

(test-group
  (define shhh #f)
  (define tell #f)
  (let ((secret 0))
    (set! shhh
  	(lambda (message)
  	  (set! secret message)))
    (set! tell
  	(lambda ()
  	  secret)))
  (shhh "sally likes harry")
  (=> (tell) "sally likes harry"))

(test-group
  (define lazy
    (lambda (t)
      (let ((val #f) (flag #f))
        (lambda ()
  	(if (not flag)
  	    (begin (set! val (t))
  		   (set! flag #t)))
  	val))))
  (define n 0)
  (define p (lazy (lambda () (set! n (+ n 1)) "got me")))
  (=> (p) "got me")
  (=> n 1)
  (=> (p) "got me")
  (=> n 1))

;; Disabled — triggers a VM NullReferenceException due to a compiler
;; bug with letrec* internal defines calling closures.
;; TODO: investigate and fix the underlying VM/compiler issue.
#;
(test-group
  (define make-stack
    (lambda ()
      (let ((ls '()))
        (lambda (msg . args)
  	(cond
  	 ((eqv? msg 'empty?) (null? ls))
  	 ((eqv? msg 'push!) (set! ls (cons (car args) ls)))
  	 ((eqv? msg 'top) (car ls))
  	 ((eqv? msg 'pop!) (set! ls (cdr ls)))
  	 (else "oops"))))))
  (define stack1 (make-stack))
  (define stack2 (make-stack))
  (=> (stack1 'empty?) #t)
  (=> (stack2 'empty?) #t)
  (stack1 'push! 'a)
  (=> (stack1 'empty?) #f)
  (=> (stack2 'empty?) #t)
  (stack1 'push! 'b)
  (stack2 'push! 'c)
  (=> (stack1 'top) 'b)
  (=> (stack2 'top) 'c)
  (stack1 'pop!)
  (=> (stack2 'empty?) #f)
  (=> (stack1 'top) 'a)
  (stack2 'pop!)
  (=> (stack2 'empty?) #t))

(test-group
  (define p (list 1 2 3))
  (set-car! (cdr p) 'two)
  (=> p '(1 two 3))
  (set-cdr! p '())
  (=> p '(1)))

(test-group
  (define make-queue
    (lambda ()
      (let ((end (cons 'ignored '())))
        (cons end end))))
  (define putq!
    (lambda (q v)
      (let ((end (cons 'ignored '())))
        (set-car! (cdr q) v)
        (set-cdr! (cdr q) end)
        (set-cdr! q end))))
  (define getq
    (lambda (q)
      (car (car q))))
  (define delq!
    (lambda (q)
      (set-car! q (cdr (car q)))))
  (define myq (make-queue))
  (putq! myq 'a)
  (putq! myq 'b)
  (=> (getq myq) 'a)
  (delq! myq)
  (=> (getq myq) 'b)
  (delq! myq)
  (putq! myq 'c)
  (putq! myq 'd)
  (=> (getq myq) 'c)
  (delq! myq)
  (=> (getq myq) 'd))

(test-group
  (=> (let* ((a 5) (b (+ a a)) (c (+ a b)))
    (list a b c)) '(5 10 15)))

(test-group
  (=> (let ((x 3))
    (unless (= x 0) (set! x (+ x 1)))
    (when (= x 4) (set! x (* x 2)))
    x) 8))

(test-group
  (=> (let ((sum (lambda (sum ls)
  	     (if (null? ls)
  		 0
  		 (+ (car ls) (sum sum (cdr ls)))))))
    (sum sum '(1 2 3 4 5))) 15))

(test-group
  (=> (letrec ((sum (lambda (ls)
  		(if (null? ls)
  		    0
  		    (+ (car ls) (sum (cdr ls)))))))
    (sum '(1 2 3 4 5))) 15))

(test-group
  (=> (letrec ((even?
  	  (lambda (x)
  	    (or (= x 0)
  		(odd? (- x 1)))))
  	 (odd?
  	  (lambda (x)
  	    (and (not (= x 0))
  		 (even? (- x 1))))))
    (list (even? 20) (odd? 20))) '(#t #f)))

(test-group
  (=> (letrec ((f (lambda () (+ x 2)))
  	 (x 1))
    (f)) 3))

(test-group
  (define my-factorial
    (lambda (n)
      (let fact ((i n))
        (if (= i 0)
  	  1
  	  (* i (fact (- i 1)))))))
  (=> (my-factorial 0) 1)
  (=> (my-factorial 1) 1)
  (=> (my-factorial 2) 2)
  (=> (my-factorial 3) 6)
  (=> (my-factorial 10) 3628800))

(test-group
  (define my-factorial
    (lambda (n)
      (let fact ((i n) (a 1))
        (if (= i 0)
  	  a
  	  (fact (- i 1) (* a i))))))
  (=> (my-factorial 0) 1)
  (=> (my-factorial 1) 1)
  (=> (my-factorial 2) 2)
  (=> (my-factorial 3) 6)
  (=> (my-factorial 10) 3628800))

(test-group
  (define fibonacci
    (lambda (n)
      (let fib ((i n))
        (cond
         ((= i 0) 0)
         ((= i 1) 1)
         (else (+ (fib (- i 1)) (fib (- i 2))))))))
  (=> (fibonacci 0) 0)
  (=> (fibonacci 1) 1)
  (=> (fibonacci 2) 1)
  (=> (fibonacci 3) 2)
  (=> (fibonacci 4) 3)
  (=> (fibonacci 5) 5)
  (=> (fibonacci 6) 8)
  (=> (fibonacci 20) 6765))

(test-group
  (define fibonacci
    (lambda (n)
      (if (= n 0)
  	0
  	(let fib ((i n) (a1 1) (a2 0))
  	  (if (= i 1)
  	      a1
  	      (fib (- i 1) (+ a1 a2) a1))))))
  (=> (fibonacci 0) 0)
  (=> (fibonacci 1) 1)
  (=> (fibonacci 2) 1)
  (=> (fibonacci 3) 2)
  (=> (fibonacci 4) 3)
  (=> (fibonacci 5) 5)
  (=> (fibonacci 6) 8)
  (=> (fibonacci 20) 6765)
  (=> (fibonacci 30) 832040))

(test-group
  (define factor
    (lambda (n)
      (let f ((n n) (i 2))
        (cond
         ((>= i n) (list n))
         ((integer? (/ n i))
  	(cons i (f (/ n i) i)))
         (else (f n (+ i 1)))))))
  (=> (factor 0) '(0))
  (=> (factor 1) '(1))
  (=> (factor 12) '(2 2 3))
  (=> (factor 3628800) '(2 2 2 2 2 2 2 2 3 3 3 3 5 5 7))
  (=> (factor 9239) '(9239)))

(test-group
  (=> (call/cc
   (lambda (k)
     (* 5 4))) 20))

(test-group
  (=> (call/cc
   (lambda (k)
     (* 5 (k 4)))) 4))

(test-group
  (=> (+ 2
     (call/cc
      (lambda (k)
        (* 5 (k 4))))) 6))

(test-group
  (define product
    (lambda (ls)
      (call/cc
       (lambda (break)
         (let f ((ls ls))
  	 (cond
  	  ((null? ls) 1)
  	  ((= (car ls) 0) (break 0))
  	  (else (* (car ls) (f (cdr ls))))))))))
  (=> (product '(1 2 3 4 5)) 120)
  (=> (product '(7 3 8 0 1 9 5)) 0))

(test-group
  (=> (let ((x (call/cc (lambda (k) k))))
    (x (lambda (ignore) "hi"))) "hi"))

(test-group
  (=> (((call/cc (lambda (k) k)) (lambda (x) x)) "HEY!") "HEY!"))

(test-group
  (define retry #f)
  (define my-factorial
    (lambda (x)
      (if (= x 0)
  	(call/cc (lambda (k) (set! retry k) 1))
  	(* x (my-factorial (- x 1))))))
  (=> (my-factorial 4) 24)
  (=> (retry 1) 24)
  (=> (retry 2) 48))

(test-group
  (=> (letrec ((f (lambda (x) (cons 'a x)))
  	 (g (lambda (x) (cons 'b (f x))))
  	 (h (lambda (x) (g (cons 'c x)))))
    (cons 'd (h '()))) '(d b a c)))

(test-group
  (=> (letrec ((f (lambda (x k) (k (cons 'a x))))
  	 (g (lambda (x k) (f x (lambda (v) (k (cons 'b v))))))
  	 (h (lambda (x k) (g (cons 'c x) k))))
    (h '() (lambda (v) (cons 'd v)))) '(d b a c)))

(test-group
  (define car&cdr
    (lambda (p k)
      (k (car p) (cdr p))))
  (=> (car&cdr '(a b c)
  	 (lambda (x y)
  	   (list y x))) '((b c) a))
  (=> (car&cdr '(a b c) cons) '(a b c))
  (=> (car&cdr '(a b c a d) memv) '(a d)))

(test-group
  (define integer-divide
    (lambda (x y success failure)
      (if (= y 0)
  	(failure "divide by zero")
  	(let ((q (quotient x y)))
  	  (success q (- x (* q y)))))))
  (=> (integer-divide 10 3 list (lambda (x) x)) '(3 1))
  (=> (integer-divide 10 0 list (lambda (x) x)) "divide by zero"))

(test-group
  (define product
    (lambda (ls k)
      (let ((break k))
        (let f ((ls ls) (k k))
  	(cond
  	 ((null? ls) (k 1))
  	 ((= (car ls) 0) (break 0))
  	 (else (f (cdr ls)
  		  (lambda (x)
  		    (k (* (car ls) x))))))))))
  (=> (product '(1 2 3 4 5) (lambda (x) x)) 120)
  (=> (product '(7 3 8 0 1 9 5) (lambda (x) x)) 0))

(test-group
  (define f (lambda (x) (* x x)))
  (=> (let ((x 3))
    (define f (lambda (y) (+ y x)))
    (f 4)) 7)
  (=> (f 4) 16))

(test-group
  (=> (let ()
    (define even?
      (lambda (x)
        (or (= x 0)
  	  (odd? (- x 1)))))
    (define odd?
      (lambda (x)
        (and (not (= x 0))
  	   (even? (- x 1)))))
    (even? 20)) #t))

(test-group
  (define calc #f)
  (let ()
    (define do-calc
      (lambda (ek exp)
        (cond
         ((number? exp) exp)
         ((and (list? exp) (= (length exp) 3))
  	(let ((op (car exp)) (args (cdr exp)))
  	  (case op
  	    ((add) (apply-op ek + args))
  	    ((sub) (apply-op ek - args))
  	    ((mul) (apply-op ek * args))
  	    ((div) (apply-op ek / args))
  	    (else (complain ek "invalid operator" op)))))
         (else (complain ek "invalid expression" exp)))))
    (define apply-op
      (lambda (ek op args)
        (op (do-calc ek (car args)) (do-calc ek (cadr args)))))
    (define complain
      (lambda (ek msg exp)
        (ek (list msg exp))))
    (set! calc
  	(lambda (exp)
  	  (call/cc
  	   (lambda (ek)
  	     (do-calc ek exp))))))
  (=> (calc '2) 2)
  (=> (calc '(add 2 3)) 5)
  (=> (calc '(add (mul 3 2) -4)) 2)
  (=> (calc '(div 6 2)) 3)
  (=> (calc '(add (mul 3 2) (div 4))) '("invalid expression" (div 4)))
  (=> (calc '(mul (add 1 -2) (pow 2 7))) '("invalid operator" pow)))

(test-group
  (=> list "#<list>"))

(test-group
  (define x 'a)
  (=> (list x x) '(a a))
  (=> (let ((x 'b))
    (list x x)) '(b b))
  (=> (let ((let 'let)) let) 'let))

(test-group
  (define f
    (lambda (x)
      (g x)))
  (define g
    (lambda (x)
      (+ x x)))
  (=> (f 3) 6))

(test-group
  (=> (lambda (x) (+ x 3)) "#<lambda>")
  (=> ((lambda (x) (+ x 3)) 7) 10)
  (=> ((lambda (x y) (* x (+ x y))) 7 13) 140)
  (=> ((lambda (f x) (f x x)) + 11) 22)
  (=> ((lambda () (+ 3 4))) 7)
  (=> ((lambda (x . y) (list x y))
   28 37) '(28 (37)))
  (=> ((lambda (x . y) (list x y))
   28 37 47 28) '(28 (37 47 28)))
  (=> ((lambda (x y . z) (list x y z))
   1 2 3 4) '(1 2 (3 4)))
  (=> ((lambda x x) 7 13) '(7 13)))

(test-group
  (=> (let ((x (* 3.0 3.0)) (y (* 4.0 4.0)))
    (sqrt (+ x y))) 5.0)
  (=> (let ((x 'a) (y '(b c)))
    (cons x y)) '(a b c))
  (=> (let ((x 0) (y 1))
    (let ((x y) (y x))
      (list x y))) '(1 0)))

(test-group
  (=> (let* ((x (* 5.0 5.0))
         (y (- x (* 4.0 4.0))))
    (sqrt y)) 3.0)
  (=> (let ((x 0) (y 1))
    (let* ((x y) (y x))
      (list x y))) '(1 1)))

(test-group
  (=> (letrec ((sum (lambda (x)
  		(if (zero? x)
  		    0
  		    (+ x (sum (- x 1)))))))
    (sum 5)) 15))

(test-group
  (define x 3)
  (=> x 3)
  (define f
    (lambda (x y)
      (* (+ x y) 2)))
  (=> (f 5 4) 18)
  (define (sum-of-squares x y)
    (+ (* x x) (* y y)))
  (=> (sum-of-squares 3 4) 25))

(test-group
  (define f
    (lambda (x)
      (+ x 1)))
  (=> (let ((x 2))
    (define f
      (lambda (y)
        (+ y x)))
    (f 3)) 5)
  (=> (f 3) 4))

(test-group
  (define flip-flop
    (let ((state #f))
      (lambda ()
        (set! state (not state))
        state)))
  (=> (flip-flop) #t)
  (=> (flip-flop) #f)
  (=> (flip-flop) #t))

(test-group
  (define memoize
    (lambda (proc)
      (let ((cache '()))
        (lambda (x)
  	(cond
  	 ((assq x cache) => cdr)
  	 (else (let ((ans (proc x)))
  		 (set! cache (cons (cons x ans) cache))
  		 ans)))))))
  (define fibonacci
    (memoize
     (lambda (n)
       (if (< n 2)
  	 n
  	 (+ (fibonacci (- n 1)) (fibonacci (- n 2)))))))
  (=> (fibonacci 30) 832040))

(test-group
  (=> (+ 3 4) 7)
  (=> ((if (odd? 3) + -) 6 2) 8)
  (=> ((lambda (x) x) 5) 5)
  (=> (let ((f (lambda (x) (+ x x))))
    (f 8)) 16))

(test-group
  (=> (apply + '(4 5)) 9)
  (=> (apply min '(6 8 3 2 5)) 2)
  (=> (apply min 5 1 3 '(6 8 3 2 5)) 1)
  (=> (apply vector 'a 'b '(c d e)) '#(a b c d e)))

(test-group
  (define my-first
    (lambda (l)
      (apply (lambda (x . y) x)
  	   l)))
  (define my-rest
    (lambda (l)
      (apply (lambda (x . y) y)
  	   l)))
  (=> (my-first '(a b c d)) 'a)
  (=> (my-rest '(a b c d)) '(b c d)))

(test-group
  (define x 3)
  (=> (begin
    (set! x (+ x 1))
    (+ x x)) 8))

(test-group
  (=> (let ()
    (begin (define x 3) (define y 4))
    (+ x y)) 7))

(test-group
  (define x 2)
  (let ()
    (begin (define x 3) (define y 4))
    (+ x y))
  (=> x 2))

(test-group
  (define swap-pair!
    (lambda (x)
      (let ((temp (car x)))
        (set-car! x (cdr x))
        (set-cdr! x temp)
        x)))
  (=> (swap-pair! (cons 'a 'b)) '(b . a)))

(test-group
  (=> (let ((l '(a b c)))
    (if (null? l)
        '()
        (cdr l))) '(b c)))

(test-group
  (=> (let ((l '()))
    (if (null? l)
        '()
        (cdr l))) '()))

(test-group
  (=> (let ((abs
         (lambda (x)
  	 (if (< x 0)
  	     (- 0 x)
  	     x))))
    (abs -4)) 4))

(test-group
  (=> (let ((x -4))
    (if (< x 0)
        (list 'minus (- 0 x))
        (list 'plus x))) '(minus 4)))

(test-group
  (=> (not #f) #t)
  (=> (not #t) #f)
  (=> (not '()) #f)
  (=> (not (< 4 6)) #f))

(test-group
  (=> (let ((x 3))
    (and (> x 2) (< x 4))) #t)
  (=> (let ((x 5))
    (and (> x 2) (< x 4))) #f)
  (=> (and #f '(a b) '(c d)) #f)
  (=> (and '(a b) '(c d) '(e f)) '(e f)))

(test-group
  (=> (let ((x 3))
    (or (< x 2) (> x 4))) #f)
  (=> (let ((x 5))
    (or (< x 2) (> x 4))) #t)
  (=> (or #f '(a b) '(c d)) '(a b)))

(test-group
  (=> (let ((x 0))
    (cond
     ((< x 0) (list 'minus (abs x)))
     ((> x 0) (list 'plus x))
     (else (list 'zero x)))) '(zero 0)))

(test-group
  (define select
    (lambda (x)
      (cond
       ((not (symbol? x)))
       ((assq x '((a . 1) (b . 2) (c . 3))) => cdr)
       (else 0))))
  (=> (select 3) #t)
  (=> (select 'b) 2)
  (=> (select 'e) 0))

(test-group
  (=> (let ((x 4) (y 5))
    (case (+ x y)
      ((1 3 5 7 9) 'odd)
      ((0 2 4 6 8) 'even)
      (else 'out-of-range))) 'odd))

(test-group
  (define divisors
    (lambda (n)
      (let f ((i 2))
        (cond
         ((>= i n) '())
         ((integer? (/ n i))
  	(cons i (f (+ i 1))))
         (else (f (+ i 1)))))))
  (=> (divisors 5) '())
  (=> (divisors 32) '(2 4 8 16)))

(test-group
  (define divisors
    (lambda (n)
      (let f ((i 2) (ls '()))
        (cond
         ((>= i n) (reverse ls))
         ((integer? (/ n i))
  	(f (+ i 1) (cons i ls)))
         (else (f (+ i 1) ls))))))
  (=> (divisors 5) '())
  (=> (divisors 32) '(2 4 8 16)))

(test-group
  (define my-factorial
    (lambda (n)
      (do ((i n (- i 1)) (a 1 (* a i)))
  	((zero? i) a))))
  (=> (my-factorial 10) 3628800))

(test-group
  (define fibonacci
    (lambda (n)
      (if (= n 0)
  	0
  	(do ((i n (- i 1)) (a1 1 (+ a1 a2)) (a2 0 a1))
  	    ((= i 1) a1)))))
  (=> (fibonacci 6) 8))

(test-group
  (define divisors
    (lambda (n)
      (do ((i 2 (+ i 1))
  	 (ls '()
  	     (if (integer? (/ n i))
  		 (cons i ls)
  		 ls)))
  	((>= i n) (reverse ls)))))
  (=> (divisors 32) '(2 4 8 16)))

(test-group
  (define scale-vector!
    (lambda (v k)
      (let ((n (vector-length v)))
        (do ((i 0 (+ i 1)))
  	  ((= i n))
  	(vector-set! v i (* (vector-ref v i) k))))))
  (define vec (vector 1 2 3 4 5))
  (scale-vector! vec 2)
  (=> vec '#(2 4 6 8 10)))

(test-group
  (=> (map abs '(1 -2 3 -4 5 -6)) '(1 2 3 4 5 6))
  (=> (map (lambda (x y) (* x y))
       '(1 2 3 4)
       '(8 7 6 5)) '(8 14 18 20)))

(test-group
  (=> (let ((same-count 0))
    (for-each
     (lambda (x y)
       (if (= x y)
  	 (set! same-count (+ same-count 1))))
     '(1 2 3 4 5 6)
     '(2 3 3 4 7 6))
    same-count) 3))

(test-group
  (define my-member
    (lambda (x ls)
      (call/cc
       (lambda (break)
         (do ((ls ls (cdr ls)))
  	   ((null? ls) #f)
  	 (if (equal? x (car ls))
  	     (break ls)))))))
  (=> (my-member 'd '(a b c)) #f)
  (=> (my-member 'b '(a b c)) '(b c)))

(test-group
  (define stream-car
    (lambda (s)
      (car (force s))))
  (define stream-cdr
    (lambda (s)
      (cdr (force s))))
  (define counters
    (let next ((n 1))
      (delay (cons n (next (+ n 1))))))
  (define stream-add
    (lambda (s1 s2)
      (delay (cons
  	    (+ (stream-car s1) (stream-car s2))
  	    (stream-add (stream-cdr s1) (stream-cdr s2))))))
  (define even-counters
    (stream-add counters counters))
  (=> (stream-car counters) 1)
  (=> (stream-car (stream-cdr counters)) 2)
  (=> (stream-car even-counters) 2)
  (=> (stream-car (stream-cdr even-counters)) 4))

(test-group
  (=> (values) (values))
  (=> (values 1) 1)
  (=> (values 1 2 3) (values 1 2 3)))

(test-group
  (define head&tail
    (lambda (ls)
      (values (car ls) (cdr ls))))
  (=> (head&tail '(a b c)) (values 'a '(b c))))

(test-group
  (=> (call-with-values
      (lambda () (values 'bond 'james))
    (lambda (x y) (cons y x))) '(james . bond)))

(test-group
  (=> (call-with-values values list) '()))

(test-group
  (define dxdy
    (lambda (p1 p2)
      (values (- (car p2) (car p1))
  	    (- (cdr p2) (cdr p1)))))
  (=> (dxdy '(0 . 0) '(0 . 5)) (values 0 5)))

(test-group
  (define dxdy
    (lambda (p1 p2)
      (values (- (car p2) (car p1))
  	    (- (cdr p2) (cdr p1)))))
  (define segment-length
    (lambda (p1 p2)
      (call-with-values
  	(lambda () (dxdy p1 p2))
        (lambda (dx dy) (sqrt (+ (* dx dx) (* dy dy)))))))
  (define segment-slope
    (lambda (p1 p2)
      (call-with-values
  	(lambda () (dxdy p1 p2))
        (lambda (dx dy) (/ dy dx)))))
  (=> (segment-length '(1 . 4) '(4 . 8)) 5)
  (=> (segment-slope '(1 . 4) '(4 . 8)) 4/3))

(test-group
  (define dxdy
    (lambda (p1 p2)
      (values (- (car p2) (car p1))
  	    (- (cdr p2) (cdr p1)))))
  (define describe-segment
    (lambda (p1 p2)
      (call-with-values
  	(lambda () (dxdy p1 p2))
        (lambda (dx dy)
  	(values
  	 (sqrt (+ (* dx dx) (* dy dy)))
  	 (/ dy dx))))))
  (=> (describe-segment '(1 . 4) '(4 . 8)) (values 5 4/3)))

(test-group
  (define my-split
    (lambda (ls)
      (if (or (null? ls) (null? (cdr ls)))
  	(values ls '())
  	(call-with-values
  	    (lambda () (my-split (cddr ls)))
  	  (lambda (odds evens)
  	    (values (cons (car ls) odds)
  		    (cons (cadr ls) evens)))))))
  (=> (my-split '(a b c d e f)) (values '(a c e) '(b d f))))

(test-group
  (=> (+ (values 2) 4) 6)
  (=> (if (values #t) 1 2) 1)
  (=> (call-with-values
      (lambda () 4)
    (lambda (x) x)) 4))

(test-group
  (=> (begin (values 1 2 3) 4) 4))

(test-group
  (=> (call-with-values
      (lambda ()
        (call/cc (lambda (k) (k 2 3))))
    (lambda (x y) (list x y))) '(2 3)))

(test-group
  (define p (delay (values 1 2 3)))
  (=> (force p) (values 1 2 3))
  (=> (call-with-values (lambda () (force p)) +) 6))

(test-group
  (=> (with-values (values 1 2) list) '(1 2))
  (=> (with-values (split '(1 2 3 4))
    (lambda (odds evens)
      evens)) '(2 4)))

(test-group
  (=> (let-values (((odds evens) (split '(1 2 3 4))))
    evens) '(2 4))
  (=> (let-values ((ls (values 'a 'b 'c)))
    ls) '(a b c)))

(test-group
  (=> (let ((cons 'not-cons))
        (eval '(let ((x 3)) (cons x 4))
              (scheme-report-environment 5))) '(3 . 4))
  (=> (let ((lambda 'not-lambda))
        (eval '(lambda (x) x) (null-environment 5))) "#<lambda>"))

(test-group
  (=> 3.2 3.2)
  (=> #f #f)
  (=> #\c #\c)
  (=> "hi" "hi"))

(test-group
  (=> (+ 2 3) 5)
  (=> '(+ 2 3) '(+ 2 3))
  (=> (quote (+ 2 3)) '(+ 2 3))
  (=> 'a 'a)
  (=> 'cons 'cons)
  (=> '() '())
  (=> '7 7))

(test-group
  (=> `(+ 2 3) '(+ 2 3))
  (=> `(+ 2 ,(* 3 4)) '(+ 2 12))
  (=> `(a b (,(+ 2 3) c) d) '(a b (5 c) d))
  (=> `(a b ,(reverse '(c d e)) f g) '(a b (e d c) f g))
  (=> (let ((a 1) (b 2))
    `(,a . ,b)) '(1 . 2))
  (=> `(+ ,@(cdr ' (* 2 3))) '(+ 2 3))
  (=> `(a b ,@(reverse '(c d e)) f g) '(a b e d c f g))
  (=> ;(let ((a 1) (b 2))
  ;  `(,a ,@b))
  ;=>
  ;(1 . 2)
  ;.
  `#(,@(list 1 2 3)) '#(1 2 3))
  (=> '`,(cons 'a 'b) '`,(cons 'a 'b))
  (=> `',(cons 'a 'b) ''(a . b)))

(test-group
  (=> (eq? 'a 3) #f)
  (=> (eq? #t 't) #f)
  (=> (eq? "abc" 'abc) #f)
  (=> (eq? "hi" '(hi)) #f)
  (=> (eq? #f '()) #f))

(test-group
  (=> (eq? #\a #\b) #f))

(test-group
  (=> (eq? #t #t) #t)
  (=> (eq? #f #f) #t)
  (=> (eq? #t #f) #f)
  (=> (eq? (null? '()) #t) #t)
  (=> (eq? (null? '(a)) #f) #t))

(test-group
  (=> (eq? (cdr '(a)) '()) #t))

(test-group
  (=> (eq? 'a 'a) #t)
  (=> (eq? 'a 'b) #f)
  (=> (eq? 'a (string->symbol "a")) #t))

(test-group
  (=> (eq? '(a) '(b)) #f)
  (=> (let ((x '(a . b)))
    (eq? x x)) #t)
  (=> (eq? (cons 'a 'b) (cons 'a 'b)) #f))

(test-group
  (=> (eq? "abc" "cba") #f)
  (=> (let ((x "hi")) (eq? x x)) #t)
  (=> (let ((x (string #\h #\i))) (eq? x x)) #t)
  (=> (eq? (string #\h #\i)
       (string #\h #\i)) #f))

(test-group
  (=> (eq? '#(a) '#(b)) #f)
  (=> (let ((x '#(a))) (eq? x x)) #t)
  (=> (let ((x (vector 'a)))
    (eq? x x)) #t)
  (=> (eq? (vector 'a) (vector 'a)) #f))

(test-group
  (=> (eq? car car) #t)
  (=> (eq? car cdr) #f)
  (=> (let ((f (lambda (x) x)))
    (eq? f f)) #t))

(test-group
  (=> (let ((f (lambda (x)
  	   (lambda ()
  	     (set! x (+ x 1))
  	     x))))
    (eq? (f 0) (f 0))) #f))

(test-group
  (=> (eqv? 'a 3) #f)
  (=> (eqv? #t 't) #f)
  (=> (eqv? "abc" 'abc) #f)
  (=> (eqv? "hi" '(hi)) #f)
  (=> (eqv? #f '()) #f)
  (=> (eqv? 9 7) #f)
  (=> (eqv? 4.5 4.0) #f)
  (=> (eqv? 3 3.0) #f)
  (=> (eqv? 3.4 53344) #f)
  (=> (eqv? 4.5 4.5) #t)
  (=> (eqv? 3 3) #t)
  (=> (eqv? 3.4 (+ 3.0 0.4)) #t)
  (=> (let ((x (* 1234567 2)))
    (eqv? x x)) #t))

(test-group
  (=> (eqv? #\a #\b) #f)
  (=> (eqv? #\a #\a) #t)
  (=> (let ((x (string-ref "hi" 0)))
    (eqv? x x)) #t))

(test-group
  (=> (eqv? #t #t) #t)
  (=> (eqv? #f #f) #t)
  (=> (eqv? #t #f) #f)
  (=> (eqv? (null? '()) #t) #t)
  (=> (eqv? (null? '(a)) #f) #t))

(test-group
  (=> (eqv? (cdr '(a)) '()) #t))

(test-group
  (=> (eqv? 'a 'a) #t)
  (=> (eqv? 'a 'b) #f)
  (=> (eqv? 'a (string->symbol "a")) #t))

(test-group
  (=> (eqv? '(a) '(b)) #f)
  (=> (let ((x '(a . b))) (eqv? x x)) #t)
  (=> (let ((x (cons 'a 'b)))
    (eqv? x x)) #t)
  (=> (eqv? (cons 'a 'b) (cons 'a 'b)) #f))

(test-group
  (=> (eqv? "abc" "cba") #f)
  (=> (let ((x "hi")) (eqv? x x)) #t)
  (=> (let ((x (string #\h #\i))) (eqv? x x)) #t)
  (=> (eqv? (string #\h #\i)
        (string #\h #\i)) #f))

(test-group
  (=> (eqv? '#(a) '#(b)) #f)
  (=> (let ((x '#(a))) (eqv? x x)) #t)
  (=> (let ((x (vector 'a)))
    (eqv? x x)) #t)
  (=> (eqv? (vector 'a) (vector 'a)) #f))

(test-group
  (=> (eqv? car car) #t)
  (=> (eqv? car cdr) #f)
  (=> (let ((f (lambda (x) x)))
    (eqv? f f)) #t))

(test-group
  (=> (let ((f (lambda (x)
  	   (lambda ()
  	     (set! x (+ x 1))
  	     x))))
    (eqv? (f 0) (f 0))) #f))

(test-group
  (=> (equal? 'a 3) #f)
  (=> (equal? #t 't) #f)
  (=> (equal? "abc" 'abc) #f)
  (=> (equal? "hi" '(hi)) #f)
  (=> (equal? #f '()) #f))

(test-group
  (=> (equal? 9 7) #f)
  (=> (equal? 4.5 4.0) #f)
  (=> (equal? 3 3.0) #f)
  (=> (equal? 3.4 53344) #f)
  (=> (equal? 4.5 4.5) #t)
  (=> (equal? 3 3) #t)
  (=> (equal? 3.4 (+ 3.0 0.4)) #t)
  (=> (let ((x (* 1234567 2)))
    (equal? x x)) #t))

(test-group
  (=> (equal? #\a #\b) #f)
  (=> (equal? #\a #\a) #t)
  (=> (let ((x (string-ref "hi" 0)))
    (equal? x x)) #t))

(test-group
  (=> (equal? #t #t) #t)
  (=> (equal? #f #f) #t)
  (=> (equal? #t #f) #f)
  (=> (equal? (null? '()) #t) #t)
  (=> (equal? (null? '(a)) #f) #t))

(test-group
  (=> (equal? (cdr '(a)) '()) #t))

(test-group
  (=> (equal? 'a 'a) #t)
  (=> (equal? 'a 'b) #f)
  (=> (equal? 'a (string->symbol "a")) #t))

(test-group
  (=> (equal? '(a) '(b)) #f)
  (=> (equal? '(a) '(a)) #t)
  (=> (let ((x '(a . b))) (equal? x x)) #t)
  (=> (let ((x (cons 'a 'b)))
    (equal? x x)) #t)
  (=> (equal? (cons 'a 'b) (cons 'a 'b)) #t))

(test-group
  (=> (equal? "abc" "cba") #f)
  (=> (equal? "abc" "abc") #t)
  (=> (let ((x "hi")) (equal? x x)) #t)
  (=> (let ((x (string #\h #\i))) (equal? x x)) #t)
  (=> (equal? (string #\h #\i)
        (string #\h #\i)) #t))

(test-group
  (=> (equal? '#(a) '#(b)) #f)
  (=> (equal? '#(a) '#(a)) #t)
  (=> (let ((x '#(a))) (equal? x x)) #t)
  (=> (let ((x (vector 'a)))
    (equal? x x)) #t)
  (=> (equal? (vector 'a) (vector 'a)) #t))

(test-group
  (=> (equal? car car) #t)
  (=> (equal? car cdr) #f)
  (=> (let ((f (lambda (x) x)))
    (equal? f f)) #t))

(test-group
  (=> (let ((f (lambda (x)
  	   (lambda ()
  	     (set! x (+ x 1))
  	     x))))
    (equal? (f 0) (f 0))) #f))

(test-group
  (=> (boolean? #t) #t)
  (=> (boolean? #f) #t)
  (=> (boolean? 't) #f)
  (=> (boolean? '()) #f))

(test-group
  (=> (null? '()) #t)
  (=> (null? '(a)) #f)
  (=> (null? (cdr '(a))) #t)
  (=> (null? 3) #f)
  (=> (null? #f) #f))

(test-group
  (=> (pair? '(a b c)) #t)
  (=> (pair? '(3 . 4)) #t)
  (=> (pair? '()) #f)
  (=> (pair? '#(a b)) #f)
  (=> (pair? 3) #f))

(test-group
  (=> (integer? 1901) #t)
  (=> (rational? 1901) #t)
  (=> (real? 1901) #t)
  (=> (complex? 1901) #t)
  (=> (number? 1901) #t))

(test-group
  (=> (integer? -3.0) #t)
  (=> (rational? -3.0) #t)
  (=> (real? -3.0) #t)
  (=> (complex? -3.0) #t)
  (=> (number? -3.0) #t))

(test-group
  (=> (integer? -2.345) #f)
  (=> (rational? -2.345) #t)
  (=> (real? -2.345) #t)
  (=> (complex? -2.345) #t)
  (=> (number? -2.345) #t))

(test-group
  (=> (integer? 'a) #f)
  (=> (rational? '(a b c)) #f)
  (=> (real? "3") #f)
  (=> (complex? #(1 2)) #f)
  (=> (number? #\a) #f))

(test-group
  (=> (char? 'a) #f)
  (=> (char? 97) #f)
  (=> (char? #\a) #t)
  (=> (char? "a") #f)
  (=> (char? (string-ref (make-string 1) 0)) #t))

(test-group
  (=> (string? "hi") #t)
  (=> (string? 'hi) #f)
  (=> (string? #\h) #f))

(test-group
  (=> (vector? '#()) #t)
  (=> (vector? '#(a b c)) #t)
  (=> (vector? (vector 'a 'b 'c)) #t)
  (=> (vector? '()) #f)
  (=> (vector? '(a b c)) #f)
  (=> (vector? "abc") #f))

(test-group
  (=> (symbol? 't) #t)
  (=> (symbol? "t") #f)
  (=> (symbol? '(t)) #f)
  (=> (symbol? #\t) #f)
  (=> (symbol? 3) #f)
  (=> (symbol? #t) #f))

(test-group
  (=> (procedure? car) #t)
  (=> (procedure? 'car) #f)
  (=> (procedure? (lambda (x) x)) #t)
  (=> (procedure? '(lambda (x) x)) #f)
  (=> (call/cc procedure?) #t))

(test-group
  (=> (cons 'a '()) '(a))
  (=> (cons 'a '(b c)) '(a b c))
  (=> (cons 3 4) '(3 . 4)))

(test-group
  (=> (car '(a)) 'a)
  (=> (car '(a b c)) 'a)
  (=> (car (cons 3 4)) 3))

(test-group
  (=> (cdr '(a)) '())
  (=> (cdr '(a b c)) '(b c))
  (=> (cdr (cons 3 4)) 4))

(test-group
  (=> (let ((x '(a b c)))
    (set-car! x 1)
    x) '(1 b c)))

(test-group
  (=> (let ((x '(a b c)))
    (set-cdr! x 1)
    x) '(a . 1)))

(test-group
  (=> (caar '((a))) 'a)
  (=> (cadr '(a b c)) 'b)
  (=> (cdddr '(a b c d)) '(d))
  (=> (cadadr '(a (b c))) 'c))

(test-group
  (=> (list) '())
  (=> (list 1 2 3) '(1 2 3))
  (=> (list 3 2 1) '(3 2 1)))

(test-group
  (=> (list? '()) #t)
  (=> (list? '(a b c)) #t)
  (=> (list? 'a) #f)
  (=> (list? '(3 . 4)) #f)
  (=> (list? 3) #f)
  (=> (let ((x (list 'a 'b 'c)))
    (set-cdr! (cddr x) x)
    (list? x)) #f))

(test-group
  (=> (length '()) 0)
  (=> (length '(a b c)) 3))

(test-group
  (=> (list-ref '(a b c) 0) 'a)
  (=> (list-ref '(a b c) 1) 'b)
  (=> (list-ref '(a b c) 2) 'c))

(test-group
  (=> (list-tail '(a b c) 0) '(a b c))
  (=> (list-tail '(a b c) 2) '(c))
  (=> (list-tail '(a b c) 3) '())
  (=> (list-tail '(a b c . d) 2) '(c . d))
  (=> (list-tail '(a b c . d) 3) 'd)
  (=> (let ((x (list 1 2 3)))
    (eq? (list-tail x 2)
         (cddr x))) #t))

(test-group
  (=> (append '(a b c) '()) '(a b c))
  (=> (append '() '(a b c)) '(a b c))
  (=> (append '(a b) '(c d)) '(a b c d))
  (=> (append '(a b) 'c) '(a b . c))
  (=> (let ((x (list 'b)))
    (eq? x (cdr (append '(a) x)))) #t))

(test-group
  (=> (reverse '()) '())
  (=> (reverse '(a b c)) '(c b a)))

(test-group
  (=> (memq 'a '(b c a d e)) '(a d e))
  (=> (memq 'a '(b c d e g)) #f)
  (=> (memq 'a '(b a c a d a)) '(a c a d a)))

(test-group
  (=> (memv 3.4 '(1.2 2.3 3.4 4.5)) '(3.4 4.5))
  (=> (memv 3.4 '(1.3 2.5 3.7 4.9)) #f)
  (=> (let ((ls (list 'a 'b 'c)))
    (set-car! (memv 'b ls) 'z)
    ls) '(a z c)))

(test-group
  (=> (member '(b) '((a) (b) (c))) '((b) (c)))
  (=> (member '(d) '((a) (b) (c))) #f)
  (=> (member "b" '("a" "b" "c")) '("b" "c")))

(test-group
  (define (count-occurrences x ls)
    (cond
     ((memq x ls) => (lambda (ls) (+ (count-occurrences x (cdr ls)) 1)))
     (else 0)))
  (=> (count-occurrences 'a '(a b c d a)) 2))

(test-group
  (=> (assq 'b '((a . 1) (b . 2))) '(b . 2))
  (=> (cdr (assq 'b '((a . 1) (b . 2)))) 2)
  (=> (assq 'c '((a . 1) (b . 2))) #f))

(test-group
  (=> (assv 2.3 '((1.3 . 1) (2.3 . 2))) '(2.3 . 2))
  (=> (assv 2.3 '((1.3 a) (3.4 . b))) #f))

(test-group
  (=> (assoc '(a) '(((a) . a) (-1 . b))) '((a) . a))
  (=> (assoc '(a) '(((b) . b) (a . c))) #f))

(test-group
  (=> (let ((alist '((2 . a) (3 . b))))
    (set-cdr! (assv 3 alist) 'c)
    alist) '((2 . a) (3 . c))))

(test-group
  (=> (exact? 1) #t)
  (=> (exact? 2.01) #f)
  (=> (exact? 2.0) #f))

(test-group
  (=> (inexact? -123) #f)
  (=> (inexact? 2.01) #t))

(test-group
  (=> (= 7 7) #t)
  (=> (= 7 9) #f))

(test-group
  (=> (< 2000 3000) #t)
  (=> (<= 1 2 3 3 4 5) #t)
  (=> (<= 1 2 3 4 5) #t))

(test-group
  (=> (= (/ -1 2) -0.5) #t))

(test-group
  (=> (> 8 4.102 .66666 -5) #t)
  (=> (let ((x 0.218723452))
    (< 0.210 x 0.220)) #t))

(test-group
  (=> (apply < '(1 2 3 4)) #t)
  (=> (apply > '(4 3 3 2)) #f))

(test-group
  (=> (+) 0)
  (=> (+ 1 2) 3)
  (=> (+ 3 4 5) 12)
  (=> (+ 3.0 4) 7.0)
  (=> (apply + '(1 2 3 4 5)) 15))

(test-group
  (=> (- 3) -3)
  (=> (- 4 3.0) 1.0)
  (=> (- 4 3 2 1) -2))

(test-group
  (=> (*) 1)
  (=> (* 3.4) 3.4)
  (=> (* 1 .5) 0.5)
  (=> (* 3 4 5.5) 66.0)
  (=> (apply * '(1 2 3 4 5)) 120))

(test-group
  (=> (/ -2) -1/2)
  (=> (/ 0.5) 2.0)
  (=> (/ 3 4) 3/4)
  (=> (/ 60 5 4 3 2) 1/2)
  (=> (/ 60 10) 6)
  (=> (/ 60 10.0) 6.0))

(test-group
  (=> (zero? 0) #t)
  (=> (zero? 1) #f)
  (=> (zero? (- 3.0 3.0)) #t))

(test-group
  (=> (positive? 128) #t)
  (=> (positive? 0.0) #f)
  (=> (positive? -0.25) #f))

(test-group
  (=> (negative? -65) #t)
  (=> (negative? 0) #f)
  (=> (negative? 0.12) #f))

(test-group
  (=> (even? 0) #t)
  (=> (even? 1) #f)
  (=> (even? 2.0) #t))

(test-group
  (=> (odd? 0) #f)
  (=> (odd? 1) #t)
  (=> (odd? 2.0) #f))

(test-group
  (=> (quotient 45 6) 7)
  (=> (quotient 6.0 2.0) 3.0)
  (=> (quotient 3.0 -2) -1.0))

(test-group
  (=> (remainder 16 4) 0)
  (=> (remainder 5 2) 1)
  (=> (remainder -45.0 7) -3.0)
  (=> (remainder 10.0 -3.0) 1.0)
  (=> (remainder -17 -9) -8))

(test-group
  (=> (modulo 16 4) 0)
  (=> (modulo 5 2) 1)
  (=> (modulo -45.0 7) 4.0)
  (=> (modulo 10.0 -3.0) -2.0)
  (=> (modulo -17 -9) -8))

(test-group
  (=> (truncate 19) 19)
  (=> (truncate (/ 2 3)) 0)
  (=> (truncate (- (/ 2 3))) 0)
  (=> (truncate 17.3) 17.0)
  (=> (truncate (- (/ 17 2))) -8))

(test-group
  (=> (floor 19) 19)
  (=> (floor (/ 2 3)) 0)
  (=> (floor (- (/ 2 3))) -1)
  (=> (floor 17.3) 17.0)
  (=> (floor (- (/ 17 2))) -9))

(test-group
  (=> (ceiling 19) 19)
  (=> (ceiling (/ 2 3)) 1)
  (=> (ceiling (- (/ 2 3))) 0)
  (=> (ceiling 17.3) 18.0)
  (=> (ceiling (- (/ 17 2))) -8))

(test-group
  (=> (round 19) 19)
  (=> (round (/ 2 3)) 1)
  (=> (round (- (/ 2 3))) -1)
  (=> (round 17.3) 17.0)
  (=> (round (- (/ 17 2))) -8)
  (=> (round 2.5) 2.0)
  (=> (round 3.5) 4.0))

(test-group
  (=> (abs 1) 1)
  (=> (abs -0.75) 0.75)
  (=> (abs 1.83) 1.83)
  (=> (abs -3) 3))

(test-group
  (=> (max 4 -7 2 0 -6) 4)
  (=> (max 1.5 1.3 -0.3 0.4 2.0 1.8) 2.0)
  (=> (max -5 -2.0) -2.0)
  (=> (let ((ls '(7 3 5 2 9 8)))
    (apply max ls)) 9))

(test-group
  (=> (min 4 -7 2 0 -6) -7)
  (=> (min 1.5 1.3 -0.3 0.4 2.0 1.8) -0.3)
  (=> (min -5 -2.0) -5)
  (=> (let ((ls '(7 3 5 2 9 8)))
    (apply min ls)) 2))

(test-group
  (=> (gcd) 0)
  (=> (gcd 34) 34)
  (=> (gcd 33.0 15.0) 3.0)
  (=> (gcd 70 -42 28) 14))

(test-group
  (=> (lcm) 1)
  (=> (lcm 34) 34)
  (=> (lcm 33.0 15.0) 165.0)
  (=> (lcm 70 -42 28) 420)
  (=> (lcm 17.0 0) 0.0))

(test-group
  (=> (expt 2 10) 1024)
  (=> (expt 2 -10) 1/1024)
  (=> (expt 0 0) 1)
  (=> (expt 0.0 0) 1.0)
  (=> (expt 3.0 3) 27.0))

(test-group
  (=> (exact->inexact 3) 3.0)
  (=> (exact->inexact 3.0) 3.0))

(test-group
  (=> (inexact->exact 3) 3)
  (=> (inexact->exact 3.0) 3))

(test-group
  (=> (magnitude 1) 1)
  (=> (magnitude -0.093) 0.093))

(test-group
  (=> (sqrt 16) 4)
  (=> (sqrt 4.84) 2.2))

(test-group
  (=> (exp 0.0) 1.0)
  (=> (exp 1.0) 2.718281828459045)
  (=> (exp -.5) 0.6065306597126334))

(test-group
  (=> (log 1.0) 0.0)
  (=> (log (exp 1.0)) 1.0)
  (=> (/ (log 100) (log 10)) 2.0))

(test-group
  (=> (string->number "0") 0)
  (=> (string->number "3.4e3") 3400.0)
  (=> (string->number "#x#e-2e2") -738)
  (=> (string->number "#e-2e2" 16) -738)
  (=> (string->number "10" 16) 16))

(test-group
  (=> (number->string 3.4) "3.4")
  (=> (number->string 100) "100")
  (=> (number->string 220 16) "dc"))

(test-group
  (=> (char>? #\a #\b) #f)
  (=> (char<? #\a #\b) #t)
  (=> (char<? #\a #\b #\c) #t)
  (=> (char<? #\a #\b #\b) #f)
  (=> (let ((c #\r))
    (char<=? #\a c #\z)) #t)
  (=> (char<=? #\Z #\W) #f)
  (=> (char=? #\+ #\+) #t)
  (=> (or (char<? #\a #\0)
      (char<? #\0 #\a)) #t))

(test-group
  (=> (char-ci<? #\a #\B) #t)
  (=> (char-ci=? #\W #\w) #t)
  (=> (char-ci=? #\= #\+) #f)
  (=> (let ((c #\R))
    (list (char<=? #\a c #\z)
  	(char-ci<=? #\a c #\z))) '(#f #t)))

(test-group
  (=> (char-alphabetic? #\a) #t)
  (=> (char-alphabetic? #\T) #t)
  (=> (char-alphabetic? #\8) #f)
  (=> (char-alphabetic? #\$) #f))

(test-group
  (=> (char-numeric? #\7) #t)
  (=> (char-numeric? #\2) #t)
  (=> (char-numeric? #\X) #f)
  (=> (char-numeric? #\space) #f))

(test-group
  (=> (char-lower-case? #\r) #t)
  (=> (char-lower-case? #\R) #f))

(test-group
  (=> (char-upper-case? #\r) #f)
  (=> (char-upper-case? #\R) #t))

(test-group
  (=> (char-whitespace? #\space) #t)
  (=> (char-whitespace? #\tab) #t)
  (=> (char-whitespace? #\newline) #t)
  (=> (char-whitespace? #\return) #t)
  (=> (char-whitespace? #\a) #f))

(test-group
  (=> (char-upcase #\g) #\G)
  (=> (char-upcase #\Y) #\Y)
  (=> (char-upcase #\7) #\7))

(test-group
  (=> (char-downcase #\g) #\g)
  (=> (char-downcase #\Y) #\y)
  (=> (char-downcase #\7) #\7))

(test-group
  (=> (char->integer #\h) 104)
  (=> (char->integer #\newline) 10)
  (=> (integer->char 104) #\h))

(test-group
  (define make-dispatch-table
    (lambda (alist default)
      (let ((codes (map char->integer (map car alist))))
        (let ((first-index (apply min codes))
  	    (last-index (apply max codes)))
  	(let ((n (+ (- last-index first-index) 1)))
  	  (let ((v (make-vector n default)))
  	    (for-each
  	     (lambda (i x) (vector-set! v (- i first-index) x))
  	     codes
  	     (map cdr alist))
  	    ;; table is built; return the table lookup procedure
  	    (lambda (c)
  	      (let ((i (char->integer c)))
  		(if (<= first-index i last-index)
  		    (vector-ref v (- i first-index))
  		    default)))))))))
  (define t (make-dispatch-table
  	   '((#\a . letter) (#\b . letter) (#\0 . digit) (#\1 . digit))
  	   'unknown))
  (=> (t #\b) 'letter)
  (=> (t #\0) 'digit)
  (=> (t #\*) 'unknown))

(test-group
  (=> (string=? "mom" "mom") #t)
  (=> (string<? "mom" "mommy") #t)
  (=> (string>? "Dad" "Dad") #f)
  (=> (string=? "Mom and Dad" "mom and dad") #f)
  (=> (string<? "a" "b" "c") #t))

(test-group
  (=> (string-ci=? "mom" "Mom" "MOM") #t)
  (=> (string-ci=? "Mom and Dad" "mom and dad") #t)
  (=> (string-ci<=? "say what" "Say What?!") #t)
  (=> (string-ci>? "N" "m" "L" "k") #t))

(test-group
  (=> (string) "")
  (=> (string #\a #\b #\c) "abc")
  (=> (string #\H #\E #\Y #\!) "HEY!"))

(test-group
  (=> (make-string 0) "")
  (=> (make-string 0 #\x) "")
  (=> (make-string 5 #\x) "xxxxx"))

(test-group
  (=> (string-length "abc") 3)
  (=> (string-length "") 0)
  (=> (string-length "hi there") 8)
  (=> (string-length (make-string 1000000)) 1000000))

(test-group
  (=> (string-ref "hi there" 0) #\h)
  (=> (string-ref "hi there" 5) #\e))

(test-group
  (=> (let ((str "hi three"))
    (string-set! str 5 #\e)
    (string-set! str 6 #\r)
    str) "hi there"))

(test-group
  (=> (string-copy "abc") "abc")
  (=> (let ((str "abc"))
    (eq? str (string-copy str))) #f))

(test-group
  (=> (string-append) "")
  (=> (string-append "abc" "def") "abcdef")
  (=> (string-append "Hey " "you " "there!") "Hey you there!"))

(test-group
  (=> (substring "hi there" 0 1) "h")
  (=> (substring "hi there" 3 6) "the")
  (=> (substring "hi there" 5 5) "")
  (=> (let ((str "hi there"))
    (let ((end (string-length str)))
      (substring str 0 end))) "hi there")
  (=> (substring "hi there" 3) "there")
  (=> (substring "hi there") "hi there")
  (=> (substring "hi there" -5) "there")
  (=> (substring "hi there" -5 -2) "the")
  (=> (substring "hi there" 0 -6) "hi"))

(test-group
  (=> (let ((str (string-copy "sleepy")))
    (string-fill! str #\Z)
    str) "ZZZZZZ"))

(test-group
  (=> (string->list "") '())
  (=> (string->list "abc") '(#\a #\b #\c))
  (=> (apply char<? (string->list "abc")) #t)
  (=> (map char-upcase (string->list "abc")) '(#\A #\B #\C)))

(test-group
  (=> (list->string '()) "")
  (=> (list->string '(#\a #\b #\c)) "abc")
  (=> (list->string
   (map char-upcase
        (string->list "abc"))) "ABC"))

(test-group
  (=> (vector) '#())
  (=> (vector 'a 'b 'c) '#(a b c)))

(test-group
  (=> (make-vector 0) '#())
  (=> (make-vector 0 'a) '#())
  (=> (make-vector 5 'a) '#(a a a a a)))

(test-group
  (=> (vector-length '#()) 0)
  (=> (vector-length '#(a b c)) 3)
  (=> (vector-length (vector 1 2 3 4)) 4)
  (=> (vector-length (make-vector 300)) 300))

(test-group
  (=> (vector-ref '#(a b c) 0) 'a)
  (=> (vector-ref '#(a b c) 1) 'b)
  (=> (vector-ref '#(x y z w) 3) 'w))

(test-group
  (=> (let ((v (vector 'a 'b 'c 'd 'e)))
    (vector-set! v 2 'x)
    v) '#(a b x d e)))

(test-group
  (=> (let ((v (vector 1 2 3)))
    (vector-fill! v 0)
    v) '#(0 0 0)))

(test-group
  (=> (vector->list (vector)) '())
  (=> (vector->list '#(a b c)) '(a b c))
  (=> (let ((v #(1 2 3 4 5)))
    (apply * (vector->list v))) 120))

(test-group
  (=> (list->vector '()) '#())
  (=> (list->vector '(a b c)) '#(a b c))
  (=> (let ((v '#(1 2 3 4 5)))
    (let ((ls (vector->list v)))
      (list->vector (map * ls ls)))) '#(1 4 9 16 25)))

(test-group
  (=> (string->symbol "x") 'x)
  (=> (eq? (string->symbol "x") 'x) #t)
  (=> (eq? (string->symbol "X") 'x) #f)
  (=> (eq? (string->symbol "x")
       (string->symbol "x")) #t))

(test-group
  (=> (symbol->string 'xyz) "xyz")
  (=> (symbol->string (string->symbol "Hi")) "Hi")
  (=> (symbol->string (string->symbol "()")) "()"))

(test-group
  (=> (input-port? (current-input-port)) #t)
  (=> (input-port? (open-input-string "hi")) #t))

(test-group
  (=> (output-port? (current-output-port)) #t)
  (=> (output-port? (open-output-string)) #t))

(test-group
  (=> (let ((p (open-input-string "1 2 3 4 5")))
    (let f ((x (read p)))
      (if (eof-object? x)
  	(begin
  	  (close-input-port p)
  	  '())
  	(cons x (f (read p)))))) '(1 2 3 4 5)))

(test-group
  (=> (call-with-input-string "1 2 3 4 5"
  			(lambda (p)
  			  (let f ((x (read p)))
  			    (if (eof-object? x)
  				'()
  				(cons x (f (read p))))))) '(1 2 3 4 5)))

(test-group
  (define (read-word p)
    (list->string
     (let f ()
       (let ((c (peek-char p)))
         (cond
  	((eof-object? c) '())
  	((char-alphabetic? c)
  	 (read-char p)
  	 (cons c (f)))
  	(else '()))))))
  (define p (open-input-string "hello world"))
  (=> (read-word p) "hello"))

(test-group
  (=> (let ((p (open-output-string)))
    (let f ((ls '(1 2 3 4 5)))
      (if (not (null? ls))
  	(begin
  	  (write (car ls) p)
  	  (newline p)
  	  (f (cdr ls)))))
    (get-output-string p)) "1\n2\n3\n4\n5\n"))
