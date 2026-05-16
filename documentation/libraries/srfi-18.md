# `(srfi 18)`

SRFI-18 — Multithreading: threads, mutexes, condition variables

## Exports

### `abandoned-mutex-exception?`

```
Syntax: (abandoned-mutex-exception? obj)
Library: (srfi 18)
Description: Returns #t if obj is an abandoned-mutex exception.
Example:
  (abandoned-mutex-exception? exn)
```

### `condition-variable-broadcast!`

```
Syntax: (condition-variable-broadcast! cv)
Library: (srfi 18)
Description: Broadcasts the condition variable, waking all waiting threads.
Example:
  (condition-variable-broadcast! cv)
```

### `condition-variable-name`

```
Syntax: (condition-variable-name cv)
Library: (srfi 18)
Description: Returns the name of the condition variable.
Example:
  (condition-variable-name (make-condition-variable 'cv)) => cv
```

### `condition-variable-signal!`

```
Syntax: (condition-variable-signal! cv)
Library: (srfi 18)
Description: Signals the condition variable, waking one waiting thread.
Example:
  (condition-variable-signal! cv)
```

### `condition-variable-specific`

```
Syntax: (condition-variable-specific cv)
Library: (srfi 18)
Description: Returns the condition-variable-specific data.
Example:
  (condition-variable-specific (make-condition-variable)) => ()
```

### `condition-variable-specific-set!`

```
Syntax: (condition-variable-specific-set! cv obj)
Library: (srfi 18)
Description: Sets the condition-variable-specific data to obj.
Example:
  (condition-variable-specific-set! cv 42)
```

### `condition-variable?`

```
Syntax: (condition-variable? obj)
Library: (srfi 18)
Description: Returns #t if obj is a condition variable.
Example:
  (condition-variable? (make-condition-variable)) => #t
```

### `current-exception-handler`

```
Syntax: (current-exception-handler)
Library: (srfi 18)
Description: Returns the current exception handler procedure. This is the handler
  that would be called if raise were invoked.
Example:
  (procedure? (current-exception-handler)) => #t
```

### `current-thread`

```
Syntax: (current-thread)
Library: (srfi 18)
Description: Returns the current thread object.
Example:
  (thread? (current-thread)) => #t
```

### `current-time`

```
Syntax: (current-time [time-type])
Library: (srfi 19)
Description: Returns the current time as a time object. Default type is time-utc.
Example:
  (time? (current-time)) => #t
  (time-type (current-time time-tai)) => time-tai
```

### `join-timeout-exception?`

```
Syntax: (join-timeout-exception? obj)
Library: (srfi 18)
Description: Returns #t if obj is a join-timeout exception.
Example:
  (guard (e ((join-timeout-exception? e) 'timeout)) (thread-join! t 0))
```

### `make-condition-variable`

```
Syntax: (make-condition-variable [name])
Library: (srfi 18)
Description: Creates a new condition variable, optionally with a name.
Example:
  (make-condition-variable 'my-cv)
```

### `make-mutex`

```
Syntax: (make-mutex [name])
Library: (srfi 18)
Description: Creates a new mutex (mutual exclusion lock), optionally with a name.
Example:
  (define m (make-mutex 'my-mutex))
```

### `make-thread`

```
Syntax: (make-thread thunk [name])
Library: (srfi 18)
Description: Creates a new thread that will run thunk when started. The thread is not started until thread-start! is called. An optional name can be provided. Note: continuations captured in one thread must not be invoked in another.
Example:
  (thread-join! (thread-start! (make-thread (lambda () (+ 1 2))))) => 3
```

### `mutex-lock!`

```
Syntax: (mutex-lock! mutex [timeout [thread]])
Library: (srfi 18)
Description: Locks the mutex. timeout can be a time object or number.
Example:
  (mutex-lock! (make-mutex)) => #t
```

### `mutex-name`

```
Syntax: (mutex-name mutex)
Library: (srfi 18)
Description: Returns the name of the mutex.
Example:
  (mutex-name (make-mutex 'my-mutex)) => my-mutex
```

### `mutex-specific`

```
Syntax: (mutex-specific mutex)
Library: (srfi 18)
Description: Returns the mutex-specific data of the mutex.
Example:
  (mutex-specific (make-mutex)) => ()
```

### `mutex-specific-set!`

```
Syntax: (mutex-specific-set! mutex obj)
Library: (srfi 18)
Description: Sets the mutex-specific data of the mutex to obj.
Example:
  (mutex-specific-set! (make-mutex) 42)
```

### `mutex-state`

```
Syntax: (mutex-state mutex)
Library: (srfi 18)
Description: Returns the state of the mutex: the symbol abandoned, not-owned, not-abandoned, or the owning thread object.
Example:
  (mutex-state (make-mutex)) => not-abandoned
```

### `mutex-unlock!`

```
Syntax: (mutex-unlock! mutex [condition-variable [timeout]])
Library: (srfi 18)
Description: Unlocks the mutex. If condition-variable and timeout are given, waits.
Example:
  (let ((m (make-mutex))) (mutex-lock! m) (mutex-unlock! m)) => #t
```

### `mutex?`

```
Syntax: (mutex? x)
Library: (srfi 18)
Description: Returns #t if x is a mutex object.
Example:
  (mutex? (make-mutex)) => #t
```

### `raise`

```
Syntax: (raise obj)
Library: (scheme base)
Description: Raises an exception by invoking the current exception handler on obj.
Example:
  (guard (e (#t (error-object-message e)))
    (raise (make-error-object "oops" '()))) => "oops"
```

### `seconds->time`

```
Syntax: (seconds->time seconds)
Library: (srfi 18)
Description: Creates a time-utc time object from seconds since the Unix epoch.
Example:
  (time? (seconds->time 100.0)) => #t
```

### `terminated-thread-exception?`

```
Syntax: (terminated-thread-exception? obj)
Library: (srfi 18)
Description: Returns #t if obj is a terminated-thread exception.
Example:
  (terminated-thread-exception? exn)
```

### `thread-join!`

```
Syntax: (thread-join! thread [timeout [timeout-val]])
Library: (srfi 18)
Description: Waits for thread to terminate. timeout can be a time object or number.
Example:
  (thread-join! (thread-start! (make-thread (lambda () 42)))) => 42
```

### `thread-name`

```
Syntax: (thread-name thread)
Library: (srfi 18)
Description: Returns the name of the thread.
Example:
  (thread-name (make-thread (lambda () #t) 'my-thread)) => my-thread
```

### `thread-sleep!`

```
Syntax: (thread-sleep! timeout)
Library: (srfi 18)
Description: Causes the current thread to sleep. timeout can be a time object (absolute deadline) or a number (relative seconds).
Example:
  (thread-sleep! 0.1)
```

### `thread-specific`

```
Syntax: (thread-specific thread)
Library: (srfi 18)
Description: Returns the thread-specific data of the thread.
Example:
  (thread-specific (current-thread)) => ()
```

### `thread-specific-set!`

```
Syntax: (thread-specific-set! thread obj)
Library: (srfi 18)
Description: Sets the thread-specific data of the thread to obj.
Example:
  (thread-specific-set! (current-thread) 42)
```

### `thread-start!`

```
Syntax: (thread-start! thread)
Library: (srfi 18)
Description: Makes thread runnable. The thread will execute its thunk in a new
  execution context with its own dynamic environment inherited from the creating
  thread. Returns the thread.
Example:
  (thread-start! (make-thread (lambda () 42)))
```

### `thread-terminate!`

```
Syntax: (thread-terminate! thread)
Library: (srfi 18)
Description: Terminates the given thread.
Example:
  (thread-terminate! thread)
```

### `thread-yield!`

```
Syntax: (thread-yield!)
Library: (srfi 18)
Description: Causes the current thread to yield the processor.
Example:
  (thread-yield!)
```

### `thread?`

```
Syntax: (thread? x)
Library: (srfi 18)
Description: Returns #t if x is a thread object.
Example:
  (thread? (make-thread (lambda () 1))) => #t
```

### `time->seconds`

```
Syntax: (time->seconds time)
Library: (srfi 18)
Description: Returns the time as an inexact number of seconds since the Unix epoch.
Example:
  (> (time->seconds (current-time)) 0) => #t
```

### `time?`

```
Syntax: (time? obj)
Library: (srfi 19)
Description: Returns #t if obj is a SRFI-19 time object, #f otherwise.
Example:
  (time? (current-time)) => #t
```

### `uncaught-exception-reason`

```
Syntax: (uncaught-exception-reason exn)
Library: (srfi 18)
Description: Returns the original exception from an uncaught-exception object.
Example:
  (uncaught-exception-reason exn)
```

### `uncaught-exception?`

```
Syntax: (uncaught-exception? obj)
Library: (srfi 18)
Description: Returns #t if obj is an uncaught exception.
Example:
  (guard (e ((uncaught-exception? e) (uncaught-exception-reason e)))
    (thread-join! (thread-start! (make-thread (lambda () (error "oops"))))))
```

### `with-exception-handler`

```
Syntax: (with-exception-handler handler thunk)
Library: (scheme base)
Description: Calls thunk with handler installed as the current exception handler.
Example:
  (with-exception-handler (lambda (e) 42) (lambda () (raise 'oops))) => 42
```

