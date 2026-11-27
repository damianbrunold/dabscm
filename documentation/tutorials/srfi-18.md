---
title: SRFI 18: threads
part: libraries
order: 18
libraries: (srfi 18)
summary: Threads, their results and names, thread-local data, mutexes and their states, condition variables, timeouts and termination, exceptions; a parallel map and a bounded buffer.
---
# SRFI 18: threads

SRFI 18 gives Scheme real threads with mutexes and condition variables. The
[concurrency](techniques-11-concurrency.md) chapter shows the common
patterns; this one goes through the library.

```scheme
(import (scheme base) (srfi 1) (srfi 18))
```

## Threads

```scheme
(define t (make-thread (lambda () (* 6 7)) 'answer))
(thread? t)                                 ;; => #t
(thread-name t)                             ;; => answer
(thread-start! t)
(thread-join! t)                            ;; => 42
(thread? (current-thread))                  ;; => #t
```

A thread is created stopped; `thread-start!` runs it. `thread-join!` waits
for the result and can be called more than once.

## Thread-local data

Each thread and mutex has a *specific* field for your own data, for example
a per-thread buffer or a worker number:

```scheme
(define (worker n)
  (make-thread (lambda ()
                 (thread-specific-set! (current-thread) n)
                 (* 10 (thread-specific (current-thread))))))

(define ws (map worker '(1 2 3)))
(for-each thread-start! ws)
(map thread-join! ws)                       ;; => (10 20 30)
```

## Mutexes

```scheme
(define m (make-mutex 'counter))
(mutex-name m)                              ;; => counter
(mutex-state m)                             ;; => not-abandoned
(mutex-lock! m)
(eq? (mutex-state m) (current-thread))      ;; => #t
(mutex-unlock! m)
(mutex-state m)                             ;; => not-abandoned
```

`mutex-state` is the owning thread while a mutex is locked. A mutex whose
owner ended without unlocking it is *abandoned*; locking it raises
`abandoned-mutex-exception`, so a crashed thread cannot silently leave
shared data half-changed.

### Example: a parallel map

Apply a procedure to every element in its own thread, keeping the order:

```scheme
(define (parallel-map f xs)
  (let ((threads (map (lambda (x) (make-thread (lambda () (f x)))) xs)))
    (for-each thread-start! threads)
    (map thread-join! threads)))

(parallel-map (lambda (n) (fold + 0 (iota n))) '(10 100 1000)) ;; => (45 4950 499500)
```

One thread per element suits a few dozen expensive pieces of work. For many
small ones, use a pool of workers fed by a queue, as in the concurrency
chapter.

## Condition variables

A thread waits on a condition variable until another thread signals it. The
classic use is a bounded buffer between a producer and a consumer:

```scheme
(define-record-type buffer
  (%make-buffer items size lock not-empty not-full)
  buffer?
  (items buffer-items set-buffer-items!)
  (size buffer-size)
  (lock buffer-lock)
  (not-empty buffer-not-empty)
  (not-full buffer-not-full))

(define (make-buffer size)
  (%make-buffer '() size (make-mutex) (make-condition-variable) (make-condition-variable)))

(define (buffer-put! b x)
  (mutex-lock! (buffer-lock b))
  (if (>= (length (buffer-items b)) (buffer-size b))
      (begin (mutex-unlock! (buffer-lock b) (buffer-not-full b))
             (buffer-put! b x))
      (begin (set-buffer-items! b (append (buffer-items b) (list x)))
             (condition-variable-signal! (buffer-not-empty b))
             (mutex-unlock! (buffer-lock b)))))

(define (buffer-take! b)
  (mutex-lock! (buffer-lock b))
  (if (null? (buffer-items b))
      (begin (mutex-unlock! (buffer-lock b) (buffer-not-empty b))
             (buffer-take! b))
      (let ((x (car (buffer-items b))))
        (set-buffer-items! b (cdr (buffer-items b)))
        (condition-variable-signal! (buffer-not-full b))
        (mutex-unlock! (buffer-lock b))
        x)))

(define buf (make-buffer 2))
(define producer (make-thread (lambda () (for-each (lambda (i) (buffer-put! buf i)) (iota 10)))))
(define consumer (make-thread (lambda () (let loop ((n 10) (acc '()))
                                          (if (= n 0) (reverse acc)
                                              (loop (- n 1) (cons (buffer-take! buf) acc)))))))
(thread-start! consumer)
(thread-start! producer)
(thread-join! consumer)                     ;; => (0 1 2 3 4 5 6 7 8 9)
```

The buffer never holds more than two items: the producer waits on
`not-full` until the consumer has taken one. `(mutex-unlock! m cv)` releases
the mutex and starts waiting in one atomic step; after waking, the code
locks again and re-checks, because another thread may have been faster.

## Time, timeouts and termination

```scheme
(time? (current-time))                      ;; => #t
(real? (time->seconds (current-time)))      ;; => #t
(define slow (make-thread (lambda () (thread-sleep! 10) 'done)))
(thread-start! slow)
(thread-join! slow 0.05 'still-running)     ;; => still-running
(thread-terminate! slow)
(guard (e ((terminated-thread-exception? e) 'terminated))
  (thread-join! slow))                      ;; => terminated
(guard (e ((join-timeout-exception? e) 'timeout))
  (thread-join! (let ((t (make-thread (lambda () (thread-sleep! 10)))))
                  (thread-start! t) t)
                0.01))                      ;; => timeout
```

Timeouts are in seconds (or a time object). `thread-yield!` gives other
threads a chance to run.

## Exceptions in threads

```scheme
(define failing (make-thread (lambda () (error "disk full" "/var"))))
(thread-start! failing)
(guard (e ((uncaught-exception? e)
           (error-object-message (uncaught-exception-reason e))))
  (thread-join! failing))                   ;; => "disk full"
```

The thread's error is wrapped in an *uncaught exception*;
`uncaught-exception-reason` unwraps it.

## Where next

- [Concurrency](techniques-11-concurrency.md), `run-parallel` in `(scm system)`.
- Reference: `(srfi 18)`.
