# `(scheme lazy)`

Lazy evaluation and promises

## Exports

### `delay`

```
Syntax: (delay expr)
Library: (scheme lazy)
Description: Returns a promise that, when forced via force, will evaluate
expr and cache the result. The expression is not evaluated until the first
call to force. Subsequent calls return the cached result.
Example:
  (define p (delay (begin (display "once") 42)))
  (force p) => 42  ; prints "once"
  (force p) => 42  ; cached, no output
```

### `delay-force`

```
Syntax: (delay-force expr)
Library: (scheme lazy)
Description: Returns a promise that, when forced, evaluates expr and then
forces the resulting promise. Enables iterative lazy algorithms by allowing
promises to be composed without growing the stack.
Example:
  (define (lazy-count n)
    (if (= n 0) (delay 'done) (delay-force (lazy-count (- n 1)))))
  (force (lazy-count 100000)) => done
```

### `force`

```
Syntax: (force promise)
Library: (scheme lazy)
Description: Forces the value of a promise created by delay, delay-force, or
make-promise. If the promise has not been forced previously, its value is
computed by calling the thunk that was used to create it and is cached for
future calls to force. If promise is not a promise, it is returned as-is.
Example:
  (force (delay (+ 1 2)))   => 3
  (define p (delay (begin (display "computed") 42)))
  (force p)  => 42  ; prints "computed" once
  (force p)  => 42  ; cached, no output
```

### `make-promise`

```
Syntax: (make-promise obj)
Library: (scheme lazy)
Description: Returns a promise wrapping obj. If obj is already a promise, it
  is returned unchanged. If obj is a procedure, it is treated as a thunk that
  will be called at most once when forced. Otherwise, obj is wrapped so that
  forcing the promise returns obj directly.
Example:
  (force (make-promise 42))               => 42
  (force (make-promise (lambda () (+ 1 2)))) => 3
  (force (make-promise (delay 10)))       => 10
```

### `promise?`

```
Syntax: (promise? obj)
Library: (scheme lazy)
Description: Returns #t if obj is a promise, otherwise returns #f. Promise
objects are created by delay, delay-force, or make-promise.
Example:
  (promise? (delay 1))          => #t
  (promise? (make-promise 42))  => #t
  (promise? 42)                 => #f
```

