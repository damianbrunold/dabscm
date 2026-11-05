(define-library (scm test)
  (export last-run-failed-tests
          last-run-total-tests
          scm-test-runner
          ;; re-export srfi 64-stuff
          test-apply
          test-approximate
          test-assert
          test-begin
          test-end
          test-eq
          test-equal
          test-eqv
          test-error
          test-expect-fail
          test-group
          test-group-with-cleanup
          test-match-all
          test-match-any
          test-match-name
          test-match-nth
          test-read-eval-string
          test-runner-factory
          test-skip
          test-with-runner)
  (import (scheme base)
          (scheme write)
          (srfi 64)
          (srfi 151)
          (scm io)
          (scm module))
  (begin
    ;; Records a non-zero process exit code without terminating, so a standalone
    ;; test run signals failure via its exit status while the in-process test
    ;; harness (which reads last-run-failed-tests) is unaffected.
    (define %set-exit-code! (%primitive "set-exit-code!"))

    (define *last-total* 0)
    (define *last-failed* 0)

    (define (last-run-total-tests) *last-total*)
    (define (last-run-failed-tests) *last-failed*)

    (define (scm-test-runner)
      (let ((runner (test-runner-null))
            (name #f)
            (group #f)
            (success #t))
        (test-runner-on-group-begin! runner
                                     (lambda (runner suite-name count)
                                       (if (not name)
                                           (set! name suite-name)
                                           (set! group suite-name))))
        (test-runner-on-test-end! runner
                                  (lambda (runner)
                                    (unless (test-passed? runner)
                                      (when success (format #t "~a~%" name))
                                      (set! success #f)
                                      (let
                                          ((test-name
                                            (test-runner-test-name runner))
                                           (source-file
                                            (test-result-ref runner
                                                             'source-file))
                                           (source-line
                                            (test-result-ref runner
                                                             'source-line)))
                                        (if
                                         (and source-file source-line)
                                         (if
                                          test-name
                                          (format #t "FAILED ~a:~a ~a ~a~%"
                                                  source-file source-line
                                                  group test-name)
                                          (format #t "FAILED ~a:~a ~a~%"
                                                  source-file source-line
                                                  group))
                                         (if
                                          test-name
                                          (format #t "FAILED ~a ~a~%" group
                                                  test-name)
                                          (format #t "FAILED ~a~%" group))))
                                      (when
                                          (test-result-ref runner
                                                           'source-form)
                                        (format
                                         #t
                                         "code:     ~a~%"
                                         (test-result-ref runner
                                                          'source-form)))
                                      (format
                                       #t
                                       "expected: ~a~%"
                                       (test-result-ref runner
                                                        'expected-value))
                                      (format
                                       #t
                                       "actual:   ~a~%"
                                       (test-result-ref runner 'actual-value))
                                      (when
                                          (test-result-ref runner
                                                           'actual-error)
                                        (format
                                         #t
                                         "error:~%~a~%"
                                         (test-result-ref runner
                                                          'actual-error))))))
        (test-runner-on-final! runner
                               (lambda (runner)
                                 (let* ((pass (test-runner-pass-count runner))
                                        (xpass
                                         (test-runner-xpass-count runner))
                                        (fail (test-runner-fail-count runner))
                                        (xfail
                                         (test-runner-xfail-count runner))
                                        (total (+ pass xpass fail xfail))
                                        (failed (+ xpass fail)))
                                   (format
                                    #t
                                    "  ~-25a ~4d ~a~%"
                                    name
                                    total
                                    (if
                                     (= 0 failed)
                                     "OK"
                                     (format #f "FAIL, ~a failed tests"
                                             failed)))
                                   (set! *last-total* total)
                                   (set! *last-failed* failed)
                                   ;; Signal failure through the process exit code (deferred, so all
                                   ;; suites in a file still run). Never resets to 0, so an earlier
                                   ;; failing suite is not masked by a later passing one.
                                   (when (> failed 0) (%set-exit-code! 1)))))
        runner))))
