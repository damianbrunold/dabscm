;; Errors raised and caught, escapes, dynamic-wind, parameterize, eval
(import (scheme base) (scheme write) (scheme eval) (soak lib))

(define p (make-parameter 1))

(soak "control"
      (lambda (round)
        (do ((i 0 (+ i 1))) ((= i (scale 2000)))
          (guard (e (#t (error-object-message e))) (error "boom" i (make-vector 10)))
          (guard (e ((symbol? e) e)) (raise 'sym))
          (call-with-current-continuation (lambda (k) (dynamic-wind (lambda () #f) (lambda () (k i)) (lambda () #f))))
          (with-exception-handler (lambda (e) 0) (lambda () (+ 1 (raise-continuable 'c))))
          (parameterize ((p i)) (p))
          (when (= 0 (modulo i 20))
            (eval (list '+ i 1) (environment '(scheme base)))))
        (garbage)))
