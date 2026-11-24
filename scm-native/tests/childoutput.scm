;; a child's output files: 'append #t appends, and stdout and stderr in one
;; file ('log-file, 'stderr 'stdout) keep both (on Windows the child got a
;; file object of its own with its pointer at 0, so that it overwrote the
;; file's start and stdout and stderr overwrote each other)
(import (scheme base) (scheme write) (scheme file) (scm fs) (scm system))

(define (sh script)
  (cond-expand
    (windows (list "cmd" "/c" script))
    (else (list "sh" "-c" script))))

(define both (sh (cond-expand (windows "echo out& echo err 1>&2& echo out2")
                              (else "echo out; echo err 1>&2; echo out2"))))
(define out-only (sh "echo out"))

(define (contents f)
  (let ((s (call-with-input-file f (lambda (p) (read-string 10000 p)))))
    (delete-file f)
    ;; cmd ends lines with CR LF and keeps the blank before 1>&2
    (let loop ((cs (filter-cr (string->list (if (eof-object? s) "" s)))) (acc '()))
      (cond ((null? cs) (list->string (reverse acc)))
            ((and (char=? (car cs) #\space) (pair? (cdr cs)) (char=? (cadr cs) #\newline))
             (loop (cdr cs) acc))
            (else (loop (cdr cs) (cons (car cs) acc)))))))

(define (filter-cr cs)
  (cond ((null? cs) '())
        ((char=? (car cs) #\return) (filter-cr (cdr cs)))
        (else (cons (car cs) (filter-cr (cdr cs))))))

(define (put f s) (call-with-output-file f (lambda (p) (write-string s p))))

(define (show label f) (display label) (display ": ") (write (contents f)) (newline))

(put "co-append.txt" "old-old-old\n")
(run-program out-only '((stdout "co-append.txt") (append #t)))
(show "run-program append" "co-append.txt")

(put "co-start.txt" "old-old-old\n")
(process-wait (start-program out-only '((stdout "co-start.txt") (append #t))))
(show "start-program append" "co-start.txt")

(put "co-trunc.txt" "old-old-old-old-old\n")
(run-program out-only '((stdout "co-trunc.txt")))
(show "truncated" "co-trunc.txt")

(run-program both '((stdout "co-both.txt") (stderr stdout)))
(show "stderr to stdout" "co-both.txt")

(put "co-both2.txt" "old\n")
(run-program both '((stdout "co-both2.txt") (stderr stdout) (append #t)))
(show "stderr to stdout, append" "co-both2.txt")

(process-wait (start-program both '((log-file "co-log.txt"))))
(show "log-file" "co-log.txt")

(put "co-log2.txt" "old\n")
(process-wait (start-program both '((log-file "co-log2.txt") (append #t))))
(show "log-file append" "co-log2.txt")

(run-program both '((stdout "co-out.txt") (stderr "co-err.txt")))
(show "stdout" "co-out.txt")
(show "stderr" "co-err.txt")
