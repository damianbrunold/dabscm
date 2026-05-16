(define-library (srfi 18)
  (import (scheme base) (srfi 19))
  (export
    ;; Threads
    current-thread thread? make-thread thread-name
    thread-specific thread-specific-set!
    thread-start! thread-yield! thread-sleep!
    thread-terminate! thread-join!
    ;; Mutexes
    mutex? make-mutex mutex-name
    mutex-specific mutex-specific-set!
    mutex-state mutex-lock! mutex-unlock!
    ;; Condition variables
    condition-variable? make-condition-variable
    condition-variable-name
    condition-variable-specific condition-variable-specific-set!
    condition-variable-signal! condition-variable-broadcast!
    ;; Time (re-exported from SRFI-19 + compatibility wrappers)
    current-time time? time->seconds seconds->time
    ;; Exceptions
    current-exception-handler with-exception-handler raise
    join-timeout-exception? abandoned-mutex-exception?
    terminated-thread-exception? uncaught-exception?
    uncaught-exception-reason)
  (begin
    ;; Thread primitives
    (define current-thread       (%primitive "current-thread"))
    (define thread?              (%primitive "thread?"))
    (define make-thread          (%primitive "make-thread"))
    (define thread-name          (%primitive "thread-name"))
    (define thread-specific      (%primitive "thread-specific"))
    (define thread-specific-set! (%primitive "thread-specific-set!"))
    (define thread-start!        (%primitive "thread-start!"))
    (define thread-yield!        (%primitive "thread-yield!"))
    (define thread-terminate!    (%primitive "thread-terminate!"))

    ;; Raw thread primitives (accept only numbers as timeouts)
    (define %raw-thread-sleep!   (%primitive "thread-sleep!"))
    (define %raw-thread-join!    (%primitive "thread-join!"))

    ;; Mutex primitives
    (define mutex?               (%primitive "mutex?"))
    (define make-mutex           (%primitive "make-mutex"))
    (define mutex-name           (%primitive "mutex-name"))
    (define mutex-specific       (%primitive "mutex-specific"))
    (define mutex-specific-set!  (%primitive "mutex-specific-set!"))
    (define mutex-state          (%primitive "mutex-state"))

    ;; Raw mutex primitives (accept only numbers as timeouts)
    (define %raw-mutex-lock!     (%primitive "mutex-lock!"))
    (define %raw-mutex-unlock!   (%primitive "mutex-unlock!"))

    ;; Condition variable primitives
    (define condition-variable?            (%primitive "condition-variable?"))
    (define make-condition-variable        (%primitive "make-condition-variable"))
    (define condition-variable-name        (%primitive "condition-variable-name"))
    (define condition-variable-specific    (%primitive "condition-variable-specific"))
    (define condition-variable-specific-set! (%primitive "condition-variable-specific-set!"))
    (define condition-variable-signal!     (%primitive "condition-variable-signal!"))
    (define condition-variable-broadcast!  (%primitive "condition-variable-broadcast!"))

    ;; ------------------------------------------------------------------
    ;; Time support — uses SRFI-19 time types
    ;; current-time and time? come from (srfi 19) import
    ;; ------------------------------------------------------------------

    (define %current-ns (%primitive "%current-nanosecond"))

    (define (%time->relative-seconds timeout)
      ;; Convert a SRFI-19 time object (absolute deadline) to relative seconds.
      (let* ((now-pair (%current-ns))
             (now-secs (+ (car now-pair) (/ (cdr now-pair) 1000000000.0)))
             (target   (+ (time-second timeout) (/ (time-nanosecond timeout) 1000000000.0))))
        (- target now-secs)))

    (define (time->seconds t)
      "Syntax: (time->seconds time)
Library: (srfi 18)
Description: Returns the time as an inexact number of seconds since the Unix epoch.
Example:
  (> (time->seconds (current-time)) 0) => #t"
      (+ (time-second t) (/ (time-nanosecond t) 1000000000.0)))

    (define (seconds->time s)
      "Syntax: (seconds->time seconds)
Library: (srfi 18)
Description: Creates a time-utc time object from seconds since the Unix epoch.
Example:
  (time? (seconds->time 100.0)) => #t"
      (let* ((sec (exact (truncate s)))
             (ns  (exact (truncate (* (- s sec) 1000000000)))))
        (make-time time-utc ns sec)))

    ;; ------------------------------------------------------------------
    ;; Wrappers that convert SRFI-19 time objects to numbers for raw prims
    ;; ------------------------------------------------------------------

    (define (thread-sleep! timeout)
      "Syntax: (thread-sleep! timeout)
Library: (srfi 18)
Description: Causes the current thread to sleep. timeout can be a time object (absolute deadline) or a number (relative seconds).
Example:
  (thread-sleep! 0.1)"
      (cond
        ((time? timeout)
         (let ((delta (%time->relative-seconds timeout)))
           (if (> delta 0) (%raw-thread-sleep! delta))))
        ((number? timeout)
         (%raw-thread-sleep! timeout))
        (else (error "thread-sleep!: expected time object or number" timeout))))

    (define (thread-join! thread . args)
      "Syntax: (thread-join! thread [timeout [timeout-val]])
Library: (srfi 18)
Description: Waits for thread to terminate. timeout can be a time object or number.
Example:
  (thread-join! (thread-start! (make-thread (lambda () 42)))) => 42"
      (if (and (not (null? args)) (time? (car args)))
          (let ((delta (%time->relative-seconds (car args))))
            (apply %raw-thread-join! thread (max 0 delta) (cdr args)))
          (apply %raw-thread-join! thread args)))

    (define (mutex-lock! mutex . args)
      "Syntax: (mutex-lock! mutex [timeout [thread]])
Library: (srfi 18)
Description: Locks the mutex. timeout can be a time object or number.
Example:
  (mutex-lock! (make-mutex)) => #t"
      (if (and (not (null? args)) (time? (car args)))
          (let ((delta (%time->relative-seconds (car args))))
            (apply %raw-mutex-lock! mutex (max 0 delta) (cdr args)))
          (apply %raw-mutex-lock! mutex args)))

    (define (mutex-unlock! mutex . args)
      "Syntax: (mutex-unlock! mutex [condition-variable [timeout]])
Library: (srfi 18)
Description: Unlocks the mutex. If condition-variable and timeout are given, waits.
Example:
  (let ((m (make-mutex))) (mutex-lock! m) (mutex-unlock! m)) => #t"
      (if (and (>= (length args) 2) (time? (cadr args)))
          (let ((delta (%time->relative-seconds (cadr args))))
            (%raw-mutex-unlock! mutex (car args) (max 0 delta)))
          (apply %raw-mutex-unlock! mutex args)))

    ;; Exception predicates
    (define join-timeout-exception?      (%primitive "join-timeout-exception?"))
    (define abandoned-mutex-exception?   (%primitive "abandoned-mutex-exception?"))
    (define terminated-thread-exception? (%primitive "terminated-thread-exception?"))
    (define uncaught-exception?          (%primitive "uncaught-exception?"))
    (define uncaught-exception-reason    (%primitive "uncaught-exception-reason"))

    ;; Internal bindings for exception handler access
    (define %exception-handlers-get (%primitive "%exception-handlers-get"))
    (define %raise-fatal (%primitive "%raise-fatal"))

    ;; current-exception-handler: return the top of the handler stack
    (define (current-exception-handler)
      "Syntax: (current-exception-handler)
Library: (srfi 18)
Description: Returns the current exception handler procedure. This is the handler
  that would be called if raise were invoked.
Example:
  (procedure? (current-exception-handler)) => #t"
      (let ((hs (%exception-handlers-get)))
        (if (null? hs)
            (lambda (e) (%raise-fatal e))
            (car hs))))))
