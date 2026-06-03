(import (scheme base) (scheme read) (scheme write) (scheme char) (scheme inexact)
        (scheme file) (scheme process-context) (scheme time)
        (scm core) (scm io) (scm fs) (srfi 1) (scm list) (scm string) (srfi 13) (scm compile) (scm macro)
        (scm macro) (scm math) (scm doc) (srfi 8))

(test-group
  (=> (factorial 10) 3628800))

(test-group
  (=> (/ 4) 1/4)
  (=> (/ 1 4) 1/4)
  (=> (/ 4 1) 4)
  (=> (/ 4 1.0) 4.0)
  (=> (/ 4 2) 2)
  (=> (/ 4.0 2) 2.0))

(test-group
  (=> (let* ((a 2) (b (+ a 2)))
    b) 4))

(test-group
  (=> (let ((x 4) (y 5))
    (case (+ x y)
      ((1 3 5 7 9) 'odd)
      ((0 2 4 6 8) 'even)
      (else 'out-of-range))) 'odd))

(test-group
  (=> (append '(a) '() '(b c)) '(a b c)))

(test-group
  (define fact
    (lambda (n)
      (do ((i n (- i 1)) (a 1 (* a i)))
  	((zero? i) a))))
  (=> (fact 10) 3628800))

(test-group
  (=> (letrec* ((a 12) (b (+ 2 a)))
    (+ a b)) 26))

(test-group
  (=> (letrec* ((odd? (lambda (n) (if (= n 0) #f (not (odd? (- n 1))))))
  	  (even? (lambda (n) (not (odd? n)))))
    (even? 4)) #t))

(test-group
  (=> (apply + 1 2 3 '(4 5)) 15)
  (=> (apply (lambda (x y) (+ (* x x) (* y y))) '(3 4)) 25))

(test-group
  (=> (call-with-values
      (lambda () (values 1 2 3))
    (lambda (x y z) (list x y z))) '(1 2 3)))

(test-group
  (=> (receive (a b) (values 1 2)
    (list a b)) '(1 2)))

(test-group
  (=> (sqrt 25) 5)
  (=> (sqrt 9) 3)
  (=> (sqrt 9.0) 3.0))

(test-group
  (=> (let ((x 2))
    (cond
     ((assq x '((1 . 1) (2 . 4) (3 . 9))) => cdr))) 4))

(test-group
  (=> (let ((a 'a) (b 'b) (x 'x) (y 'y))
    (let-values (((a b) (values x y))
  	       ((x y) (values a b)))
      (list a b x y))) '(x y a b)))

(test-group
  (=> (let ((a 'a) (b 'b) (x 'x) (y 'y))
    (let*-values (((a b) (values x y))
  	       ((x y) (values a b)))
      (list a b x y))) '(x y x y)))

(test-group
  (=> (string-join '("foo" "bar" "baz") ":") "foo:bar:baz")
  (=> (string-join '("foo" "bar" "baz") ":" 'suffix) "foo:bar:baz:")
  (=> (string-join '()   ":") "")
  (=> (string-join '("") ":") "")
  (=> (string-join '()   ":" 'suffix) "")
  (=> (string-join '("") ":" 'suffix) ":"))

(test-group
  (=> (string-join '("a" "b" "c") "-" 'prefix) "-a-b-c")
  (=> (string-join '("a" "b" "c") "-" 'infix) "a-b-c")
  (=> (string-join '("a" "b" "c") "-" 'suffix) "a-b-c-")
  (=> (string-join '("a") "-" 'prefix) "-a")
  (=> (string-join '("a") "-" 'infix) "a")
  (=> (string-join '("a") "-" 'suffix) "a-"))

(test-group
  (=> (string-split "a b c") '("a" "b" "c"))
  (=> (string-split "a b\t c\n\rd") '("a" "b" "c" "d"))
  (=> (string-split "31.12.2016" "[.]") '("31" "12" "2016")))

(test-group
  (=> ; string-matches
  (string-matches "hello" "xyz") #f)
  (=> (string-matches "hello" "hel+o") '("hello"))
  (=> (string-matches "abc123" "([a-z]+)([0-9]+)") '("abc123" "abc" "123"))
  (=> (string-matches "abc123" "[a-z]+([0-9]+)") '("abc123" "123"))
  (=> (string-matches "  hello  " "hello") '("hello"))
  (=> (string-matches "2024-03-15" "([0-9]+)-([0-9]+)-([0-9]+)") '("2024-03-15" "2024" "03" "15")))

(test-group
  (=> ; string-replace-all-regex
  (string-replace-all-regex "hello world" "o" "0") "hell0 w0rld")
  (=> (string-replace-all-regex "abc123def456" "[0-9]+" "#") "abc#def#")
  (=> (string-replace-all-regex "2024-01-31" "([0-9]+)-([0-9]+)-([0-9]+)" "~3.~2.~1") "31.01.2024")
  (=> (string-replace-all-regex "John Smith" "([a-z]+) ([a-z]+)" "~2 ~1") "John Smith")
  (=> (string-replace-all-regex "John Smith" "([A-Za-z]+) ([A-Za-z]+)" "~2, ~1") "Smith, John")
  (=> (string-replace-all-regex "a-b" "(a)-(b)" "~1~~~2") "a~b")
  (=> (string-replace-all-regex "no match here" "xyz" "Q") "no match here"))

(test-group
  (=> (string-split-vector "a b c") '#("a" "b" "c")))

(test-group
  (=> (string-take "Pete Szilagyi" 6) "Pete S")
  (=> (string-drop "Pete Szilagyi" 6) "zilagyi"))

(test-group
  (=> (string-take-right "Beta rules" 5) "rules")
  (=> (string-drop-right "Beta rules" 5) "Beta "))

(test-group
  (=> (string-skip "  abc  " char-whitespace?) 2)
  (=> (string-skip-right "  abc  " char-whitespace?) 4))

(test-group
  (=> (string-index "  abca  " #\a) 2)
  (=> (string-index-right "  abca  " #\a) 5))

(test-group
  (=> (string-trim "  The outlook wasn't brilliant,  \n\r") "The outlook wasn't brilliant,  \n\r")
  (=> (string-trim-right "  The outlook wasn't brilliant,  \n\r") "  The outlook wasn't brilliant,")
  (=> (string-trim-both "  The outlook wasn't brilliant,  \n\r") "The outlook wasn't brilliant,"))

(test-group
  (=> (zip-alist '(1 2 3) '(a b c)) '((1 . a) (2 . b) (3 . c))))

(test-group
  (=> (string-suffix? "c" "abc") #t)
  (=> (string-suffix? "d" "abc") #f)
  (=> (string-suffix? "abc" "abc") #t)
  (=> (string-suffix? "abd" "abc") #f)
  (=> (string-suffix? "dbc" "abc") #f)
  (=> (string-suffix? "xabc" "abc") #f)
  (=> (string-suffix? "a" "") #f)
  (=> (string-suffix? "" "") #t))

(test-group
  (=> (string-prefix? "a" "abc") #t)
  (=> (string-prefix? "d" "abc") #f)
  (=> (string-prefix? "abc" "abc") #t)
  (=> (string-prefix? "dbc" "abc") #f)
  (=> (string-prefix? "abd" "abc") #f)
  (=> (string-prefix? "abcx" "abc") #f)
  (=> (string-prefix? "a" "") #f)
  (=> (string-prefix? "" "") #t))

(test-group
  ;; macroexpand uses the Dybvig Expander for full expansion
  (=> (macroexpand 'x) 'x)
  (=> (macroexpand '(+ 1 2)) '(+ 1 2))
  (=> (macroexpand '(not-a-macro a b)) '(not-a-macro a b))
  (=> (macroexpand '(and 1 2 3)) '(if 1 (if 2 3 #f) #f))
  (=> (macroexpand '(or 1 2)) '(let ((t 1)) (if t t 2))))

(test-group
  (=> ; pretty-print
  (call-with-output-string (lambda (p) (pretty-print 42 p))) "42\n")
  (=> (call-with-output-string (lambda (p) (pretty-print '(+ 1 2) p))) "(+ 1 2)\n")
  (=> (call-with-output-string
    (lambda (p)
      (pretty-print
        '(let ((first-variable 100) (second-variable 200) (third-variable 300))
           (do-something first-variable second-variable third-variable))
        p))) "(let ((first-variable 100) (second-variable 200) (third-variable 300))\n  (do-something first-variable second-variable third-variable))\n"))

(test-group
  (=> ; doc system tests
  (string? (procedure-doc car)) #t)
  (=> (string? (procedure-doc map)) #t)
  (=> (number? (string-contains (procedure-doc car) "Syntax:")) #t)
  (=> (number? (string-contains (procedure-doc map) "Library:")) #t)
  (define (f x) "doc here" (* x 2))
  (=> (f 5) 10)
  (=> (procedure-doc f) "doc here")
  (=> (procedure-doc 42) #f))

(test-group
  (=> ;;; list utilities
  
  (find even? '(3 1 4 1 5 9)) 4)
  (=> (find even? '(3 1 5 1 5 9)) #f))

(test-group
  (=> (every even? '(3 1 4 1 5 9)) #f)
  (=> (every even? '(2 4 14)) #t)
  (=> (every (lambda (n) (and (even? n) n))
  	 '(2 4 14)) 14)
  (=> (every < '(1 2 3) '(2 3 4)) #t)
  (=> (every < '(1 2 4) '(2 3 4)) #f))

(test-group
  (=> (any even? '(3 1 4 1 5 9)) #t)
  (=> (any even? '(3 1 1 5 9)) #f)
  (=> (any (lambda (n) (and (even? n) n)) '(2 1 4 14)) 2)
  (=> (any < '(1 2 4) '(2 3 4)) #t)
  (=> (any > '(1 2 3) '(2 3 4)) #f))

(test-group
  (=> (filter even? '(3 1 4 1 5 9 2 6)) '(4 2 6))
  (=> (partition even? '(3 1 4 1 5 9 2 6)) (values '(4 2 6) '(3 1 1 5 9))))

(test-group
  (=> (fold + 0 '(1 2 3 4 5)) 15)
  (=> (fold (lambda (e a) (cons e a)) '() '(1 2 3 4 5)) '(5 4 3 2 1))
  (=> (fold (lambda (x count)
  	     (if (odd? x) (+ count 1) count))
  	   0
  	   '(3 1 4 1 5 9 2 6 5 3)) 7)
  (=> (fold (lambda (s max-len)
  	     (max max-len (string-length s)))
  	   0
  	   '("longest" "long" "longer")) 7)
  (=> (fold (lambda (e a) (cons a e)) '(q) '(a b c)) '((((q) . a) . b) . c))
  (=> (fold + 0 '(1 2 3) '(4 5 6)) 21))

(test-group
  (=> (fold-right + 0 '(1 2 3 4 5)) 15)
  (=> (fold-right cons '() '(1 2 3 4 5)) '(1 2 3 4 5))
  (=> (fold-right (lambda (x l)
  	      (if (odd? x) (cons x l) l))
  	    '()
  	    '(3 1 4 1 5 9 2 6 5)) '(3 1 1 5 9 5))
  (=> (fold-right cons '(q) '(a b c)) '(a b c q))
  (=> (fold-right + 0 '(1 2 3) '(4 5 6)) 21))

(test-group
  (=> (read (open-input-string "#'x")) '(syntax x))
  (=> (read (open-input-string "#`x")) '(quasisyntax x))
  (=> (read (open-input-string "#,x")) '(unsyntax x))
  (=> (read (open-input-string "#,@x")) '(unsyntax-splicing x)))

;; shebang line (#!/) treated as line comment
(test-group
  (=> (read (open-input-string "#!/usr/bin/env scm\nabc")) 'abc))

;; get-property
(test-group
  (=> (get-property '((x 1) (y 2)) 'x) 1)
  (=> (get-property '((x 1) (y 2)) 'y) 2)
  (=> (get-property '((x 1) (y 2)) 'z) #f)
  (=> (get-property '((x 1) (y 2)) 'z 'missing) 'missing)
  (=> (get-property '((x 1) (y 2)) 'x 'missing) 1)
  (=> (get-property '() 'a) #f)
  (=> (get-property '() 'a #f) #f)
  (=> (get-property '() 'a 'missing) 'missing)
  (=> (get-property '(foo bar) 'foo) 'foo)
  (=> (get-property '(foo bar) 'baz) #f)
  (=> (get-property '(foo bar) 'baz 'none) 'none)
  (=> (get-property '(foo (x 1) bar (y 2)) 'x) 1)
  (=> (get-property '(foo (x 1) bar (y 2)) 'bar) 'bar)
  (=> (get-property '((a 1) (b 2) (a 3)) 'a) 1))

;; get-property-list
(test-group
  (=> (get-property-list '((x 1 2) (y 3)) 'x) '(1 2))
  (=> (get-property-list '((x 1 2) (y 3)) 'y) '(3))
  (=> (get-property-list '((x 1 2) (y 3)) 'z) #f)
  (=> (get-property-list '((x 1 2) (y 3)) 'z 'missing) 'missing)
  (=> (get-property-list '((x 1 2) (y 3)) 'x 'missing) '(1 2))
  (=> (get-property-list '() 'a) #f)
  (=> (get-property-list '() 'a #f) #f)
  (=> (get-property-list '() 'a 'missing) 'missing)
  (=> (get-property-list '(foo (x 1 2) bar) 'x) '(1 2))
  (=> (get-property-list '(foo (x 1 2) bar) 'foo) 'foo)
  (=> (get-property-list '(foo (x 1 2) bar) 'baz) #f))
