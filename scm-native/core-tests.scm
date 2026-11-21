;; Run the core tests (scm-tests/core) natively.
;;
;; The JVM harness (SchemeTests.runCoreTest) evaluates each file form by
;; form; a (test-group ...) holds assertions (=> expr expected) that compare
;; the printed representations of expr and expected. Here each file becomes
;; a program: the forms stay top-level forms, every assertion becomes a call
;; of a checking procedure, and the program reports the counts at the end.
;; (The JVM harness also resets the state after each group; this one does
;; not.)
;;
;; The JVM harness evaluates the forms one at a time, like a REPL: a
;; continuation captured in a form ends with that form, and re-entering it
;; continues with the next form not yet read. To get the same behavior, each
;; form becomes a thunk, run in order by a loop whose position is a mutable
;; variable; definitions stay at top level and get their values in the
;; thunks.
;;
;; Usage: scm scm-native/core-tests.scm [name ...]   (e.g. tests_r7rs)

(import (scheme base)
        (scheme file)
        (scheme process-context)
        (scheme read)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm fs)
        (scm module)
        (scm system))

(define native-dir (directory-name (absolute-path (car (command-line)))))
(module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))

(import (scm native driver))

(define base-dir (directory-name native-dir))
(define core-dir (join-path base-dir "scm-tests" "core"))
(define build-dir (join-path native-dir "build"))

;; The checking procedure: only primitives, so it does not depend on what
;; the test file imports.
(define prelude
  '((define %t-tests 0)
    (define %t-failures 0)
    (define %t-display (%primitive "display"))
    (define %t-write (%primitive "write"))
    (define %t-newline (%primitive "newline"))
    (define %t-rep
      (lambda (v)
        ((lambda (p) ((%primitive "write") v p) ((%primitive "get-output-string") p))
         ((%primitive "open-output-string")))))
    (define %t-fail
      (lambda (where code)
        (set! %t-failures ((%primitive "+") %t-failures 1))
        (%t-display "  FAIL at ") (%t-display where) (%t-newline)
        (%t-display "    code:     ") (%t-write code) (%t-newline)))
    (define %t-check
      (lambda (where code thunk expected-thunk)
        (set! %t-tests ((%primitive "+") %t-tests 1))
        ((%primitive "call-with-current-continuation")
         (lambda (k)
           ((lambda (saved)
              ((%primitive "%exception-handlers-set!")
               ((%primitive "list")
                (lambda (e)
                  ((%primitive "%exception-handlers-set!") saved)
                  (%t-fail where code)
                  (%t-display "    exception: ")
                  (if ((%primitive "error-object?") e)
                      (begin (%t-display ((%primitive "error-object-message") e))
                             (%t-display " ")
                             (%t-write ((%primitive "error-object-irritants") e)))
                      (%t-write e))
                  (%t-newline)
                  (k #f))))
              ((lambda (actual)
                 ((lambda (expected-value)
                    ((lambda (expected)
                       ((%primitive "%exception-handlers-set!") saved)
                       (if ((%primitive "not") ((%primitive "string=?") actual expected))
                           (begin (%t-fail where code)
                                  (%t-display "    expected: ") (%t-display expected) (%t-newline)
                                  (%t-display "    actual:   ") (%t-display actual) (%t-newline))))
                     (if (if ((%primitive "string?") expected-value)
                             (if ((%primitive ">=") ((%primitive "string-length") expected-value) 2)
                                 ((%primitive "string=?") ((%primitive "substring") expected-value 0 2) "#<")
                                 #f)
                             #f)
                         expected-value
                         (%t-rep expected-value))))
                  (expected-thunk)))
               (%t-rep (thunk))))
            ((%primitive "%exception-handlers-get")))))))))

(define driver
  '((define %t-thunks '())
    (define %t-add! (lambda (thunk) (set! %t-thunks ((%primitive "cons") thunk %t-thunks))))))

(define epilogue
  '((define %t-next 0)
    (define %t-all ((%primitive "list->vector") ((%primitive "reverse") %t-thunks)))
    ((lambda ()
       (define (loop)
         (if ((%primitive "<") %t-next ((%primitive "vector-length") %t-all))
             (begin
               ((lambda (i)
                  (set! %t-next ((%primitive "+") i 1))
                  (((%primitive "vector-ref") %t-all i)))
                %t-next)
               (loop))))
       (loop)))
    (%t-display "tests: ") (%t-display %t-tests)
    (%t-display " failures: ") (%t-display %t-failures) (%t-newline)))

(define (read-forms file)
  (call-with-input-file file
    (lambda (port)
      (let loop ((acc '()))
        (let ((x (read port)))
          (if (eof-object? x) (reverse acc) (loop (cons x acc))))))))

(define (transform-group name group-index body)
  (let loop ((forms body) (i 1) (acc '()))
    (cond ((null? forms) (reverse acc))
          ((and (pair? (car forms)) (eq? (caar forms) '=>))
           (let* ((f (car forms))
                  (where (string-append name " group " (number->string group-index)
                                        " assertion " (number->string i))))
             (loop (cdr forms) (+ i 1)
                   (cons `(%t-check ,where ',(cadr f) (lambda () ,(cadr f)) (lambda () ,(caddr f)))
                         acc))))
          (else (loop (cdr forms) i (cons (car forms) acc))))))

(define (definition-name f)
  (and (pair? f) (eq? (car f) 'define)
       (let ((target (cadr f)))
         (let loop ((t target)) (if (pair? t) (loop (car t)) t)))))

(define (definition-value f)
  (let ((target (cadr f)))
    (if (pair? target)
        (let loop ((target target) (body (cddr f)))
          (if (pair? (car target))
              (loop (car target) (list `(lambda ,(cdr target) ,@body)))
              `(lambda ,(cdr target) ,@body)))
        (if (pair? (cddr f)) (caddr f) #f))))

;; A top-level form as run by the driver
(define (thunked f)
  (cond ((definition-name f)
         => (lambda (name)
              (list `(define ,name #f)
                    `(%t-add! (lambda () (set! ,name ,(definition-value f)))))))
        ((and (pair? f) (memq (car f) '(define-syntax define-record-type import define-library begin)))
         (list f))
        (else (list `(%t-add! (lambda () ,f))))))

(define (generate name)
  (let* ((forms (read-forms (join-path core-dir (string-append name ".scm"))))
         (out (join-path build-dir (string-append "core-" name ".scm"))))
    (let loop ((forms (cdr forms)) (g 1) (acc '()))
      (if (null? forms)
          (call-with-output-file out
            (lambda (p)
              (for-each (lambda (f) (write f p) (newline p))
                        (append (list (car (read-forms (join-path core-dir (string-append name ".scm")))))
                                prelude
                                driver
                                (append-map thunked (reverse acc))
                                epilogue))))
          (let ((f (car forms)))
            (if (and (pair? f) (eq? (car f) 'test-group))
                (loop (cdr forms) (+ g 1) (append (reverse (transform-group name g (cdr f))) acc))
                (loop (cdr forms) g (cons f acc))))))
    out))

(define (names)
  (let ((args (cdr (command-line))))
    (if (pair? args)
        args
        (map (lambda (f) (substring f 0 (- (string-length f) 4)))
             (list-sort string<? (filter (lambda (f) (string-suffix? ".scm" f)) (directory-files core-dir)))))))

(define (string-suffix? suffix s)
  (and (>= (string-length s) (string-length suffix))
       (string=? suffix (substring s (- (string-length s) (string-length suffix)) (string-length s)))))

(unless (directory-exists? build-dir) (make-directory build-dir))
(for-each
 (lambda (name)
   (display "== ") (display name) (newline)
   (guard (e (#t (display "COMPILE FAILED: ")
                 (display (if (error-object? e) (error-object-message e) e))
                 (when (error-object? e)
                   (for-each (lambda (x) (display " ") (write x)) (error-object-irritants e)))
                 (newline)))
     (let* ((source (generate name))
            (exe (join-path build-dir (string-append "core-" name))))
       (compile-program source exe native-dir '())
       (let ((r (run-program/capture (list "timeout" "120" exe))))
         (display (cadr r))
         (unless (string=? (caddr r) "") (display "stderr: ") (display (caddr r)))
         (unless (zero? (car r)) (display "exit code: ") (display (car r)) (newline))))))
 (names))
