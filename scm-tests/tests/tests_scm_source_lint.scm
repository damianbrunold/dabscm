(import (scheme base)
        (srfi 1)
        (scm source lint)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm source lint")

;; unused-import is off unless options are given: most snippets do not
;; use everything prog imports
(define (findings text . opts)
  (lint-string text "t.scm"
               (if (pair? opts) (car opts) '((disable unused-import)))))
(define (rules text . opts)
  (map lint-finding-rule (apply findings text opts)))
(define (prog . lines)
  (let loop ((ls lines) (acc "(import (scheme base) (scheme write))\n"))
    (if (null? ls) acc (loop (cdr ls) (string-append acc (car ls) "\n")))))
(define (has? rule text . opts) (and (memq rule (apply rules text opts)) #t))

(test-group "clean code has no findings"
  (test-equal '() (rules (prog "(define (f x) (display x))" "(f 1)")))
  (test-equal '()
              (rules
               "(define-library (a b)\n  (export f)\n  (import (scheme base))\n  (begin\n    (define (f x) (+ x 1))))\n")))

(test-group "read errors"
  (let ((fs (findings "(foo (bar)")))
    (test-equal '(read-error) (map lint-finding-rule fs))
    (test-equal 'error (lint-finding-severity (car fs)))
    (test-equal 1 (lint-finding-line (car fs)))))

(test-group "unbound identifiers"
  (test-assert (has? 'unbound-identifier (prog "(display (h 2))")))
  (test-assert (not (has? 'unbound-identifier
                          (prog "(define (h x) x)" "(display (h 2))"))))
  ;; inlined primitives work in call position without an import ...
  (test-assert (not (has? 'unbound-identifier
                          "(import (scm core))\n(vector-ref (list 1) 0)\n")))
  ;; ... but not as values
  (test-assert (has? 'unbound-identifier
                     "(import (scm core))\n(define v vector-ref)\n"))
  ;; macros not known to the linter are not looked into
  (test-assert (not (has? 'unbound-identifier
                          "(import (scheme base) (scm test))\n(test-equal 1 (whatever x))\n")))
  ;; unknown libraries and loaded files make the environment unknown
  (test-assert (not (has? 'unbound-identifier
                          "(import (no such lib))\n(foo)\n")))
  (test-assert (not (has? 'unbound-identifier
                          (prog "(load \"x.scm\")" "(foo)"))))
  (test-assert (not (has? 'unbound-identifier "(foo bar)\n")))
  (test-assert (not (has? 'unbound-identifier (prog "(display +inf.0)")))))

(test-group "imports"
  (test-assert (has? 'unused-import (prog "(display 1)") '()))
  (test-equal '(unused-import)
              (rules "(import (scheme base) (scheme char))\n(car '(1))\n"
                     '()))
  ;; a library whose used names all come from another one is redundant
  (let ((fs (findings "(import (scheme base) (srfi 1))\n(car '(1))\n" '())))
    (test-equal '(unused-import) (map lint-finding-rule fs))
    (test-equal
     "(srfi 1) is redundant: the names used from it also come from (scheme base)"
     (lint-finding-message (car fs))))
  (test-equal '(unused-only-name)
              (rules
               "(import (scheme base) (only (srfi 1) fold first))\n(fold + 0 '())\n"
               '()))
  (test-assert (has? 'duplicate-import
                     "(import (scheme base) (scheme base))\n(car '(1))\n"))
  (test-assert (has? 'import-conflict
                     "(import (scheme base) (srfi 13) (srfi 69))\n(string-hash \"a\") (string-index \"a\" #\\a) (make-hash-table)\n")))

(test-group "locals and definitions"
  (test-equal '(unused-local)
              (rules (prog "(let ((unused 1) (y 2)) (display y))")))
  (test-equal '(unused-local) (rules (prog "(let loop ((i 0)) (display i))")))
  (test-assert (not (has? 'unused-local
                          (prog "(let ((_x 1) (y 2)) (display y))"))))
  (test-assert (not (has? 'unused-parameter
                          (prog "(define (f x) 1)" "(f 1)"))))
  (test-assert (has? 'unused-parameter
                     (prog "(define (f x) 1)" "(f 1)")
                     '((enable unused-parameter))))
  (test-assert (has? 'duplicate-definition
                     (prog "(define (g) 1)" "(define (g) 2)" "(g)")))
  (test-assert (has? 'definition-context
                     (prog "(when #t (define z 1) (display z))")))
  (let
      ((lib
        "(define-library (a b)\n  (export f undefined-x f)\n  (import (scheme base))\n  (begin\n    (define (f) 1)\n    (define (helper) 2)))\n"))
    (test-assert (has? 'export-undefined lib))
    (test-assert (has? 'duplicate-export lib))
    (test-assert (has? 'unused-definition lib)))
  (test-assert (has? 'set-imported (prog "(set! car 1)")))
  (test-assert (not (has? 'set-imported
                          (prog "(define x 1)" "(set! x 2)" "(display x)")))))

(test-group "arity and form shapes"
  (test-equal '(arity-mismatch)
              (rules (prog "(define (g a b) (+ a b))" "(display (g 1))")))
  (test-assert (not (has? 'arity-mismatch
                          (prog "(define (g a . r) a)"
                                "(display (g 1 2 3))"))))
  (test-assert (has? 'arity-mismatch
                     (prog "(define-record-type p (make-p x y) p? (x p-x))"
                           "(display (p-x (make-p 1)))")))
  ;; a procedure that is set! later may change its arity
  (test-assert (not (has? 'arity-mismatch
                          (prog "(define (g a) a)" "(set! g list)"
                                "(display (g 1 2))"))))
  (test-assert (has? 'malformed-form (prog "(display (if 1 2 3 4))")))
  (test-assert (has? 'malformed-form
                     (prog "(display (cond (else 1) (#f 2)))")))
  (test-assert (has? 'malformed-form (prog "(display (let ((x)) x))")))
  (test-assert (has? 'malformed-form (prog "(display (lambda (x)))")))
  (test-assert (has? 'malformed-form (prog "(display (lambda (x x) x))")))
  (test-assert (has? 'duplicate-case-datum
                     (prog "(display (case 1 ((1 2) 'a) ((2) 'b)))")))
  (test-assert (has? 'unreachable-clause
                     (prog "(display (cond (#t 1) ((car '()) 2)))"))))

(test-group "idioms"
  (test-assert (has? 'cxr (prog "(define (f x) (car (cdr x)))" "(f 1)")))
  (test-assert (not (has? 'cxr (prog "(define (f x) (car x))" "(f 1)"))))
  (test-assert (has? 'if-boolean
                     (prog "(define (f x) (if (null? x) #t #f))" "(f 1)")))
  (test-assert (has? 'if-without-else (prog "(if (pair? '()) (display 1))")))
  (test-assert (has? 'null-compare (prog "(display (eq? '() '()))")))
  (test-assert (has? 'eq-literal (prog "(display (eq? \"a\" \"a\"))")))
  (test-assert (has? 'eq-literal (prog "(display (memq 1 '(1 2)))")))
  (test-assert (not (has? 'eq-literal (prog "(display (memq 'a '(a b)))"))))
  (test-assert (has? 'length-zero (prog "(display (= (length '()) 0))")))
  (test-assert (has? 'append-list (prog "(display (append (list 1) '(2)))")))
  (test-assert (has? 'redundant-call
                     (prog "(display (string-append \"a\"))")))
  (test-assert (has? 'begin-single (prog "(display (begin 1))")))
  (test-assert (has? 'empty-let (prog "(display (let () 1))")))
  (test-assert (has? 'eta-lambda
                     (prog "(display (map (lambda (x) (car x)) '()))")))
  (test-assert (has? 'nested-if
                     (prog
                      "(define (f a) (if a 1 (if (car a) 2 (if (cdr a) 3 4))))"
                      "(f 1)")))
  (test-assert (has? 'define-lambda
                     (prog "(define f (lambda (x) x))" "(f 1)")
                     '((enable define-lambda))))
  (test-assert (has? 'predicate-naming
                     (prog "(define (even x) (= 0 (remainder x 2)))"
                           "(even 1)")
                     '((enable predicate-naming)))))

(test-group "docstring conventions"
  (let
      ((lib (lambda (doc)
              (string-append
               "(define-library (scm foo)\n  (export a)\n  (import (scheme base))\n"
               "  (begin\n    (define (a x)\n"
               (if (string=? doc "") "" (string-append "      " doc "\n"))
               "      (+ x 1))))\n"))))
    (test-equal '()
                (rules (lib
                        "\"Syntax: (a x)\nLibrary: (scm foo)\nDescription: d\"")))
    (test-equal '(missing-docstring) (rules (lib "")))
    (test-equal '(docstring-syntax-mismatch)
                (rules (lib "\"Syntax: (b x)\nLibrary: (scm foo)\"")))
    (test-equal '(docstring-library-mismatch)
                (rules (lib "\"Syntax: (a x)\nLibrary: (scm bar)\"")))
    (test-equal '()
                (rules (lib "")
                       '((docstring-libraries "other")
                         (disable unused-import))))))

(test-group "library file names"
  (test-equal '(library-file-name)
              (map lint-finding-rule
                   (lint-string
                    "(define-library (a b) (export) (import (scheme base)) (begin))\n"
                    "x.sld"
                    '((disable unused-import)))))
  (test-equal '()
              (map lint-finding-rule
                   (lint-string
                    "(define-library (a b) (export) (import (scheme base)) (begin))\n"
                    "src/a-b.sld"
                    '((disable unused-import)))))
  (test-assert (not (has? 'library-file-name
                          "(import (scheme base))\n(car '(1))\n"))))

(test-group "text and formatting rules"
  (test-assert (has? 'trailing-whitespace (prog "(display 1) ")))
  (test-assert (has? 'tab-character (prog "(display\t1)")))
  (test-assert (not (has? 'tab-character (prog "(display \"\t\")"))))
  (test-assert (has? 'missing-final-newline
                     "(import (scheme base))\n(car '(1))"))
  (test-assert (has? 'line-too-long
                     (prog (string-append "(display '("
                                          (make-string 80 #\a)
                                          "))"))))
  (test-assert (not (has? 'line-too-long
                          (prog (string-append "(display \""
                                               (make-string 80 #\a)
                                               "\")")))))
  (test-assert (has? 'unsorted-imports
                     "(import (scheme write) (scheme base))\n(display (car '(1)))\n"))
  (test-assert (not (has? 'not-formatted (prog "(display    1)"))))
  (test-assert (has? 'not-formatted
                     (prog "(display    1)")
                     '((fmt-check . #t)))))

(test-group "rule selection and suppression"
  (test-assert (not (has? 'cxr
                          (prog "(define (f x) (car (cdr x)))" "(f 1)")
                          '((disable cxr)))))
  (test-equal '()
              (rules (prog "(define (f x) (car (cdr x))) ; lint: ignore"
                           "(f 1)")))
  (test-equal '()
              (rules (prog "; lint: ignore cxr" "(define (f x) (car (cdr x)))"
                           "(f 1)")))
  (test-assert (has? 'cxr
                     (prog "; lint: ignore if-boolean"
                           "(define (f x) (car (cdr x)))" "(f 1)")))
  (test-equal '()
              (rules (prog ";; lint: disable cxr unbound-identifier"
                           "(define (f x) (car (cdr x)))" "(f (zz))"))))

(test-group "output formats"
  (let ((fs (findings (prog "(display (h 2))"))))
    (test-equal "t.scm:2:11: error: [unbound-identifier] h is not bound\n"
                (lint-findings->text fs))
    (test-equal
     "[\n  {\"file\": \"t.scm\", \"line\": 2, \"column\": 11, \"severity\": \"error\", \"rule\": \"unbound-identifier\", \"message\": \"h is not bound\"}\n]"
     (lint-findings->json fs)))
  (test-equal "[]" (lint-findings->json '()))
  (test-assert (every (lambda (r)
                        (and (symbol? (car r))
                             (memq (cadr r) '(error warning info))))
                      (lint-rules))))

(test-group "lint-command"
  (test-equal 2
              (parameterize ((current-error-port (open-output-string)))
                (lint-command '())))
  (test-equal 2
              (parameterize ((current-error-port (open-output-string)))
                (lint-command '("--disable" "no-such-rule" "x"))))
  (test-equal 0
              (parameterize ((current-output-port (open-output-string)))
                (lint-command '("--list-rules")))))

(test-end "scm source lint")
