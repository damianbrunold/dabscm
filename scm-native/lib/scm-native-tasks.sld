(define-library (scm native tasks)
  (export spawn!
          wait-for!
          wait-until!
          task-sleep!
          set-pollers!)
  (import (scheme base)
          (scm datetime))
  (begin
    ;; The cooperative scheduler of dabscm native (no threads yet): tasks are
    ;; continuations. A task that would block (on a socket, a sleep, a
    ;; condition) yields; the scheduler polls the sockets the tasks wait for
    ;; and the listeners of running servers (pollers, set by (scm native
    ;; http)), and resumes the tasks whose wait is over. The program itself
    ;; is a task too.

    (define net-poll (%primitive "%net-poll"))

    (define (now-ms) (timestamp))

    (define runnable '())               ; thunks to run (each never returns)
    (define waiting '())                ; #(item deadline k): item (object . mode) or (#f . predicate)
    ;; (listener . on-ready) of the running servers: polled for accept
    (define pollers '())
    (define (set-pollers! l) (set! pollers l))

    (define (spawn! thunk)
      (set! runnable (append runnable (list (lambda () (thunk) (schedule!))))))

    ;; Wait until object (a socket or listener) is ready for mode (read,
    ;; write); #f if the deadline (ms, or #f) passed first
    (define (wait-for! object mode deadline)
      (call/cc
       (lambda (k)
         (set! waiting (cons (vector (cons object mode) deadline k) waiting))
         (schedule!))))

    ;; Wait until (ready?) is true
    (define (wait-until! ready?)
      (unless (ready?)
        (call/cc
         (lambda (k)
           (set! waiting (cons (vector (cons #f ready?) #f k) waiting))
           (schedule!)))))

    (define (resume! entry value)
      (set! waiting (remove-eq entry waiting))
      (let ((k (vector-ref entry 2)))
        (set! runnable (append runnable (list (lambda () (k value)))))))

    (define (remove-eq x l)
      (cond ((null? l) '())
            ((eq? (car l) x) (cdr l))
            (else (cons (car l) (remove-eq x (cdr l))))))

    (define (schedule!)
      (let loop ()
        (cond
         ((pair? runnable)
          (let ((t (car runnable)))
            (set! runnable (cdr runnable))
            (t)))
         (else
          ;; conditions that hold now
          (for-each (lambda (e)
                      (let ((item (vector-ref e 0)))
                        (when (and (not (car item)) ((cdr item))) (resume! e #t))))
                    waiting)
          (if (pair? runnable)
              (loop)
              (let* ((io (filter-list (lambda (e) (car (vector-ref e 0))) waiting))
                     (listeners (map (lambda (p) (cons (car p) 'read)) pollers))
                     (items (append (map (lambda (e) (vector-ref e 0)) io) listeners))
                     (now (now-ms))
                     (timeout (fold-deadlines waiting now))
                     (conds? (any-list (lambda (e) (not (car (vector-ref e 0)))) waiting)))
                (when (and (null? items) (not timeout))
                  (error "deadlock: every task waits for a condition"))
                (let ((ready (net-poll items (cond ((and conds? (or (not timeout) (> timeout 100))) 100)
                                                   (timeout timeout)
                                                   (else -1)))))
                  (for-each (lambda (p)
                              (when (memq (assq (car p) ready) ready)
                                ((cdr p))))
                            pollers)
                  (for-each (lambda (e)
                              (cond ((memq (vector-ref e 0) ready) (resume! e #t))
                                    ((and (vector-ref e 1) (>= (now-ms) (vector-ref e 1))) (resume! e #f))))
                            io)
                  ;; deadlines of conditions
                  (for-each (lambda (e)
                              (when (and (not (car (vector-ref e 0))) (vector-ref e 1) (>= (now-ms) (vector-ref e 1)))
                                (resume! e #f)))
                            waiting)
                  (loop))))))))

    (define (fold-deadlines entries now)
      (let loop ((es entries) (best #f))
        (if (null? es)
            best
            (let ((d (vector-ref (car es) 1)))
              (loop (cdr es)
                    (if d
                        (let ((left (max 0 (- d now))))
                          (if (or (not best) (< left best)) left best))
                        best))))))

    (define (filter-list keep? l)
      (cond ((null? l) '())
            ((keep? (car l)) (cons (car l) (filter-list keep? (cdr l))))
            (else (filter-list keep? (cdr l)))))

    (define (any-list p l) (and (pair? l) (or (p (car l)) (any-list p (cdr l)))))


    ;; Sleep for seconds, letting the other tasks run
    (define (task-sleep! seconds)
      (let ((until (+ (now-ms) (exact (round (* 1000 seconds))))))
        (if (null? pollers)
            ((%primitive "thread-sleep!") seconds)
            (call/cc
             (lambda (k)
               (set! waiting (cons (vector (cons #f (lambda () (>= (now-ms) until))) until k) waiting))
               (schedule!))))))))
