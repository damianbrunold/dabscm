(import (scheme base) (scheme write) (scheme eval) (scheme cxr) (srfi 1)
        (scm compile))

;; The VM's state (function, instruction pointer, environment, stack)
;; across the points where it leaves the dispatch loop or is replaced
;; from outside it: errors and exception handlers, continuations, stack
;; growth, apply and multiple values, nested evaluation.

;; Errors raised by primitives, by VM opcodes (wrong type casts) and by
;; raise, caught at different depths; the catching function's locals and
;; the stack below must be intact afterwards.
(test-group
  (define (deep n thunk) (if (= n 0) (thunk) (+ 0 (deep (- n 1) thunk))))
  (define (catch-msg thunk)
    (guard (e ((error-object? e) (error-object-message e))
              (#t (list 'raised e)))
      (thunk)))
  (=> (catch-msg (lambda () (car 1))) "Failed in car: wrong argument type")
  (=> (catch-msg (lambda () (deep 50 (lambda () (vector-ref (vector 1) 5)))))
      "vector-ref: index out of range: 5")
  (=> (catch-msg (lambda () (deep 50 (lambda () (string-length 5)))))
      "Failed in string-length: wrong argument type")
  (=> (catch-msg (lambda () (deep 50 (lambda () (raise 'boom))))) '(raised boom))
  (=> (catch-msg (lambda () (deep 50 (lambda () (error "custom" 1 2))))) "custom")
  (=> (catch-msg (lambda () (deep 3 (lambda () (- 'x 4)))))
      "Failed in -: wrong argument type")
  (=> ; locals and pending arguments of the catching frame survive
  (let ((a 1) (b 2))
    (let ((r (list a (guard (e (#t (+ a b 100))) (+ a (car 'no))) b)))
      (list r a b)))
  '((1 103 2) 1 2))
  (=> ; after a caught error, the following calls run in the right frame
  (let loop ((i 0) (acc '()))
    (if (= i 5)
        (reverse acc)
        (loop (+ i 1)
              (cons (guard (e (#t (* i 10))) (if (odd? i) (car i) i)) acc))))
  '(0 10 2 30 4))
  (=> ; many errors caught in a loop do not leak stack
  (let loop ((i 0) (n 0))
    (if (= i 20000)
        n
        (loop (+ i 1) (+ n (guard (e (#t 1)) (deep 3 (lambda () (car '()))))))))
  20000)
  (=> ; nested guards: inner re-raises, outer catches
  (guard (e ((symbol? e) (list 'outer e)))
    (guard (e ((string? e) 'inner))
      (deep 10 (lambda () (raise 'sym)))))
  '(outer sym))
  (=> ; error inside a guard clause goes to the outer guard
  (guard (e2 (#t (list 'outer (error-object-message e2))))
    (guard (e (#t (car e)))
      (raise 5)))
  '(outer "Failed in car: wrong argument type"))
  (=> ; error while evaluating arguments of a primitive call
  (guard (e (#t 'caught)) (list 1 2 (car 3) 4)) 'caught)
  (=> ; wrong arity, fixed and rest-argument lambdas
  (list (guard (e (#t 'a)) ((lambda (x y) x) 1))
        (guard (e (#t 'b)) ((lambda (x y . r) x) 1))
        ((lambda (x . r) (list x r)) 1 2 3))
  '(a b (1 (2 3)))))

;; with-exception-handler: handlers that escape, that return (raise-
;; continuable resumes, raise reports "handler returned"), primitive
;; handlers and handlers that raise themselves.
(test-group
  (=> (+ 1 (with-exception-handler
            (lambda (e) 41)
            (lambda () (raise-continuable 'c))))
      42)
  (=> ; resuming inside a deep non-tail computation
  (let ((f (lambda (n) (* n (raise-continuable n)))))
    (with-exception-handler
     (lambda (n) (+ n 1))
     (lambda () (list (f 2) (f 3) (+ 1 (f 4))))))
  '(6 12 21))
  (=> (call/cc
       (lambda (k)
         (with-exception-handler
          (lambda (e) (k (list 'escaped (error-object-message e))))
          (lambda () (+ 1 (car 'x))))))
      '(escaped "Failed in car: wrong argument type"))
  (=> ; a handler that returns from a non-continuable raise
  (guard (e ((error-object? e) (error-object-message e)))
    (with-exception-handler
     (lambda (e) 'ignored)
     (lambda () (raise 'boom))))
  "raise: exception handler returned")
  (=> ; the same for a primitive handler
  (guard (e ((error-object? e) (error-object-message e)))
    (with-exception-handler list (lambda () (raise 'boom))))
  "raise: exception handler returned")
  (=> ; a handler that raises goes to the outer handler
  (guard (e (#t (list 'outer e)))
    (with-exception-handler
     (lambda (e) (raise (list 'from-handler e)))
     (lambda () (+ 1 (raise 'inner)))))
  '(outer (from-handler inner)))
  (=> ; a VM error inside a handler goes to the outer handler
  (guard (e ((error-object? e) (error-object-message e)))
    (with-exception-handler
     (lambda (e) (vector-ref e 0))
     (lambda () (raise 'x))))
  "Failed in vector-ref: wrong argument type"))

;; Continuations: escapes from deep non-tail calls, re-entry, generators,
;; dynamic-wind.
(test-group
  (define (deep n thunk) (if (= n 0) (thunk) (+ 1 (deep (- n 1) thunk))))
  (=> (call/cc (lambda (k) (deep 1000 (lambda () (k 'out))))) 'out)
  (=> ; re-entering a continuation captured deep in non-tail calls
  (let ((k2 #f) (count 0))
    (let ((r (deep 100 (lambda () (call/cc (lambda (k) (set! k2 k) 0))))))
      (set! count (+ count 1))
      (if (< count 4) (k2 count) (list r count))))
  '(103 4))
  (=> ; a generator with two continuations
  (let ()
    (define return #f)
    (define resume #f)
    (define (gen)
      (for-each (lambda (x) (call/cc (lambda (k) (set! resume k) (return x))))
                '(a b c))
      (return 'done))
    (let loop ((acc '()))
      (let ((v (call/cc (lambda (k)
                          (set! return k)
                          (if resume (resume #f) (gen))))))
        (if (eq? v 'done) (reverse acc) (loop (cons v acc))))))
  '(a b c))
  (=> ; dynamic-wind with escape and re-entry
  (let ((log '()) (k2 #f) (n 0))
    (dynamic-wind
     (lambda () (set! log (cons 'in log)))
     (lambda () (call/cc (lambda (k) (set! k2 k))) (set! n (+ n 1)))
     (lambda () (set! log (cons 'out log))))
    (if (< n 3) (k2 #f))
    (reverse log))
  '(in out in out in out))
  (=> ; escaping from deep inside dynamic-wind runs the after thunk
  (let ((log '()))
    (let ((r (call/cc
              (lambda (k)
                (dynamic-wind
                 (lambda () (set! log (cons 'in log)))
                 (lambda () (deep 200 (lambda () (k 'escaped))))
                 (lambda () (set! log (cons 'out log))))))))
      (list r (reverse log))))
  '(escaped (in out)))
  (=> ; guard clauses run after the after thunks of the body (R7RS)
  (let ((log '()))
    (guard (e (#t (set! log (cons 'caught log))))
      (dynamic-wind
       (lambda () (set! log (cons 'in log)))
       (lambda () (+ 1 (car 'x)))
       (lambda () (set! log (cons 'out log)))))
    (reverse log))
  '(in out caught))
  (=> ; the same for raise
  (let ((log '()))
    (guard (e ((symbol? e) (set! log (cons e log))))
      (dynamic-wind
       (lambda () (set! log (cons 'in log)))
       (lambda () (raise 'boom))
       (lambda () (set! log (cons 'out log)))))
    (reverse log))
  '(in out boom))
  (=> ; no clause matches: the re-raise happens back inside the body's extent
  (let ((log '()))
    (guard (e (#t (set! log (cons (list 'outer e) log))))
      (guard (e ((string? e) (set! log (cons 'inner log))))
        (dynamic-wind
         (lambda () (set! log (cons 'in log)))
         (lambda () (raise 'sym))
         (lambda () (set! log (cons 'out log))))))
    (reverse log))
  '(in out in out (outer sym)))
  (=> ; raise-continuable through a guard without matching clause resumes
  (with-exception-handler
   (lambda (e) 10)
   (lambda ()
     (+ 1 (guard (e ((string? e) 'no))
            (raise-continuable 'c)))))
  11)
  (=> ; a guard clause sees the handlers outside the guard
  (guard (e2 (#t (list 'outer e2)))
    (guard (e (#t (raise (list 'again e))))
      (raise 'first)))
  '(outer (again first)))
  (=> ; guard returns multiple values of its body
  (call-with-values (lambda () (guard (e (#t 0)) (values 1 2))) list)
  '(1 2))
  (=> ; a continuation called with multiple values
  (call-with-values (lambda () (call/cc (lambda (k) (k 1 2 3)))) list)
  '(1 2 3)))

;; Stack growth (the initial VM stack holds 512 entries): deep recursion
;; with many arguments and pending values, apply with long lists, many
;; values.
(test-group
  (define (wide n a b c d e f g h)
    (if (= n 0)
        (+ a b c d e f g h)
        (+ 1 (wide (- n 1) a b c d e f g h))))
  (=> (wide 20000 1 2 3 4 5 6 7 8) 20036)
  (=> ; growth while arguments of an outer call are pending
  (list 1 2 3 (wide 5000 0 0 0 0 0 0 0 0) 5 6)
  '(1 2 3 5000 5 6))
  (=> (apply + (iota 10000)) 49995000)
  (=> (apply (lambda args (length args)) (iota 5000)) 5000)
  (=> (apply max 1 2 (iota 3000)) 2999)
  (=> (call-with-values (lambda () (apply values (iota 2000))) (lambda xs (length xs)))
      2000)
  (=> ; deep recursion through a primitive-calling, list-building body
  (length (let loop ((n 30000)) (if (= n 0) '() (cons (string-length "ab") (loop (- n 1))))))
  30000)
  (=> ; a continuation captured on a big stack, used after it shrank
  (let ((k2 #f) (n 0))
    (let ((r (wide 2000 0 0 0 0 0 0 0 (call/cc (lambda (k) (set! k2 k) 1)))))
      (set! n (+ n 1))
      (if (< n 3) (k2 (* 10 n)) (list r n))))
  '(2020 3)))

;; Multiple values through primitive calls and frames.
(test-group
  (=> (call-with-values (lambda () (values)) list) '())
  (=> (call-with-values (lambda () (values 1 2)) (lambda (a b) (list b a))) '(2 1))
  (=> ; values returned through several non-tail frames
  (let ((f (lambda () (values 'x 'y))))
    (call-with-values (lambda () (f)) list))
  '(x y))
  (=> (let-values (((a b) (values 1 2)) ((c) (values 3))) (list a b c)) '(1 2 3))
  (=> ; values stored by a primitive keep their contents after later calls
  (let ((v (values 1 2)))
    (string-length "abc")
    (call-with-values (lambda () v) list))
  '(1 2)))

;; Frames: variables of outer frames read and written across calls,
;; closures over loop variables.
(test-group
  (=> (let ((a 1))
        (let ((b 2))
          (let ((c 3))
            (set! a (+ a 10))
            (set! b (+ b (string-length "xyz")))
            ((lambda () (set! c (+ a b c))))
            (list a b c))))
      '(11 5 19))
  (=> (map (lambda (th) (th))
           (let loop ((i 0) (acc '()))
             (if (= i 3) (reverse acc) (loop (+ i 1) (cons (lambda () (* i i)) acc)))))
      '(0 1 4))
  (=> (let ((counter (let ((n 0)) (lambda () (set! n (+ n 1)) n))))
        (counter) (counter)
        (list (counter) (+ 1 (counter))))
      '(3 5))
  (=> ; set-code! replaces the code of a procedure that already ran
  (let ((f (lambda () 1)))
    (let ((before (f)))
      (set-code! f (list-ref (compile 2) 5))
      (list before (f))))
  '(1 2)))

;; Nested evaluation: eval runs in its own VM and returns into the
;; caller's frame.
(test-group
  (=> (let ((a 5)) (+ a (eval '(+ 1 2) (environment '(scheme base))) a)) 13)
  (=> (let ((a 5)) (list a (eval '(let loop ((i 0)) (if (= i 1000) i (loop (+ i 1))))
                                 (environment '(scheme base)))
                         a))
      '(5 1000 5))
  (=> (guard (e (#t 'caught)) (+ 1 (eval '(car 1) (environment '(scheme base))))) 'caught))

;; Fixnum overflow inside the arithmetic opcodes (the result becomes a
;; bignum) at positions where the stack below holds pending values.
(test-group
  (define big 9223372036854775807)
  (define small -9223372036854775808)
  (=> (list 1 (+ big 1) 2) '(1 9223372036854775808 2))
  (=> (list 1 (- small 1) 2) '(1 -9223372036854775809 2))
  (=> (list 1 (* big 2) 2) '(1 18446744073709551614 2))
  (=> (list 1 (- small) 2) '(1 9223372036854775808 2))
  (=> (let ((x big)) (list 'a (+ x 1) 'b (- (- x) 2) 'c))
      '(a 9223372036854775808 b -9223372036854775809 c))
  (=> (let loop ((i 0) (acc '()))
        (if (= i 3) (reverse acc) (loop (+ i 1) (cons (+ big i) acc))))
      '(9223372036854775807 9223372036854775808 9223372036854775809))
  (=> (let ((f (lambda (n) (* n n n))))
        (list (f 3) (f 3000000000) (f 4)))
      '(27 27000000000000000000000000000 64)))

;; (scm core) exports the same call/cc as (scheme base): importing it last
;; still runs the dynamic-wind thunks.
(test-group
  (import (scheme base) (scm core))
  (=> (let ((log '()) (k2 #f) (n 0))
        (dynamic-wind
         (lambda () (set! log (cons 'in log)))
         (lambda () (call/cc (lambda (k) (set! k2 k))) (set! n (+ n 1)))
         (lambda () (set! log (cons 'out log))))
        (if (< n 2) (k2 #f))
        (reverse log))
      '(in out in out))
  (=> (let ((log '()))
        (call/cc
         (lambda (k)
           (dynamic-wind
            (lambda () (set! log (cons 'in log)))
            (lambda () (k 'x))
            (lambda () (set! log (cons 'out log))))))
        (reverse log))
      '(in out)))

;; define-record-type procedures are primitives (%record-procedure).
(test-group
  (define (msg+irritants thunk)
    (guard (e ((error-object? e)
               (cons (error-object-message e) (length (error-object-irritants e)))))
      (thunk)))
  (define-record-type point (make-point x y) point? (x point-x set-point-x!) (y point-y))
  (define-record-type cell (make-cell value) cell? (value cell-value) (extra cell-extra set-cell-extra!))
  (define p (make-point 1 2))
  (=> (list (point-x p) (point-y p) (point? p) (point? 5) (point? (make-cell 1))) '(1 2 #t #f #f))
  (=> (begin (set-point-x! p 10) (point-x p)) 10)
  (=> (cell-extra (make-cell 1)) #f)
  (=> (let ((c (make-cell 1))) (set-cell-extra! c 'e) (list (cell-value c) (cell-extra c))) '(1 e))
  (=> (msg+irritants (lambda () (point-x (make-cell 1)))) '("accessor applied to bad value" . 3))
  (=> (msg+irritants (lambda () (point-x 'p))) '("accessor applied to bad value" . 3))
  (=> (msg+irritants (lambda () (set-point-x! 'p 1))) '("modifier applied to bad value" . 3))
  (=> (msg+irritants (lambda () (make-point 1))) '("wrong number of arguments to constructor" . 2))
  (=> (msg+irritants (lambda () (make-point 1 2 3))) '("wrong number of arguments to constructor" . 2))
  (=> (map point-y (list (make-point 1 'a) (make-point 2 'b))) '(a b))
  (=> (procedure? point-x) #t)
  (=> (let loop ((i 0) (acc '())) (if (= i 3) (map point-x acc) (loop (+ i 1) (cons (make-point i i) acc))))
      '(2 1 0)))

;; Compiler: named lets as loops (LOOP), self tail calls of letrec lambdas
;; (LOOP), or without a temporary frame (TJUMP_KEEP); the cases below fall
;; back to the ordinary compilation or must keep its semantics.
(test-group
  (define (arity thunk) (guard (e (#t 'error)) (thunk)))
  ;; named let: per-iteration bindings, non-tail use, deep iteration
  (=> (map (lambda (p) (p)) (let loop ((i 0) (acc '())) (if (= i 3) acc (loop (+ i 1) (cons (lambda () i) acc)))))
      '(2 1 0))
  (=> (+ 1 (let loop ((i 0)) (if (< i 10) (loop (+ i 1)) i))) 11)
  (=> (let loop ((i 0)) (if (< i 1000000) (loop (+ i 1)) i)) 1000000)
  (=> (let outer ((i 0) (acc '()))
        (if (= i 3) (reverse acc)
            (let inner ((j 0)) (if (< j i) (inner (+ j 1)) (outer (+ i 1) (cons j acc))))))
      '(0 1 2))
  (=> (let loop ((i 0)) (define (dbl x) (* 2 x)) (if (< i 3) (loop (+ i 1)) (dbl i))) 6)
  (=> (call-with-values (lambda () (let loop ((i 0)) (if (< i 2) (loop (+ i 1)) (values i 'v)))) list) '(2 v))
  ;; named let falling back: non-tail call, name as value, set!, shadowed,
  ;; called from a nested lambda, wrong argument count
  (=> (let loop ((x '(1 (2 3) 4))) (if (pair? x) (+ (loop (car x)) (loop (cdr x))) (if (null? x) 0 x))) 10)
  (=> (let loop ((i 0)) (if (< i 3) (loop (+ i 1)) (procedure? loop))) #t)
  (=> (let loop ((i 0)) (if (< i 2) (loop (+ i 1)) (begin (set! loop 5) loop))) 5)
  (=> (let loop ((i 0)) (if (< i 3) (let ((loop (lambda (x) (* x 100)))) (loop (+ i 1))) i)) 100)
  (=> (let loop ((i 0)) (if (< i 3) ((lambda () (loop (+ i 1)))) i)) 3)
  (=> (arity (lambda () (let loop ((i 0)) (if (< i 2) (loop (+ i 1) 'extra) i)))) 'error)
  ;; self tail calls
  (=> (let () (define (h i acc) (if (= i 0) acc (h (- i 1) (+ acc i)))) (h 1000000 0)) 500000500000)
  (=> (letrec ((g (lambda (n) (if (= n 0) 'g0 (g (- n 1))))))
        (let ((r (g 3))) (set! g (lambda (n) 'new)) (list r (g 3))))
      '(g0 new))
  (=> (letrec ((g (lambda (n) (if (= n 0) 0 ((lambda () (+ 1 (g (- n 1))))))))) (g 5)) 5)
  (=> (arity (lambda () (let () (define (h i) (if (= i 0) 'done (h (- i 1) 'x))) (h 3)))) 'error)
  ;; or
  (=> (let ((o (lambda (a b) (or a b)))) (list (o #f 1) (o 2 #f) (o #f #f) (or))) '(1 2 #f #f))
  (=> (list (if (or #f 'a) 'yes 'no) (if (or #f #f) 'yes 'no) (let ((t 1)) (or #f t))) '(yes no 1))
  (=> (let ((r '())) (or (begin (set! r (cons 1 r)) #f) (begin (set! r (cons 2 r)) #f)) r) '(2 1))
  (=> (list (or (memv 3 '(1 2 3)) 'no) (or (memv 9 '(1 2)) 'no) (and (or #f 1) (or 2))) '((3) no 2))
  (=> (let loop ((i 0) (c 0)) (if (= i 10) c (loop (+ i 1) (if (or (eq? i 3) (eq? i 5) (not (odd? i))) (+ c 1) c))))
      7))
