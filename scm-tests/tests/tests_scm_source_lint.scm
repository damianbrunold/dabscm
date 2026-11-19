(import (scheme base)
        (srfi 1)
        (scm source format)
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
  (test-assert (not (has? 'unbound-identifier
                          (prog "(define (setup) (load \"x.scm\"))" "(setup)"
                                "(foo)"))))
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

(test-group "cond-expand"
  ;; the clause for this implementation is checked, the others are not
  (test-assert (has? 'unbound-identifier
                     (prog
                      "(cond-expand (guile (guile-only)) (else (display (nope))))")))
  (test-assert (not (has? 'unbound-identifier
                          (prog
                           "(cond-expand (guile (guile-only)) (else (display 1)))"))))
  (test-assert (has? 'unbound-identifier
                     (prog
                      "(cond-expand ((and r7rs (not guile)) (nope)) (else (other)))")))
  (test-assert (not (has? 'unbound-identifier
                          (prog
                           "(cond-expand ((library (scheme base)) (display 1)) (else (nope)))")))))

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

(test-group "redundant and dead code"
  (define (f . body)
    ;; body as the body of (define (f c x y l) ...), called once
    (apply prog
           (append (list "(define (f c x y l)")
                   body
                   (list ")" "(f #t 1 2 '(1))"))))
  (test-assert (has? 'constant-test (f "(if #f #f)")))
  (test-assert (has? 'constant-test (f "(if #t x y)")))
  (test-assert (has? 'constant-test (f "(if \"s\" x y)")))
  (test-assert (has? 'constant-test (f "(when #f (display x))")))
  (test-assert (has? 'constant-test (f "(unless '() (display x))")))
  (test-assert (has? 'constant-test (f "(cond (#f 1) (else 2))")))
  (test-assert (not (has? 'constant-test (f "(if c x y)"))))
  (test-assert (has? 'if-same-branches (f "(if c (car x) (car x))")))
  (test-assert (not (has? 'if-same-branches (f "(if c (car x) (cdr x))"))))
  (test-assert (has? 'if-and-or (f "(if c (car l) #f)")))
  (test-assert (has? 'if-and-or (f "(if x x y)")))
  (test-assert (not (has? 'if-and-or (f "(if x y x)"))))
  (test-assert (has? 'when-not (f "(when (not c) (display x))")))
  (test-assert (has? 'when-not (f "(unless (not c) (display x))")))
  (test-assert (has? 'true-clause (f "(cond (c 1) (#t 2))")))
  (test-assert (has? 'true-clause (f "(guard (e (#t #f)) (car l))")))
  (test-assert (not (has? 'true-clause (f "(cond (c 1) (else 2))"))))
  (test-assert (has? 'false-compare (f "(eq? x #f)")))
  (test-assert (not (has? 'false-compare (f "(eq? x #t)"))))
  (test-assert (has? 'redundant-call (f "(and x)")))
  (test-assert (has? 'redundant-call (f "(or x)")))
  (test-assert (has? 'redundant-call (f "(* x)")))
  (test-assert (not (has? 'redundant-call (f "(and x y)"))))
  (test-assert (has? 'let-identity (f "(let ((z (car l))) z)")))
  (test-assert (not (has? 'let-identity (f "(let ((z (car l))) (display z) z)"))))
  (test-assert (has? 'identity-lambda (f "(map (lambda (e) e) l)")))
  (test-assert (has? 'identity-lambda
                     (f "(cond ((assq x l) => (lambda (p) p)) (else #f))")))
  (test-assert (not (has? 'identity-lambda (f "(map (lambda (e) (car e)) l)"))))
  ;; a local named map is not the standard map
  (test-assert (not (has? 'identity-lambda
                          (f "(let ((map (lambda (g k) k))) (map (lambda (e) e) l))")))))

(test-group "fixes"
  ;; (fixed body) is the fixed text of (define (f c x y l) body) after
  ;; prog's import line, as (text . number-of-fixes)
  (define (fixed body)
    (let-values (((t n) (lint-fix-string
                         (prog (string-append "(define (f c x y l) " body ")")
                               "(f #t 1 2 '(1))")
                         "t.scm"
                         '((disable unused-import)))))
      (let* ((head "(import (scheme base) (scheme write))\n(define (f c x y l) ")
             (tail ")\n(f #t 1 2 '(1))\n"))
        (cons (if (and (> (string-length t) (+ (string-length head)
                                               (string-length tail)))
                       (string=? head (substring t 0 (string-length head))))
                  (substring t (string-length head)
                             (- (string-length t) (string-length tail)))
                  t)
              n))))
  (define (fix body) (car (fixed body)))
  (test-equal "(when c (display x))" (fix "(if c (display x))"))
  (test-equal "(unless c (display x))" (fix "(if (not c) (display x))"))
  (test-equal "(unless c (display x))" (fix "(when (not c) (display x))"))
  (test-equal "(when c (display x))" (fix "(unless (not c) (display x))"))
  (test-equal "(cond (c 1) (else 2))" (fix "(cond (c 1) (#t 2))"))
  (test-equal "(guard (e (else #f)) (car l))" (fix "(guard (e (#t #f)) (car l))"))
  (test-equal "(and c (car l))" (fix "(if c (car l) #f)"))
  (test-equal "(and c x (car l))" (fix "(if (and c x) (car l) #f)"))
  (test-equal "(or x y)" (fix "(if x x y)"))
  (test-equal "(not (pair? l))" (fix "(if (pair? l) #f #t)"))
  (test-equal "(not x)" (fix "(eq? x #f)"))
  (test-equal "(not x)" (fix "(eq? #f x)"))
  (test-equal "(null? l)" (fix "(equal? l '())"))
  (test-equal "(eqv? x 1)" (fix "(eq? x 1)"))
  (test-equal "(member \"a\" l)" (fix "(memq \"a\" l)"))
  (test-equal "(cadr l)" (fix "(car (cdr l))"))
  (test-equal "(cddr l)" (fix "(cdr (cdr l))"))
  (test-equal "(cons x l)" (fix "(append (list x) l)"))
  (test-equal "l" (fix "(append l)"))
  (test-equal "x" (fix "(and x)"))
  (test-equal "x" (fix "(+ x)"))
  (test-equal "(list (car l))" (fix "(list (begin (car l)))"))
  (test-equal "(when c (display x) (newline))"
              (fix "(when c (begin (display x) (newline)))"))
  (test-equal "(car l)" (fix "(let () (car l))"))
  (test-equal "(car l)" (fix "(let ((z (car l))) z)"))
  ;; nested fixes are made in rounds
  (test-equal '("(when c x)" . 2) (fixed "(if c (begin x))"))
  ;; a comment between the parts that would be dropped blocks the fix
  (test-equal "(if c x ; why\n #f)" (fix "(if c x ; why\n #f)"))
  ;; ... a comment that stays is kept
  (test-equal "(when c ; why\n x)" (fix "(if c ; why\n x)"))
  ;; no fix for findings without a safe rewrite
  (test-equal '("(if c x x)" . 0) (fixed "(if c x x)"))
  (test-equal '("(string-append x)" . 0) (fixed "(string-append x)"))
  (test-equal '("(if x #t #f)" . 0) (fixed "(if x #t #f)"))
  ;; disabled rules and suppressed lines are not fixed
  (test-equal "(if c x)"
              (car (let-values (((t n) (lint-fix-string "(import (scheme base))\n(define (f c x) (if c x))\n(f 1 2)\n"
                                                        "t.scm"
                                                        '((disable if-without-else unused-import)))))
                     (list (substring t 39 47) n))))
  (test-equal 0
              (let-values (((t n) (lint-fix-string "(import (scheme base))\n(define (f c x) (if c x)) ; lint: ignore\n(f 1 2)\n"
                                                   "t.scm"
                                                   '((disable unused-import)))))
                n))
  ;; text fixes
  (test-equal "(import (scheme base))\n(display 1)\n"
              (let-values (((t n) (lint-fix-string "(import (scheme base))  \n(display 1)"
                                                   "t.scm"
                                                   '((disable unused-import)))))
                t))
  ;; a formatted file is formatted again after the fixes
  (let-values (((t n) (lint-fix-string
                       (string-append "(import (scheme base)\n        (scheme write))\n"
                                      "(define (f c x)\n  (if c\n      (begin\n"
                                      "        (display x)\n        (newline))))\n"
                                      "(f 1 2)\n")
                       "t.scm"
                       '((disable unused-import)))))
    (test-equal 2 n)
    (test-equal t (format-source-string t))
    (test-assert (not (let loop ((k 0))
                        (and (<= (+ k 5) (string-length t))
                             (or (string=? "begin" (substring t k (+ k 5)))
                                 (loop (+ k 1))))))))
  (test-assert (lint-finding-fixable?
                (car (findings (prog "(define (f x) (car (cdr x)))" "(f 1)"))))))

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

(test-group "definer macros"
  (let ((lib (string-append "(define-library (a b)\n  (export cmd run var)\n"
                            "  (import (scheme base))\n  (begin\n"
                            "    (define-syntax define-cmd\n"
                            "      (syntax-rules () ((_ (n . a) b ...) (define (n . a) b ...))))\n"
                            "    (define-syntax define-var\n"
                            "      (syntax-rules () ((_ n v) (define n v))))\n"
                            "    (define-cmd (cmd x) (+ x 1))\n"
                            "    (define-cmd (helper) 1)\n"
                            "    (define-var var 2)\n"
                            "    (define (run) (cmd var))))\n"))
        (opts (lambda (ds)
                (list (cons 'definers ds) '(disable unused-import)))))
    ;; unknown macros define nothing: the exports are undefined and the
    ;; uses unbound
    (test-equal '(export-undefined export-undefined unbound-identifier
                  unbound-identifier)
                (rules lib (opts '())))
    ;; listed definers define their first argument, (name . args) or name;
    ;; helper, defined but only referenced by name, is not reported
    (test-equal '() (rules lib (opts '(define-cmd define-var))))
    (test-equal '(export-undefined unbound-identifier)
                (rules lib (opts '(define-cmd))))
    (test-equal '(define-cmd)
                (cdr (assq 'definers
                           (lint-options "t.scm" '((definers define-cmd)))))))
  ;; in a program body, uses of the defined name are not unbound
  (test-equal '()
              (rules (prog
                      "(define-syntax def (syntax-rules () ((_ n v) (define n v))))"
                      "(def x 1)" "(display x)")
                     '((definers def) (disable unused-import)))))

(test-group "source-xref"
  (define (xs text . opts)
    (map (lambda (x)
           (list (xref-role x)
                 (xref-name x)
                 (xref-line x)
                 (xref-col x)
                 (xref-target x)))
         (apply source-xref text "t.scm" opts)))
  (test-equal '((definition f 2 9 (here 2 9))
                (local-definition x 2 11 (here 2 11))
                (reference car 2 15 (import (scheme base) car))
                (reference x 2 19 (here 2 11)))
              (xs "(import (scheme base))\n(define (f x) (car x))\n"))
  (test-equal '(define param #f)
              (map xref-kind
                   (source-xref "(import (scheme base))\n(define (f x) x)\n"
                                "t.scm")))
  ;; renamed imports name the original; quoted symbols and macro
  ;; arguments are told apart from references
  (test-equal '((definition m 3 22 (here 3 22))
                (quoted f 4 12 #f)
                (reference m 4 17 (here 3 22))
                (mention first 4 20 (import (scheme base) car))
                (export m 5 8 (here 3 22)))
              (filter (lambda (x) (memq (cadr x) '(m f first)))
                      (xs (string-append
                           "(define-library (t)\n(import (scheme base) "
                           "(rename (only (scheme base) car) (car first)))\n"
                           "(begin (define-syntax m (syntax-rules () ((_ a) a)))\n"
                           "(define v '(f)) (m (first v)))\n"
                           "(export m))\n"))))
  ;; definers define their first argument, also locally in a body
  (test-equal '((definition cmd 2 13 (here 2 13))
                (reference cmd 3 1 (here 2 13)))
              (filter (lambda (x) (eq? (cadr x) 'cmd))
                      (xs (string-append "(import (scheme base))\n"
                                         "(define-cmd (cmd x) x)\n"
                                         "(cmd 1)\n")
                          '((definers define-cmd)))))
  (test-equal #f (source-xref "(foo" "t.scm")))

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
