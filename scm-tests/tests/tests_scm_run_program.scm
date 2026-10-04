(import (scheme base)
        (scm system)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-run-program")

;; Options of run-program: 'work-dir and 'env are both optional and
;; independent. Regression: an options alist WITHOUT 'work-dir (e.g. only
;; 'env) used to make run-program fail and return #f.

(define windows? (eq? (sys-platform) 'windows))

;; argv running a shell snippet: exit 0 iff env var X equals "1"
(define (check-x-argv)
  (if windows?
      (list "cmd" "/c" "if \"%X%\"==\"1\" (exit 0) else (exit 1)")
      (list "sh" "-c" "test \"$X\" = 1")))

(define (exit-argv code)
  (if windows?
      (list "cmd" "/c" (string-append "exit " (number->string code)))
      (list "sh" "-c" (string-append "exit " (number->string code)))))

(test-group "run-program options"
  (test-equal "no options" 0 (run-program (exit-argv 0)))
  (test-equal "exit code" 3 (run-program (exit-argv 3)))
  (test-equal "work-dir only" 0 (run-program (exit-argv 0) '((work-dir "."))))
  (test-equal "env without work-dir" 0
    (run-program (check-x-argv) '((env (("X" "1"))))))
  (test-equal "env value reaches child" 1
    (run-program (check-x-argv) '((env (("X" "2"))))))
  (test-equal "env with work-dir" 0
    (run-program (check-x-argv) '((work-dir ".") (env (("X" "1")))))))

(test-group "run-program/capture options"
  (test-equal "env without work-dir" 0
    (car (run-program/capture (check-x-argv) '((env (("X" "1")))))))
  (test-equal "no options" 0 (car (run-program/capture (exit-argv 0)))))

(test-end "scm-run-program")
