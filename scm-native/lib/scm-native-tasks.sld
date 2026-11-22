(define-library (scm native tasks)
  (export spawn!
          wait-for!
          wait-until!
          task-sleep!
          make-lock
          with-lock)
  (import (scheme base)
          (scm datetime))
  (begin
    ;; Tasks of the native network libraries, over threads (SRFI 18's
    ;; primitives): a task is a thread; a task that waits for a socket
    ;; blocks its thread in poll; with-lock guards shared state.

    (define net-poll (%primitive "%net-poll"))
    (define make-thread (%primitive "make-thread"))
    (define thread-start! (%primitive "thread-start!"))
    (define thread-sleep! (%primitive "thread-sleep!"))
    (define make-mutex (%primitive "make-mutex"))
    (define mutex-lock! (%primitive "mutex-lock!"))
    (define mutex-unlock! (%primitive "mutex-unlock!"))

    (define (now-ms) (timestamp))

    ;; Run thunk in a new thread
    (define (spawn! thunk)
      (thread-start! (make-thread thunk)))

    ;; Wait until object (a socket or listener) is ready for mode (read,
    ;; write); #f if the deadline (ms, or #f) passed first
    (define (wait-for! object mode deadline)
      (let ((timeout (if deadline (max 0 (- deadline (now-ms))) -1)))
        (pair? (net-poll (list (cons object mode)) timeout))))

    ;; Wait until (ready?) is true (checked every 20 ms)
    (define (wait-until! ready?)
      (let loop ()
        (unless (ready?)
          (thread-sleep! 0.02)
          (loop))))

    (define (task-sleep! seconds) (thread-sleep! seconds))

    (define (make-lock) (make-mutex))

    ;; thunk's values, with lock held (released on exit, also by an error)
    (define (with-lock lock thunk)
      (mutex-lock! lock)
      (call-with-values
          (lambda ()
            (guard (e (#t (mutex-unlock! lock) (raise e)))
              (thunk)))
        (lambda vals
          (mutex-unlock! lock)
          (apply values vals))))))
