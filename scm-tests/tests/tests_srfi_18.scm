(import (scheme base)
        (scheme write)
        (scm test)
        (srfi 18))

(test-runner-factory scm-test-runner)

(test-begin "srfi-18")

;;; ---- Thread basics ----
(test-group "thread basics"
  (test-equal "make-thread" #t (thread? (make-thread (lambda () 1))))
  (test-equal "num is no thread" #f (thread? 42))
  (test-equal "str is no thread" #f (thread? "hello"))
  (test-equal "with thread-name" "worker" (thread-name (make-thread (lambda () 1) "worker")))
  (test-equal "w/o thread-name" #f (thread-name (make-thread (lambda () 1))))
  (test-equal "current-thread is thread" #t (thread? (current-thread)))
  (test-equal "current-thread is primordial" 'primordial (thread-name (current-thread))))

;;; ---- Thread specific data ----
(test-group "thread specific data"
  (test-equal 'my-data
    (let ((t (make-thread (lambda () 1))))
      (thread-specific-set! t 'my-data)
      (thread-specific t)))
  (test-equal '()
    (let ((t (make-thread (lambda () 1))))
      (thread-specific t))))

;;; ---- Thread start/join basic ----
(test-group "thread start/join basic"
  (test-equal 3 (thread-join! (thread-start! (make-thread (lambda () (+ 1 2))))))
  (test-equal 42 (thread-join! (thread-start! (make-thread (lambda () (* 6 7))))))
  (test-equal "hello" (thread-join! (thread-start! (make-thread (lambda () "hello"))))))

;;; ---- Thread join with timeout ----
(test-group "thread join with timeout"
  ;; Join a thread that completes quickly - should get result
  (test-equal 99 (thread-join! (thread-start! (make-thread (lambda () 99))) 5))
  ;; Join with timeout-val when thread takes too long
  (test-equal 'timed-out
    (let ((t (make-thread (lambda () (thread-sleep! 10) 'late))))
      (thread-start! t)
      (thread-join! t 0.01 'timed-out))))

;;; ---- Thread join timeout exception ----
(test-group "thread join timeout exception"
  (test-equal 'timeout
    (guard (e ((join-timeout-exception? e) 'timeout))
      (let ((t (make-thread (lambda () (thread-sleep! 10)))))
        (thread-start! t)
        (thread-join! t 0.01)))))

;;; ---- Uncaught exception ----
(test-group "uncaught exception"
  (test-equal 'caught
    (guard (e ((uncaught-exception? e) 'caught))
      (thread-join! (thread-start! (make-thread (lambda () (error "boom"))))))))

;;; ---- Thread yield (no error) ----
(test-group "thread yield"
  (test-equal 'ok (begin (thread-yield!) 'ok)))

;;; ---- Thread sleep ----
(test-group "thread sleep"
  (test-equal #t
    (let ((start (time->seconds (current-time))))
      (thread-sleep! 0.05)
      (>= (- (time->seconds (current-time)) start) 0.04))))

;;; ---- Mutex basics ----
(test-group "mutex basics"
  (test-equal #t (mutex? (make-mutex)))
  (test-equal #f (mutex? 42))
  (test-equal "my-lock" (mutex-name (make-mutex "my-lock")))
  (test-equal #f (mutex-name (make-mutex)))
  (test-equal 'not-abandoned (mutex-state (make-mutex))))

;;; ---- Mutex specific data ----
(test-group "mutex specific data"
  (test-equal 'data
    (let ((m (make-mutex)))
      (mutex-specific-set! m 'data)
      (mutex-specific m))))

;;; ---- Mutex lock/unlock and state ----
(test-group "mutex lock/unlock and state"
  (test-equal #t
    (let ((m (make-mutex)))
      (mutex-lock! m)
      (let ((s (mutex-state m)))
        (mutex-unlock! m)
        (thread? s))))
  (test-equal 'not-abandoned
    (let ((m (make-mutex)))
      (mutex-lock! m)
      (mutex-unlock! m)
      (mutex-state m))))

;;; ---- Mutex lock with timeout ----
(test-group "mutex lock with timeout"
  (test-equal #f
    (let ((m (make-mutex)))
      (mutex-lock! m)  ; lock it
      ;; Try to lock from a thread with timeout - should fail
      (let ((t (make-thread (lambda () (mutex-lock! m 0.01)))))
        (thread-start! t)
        (let ((result (thread-join! t)))
          (mutex-unlock! m)
          result)))))

;;; ---- Mutex protects shared state ----
(test-group "mutex protects shared state"
  (test-equal 1
    (let ((m (make-mutex))
          (result 0))
      (let ((t (make-thread
                 (lambda ()
                   (mutex-lock! m)
                   (set! result (+ result 1))
                   (mutex-unlock! m)))))
        (thread-start! t)
        (thread-join! t)
        result))))

;;; ---- Condition variable basics ----
(test-group "condition variable basics"
  (test-equal #t (condition-variable? (make-condition-variable)))
  (test-equal #f (condition-variable? 42))
  (test-equal "cv1" (condition-variable-name (make-condition-variable "cv1")))
  (test-equal #f (condition-variable-name (make-condition-variable))))

;;; ---- Condition variable specific ----
(test-group "condition variable specific"
  (test-equal 'info
    (let ((cv (make-condition-variable)))
      (condition-variable-specific-set! cv 'info)
      (condition-variable-specific cv))))

;;; ---- Condition variable signal ----
(test-group "condition variable signal"
  ;; Producer/consumer with condition variable
  (test-equal 'ready
    (let ((m (make-mutex))
          (cv (make-condition-variable))
          (data #f))
      (let ((consumer (make-thread
                        (lambda ()
                          (mutex-lock! m)
                          (mutex-unlock! m cv)
                          ;; After being signaled, data should be set
                          data))))
        (thread-start! consumer)
        (thread-sleep! 0.05)  ; let consumer start waiting
        (set! data 'ready)
        (condition-variable-signal! cv)
        (thread-join! consumer 2)))))

;;; ---- Time basics ----
(test-group "time basics"
  (test-equal #t (time? (current-time)))
  (test-equal #f (time? 42))
  (test-equal #t (> (time->seconds (current-time)) 0))
  (test-equal #t (time? (seconds->time 100.0)))
  (test-equal 123.456 (time->seconds (seconds->time 123.456))))

;;; ---- Exception predicates ----
(test-group "exception predicates"
  (test-equal #f (join-timeout-exception? 42))
  (test-equal #f (abandoned-mutex-exception? 42))
  (test-equal #f (terminated-thread-exception? 42))
  (test-equal #f (uncaught-exception? 42)))

;;; ---- current-exception-handler ----
(test-group "current-exception-handler"
  (test-assert (procedure? (current-exception-handler))))

;;; ---- Shared top-level bindings across threads ----
;; Regression for the threading-shared-bindings change: top-level set!
;; must be visible across threads. Before the Cell + deepClone-removal
;; refactor, thread-start! deep-cloned every module's bindings, so a
;; worker thread's set! on a top-level variable was invisible to the
;; spawning thread. See notes/threading-shared-bindings.md.

(define shared-counter 0)
(define shared-flag #f)

(test-group "shared top-level set! visible across threads"
  ;; Worker mutates a top-level binding; primordial thread observes it.
  (test-equal 'observed
    (begin
      (set! shared-flag #f)
      (let ((t (make-thread (lambda () (set! shared-flag 'observed)))))
        (thread-start! t)
        (thread-join! t)
        shared-flag))))

(test-group "shared counter under mutex"
  ;; 4 workers each increment a shared top-level counter 250 times under
  ;; a mutex. Final value must be 1000. Pre-fix this returned 0 because
  ;; each thread had its own clone of the binding.
  (test-equal 1000
    (let ((m (make-mutex)))
      (set! shared-counter 0)
      (let ((ts (map (lambda (_)
                       (let ((t (make-thread
                                  (lambda ()
                                    (let loop ((k 0))
                                      (cond ((< k 250)
                                             (mutex-lock! m)
                                             (set! shared-counter
                                                   (+ shared-counter 1))
                                             (mutex-unlock! m)
                                             (loop (+ k 1)))))))))
                         (thread-start! t)
                         t))
                     '(0 1 2 3))))
        (for-each thread-join! ts)
        shared-counter))))

(test-end "srfi-18")
