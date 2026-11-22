;; scm as a native program: a REPL, -e, and scripts, over the native eval.
;;
;; Build: scm scm-native/scmc.scm scm-native/tools/scm.scm -o scm-native/build/scm
;;
;; Usage: scm                      the REPL (line editing on a terminal)
;;        scm -e expr              prints the value of expr
;;        scm script.scm arg ...   runs the script
;;        scm fmt|lint|new-app ...  the built-in tools, as on the JVM
;;
;; The libraries imported here are compiled into the executable; a script or
;; the REPL importing others loads them from source and interprets them.

(import (scheme base)
        (scheme case-lambda)
        (scheme char)
        (scheme complex)
        (scheme cxr)
        (scheme eval)
        (scheme file)
        (scheme inexact)
        (scheme lazy)
        (scheme load)
        (scheme process-context)
        (scheme read)
        (scheme repl)
        (scheme time)
        (scheme write)
        (srfi 1)
        (srfi 13)
        (srfi 69)
        (srfi 132)
        (scm fs)
        (scm io)
        (scm string)
        (scm system)
        (scm terminal))

(define (error-text e)
  (let ((out (open-output-string)))
    (cond ((error-object? e)
           (display (error-object-message e) out)
           (for-each (lambda (x) (write-char #\space out) (write x out)) (error-object-irritants e)))
          (else (display "uncaught exception: " out) (write e out)))
    (get-output-string out)))

(define (report-error e)
  (let ((err (current-error-port)))
    (display (error-text e) err)
    (newline err)
    (flush-output-port err)))

(define (print-value v)
  (write v)
  (newline)
  (flush-output-port))

;; --- reading a datum from text ---------------------------------------------

;; The data in text, or 'incomplete if the text ends inside a datum
(define (read-all text)
  (guard (e (#t (if (and (error-object? e)
                         (let ((m (error-object-message e)))
                           (or (string-contains m "end of file")
                               (string-contains m "unterminated"))))
                    'incomplete
                    (raise e))))
    (let ((p (open-input-string text)))
      (let loop ((acc '()))
        (let ((x (read p)))
          (if (eof-object? x) (reverse acc) (loop (cons x acc))))))))

;; --- line editor -------------------------------------------------------------

(define history-file
  (or (get-environment-variable "DABSCM_HISTORY")
      (let ((home (get-environment-variable "HOME")))
        (and home (string-append home "/.dabscm-history")))))

(define history
  (if (and history-file (file-exists? history-file))
      (reverse (filter (lambda (l) (not (string=? l ""))) (read-file-lines history-file)))
      '()))

(define (remember! line)
  (unless (or (string=? line "") (and (pair? history) (string=? line (car history))))
    (set! history (cons line history))
    (when history-file
      (guard (e (#t #f))
        (call-with-output-file history-file
          (lambda (p)
            (for-each (lambda (l) (write-string l p) (newline p))
                      (reverse (if (> (length history) 1000) (take history 1000) history)))))))))

(define (out s) (write-string s) (flush-output-port))

;; Read one line with editing; #f at end of input (ctrl-d on an empty line)
(define (edit-line prompt)
  (let loop ((text "") (pos 0) (hist -1) (saved ""))
    (define (redraw text pos)
      (out (string-append "\r" prompt text "\x1b;[K"))
      (let ((back (string-width (substring text pos (string-length text)))))
        (when (> back 0) (out (string-append "\x1b;[" (number->string back) "D")))))
    (redraw text pos)
    (let ((k (terminal-read-key)))
      (cond ((eof-object? k) #f)
            ((or (eq? k 'enter) (eqv? k #\return) (eqv? k #\newline))
             (out "\r\n")
             text)
            ((and (eq? k 'ctrl-d) (string=? text "")) (out "\r\n") #f)
            ((eq? k 'ctrl-c) (out "\r\n") (loop "" 0 -1 ""))
            ((or (char? k) (string? k))
             (let ((s (if (char? k) (string k) k)))
               (loop (string-append (substring text 0 pos) s (substring text pos (string-length text)))
                     (+ pos (string-length s)) hist saved)))
            ((and (eq? k 'backspace) (> pos 0))
             (loop (string-append (substring text 0 (- pos 1)) (substring text pos (string-length text)))
                   (- pos 1) hist saved))
            ((and (memq k '(delete ctrl-d)) (< pos (string-length text)))
             (loop (string-append (substring text 0 pos) (substring text (+ pos 1) (string-length text)))
                   pos hist saved))
            ((and (memq k '(left ctrl-b)) (> pos 0)) (loop text (- pos 1) hist saved))
            ((and (memq k '(right ctrl-f)) (< pos (string-length text))) (loop text (+ pos 1) hist saved))
            ((memq k '(home ctrl-a)) (loop text 0 hist saved))
            ((memq k '(end ctrl-e)) (loop text (string-length text) hist saved))
            ((eq? k 'ctrl-k) (loop (substring text 0 pos) pos hist saved))
            ((and (memq k '(up ctrl-p)) (< (+ hist 1) (length history)))
             (let ((l (list-ref history (+ hist 1))))
               (loop l (string-length l) (+ hist 1) (if (= hist -1) text saved))))
            ((and (memq k '(down ctrl-n)) (>= hist 0))
             (let ((l (if (= hist 0) saved (list-ref history (- hist 1)))))
               (loop l (string-length l) (- hist 1) saved)))
            (else (loop text pos hist saved))))))

;; --- the REPL ------------------------------------------------------------------

(define env (interaction-environment))

(define (eval-and-print forms)
  (for-each (lambda (f)
              (guard (e (#t (report-error e)))
                (call-with-values (lambda () (eval f env))
                  (lambda vs (for-each print-value vs)))))
            forms))

(define (repl-terminal)
  (let loop ((pending ""))
    (let ((line (with-terminal-raw (lambda () (edit-line (if (string=? pending "") "> " "  "))))))
      (when line
        (let* ((text (if (string=? pending "") line (string-append pending "\n" line)))
               (forms (guard (e (#t (report-error e) '())) (read-all text))))
          (cond ((eq? forms 'incomplete) (loop text))
                (else
                 ;; one line in the history (and its file)
                 (remember! (string-map (lambda (c) (if (char=? c #\newline) #\space c))
                                        (string-trim-both text)))
                 (eval-and-print forms)
                 (loop ""))))))))

;; stdin is not a terminal: read data, print values
(define (repl-cooked)
  (let loop ()
    (let ((x (guard (e (#t (report-error e) #f)) (read))))
      (unless (eof-object? x)
        (when x (eval-and-print (list x)))
        (loop)))))

;; --- scripts -------------------------------------------------------------------

(define (run-script file args)
  ((%primitive "%set-command-line!") (cons file args))
  (let ((e (environment)))
    (eval `(define script-name ,file) e)
    (eval `(define script-arguments ',args) e)
    (guard (x (#t (report-error x) (exit 1)))
      (load file e))))

;; the built-in tools (scm new-app, scm fmt, scm lint), as the JVM
;; implementation's, unless there is a script of that name
(define builtin-tools
  '(("new-app" . "(import (scm scaffold)) (new-app-command script-arguments)")
    ("fmt" . "(import (scm source format)) (fmt-command script-arguments)")
    ("lint" . "(import (scm source lint)) (lint-command script-arguments)")))

(define (run-tool name code args)
  ((%primitive "%set-command-line!") (cons name args))
  (let ((e (environment)))
    (eval `(define script-name ,name) e)
    (eval `(define script-arguments ',args) e)
    (guard (x (#t (report-error x) (exit 1)))
      (let loop ((forms (read-all code)) (v #f))
        (if (null? forms)
            (exit (if (exact-integer? v) v 0))
            (loop (cdr forms) (eval (car forms) e)))))))

(let ((args (cdr (command-line))))
  (cond ((null? args)
         (if (terminal?) (repl-terminal) (repl-cooked)))
        ((and (string=? (car args) "-e") (pair? (cdr args)))
         (guard (e (#t (report-error e) (exit 1)))
           (let ((forms (read-all (cadr args))))
             (when (eq? forms 'incomplete) (error "-e: incomplete expression"))
             (let loop ((fs forms) (v (if #f #f)))
               (if (null? fs)
                   (print-value v)
                   (loop (cdr fs) (eval (car fs) env)))))))
        ((and (assoc (car args) builtin-tools) (not (file-exists? (car args))))
         (run-tool (car args) (cdr (assoc (car args) builtin-tools)) (cdr args)))
        (else (run-script (car args) (cdr args)))))
