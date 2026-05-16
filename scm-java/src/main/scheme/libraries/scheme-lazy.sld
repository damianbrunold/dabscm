(define-library (scheme lazy)
  (import (scm core))
  (export delay
          delay-force
          force
          make-promise
          promise?)
  (begin
    (define apply (%primitive "apply"))
    (define values (%primitive "values"))
    (define call-with-values (%primitive "call-with-values"))
    (define car (%primitive "car"))
    (define eq? (%primitive "eq?"))
    (define = (%primitive "="))
    (define vector? (%primitive "vector?"))
    (define vector-length (%primitive "vector-length"))
    (define vector-ref (%primitive "vector-ref"))
    (define vector (%primitive "vector"))
    (define not (%primitive "not"))
    (define lambda? (%primitive "lambda?"))
    (define primitive? (%primitive "primitive?"))

    (define (make-promise p)
      "Syntax: (make-promise obj)
Library: (scheme lazy)
Description: Returns a promise wrapping obj. If obj is already a promise, it
  is returned unchanged. If obj is a procedure, it is treated as a thunk that
  will be called at most once when forced. Otherwise, obj is wrapped so that
  forcing the promise returns obj directly.
Example:
  (force (make-promise 42))               => 42
  (force (make-promise (lambda () (+ 1 2)))) => 3
  (force (make-promise (delay 10)))       => 10"
      (cond
        ((promise? p) p)
        ((or (lambda? p) (primitive? p))
         ;; Thunk — used internally by delay/delay-force
         (let ((vals #f) (set? #f))
           (let ((self
                  (lambda ()
                    (if (not set?)
                        (call-with-values p
                          (lambda x
                            (if (not set?)
                                (begin (set! vals x) (set! set? #t))))))
                    (apply values vals))))
             (vector 'promise self))))
        (else
         ;; Plain value — wrap as pre-forced promise
         (vector 'promise (lambda () p)))))

    (define (promise? x)
      "Syntax: (promise? obj)
Library: (scheme lazy)
Description: Returns #t if obj is a promise, otherwise returns #f. Promise
objects are created by delay, delay-force, or make-promise.
Example:
  (promise? (delay 1))          => #t
  (promise? (make-promise 42))  => #t
  (promise? 42)                 => #f"
      (and (vector? x)
           (= (vector-length x) 2)
           (eq? (vector-ref x 0) 'promise)))

    (define (force p)
      "Syntax: (force promise)
Library: (scheme lazy)
Description: Forces the value of a promise created by delay, delay-force, or
make-promise. If the promise has not been forced previously, its value is
computed by calling the thunk that was used to create it and is cached for
future calls to force. If promise is not a promise, it is returned as-is.
Example:
  (force (delay (+ 1 2)))   => 3
  (define p (delay (begin (display \"computed\") 42)))
  (force p)  => 42  ; prints \"computed\" once
  (force p)  => 42  ; cached, no output"
      (if (promise? p)
          ((vector-ref p 1))
          p))

    (define-syntax delay
      "Syntax: (delay expr)
Library: (scheme lazy)
Description: Returns a promise that, when forced via force, will evaluate
expr and cache the result. The expression is not evaluated until the first
call to force. Subsequent calls return the cached result.
Example:
  (define p (delay (begin (display \"once\") 42)))
  (force p) => 42  ; prints \"once\"
  (force p) => 42  ; cached, no output"
      (syntax-rules ()
        ((delay expr) (make-promise (lambda () expr)))))

    (define-syntax delay-force
      "Syntax: (delay-force expr)
Library: (scheme lazy)
Description: Returns a promise that, when forced, evaluates expr and then
forces the resulting promise. Enables iterative lazy algorithms by allowing
promises to be composed without growing the stack.
Example:
  (define (lazy-count n)
    (if (= n 0) (delay 'done) (delay-force (lazy-count (- n 1)))))
  (force (lazy-count 100000)) => done"
      (syntax-rules ()
        ((delay-force expr) (make-promise (lambda () (force expr))))))))
