;; Threads started and joined, mutexes and condition variables, thread
;; parameters
(import (scheme base) (scheme write) (srfi 18) (soak lib))

(define p (make-parameter 0))

(soak "threads"
      (lambda (round)
        (do ((i 0 (+ i 1))) ((= i (scale 200)))
          (let* ((m (make-mutex))
                 (cv (make-condition-variable))
                 (box (list #f))
                 (consumer (make-thread
                            (lambda ()
                              (mutex-lock! m)
                              (let loop ()
                                (if (car box)
                                    (begin (mutex-unlock! m) (car box))
                                    (begin (mutex-unlock! m cv) (mutex-lock! m) (loop)))))))
                 (worker (make-thread (lambda () (parameterize ((p i)) (make-vector 100 (p)))))))
            (thread-start! consumer)
            (thread-start! worker)
            (thread-join! worker)
            (mutex-lock! m)
            (set-car! box i)
            (condition-variable-broadcast! cv)
            (mutex-unlock! m)
            (unless (= i (thread-join! consumer)) (error "wrong value"))))))
