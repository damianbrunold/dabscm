;; Phase 1 tests: compile every program in scm-native/tests natively, run
;; it, and compare its output with the output of the JVM implementation.
;;
;; Usage: scm scm-native/test.scm [--gc-stress spec] [name ...]   (names without .scm)
;;   --gc-stress: the native programs run with SCM_NATIVE_GC_STRESS=spec
;;     (runtime/rt.zig: "words[,major]", e.g. 100)

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm fs)
        (scm module)
        (scm system))

(define native-dir (directory-name (normalized-path (absolute-path (car (command-line))))))
(module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))

(import (scm native driver))

(define base-dir (directory-name native-dir))
(define tests-dir (join-path native-dir "tests"))
(define build-dir (join-path native-dir "build"))
(define jar (join-path base-dir "scm-java" "scm.jar"))

(define gc-stress #f)
(define name-args
  (let loop ((args (cdr (command-line))) (acc '()))
    (cond ((null? args) (reverse acc))
          ((and (string=? (car args) "--gc-stress") (pair? (cdr args)))
           (set! gc-stress (cadr args)) (loop (cddr args) acc))
          (else (loop (cdr args) (cons (car args) acc))))))

(define (test-names)
  (let ((args name-args))
    (if (pair? args)
        args
        (map (lambda (f) (substring f 0 (- (string-length f) 4)))
             (filter (lambda (f) (and (> (string-length f) 4)
                                      (string=? (substring f (- (string-length f) 4) (string-length f)) ".scm")))
                     (list-sort string<? (directory-files tests-dir)))))))

(define (first-difference a b)
  (let loop ((i 0))
    (cond ((or (= i (string-length a)) (= i (string-length b))) i)
          ((char=? (string-ref a i) (string-ref b i)) (loop (+ i 1)))
          (else i))))

(define (excerpt s i)
  (substring s (max 0 (- i 40)) (min (string-length s) (+ i 40))))

(define (string-prefix? p s)
  (and (<= (string-length p) (string-length s))
       (string=? p (substring s 0 (string-length p)))))

(define failures 0)

(define (run-test name)
  (let* ((source (join-path tests-dir (string-append name ".scm")))
         (exe (join-path build-dir name))
         ;; both in the tests directory: the JVM finds the libraries of a
         ;; test there (lazy-*.sld), natively the program's directory
         (expected (run-program/capture (list "java" "-jar" jar source)
                                        (list (list 'work-dir tests-dir)))))
    (display name)
    (display " ... ")
    (guard (e (#t (set! failures (+ failures 1))
                  (display "COMPILE FAILED: ")
                  (display (if (error-object? e) (error-object-message e) e))
                  (when (error-object? e)
                    (for-each (lambda (x) (display " ") (display x)) (error-object-irritants e)))
                  (newline)))
      (compile-program source exe native-dir '())
      (let ((actual (run-program/capture (list exe)
                                         (cons (list 'work-dir tests-dir)
                                               (if gc-stress
                                                   (list (list 'env (list (cons "SCM_NATIVE_GC_STRESS" gc-stress))))
                                                   '())))))
        (cond ((and (= (car actual) (car expected))
                    (or (string=? (cadr actual) (cadr expected))
                        ;; a failing program: the JVM prints its error message
                        ;; to stdout, in its own format
                        (and (not (zero? (car expected)))
                             (string-prefix? (cadr actual) (cadr expected)))))
               (display "ok")
               (newline))
              (else
               (set! failures (+ failures 1))
               (display "FAILED")
               (newline)
               (let ((i (first-difference (cadr expected) (cadr actual))))
                 (display "  expected: ") (write (excerpt (cadr expected) i)) (newline)
                 (display "  actual:   ") (write (excerpt (cadr actual) i)) (newline))
               (unless (= (car actual) (car expected))
                 (display "  exit codes: ") (write (list (car expected) (car actual))) (newline))
               (unless (string=? (caddr actual) "")
                 (display "  stderr: ") (display (caddr actual)) (newline))))))))

(define names (test-names))
(for-each run-test names)
(newline)
(display (- (length names) failures))
(display " of ")
(display (length names))
(display " passed")
(newline)
(exit (if (zero? failures) 0 1))
