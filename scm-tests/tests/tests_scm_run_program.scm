(import (scheme base)
        (scheme file)
        (scheme write)
        (scm fs)
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
              (run-program (check-x-argv)
                           '((work-dir ".") (env (("X" "1")))))))

;; split s at newlines, without the empty last piece
(define (string-split-lines s)
  (let loop ((i 0) (start 0) (acc '()))
    (cond ((= i (string-length s))
           (reverse (if (< start i) (cons (substring s start i) acc) acc)))
          ((char=? (string-ref s i) #\newline)
           (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else (loop (+ i 1) start acc)))))

;; run-program hands the child the caller's stdin. The check: a child scm
;; started with a known stdin (run-program/capture 'stdin) prints its own fd 0
;; and lets run-program start readlink on the grandchild's fd 0: both name the
;; same pipe. Regression: Java gave the child a private stdin pipe, so a
;; program run with run-program never saw the terminal. Linux only (/proc).
(test-group "run-program stdin"
  (if (or windows? (not (read-symlink "/proc/self/fd/0")))
      (test-assert "skipped: no /proc/self/fd" #t)
      (let* ((tmp (mktemp))
             (script (string-append tmp ".scm")))
        (call-with-output-file script
          (lambda (o)
            (write '(import (scheme base) (scheme write) (scm fs) (scm system)) o)
            (write '(begin
                      (display (read-symlink "/proc/self/fd/0"))
                      (newline)
                      (flush-output-port)
                      (run-program '("readlink" "/proc/self/fd/0")))
                   o)))
        (let* ((r (run-program/capture (append (sys-scm-command) (list script))
                                       '((stdin "x"))))
               (lines (and r (string-split-lines (cadr r)))))
          (delete-file script)
          (delete-file tmp)
          (test-equal "child exit" 0 (and r (car r)))
          (test-assert "two lines" (and lines (= 2 (length lines))))
          (test-equal "the grandchild has the child's stdin"
                      (and lines (car lines))
                      (and lines (pair? (cdr lines)) (cadr lines)))))))

(test-group "run-program/capture options"
  (test-equal "env without work-dir" 0
              (car (run-program/capture (check-x-argv) '((env (("X" "1")))))))
  (test-equal "no options" 0 (car (run-program/capture (exit-argv 0)))))

(test-end "scm-run-program")
