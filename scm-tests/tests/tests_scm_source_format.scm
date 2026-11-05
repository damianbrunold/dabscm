(import (scheme base)
        (scm io)
        (scm source)
        (scm source format)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm source format")

(define (fmt s . opts)
  (format-source-string s (if (pair? opts) (car opts) '())))
(define (keep s) (fmt s '((keep-breaks . #t))))
(define (lines . ls)
  (let loop ((ls ls) (acc ""))
    (if (null? ls) acc (loop (cdr ls) (string-append acc (car ls) "\n")))))

(test-group "short forms join onto one line"
  (test-equal "(define (f x) (if x 1 2))\n"
              (fmt "(define (f x)\n(if x\n1 2))"))
  (test-equal "(display 1)\n" (fmt "  (display\n   1)  "))
  (test-equal "" (fmt ""))
  (test-equal "(a)\n(b)\n" (fmt "(a) (b)")))

(test-group "body forms"
  (test-equal (lines "(define (f x)" "  \"doc\""
                     "  (let ((a 1) (b 2)) (+ a b)))")
              (fmt "(define (f x) \"doc\" (let ((a 1) (b 2)) (+ a b)))"))
  (test-equal (lines "(when (> x 1)" "  (display x)" "  (newline))")
              (fmt "(when (> x 1) (display x) (newline))"))
  (test-equal (lines "(let loop ((i 0) (acc '()))"
                     "  (if (= i 10) (reverse acc) (loop (+ i 1) (cons (* i i) acc))))")
              (fmt
               "(let loop ((i 0) (acc '()))\n  (if (= i 10) (reverse acc) (loop (+ i 1) (cons (* i i) acc))))"))
  (test-equal (lines "(let ((a (f 1))" "      (b 2))" "  a)")
              (fmt "(let ((a (f 1)) (b 2)) a)"))
  (test-equal (lines "(define x"
                     "  (string-append \"aaaaaaaaaaaaaaaaaaaa\" \"bbbbbbbbbbbbbbbbbbbbbbb\""
                     "                 \"ccccccccccccccccccccccccccc\"))")
              (fmt
               "(define x (string-append \"aaaaaaaaaaaaaaaaaaaa\" \"bbbbbbbbbbbbbbbbbbbbbbb\" \"ccccccccccccccccccccccccccc\"))")))

(test-group "calls and clauses"
  (test-equal (lines "(define (process-the-items items accumulator)"
                     "  (cond ((null? items) accumulator)"
                     "        ((pair? (car items))"
                     "         (process-the-items (cdr items) (cons (car items) accumulator)))"
                     "        (else (error \"bad item in the list of items\" (car items)))))")
              (fmt
               "(define (process-the-items items accumulator) (cond ((null? items) accumulator) ((pair? (car items)) (process-the-items (cdr items) (cons (car items) accumulator))) (else (error \"bad item in the list of items\" (car items)))))"))
  (test-equal (lines
               "(router-add! router \"GET\" \"/a/long/path/for/the/test\""
               "             (lambda (request) (handle-the-request request with options)))")
              (fmt
               "(router-add! router \"GET\" \"/a/long/path/for/the/test\" (lambda (request) (handle-the-request request with options)))"))
  (test-equal (lines
               "(router-add! router \"GET\" \"/a/long/path/for/the/test\""
               "  (lambda (request) (handle-the-request request with options)))")
              (fmt
               "(router-add! router \"GET\" \"/a/long/path/for/the/test\" (lambda (request) (handle-the-request request with options)))"
               '((indent ("router-add!" . 3))))))

(test-group "data"
  (test-equal (lines
               "(bar '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27"
               "       28 29 30 31))")
              (fmt
               "(bar '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31))"))
  (test-equal "#(1 2 3)\n" (fmt "#(1\n2\n3)"))
  (test-equal (lines
               "`(span (@ (class ,(string-append \"tag tag-with-a-long-name \""
               "                                 (state-class s))))"
               "       ,(string-upcase state))")
              (fmt
               "`(span (@ (class ,(string-append \"tag tag-with-a-long-name \" (state-class s)))) ,(string-upcase state))")))

(test-group "comments"
  (test-equal (lines "(foo a ; c1" "     b)") (fmt "(foo a ; c1\n b)"))
  (test-equal "(f (g x)) ; c\n" (fmt "(f (g x ; c\n))"))
  (test-equal (lines "#!/usr/bin/env scm" ";; hdr" "(display 1) ; t1" ""
                     ";; tail comment")
              (fmt
               "#!/usr/bin/env scm\n;; hdr\n(display 1) ; t1\n\n\n\n;; tail comment"))
  (test-equal (lines "(define x" "  '(a" "    b" "    ;; own line" "    c))")
              (fmt "(define x '(a b\n ;; own line\n c))"))
  (test-equal "(a #| inline |# b)\n" (fmt "(a #| inline |# b)"))
  (test-equal "#;(old code)\n(new)\n" (fmt "#;(old code)\n(new)")))

(test-group "atoms are copied verbatim"
  (test-equal (lines "(define (f)" "  \"Syntax: (f)" "Library: (x)\"" "  1)")
              (fmt "(define (f) \"Syntax: (f)\nLibrary: (x)\" 1)"))
  (test-equal "(char-set #<<END\nhello\n  END\nEND\n          x)\n"
              (fmt "(char-set #<<END\nhello\n  END\nEND\n x)"))
  (test-equal "(x |a b| #\\( #\\space #u8(1 2) 1.50)\n"
              (fmt "(x |a b| #\\( #\\space #u8(1 2) 1.50)")))

(test-group "brackets"
  (test-equal "(let ((x 1)) x)\n" (fmt "[let ([x 1]) x]"))
  (test-equal "[let ([x 1]) x]\n"
              (fmt "[let ([x 1]) x]" '((keep-brackets . #t)))))

(test-group "keep-breaks"
  (test-equal (lines "(define (f x)" "  (+ x" "     1))")
              (keep "(define (f x)\n(+ x\n1))"))
  (test-equal (lines "(foo a b" "     c)") (keep "(foo a b\n c)"))
  (test-equal (lines "(foo" " a b)") (keep "(foo\n      a b)")))

(test-group "import and export sorting"
  (test-equal (lines "(import (scheme base)" "        (scheme write)"
                     "        (except (srfi 1) map)" "        (srfi 13)"
                     "        (scm io))")
              (fmt
               "(import (srfi 13) (scheme base) (scm io) (except (srfi 1) map) (scheme write))"))
  (test-equal (lines "(define-library (x y)" "  (export a"
                     "          (rename q b)" "          m" "          z)"
                     "  (import (scheme base))" "  (begin (define a 1)))")
              (fmt
               "(define-library (x y) (export z a (rename q b) m) (import (scheme base)) (begin (define a 1)))"))
  ;; groups delimited by comments are sorted separately
  (test-equal (lines "(define-library (x y)" "  (export b" "          c"
                     "          ;; more" "          a" "          d)"
                     "  (import (scheme base))" "  (begin (define a 1)))")
              (fmt
               "(define-library (x y) (export c b\n ;; more\n d a) (import (scheme base)) (begin (define a 1)))"))
  ;; (srfi 13) and (srfi 69) bind string-hash differently: order matters
  (test-equal (lines "(import (srfi 69)" "        (srfi 13))")
              (fmt "(import (srfi 69) (srfi 13))"))
  ;; an unknown library may export anything
  (test-equal (lines "(import (no such lib)" "        (scheme base))")
              (fmt "(import (no such lib) (scheme base))"))
  (test-equal (lines "(import (srfi 13)" "        (scheme base))")
              (fmt "(import (srfi 13) (scheme base))"
                   '((sort-imports . #f)))))

(test-group "sorting keeps end-of-line comments working"
  ;; the commented entry moves last: the closing parenthesis must not end
  ;; up inside its comment
  (test-equal (lines "(define-library (x y)" "  (export a" "          b"
                     "          z) ; last" "  (import (scheme base))"
                     "  (begin (define a 1)))")
              (fmt
               "(define-library (x y) (export z ; last\n b a) (import (scheme base)) (begin (define a 1)))"))
  (test-equal (lines "(define-library (x y)" "  (export a ; first"
                     "          b)" "  (import (scheme base))"
                     "  (begin (define a 1)))")
              (fmt
               "(define-library (x y) (export b a ; first\n) (import (scheme base)) (begin (define a 1)))"))
  ;; two end-of-line comments brought onto one line: the second gets a line
  ;; of its own (and stays there when formatted again)
  (test-equal (lines "(define-library (x y)" "  (import (scheme base) ; base"
                     "          (scheme char)) ; char" "  ; after"
                     "  (begin (define a 1)))")
              (fmt
               "(define-library (x y) (import (scheme char) ; char\n (scheme base) ; base\n) ; after\n (begin (define a 1)))")))

(test-group "width"
  (test-equal (lines "(foo aaaa" "     bbbb)")
              (fmt "(foo aaaa bbbb)" '((width . 12))))
  (test-equal "(foo aaaa bbbb)\n" (fmt "(foo aaaa bbbb)" '((width . 15)))))

(test-group "errors"
  (test-assert (source-read-error-position
                (guard (e (#t e)) (fmt "(unclosed"))))
  (test-error (fmt ")")))

(test-group "diff"
  (test-equal "" (source-diff "a\n" "a\n" "x"))
  (test-equal
   "--- x.scm\n+++ x.scm (formatted)\n@@ -1,2 +1,2 @@\n a\n-b\n+c\n"
   (source-diff "a\nb\n" "a\nc\n" "x.scm")))

(test-group "fmt-command"
  (test-equal 2
              (parameterize ((current-error-port (open-output-string)))
                (fmt-command '())))
  (test-equal 2
              (parameterize ((current-error-port (open-output-string)))
                (fmt-command '("--bogus" "x")))))

;; Formatting is stable and keeps the datums on real sources.
(define lib-dir
  (let loop
      ((cands '("scm-lib/libraries" "../scm-lib/libraries"
                "../../scm-lib/libraries" "../../../scm-lib/libraries")))
    (cond ((null? cands) #f)
          ((file->string (string-append (car cands) "/scm-source.sld"))
           (car cands))
          (else (loop (cdr cands))))))

(when lib-dir
  (test-group "library sources format stably"
    (for-each (lambda (name)
                (let ((s (read-file-string (string-append lib-dir "/" name))))
                  (test-assert name
                               (let ((once (fmt s)))
                                 (string=? once (fmt once))))
                  (test-assert name
                               (let ((once (keep s)))
                                 (string=? once (keep once))))))
              '("scm-source.sld" "scm-source-format.sld" "scm-toml.sld"
                "srfi-14.sld" "scm-net-http-server.sld"))))

(test-end "scm source format")
