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


;; the lines of a file, without carriage returns (cmd writes CR LF)
(define (file-lines path)
  (if (file-exists? path)
      (let ((text (call-with-input-file path
                    (lambda (in)
                      (let loop ((acc '()))
                        (let ((c (read-char in)))
                          (if (eof-object? c)
                              (list->string (reverse acc))
                              (loop (if (char=? c #\return) acc (cons c acc))))))))))
        (map (lambda (l) (string-trim-right-spaces l)) (string-split-lines text)))
      'missing))

(define (string-trim-right-spaces s)
  (let loop ((n (string-length s)))
    (if (and (> n 0) (char=? (string-ref s (- n 1)) #\space))
        (loop (- n 1))
        (substring s 0 n))))

;; a list of strings in order
(define (sorted ls)
  (if (or (not (pair? ls)) (null? (cdr ls)))
      ls
      (let insert ((x (car ls)) (rest (sorted (cdr ls))))
        (cond ((null? rest) (list x))
              ((string<=? x (car rest)) (cons x rest))
              (else (cons (car rest) (insert x (cdr rest))))))))

;; argv copying stdin to stdout
(define cat-argv (if windows? '("findstr" "^") '("cat")))

;; argv writing "out" to stdout, then "err" to stderr
(define out-err-argv
  (if windows?
      '("cmd" "/c" "echo out& echo err 1>&2")
      '("sh" "-c" "echo out; echo err 1>&2")))

(define out-file "run-program-out.tmp")
(define err-file "run-program-err.tmp")
(define in-file "run-program-in.tmp")

(define (clean)
  (for-each (lambda (f) (when (file-exists? f) (delete-file f)))
            (list out-file err-file in-file)))

(test-group "run-program redirections"
  (clean)
  (test-equal "stdin text to a stdout file" 0
              (run-program cat-argv `((stdin "one\ntwo\n") (stdout ,out-file))))
  (test-equal "the file" '("one" "two") (file-lines out-file))
  (test-equal "stdout and stderr files" 0
              (run-program out-err-argv `((stdout ,out-file) (stderr ,err-file))))
  (test-equal "stdout" '("out") (file-lines out-file))
  (test-equal "stderr" '("err") (file-lines err-file))
  (test-equal "stderr to stdout" 0
              (run-program out-err-argv `((stdout ,out-file) (stderr stdout))))
  ;; in either order: on .NET two pipes are copied into the file
  (test-equal "both in the file" '("err" "out") (sorted (file-lines out-file)))
  (run-program out-err-argv `((stdout ,out-file) (stderr ,err-file) (append #t)))
  (test-equal "appended" '("err" "out" "out") (sorted (file-lines out-file)))
  (test-equal "stderr appended" '("err" "err") (file-lines err-file))
  (call-with-output-file in-file (lambda (o) (write-string "from a file\n" o)))
  (test-equal "stdin-file" 0
              (run-program cat-argv `((stdin-file ,in-file) (stdout ,out-file))))
  (test-equal "the copy" '("from a file") (file-lines out-file))
  (test-equal "a child that does not read its stdin" 0
              (run-program (exit-argv 0) `((stdin ,(make-string 200000 #\x)))))
  (clean))

(test-group "start-program redirections"
  (clean)
  (let ((p (start-program cat-argv `((stdin "started\n") (stdout ,out-file)))))
    (test-equal "exit" 0 (process-wait p))
    (test-equal "the file" '("started") (file-lines out-file)))
  (let ((p (start-program out-err-argv `((log-file ,out-file) (append #t)))))
    (process-wait p)
    (test-equal "log-file appended" 3 (length (file-lines out-file))))
  (clean))

;; 'new-group: the child leads a process group of its own (Linux: /proc)
(test-group "start-program new-group"
  (if (or windows? (not (file-exists? "/proc/self/stat")))
      (test-assert "skipped: no /proc" #t)
      (let ((leader '("sh" "-c" "test \"$(cut -d' ' -f5 /proc/$$/stat)\" = $$")))
        (test-equal "new group" 0 (process-wait (start-program leader '((new-group #t)))))
        (test-equal "else the caller's group" 1 (process-wait (start-program leader))))))

(test-group "interrupts"
  (test-equal "the mode at the start" 'default (set-interrupt-handler! 'record))
  (test-equal "nothing recorded" #f (take-interrupt!))
  (unless windows?
    ;; Ctrl+C as SIGINT from kill
    (run-program (list "kill" "-INT" (number->string (current-pid))))
    (test-equal "recorded" #t
                (let loop ((i 0))
                  (cond ((take-interrupt!) #t)
                        ((< i 100) (sleep 0.02) (loop (+ i 1)))
                        (else #f))))
    (test-equal "taken" #f (take-interrupt!))
    (test-equal "ignore" 'record (set-interrupt-handler! 'ignore))
    (run-program (list "kill" "-INT" (number->string (current-pid))))
    (sleep 0.2)
    (test-equal "ignored, not recorded" #f (take-interrupt!)))
  (test-equal "back" (if windows? 'record 'ignore) (set-interrupt-handler! 'default))
  (test-error "an unknown mode" #t (set-interrupt-handler! 'other)))

(test-end "scm-run-program")
