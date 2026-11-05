(import (scheme base)
        (scheme read)
        (scm io)
        (scm source)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm source")

(define (top str) (cst-children (source-read-string str)))
(define (kinds str) (map cst-kind (top str)))
(define (round-trip? str)
  (string=? str (cst->string (source-read-string str))))
(define (read-all str)
  (let ((p (open-input-string (string-append str "\n"))))
    (let loop ((acc '()))
      (let ((d (read p)))
        (if (eof-object? d) (reverse acc) (loop (cons d acc)))))))
(define (error-pos thunk)
  (guard (e (#t (source-read-error-position e)))
    (thunk)
    'no-error))

(test-group "node kinds"
  (test-equal '(list comment) (kinds "(a b) ; c"))
  (test-equal '(atom atom atom atom atom) (kinds "foo 42 #t \"s\" #\\a"))
  (test-equal '(vector bytevector) (kinds "#(1 2) #u8(1 2)"))
  (test-equal '(prefix prefix prefix prefix) (kinds "'a `b ,c ,@d"))
  (test-equal '(prefix prefix prefix prefix) (kinds "#'a #`b #,c #,@d"))
  (test-equal '(block-comment datum-comment) (kinds "#| x |# #;(y)"))
  (test-equal '(directive atom) (kinds "#!fold-case a"))
  (test-equal '(directive list) (kinds "#!/usr/bin/env scm\n(x)"))
  (test-equal '(label) (kinds "#0=(a . #0#)"))
  (test-equal '(atom dot atom)
              (map cst-kind (cst-children (car (top "(a . b)"))))))

(test-group "atoms keep their spelling"
  (test-equal '("#x1F" "|a b|" "#\\(" "#\\space" "1.50" "#true")
              (map cst-text (top "#x1F |a b| #\\( #\\space 1.50 #true")))
  (test-equal "\"a \\\" b\"" (cst-text (car (top "\"a \\\" b\""))))
  (test-equal "[" (cst-text (car (top "[a b]"))))
  (test-equal '("" . "]") (cst-close (car (top "[a b]"))))
  (test-equal "#<<END\nline\n  END\nEND\n"
              (cst-text (car (top "#<<END\nline\n  END\nEND\n")))))

(test-group "nested block comments"
  (test-equal "#| a #| b |# c |#"
              (cst-text (car (top "#| a #| b |# c |# x")))))

(test-group "prefixes carry comments and their datum"
  (let ((p (car (top "' ; c\n x"))))
    (test-equal "'" (cst-text p))
    (test-equal '(comment atom) (map cst-kind (cst-children p))))
  (test-equal '(atom) (map cst-kind (cst-children (car (top "#;x y"))))))

(test-group "positions"
  (let ((nodes (top "(a)\n  b ; c\n\n#(d)")))
    (test-equal '(1 2 2 4) (map cst-line nodes))
    (test-equal '(0 2 4 0) (map cst-col nodes))
    (test-equal '(0 1 0 2) (map cst-newlines-before nodes))
    (test-equal '(#f #f #t #f) (map cst-trailing-comment? nodes)))
  (let ((inner (cst-children (car (top "(f\n   x)")))))
    (test-equal '(1 2) (map cst-line inner))
    (test-equal '(1 3) (map cst-col inner))))

(test-group "predicates"
  (let ((nodes (top "; a\n#|b|# #;c d (e) . 1")))
    (test-equal '(#t #t #t #f #f #f #f) (map cst-comment? nodes))
    (test-equal '(#f #f #f #t #t #f #t) (map cst-code? nodes))
    (test-equal '(#f #f #f #f #t #f #f) (map cst-container? nodes))))

(test-group "round trip"
  (for-each (lambda (s) (test-assert s (round-trip? s)))
            '("" "  \n" "(a  [b] ; c\n)" "(define (f x)\n  ;; doc\n  x)\n"
              "#!/usr/bin/env scm\n(display 1)\n"
              "#| a #| b |# |#\n#;(skip me) (keep)\n"
              "(x #\\( #\\) #\\; #\\space #u8(1 2) #(a) |a b| `(,x ,@y) #'s)"
              "#0=(a . #0#)" "\"multi\nline\" ; t\n"
              "(srfi #<<END\nhello\n  END\nEND\n)\n" "'( a . b )\t\r\n")))

(test-group "cst->datum agrees with read"
  (for-each (lambda (s)
              (test-equal s (read-all s) (cst->datum (source-read-string s))))
            '("(a #;b c)" "'x `(a ,b ,@c)" "#(1 2) #u8(3)" "(a . b)" "[x y]"
              "#|c|# 42 ; t" "\"s\\ttr\"" "(srfi #<<END\nhello\nEND\n)"))
  (test-equal ''(a c) (cst->datum (car (top "'(a #;b c)")))))

(test-group "read errors"
  (test-equal '("x.scm" 1 0)
              (error-pos (lambda () (source-read-string "(a" "x.scm"))))
  (test-equal '("x.scm" 2 2)
              (error-pos (lambda () (source-read-string "a\n b)" "x.scm"))))
  (test-equal '("<string>" 1 2)
              (error-pos (lambda () (source-read-string "a \"bc"))))
  (test-equal '("<string>" 1 0)
              (error-pos (lambda () (source-read-string "#| open"))))
  (test-equal '("<string>" 1 0)
              (error-pos (lambda () (source-read-string "'"))))
  (test-equal '("<string>" 1 0)
              (error-pos (lambda () (source-read-string "#<<END\nx\n"))))
  (test-equal #f (source-read-error-position 'not-an-error)))

;; Every embedded library, when the source tree is around (the tests run
;; from the repository root or from a backend test directory).
(define lib-dir
  (let loop
      ((cands '("scm-lib/libraries" "../scm-lib/libraries"
                "../../scm-lib/libraries" "../../../scm-lib/libraries")))
    (cond ((null? cands) #f)
          ((file->string (string-append (car cands) "/scm-source.sld"))
           (car cands))
          (else (loop (cdr cands))))))

(when lib-dir
  (test-group "round trip of the library sources"
    (for-each (lambda (name)
                (let* ((path (string-append lib-dir "/" name))
                       (s (read-file-string path))
                       (cst (source-read-file path)))
                  (test-assert name (string=? s (cst->string cst)))
                  (test-assert name (equal? (read-all s) (cst->datum cst)))))
              '("scm-source.sld" "scm-toml.sld" "srfi-14.sld" "scm-data-r.sld"
                "scm-net-http-server.sld" "scheme-base.sld"))))

(test-end "scm source")
