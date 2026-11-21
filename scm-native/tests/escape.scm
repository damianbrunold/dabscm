(import (scheme base) (scheme write))
;; escape continuations (receivers that only call k) and full ones
(define (first-even l)
  (call/cc (lambda (return)
    (let loop ((l l))
      (cond ((null? l) #f)
            ((even? (car l)) (return (car l)))
            (else (loop (cdr l))))))))
(write (list (first-even '(1 3 4 5)) (first-even '(1 3))))
(newline)
;; deep: escaping from deep recursion
(define (deep n k) (if (= n 0) (k 'escaped) (+ 1 (deep (- n 1) k))))
(write (call/cc (lambda (k) (deep 100000 k))))   ; k passed on: a full continuation
(newline)
(write (call/cc (lambda (k) (+ 1 (k 42)))))      ; escape-only
(newline)
(write (+ 1 (call/cc (lambda (k) 10))))           ; not called at all
(newline)
(write (call-with-values (lambda () (call/cc (lambda (k) (k 1 2 3)))) list))
(newline)
;; with dynamic-wind: the after thunk runs on escape
(define trace '())
(write (call/cc (lambda (k)
  (dynamic-wind (lambda () (set! trace (cons 'in trace)))
                (lambda () (k 'out-of-wind))
                (lambda () (set! trace (cons 'after trace)))))))
(write (reverse trace))
(newline)
;; many escapes in a loop
(define (count-escapes n)
  (let loop ((i 0) (s 0))
    (if (= i n) s (loop (+ i 1) (+ s (call/cc (lambda (k) (k i))))))))
(write (count-escapes 100000))
(newline)
