## Overview

SRFI-18 is the multithreading library: create and start threads, wait for results,
and coordinate with mutexes and condition variables.

## Common uses

```scheme
(import (srfi 18))

(define t (make-thread (lambda () (* 6 7))))
(thread-start! t)
(thread-join! t)        ;; => 42   (the thread's result)
```

Mutexes (`make-mutex`, `mutex-lock!`, `mutex-unlock!`) and condition variables
(`make-condition-variable`, `condition-variable-wait!`, …) provide synchronization;
`thread-sleep!` pauses the current thread.
