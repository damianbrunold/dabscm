;; Run the library tests (scm-tests/tests) natively.
;;
;; As the JVM harness (SchemeTests.runTestsTest), each file runs as a
;; program and reports through (scm test): the number of tests and of
;; failures of its last run.
;;
;; Usage: scm scm-native/lib-tests.scm [--target triple] [--run-with cmd] [--gc-stress spec] [-O mode] [name ...]
;;        (e.g. tests_scm_string)

(import (scheme base)
        (scheme file)
        (scheme process-context)
        (scheme read)
        (scheme time)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm fs)
        (scm io)
        (scm module)
        (scm system))

(define native-dir (directory-name (normalized-path (absolute-path (car (command-line))))))

;; Windows: executables end in .exe, and there is no timeout command
(define windows? (eq? (sys-platform) 'windows))
(define (exe-name base) (if windows? (string-append base ".exe") base))
(define (with-timeout secs exe)
  (if windows?
      (append run-with (list exe))
      ;; the stress mode is slower: 20 times the time
      (append (list "timeout" (if gc-stress (number->string (* 20 (string->number secs))) secs)) run-with (list exe))))
;; --target triple cross-compiles; --run-with cmd runs the executables under
;; cmd (e.g. --target aarch64-linux-musl --run-with qemu-aarch64)
;; --gc-stress spec runs the executables with SCM_NATIVE_GC_STRESS=spec (see
;; runtime/rt.zig: "words[,major]", e.g. 100), -O mode builds them in that
;; mode (e.g. ReleaseSafe, with Zig's checks)
(define target #f)
(define run-with '())
(define gc-stress #f)
(define optimize #f)
(define name-args
  (let loop ((args (cdr (command-line))) (acc '()))
    (cond ((null? args) (reverse acc))
          ((and (string=? (car args) "--target") (pair? (cdr args)))
           (set! target (cadr args)) (loop (cddr args) acc))
          ((and (string=? (car args) "--run-with") (pair? (cdr args)))
           (set! run-with (list (cadr args))) (loop (cddr args) acc))
          ((and (string=? (car args) "--gc-stress") (pair? (cdr args)))
           (set! gc-stress (cadr args)) (loop (cddr args) acc))
          ((and (string=? (car args) "-O") (pair? (cdr args)))
           (set! optimize (cadr args)) (loop (cddr args) acc))
          (else (loop (cdr args) (cons (car args) acc))))))
(define compile-options
  (append (if target (list (cons 'target target)) '())
          (if optimize (list (cons 'optimize optimize)) '())))
;; the options of a test executable's run
(define (run-options . more)
  (append more
          (if gc-stress (list (list 'env (list (cons "SCM_NATIVE_GC_STRESS" gc-stress)))) '())))
(define exe-suffix (if target (string-append "-" target) ""))

(module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))

(import (scm native driver))

(define base-dir (directory-name native-dir))
(define tests-dir (join-path base-dir "scm-tests" "tests"))
(define build-dir (join-path native-dir "build"))

(define epilogue
  "\n(import (scm test) (scheme write))\n(display \"tests: \") (display (last-run-total-tests)) (display \" failures: \") (display (last-run-failed-tests)) (newline)\n")

(define (string-suffix? suffix s)
  (and (>= (string-length s) (string-length suffix))
       (string=? suffix (substring s (- (string-length s) (string-length suffix)) (string-length s)))))

(define (names)
  (let ((args name-args))
    (if (pair? args)
        args
        (map (lambda (f) (substring f 0 (- (string-length f) 4)))
             (list-sort string<? (filter (lambda (f) (string-suffix? ".scm" f)) (directory-files tests-dir)))))))

(define (last-line s)
  (let loop ((i (- (string-length s) 2)))
    (cond ((< i 0) s)
          ((char=? (string-ref s i) #\newline) (substring s (+ i 1) (string-length s)))
          (else (loop (- i 1))))))

(unless (directory-exists? build-dir) (make-directory build-dir))
(define summary '())
;; compile and run times, per test and in total
(define compile-secs 0)
(define run-secs 0)
(define (seconds jiffies) (/ jiffies (jiffies-per-second)))
(define (seconds-text jiffies)
  (number->string (/ (round (* 10 (seconds jiffies))) 10.)))
(for-each
 (lambda (name)
   (let* ((started (current-jiffy))
          (compiled #f)
          (source (join-path tests-dir (string-append name ".scm")))
          (program (join-path build-dir (string-append "lib-" name ".scm")))
          (exe (join-path build-dir (exe-name (string-append "lib-" name exe-suffix)))))
     (call-with-output-file program
       (lambda (p) (write-string (file->string source) p) (write-string epilogue p)))
     (let ((result
            (guard (e (#t (string-append "COMPILE FAILED: "
                                         (if (error-object? e)
                                             (let* ((p (open-output-string))
                                                    (_ (begin (display (error-object-message e) p)
                                                              (for-each (lambda (x) (display " " p) (write x p))
                                                                        (error-object-irritants e))))
                                                    (m (get-output-string p)))
                                               (if (> (string-length m) 300) (substring m 0 300) m))
                                             "?"))))
              (compile-program program exe native-dir compile-options)
              (set! compiled (current-jiffy))
              ;; run in the tests directory, as the JVM harness does from its resources
              (let ((r (run-program/capture (with-timeout "300" exe) (run-options (list 'work-dir tests-dir)))))
                (string-append
                 (let ((l (last-line (cadr r))))
                   (if (and (> (string-length l) 6) (string=? (substring l 0 6) "tests:"))
                       (substring l 0 (- (string-length l) 1))
                       (string-append "no result, exit " (number->string (car r)))))
                 (if (string=? (caddr r) "")
                     ""
                     (string-append "  stderr: " (let ((e (caddr r))) (if (> (string-length e) 160) (substring e 0 160) e)))))))))
       ;; keep the executables of failing tests only (each is several MB)
       (when (and (string-suffix? " failures: 0" result) (file-exists? exe))
         (delete-file exe))
       (let ((end (current-jiffy)))
         (set! compile-secs (+ compile-secs (seconds (- (or compiled end) started))))
         (set! run-secs (+ run-secs (if compiled (seconds (- end compiled)) 0)))
         (display name) (display ": ") (display result)
         (display "  [compile ") (display (seconds-text (- (or compiled end) started)))
         (when compiled (display ", run ") (display (seconds-text (- end compiled))))
         (display "]") (newline))
       (set! summary (cons (cons name result) summary)))))
 (names))
(display "compile ") (display (round (inexact compile-secs)))
(display " s, run ") (display (round (inexact run-secs))) (display " s") (newline)
