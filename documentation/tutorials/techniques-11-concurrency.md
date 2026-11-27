---
title: Concurrency
part: techniques
order: 11
libraries: (srfi 18) (scm system)
summary: Threads with SRFI 18, joining results, mutexes for shared state, condition variables, a work queue with a pool of workers, errors in threads, run-parallel.
---
# Concurrency

dabscm threads (SRFI 18) are real operating-system threads on all three
implementations, so CPU-bound work spreads over several cores.

```scheme
(import (scheme base) (srfi 1) (srfi 18) (scm system))
```

## Starting and joining threads

`make-thread` takes a thunk, `thread-start!` runs it, and `thread-join!`
waits for it and returns its result:

```scheme
(define (sum-range from to)
  (let loop ((i from) (s 0)) (if (> i to) s (loop (+ i 1) (+ s i)))))

(define t1 (make-thread (lambda () (sum-range 1 500000))))
(define t2 (make-thread (lambda () (sum-range 500001 1000000))))
(thread-start! t1)
(thread-start! t2)
(+ (thread-join! t1) (thread-join! t2))     ;; => 500000500000
```

The two halves run at the same time. For independent pieces of work like
these, `run-parallel` from `(scm system)` does the same in one call:

```scheme
(run-parallel (lambda (x) (* x x)) '(1 2 3 4)) ;; => (1 4 9 16)
(fold + 0 (run-parallel (lambda (r) (sum-range (car r) (cdr r)))
                        '((1 . 250000) (250001 . 500000)
                          (500001 . 750000) (750001 . 1000000))))
;; => 500000500000
```

## Shared state needs a mutex

Threads that change the same data must take turns. Without a lock, two
threads can read the same old value and one update gets lost. A mutex
makes the read-change-write step atomic:

```scheme
(define counter 0)
(define lock (make-mutex))

(define (increment-many n)
  (do ((i 0 (+ i 1))) ((= i n))
    (mutex-lock! lock)
    (set! counter (+ counter 1))
    (mutex-unlock! lock)))

(define workers (map (lambda (_) (make-thread (lambda () (increment-many 10000))))
                     (iota 4)))
(for-each thread-start! workers)
(for-each thread-join! workers)
counter                                     ;; => 40000
```

A helper that always unlocks, even when the body raises an error:

```scheme
(define (with-lock m thunk)
  (dynamic-wind
    (lambda () (mutex-lock! m))
    thunk
    (lambda () (mutex-unlock! m))))

(with-lock lock (lambda () (set! counter 0) counter)) ;; => 0
```

The best concurrent code shares little: give each thread its own input,
collect results through `thread-join!`, and combine them at the end.

## A work queue with condition variables

A *condition variable* lets a thread sleep until another one signals that
something changed. Here is a queue that worker threads take jobs from:

```scheme
(define-record-type queue
  (%make-queue items mutex nonempty closed)
  queue?
  (items queue-items set-queue-items!)
  (mutex queue-mutex)
  (nonempty queue-nonempty)
  (closed queue-closed? set-queue-closed!))

(define (make-queue) (%make-queue '() (make-mutex) (make-condition-variable) #f))

(define (queue-put! q x)
  (mutex-lock! (queue-mutex q))
  (set-queue-items! q (append (queue-items q) (list x)))
  (condition-variable-signal! (queue-nonempty q))
  (mutex-unlock! (queue-mutex q)))

(define (queue-close! q)
  (mutex-lock! (queue-mutex q))
  (set-queue-closed! q #t)
  (condition-variable-broadcast! (queue-nonempty q))
  (mutex-unlock! (queue-mutex q)))

;; the next item, or #f when the queue is closed and empty
(define (queue-take! q)
  (mutex-lock! (queue-mutex q))
  (let loop ()
    (cond ((pair? (queue-items q))
           (let ((x (car (queue-items q))))
             (set-queue-items! q (cdr (queue-items q)))
             (mutex-unlock! (queue-mutex q))
             x))
          ((queue-closed? q) (mutex-unlock! (queue-mutex q)) #f)
          (else
           ;; releases the mutex while waiting, takes it again on wake-up
           (mutex-unlock! (queue-mutex q) (queue-nonempty q))
           (mutex-lock! (queue-mutex q))
           (loop)))))
```

`mutex-unlock!` with a condition variable unlocks and waits in one step, so
no signal can slip in between. Three workers process the jobs; each keeps
its own results, which the main thread combines:

```scheme
(define jobs (make-queue))

(define (worker)
  (let loop ((done '()))
    (let ((n (queue-take! jobs)))
      (if n (loop (cons (* n n) done)) done))))

(define pool (map (lambda (_) (make-thread worker)) (iota 3)))
(for-each thread-start! pool)
(for-each (lambda (n) (queue-put! jobs n)) (iota 10 1))
(queue-close! jobs)

(define results (append-map thread-join! pool))
(length results)                            ;; => 10
(fold + 0 results)                          ;; => 385
```

Which worker did which job depends on timing; the sum does not.

## Errors in threads

An error that a thread does not catch ends the thread. `thread-join!` then
raises an "uncaught exception" in the thread that joins, so failures are not
lost:

```scheme
(define broken (make-thread (lambda () (car '()))))
(thread-start! broken)
(guard (e ((uncaught-exception? e) 'thread-failed))
  (thread-join! broken))                    ;; => thread-failed
```

`uncaught-exception-reason` gives the original error.

## Sleeping and timeouts

```scheme
(thread-sleep! 0.01)                        ; a hundredth of a second
(define slow (make-thread (lambda () (thread-sleep! 5) 'late)))
(thread-start! slow)
(thread-join! slow 0.05 'timed-out)         ;; => timed-out
(thread-terminate! slow)
```

`thread-join!` with a timeout and a default value returns the default if the
thread has not finished in time.

## Where next

- [The system: programs, environment, platform](techniques-12-system.md).
- [SRFI 18](srfi-18.md).
