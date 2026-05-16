(define-library (scm system)
  (import (only (scm core) modules)
          (scheme base)
          (srfi 18))
  (export get-environment-variable
          get-bytes
          modules
          process-alive?
          process-kill
          process-pid
          process-wait
          run-parallel
          run-program
          start-program
          sys-machine-name
          sys-num-cpu-cores
          sys-os-version
          sys-platform
          sys-scm-technology
          sys-scm-version
          sys-user-name)
  (begin
    (define get-environment-variable (%primitive "get-environment-variable"))
    (define get-bytes (%primitive "get-bytes"))
    (define process-alive? (%primitive "process-alive?"))
    (define process-kill   (%primitive "process-kill"))
    (define process-pid    (%primitive "process-pid"))
    (define process-wait   (%primitive "process-wait"))
    (define run-program (%primitive "run-program"))
    (define start-program (%primitive "start-program"))
    (define (run-parallel fn values)
      "Syntax: (run-parallel fn values)
Library: (scm system)
Description: Runs fn in parallel over each element of values using one thread per
  element and returns the results as a list in the same order. Exceptions raised
  in any thread are propagated when joining.
Example:
  (run-parallel (lambda (x) (* x x)) '(1 2 3 4)) => (1 4 9 16)"
      (let* ((threads (map (lambda (v)
                             (make-thread (lambda () (fn v))))
                           values))
             (_ (for-each thread-start! threads)))
        (map thread-join! threads)))
    (define sys-machine-name (%primitive "sys-machine-name"))
    (define sys-num-cpu-cores (%primitive "sys-num-cpu-cores"))
    (define sys-os-version (%primitive "sys-os-version"))
    (define sys-platform (%primitive "sys-platform"))
    (define sys-scm-technology (%primitive "sys-scm-technology"))
    (define sys-scm-version (%primitive "sys-scm-version"))
    (define sys-user-name (%primitive "sys-user-name"))))
