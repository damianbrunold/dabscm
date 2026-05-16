(import (except (scheme base) make-list list-copy) (scheme write) (scm io) (scm core) (scm compile) (scm module))

(test-group
  (define-library (dl-basic)
    (import (scheme base))
    (export dl-double dl-triple)
    (begin
      (define (dl-double x) (* x 2))
      (define (dl-triple x) (* x 3))))
  (import (dl-basic))
  (=> (dl-double 5) 10)
  (=> (dl-triple 4) 12))

(test-group
  (define-library (dl-only)
    (import (scheme base))
    (export dl-ot-add dl-ot-sub)
    (begin
      (define (dl-ot-add x y) (+ x y))
      (define (dl-ot-sub x y) (- x y))))
  (import (only (dl-only) dl-ot-add))
  (=> (dl-ot-add 3 4) 7)
  (=> (bound? 'dl-ot-sub) #f))

(test-group
  (define-library (dl-except)
    (import (scheme base))
    (export dl-ex-mul dl-ex-div)
    (begin
      (define (dl-ex-mul x y) (* x y))
      (define (dl-ex-div x y) (/ x y))))
  (import (except (dl-except) dl-ex-div))
  (=> (dl-ex-mul 3 4) 12)
  (=> (bound? 'dl-ex-div) #f))

(test-group
  (define-library (dl-prefix)
    (import (scheme base))
    (export dl-pfx-fn)
    (begin
      (define (dl-pfx-fn x) (* x 10))))
  (import (prefix (dl-prefix) pfx:))
  (=> (pfx:dl-pfx-fn 5) 50)
  (=> (bound? 'dl-pfx-fn) #f))

(test-group
  (define-library (dl-rename)
    (import (scheme base))
    (export dl-rn-add dl-rn-mul)
    (begin
      (define (dl-rn-add x y) (+ x y))
      (define (dl-rn-mul x y) (* x y))))
  (import (rename (dl-rename) (dl-rn-add dl-rn-sum)))
  (=> (dl-rn-sum 3 4) 7)
  (=> (dl-rn-mul 3 4) 12)
  (=> (bound? 'dl-rn-add) #f))

(test-group
  (define-library (dl-base2)
    (import (scheme base))
    (export dl-square)
    (begin
      (define (dl-square x) (* x x))))
  (define-library (dl-ext2)
    (import (scheme base) (dl-base2))
    (export dl-sum-sq)
    (begin
      (define (dl-sum-sq a b)
        (+ (dl-square a) (dl-square b)))))
  (import (dl-base2))
  (import (dl-ext2))
  (=> (dl-sum-sq 3 4) 25))

(test-group
  (define-library (dl-exports)
    (import (scheme base))
    (export dl-ea dl-eb dl-ec)
    (begin
      (define dl-ea 1)
      (define dl-eb 2)
      (define dl-ec 3)))
  (=> (length (%module-exports '(dl-exports))) 3))

(test-group
  (define-library (dl-only-rename)
    (import (scheme base))
    (export dl-or-add dl-or-sub)
    (begin
      (define (dl-or-add x y) (+ x y))
      (define (dl-or-sub x y) (- x y))))
  (import (only (rename (dl-only-rename) (dl-or-add dl-or-sum)) dl-or-sum))
  (=> (dl-or-sum 3 4) 7)
  (=> (bound? 'dl-or-sub) #f)
  (=> (bound? 'dl-or-add) #f))

(test-group
  (define-library (dl-prefix-only)
    (import (scheme base))
    (export dl-po-x dl-po-y)
    (begin
      (define (dl-po-x n) (* n 2))
      (define (dl-po-y n) (* n 3))))
  (import (prefix (only (dl-prefix-only) dl-po-x) po:))
  (=> (po:dl-po-x 5) 10)
  (=> (bound? 'dl-po-y) #f)
  (=> (bound? 'po:dl-po-y) #f))

(test-group
  (define-library (dl-except-rename)
    (import (scheme base))
    (export dl-er-mul dl-er-div)
    (begin
      (define (dl-er-mul x y) (* x y))
      (define (dl-er-div x y) (/ x y))))
  (import (except (rename (dl-except-rename) (dl-er-div dl-er-quo)) dl-er-quo))
  (=> (dl-er-mul 3 4) 12)
  (=> (bound? 'dl-er-quo) #f)
  (=> (bound? 'dl-er-div) #f))

(test-group
  (define-library (dl-inner-base)
    (import (scheme base))
    (export dl-ib-foo dl-ib-bar)
    (begin
      (define (dl-ib-foo x) (* x 5))
      (define (dl-ib-bar x) (* x 7))))
  (define-library (dl-inner-use)
    (import (scheme base) (only (dl-inner-base) dl-ib-foo))
    (export dl-iu-result)
    (begin
      (define (dl-iu-result x) (dl-ib-foo x))))
  (import (dl-inner-use))
  (=> (dl-iu-result 3) 15))

(test-group
  (import (scm templating))
  (=> ;; Basic variable substitution
  (template-render "Hello {{ name }}!" '((name . "World"))) "Hello World!")
  (=> ;; Missing variable → empty string
  (template-render "Hi {{ missing }}!" '()) "Hi !")
  (=> ;; Nested dot notation
  (template-render "{{ person.name }}" '((person . ((name . "Alice"))))) "Alice")
  (=> ;; Numeric index into list
  (template-render "{{ items.1 }}" '((items . (10 20 30)))) "20")
  (=> ;; For loop over list
  (template-render "{% for x in nums %}{{ x }},{% endfor %}" '((nums . (1 2 3)))) "1,2,3,")
  (=> ;; For loop over vector
  (template-render "{% for x in v %}{{ x }}{% endfor %}" (list (cons 'v (vector "a" "b")))) "ab")
  (=> ;; If true branch
  (template-render "{% if flag %}yes{% else %}no{% endif %}" '((flag . #t))) "yes")
  (=> ;; If false branch
  (template-render "{% if flag %}yes{% else %}no{% endif %}" '((flag . #f))) "no")
  (=> ;; Empty list is falsy
  (template-render "{% if items %}has{% else %}empty{% endif %}" '((items . ()))) "empty")
  (=> ;; If without else
  (template-render "{% if x %}X{% endif %}" '((x . "hello"))) "X")
  (=> ;; Nested context access in for loop body
  (template-render "{% for p in people %}{{ p.name }} {% endfor %}"
                   '((people . (((name . "Alice")) ((name . "Bob")))))) "Alice Bob ")
  (=> ;; template-context helper
  (template-context 'a 1 'b "two") '((a . 1) (b . "two"))))

(test-group
  (import (srfi :1))
  (=> (procedure? iota) #t)
  (import (srfi :1 lists))
  =
  (=> (procedure? iota) #t))

(test-group
  (import (srfi srfi-1))
  (=> (procedure? iota) #t))

;; Test let-values in a library that only imports (scheme base)
;; Verifies that the macro expansion doesn't reference symbols
;; unavailable at the use site (e.g. with-values from scm core)
(test-group
  (define-library (dl-let-values)
    (import (scheme base))
    (export lv-test lv-test-multi)
    (begin
      (define (lv-test)
        (let-values (((a b) (values 1 2)))
          (+ a b)))
      (define (lv-test-multi)
        (let-values (((a b) (values 1 2))
                     ((c)   (values 3)))
          (list a b c)))))
  (import (dl-let-values))
  (=> (lv-test) 3)
  (=> (lv-test-multi) '(1 2 3)))

;; Test let*-values in a library that only imports (scheme base)
(test-group
  (define-library (dl-let*-values)
    (import (scheme base))
    (export lsv-test)
    (begin
      (define (lsv-test)
        (let*-values (((a b) (values 1 2))
                      ((c)   (values (+ a b))))
          c))))
  (import (dl-let*-values))
  (=> (lsv-test) 3))

;; Test define-values in a library that only imports (scheme base)
(test-group
  (define-library (dl-define-values)
    (import (scheme base))
    (export dv-a dv-b dv-c)
    (begin
      (define-values (dv-a dv-b dv-c) (values 10 20 30))))
  (import (dl-define-values))
  (=> dv-a 10)
  (=> dv-b 20)
  (=> dv-c 30))

;; Test receive from (srfi 8) in a library
(test-group
  (define-library (dl-receive)
    (import (scheme base) (srfi 8))
    (export recv-test)
    (begin
      (define (recv-test)
        (receive (a b) (values 1 2) (+ a b)))))
  (import (dl-receive))
  (=> (recv-test) 3))

;; Test define-syntax available for subsequent forms in same begin block (R7RS 5.6.1)
;; ds-use and ds-update! are regular functions that call ds-get/ds-set! macros
;; defined earlier in the same begin block.
(test-group
  (define-library (dl-define-syntax-in-begin)
    (import (scheme base))
    (export ds-make ds-use ds-update!)
    (begin
      (define-syntax ds-get (syntax-rules () ((_ v) (vector-ref v 1))))
      (define-syntax ds-set! (syntax-rules () ((_ v x) (vector-set! v 1 x))))
      (define (ds-make x) (vector 'tag x))
      (define (ds-use v) (ds-get v))
      (define (ds-update! v x) (ds-set! v x))))
  (import (dl-define-syntax-in-begin))
  (=> (ds-use (ds-make 42)) 42)
  (define ds-test-v (ds-make 10))
  (ds-update! ds-test-v 99)
  (=> (ds-use ds-test-v) 99))
