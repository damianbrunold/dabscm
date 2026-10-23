(import (scheme base) (scm compile) (scm core))

(test-group
  (define (first-word s)
    (let loop ((i 0))
      (if (or (= i (string-length s))
              (char=? (string-ref s i) #\space))
          (substring s 0 i)
          (loop (+ i 1)))))
  (define (opcodes fn)
    (map first-word (get-code fn)))
  (define (has-opcode? fn op)
    (let loop ((code (opcodes fn)))
      (cond ((null? code) #f)
            ((string=? (car code) op) #t)
            (else (loop (cdr code))))))
  (=> (opcodes (lambda () (if #t 42 0))) '("ARGS" "CONST" "RETURN"))
  (=> (opcodes (lambda () (if #f 0 42))) '("ARGS" "CONST" "RETURN"))
  (=> ; Case A: (if x 1 2) with val=false → both branches nil → whole if eliminated
  ; Result: only ARGS + CONST 3 + RETURN
  (length (get-code (lambda (x) (begin (if x 1 2) 3)))) 3)
  (=> ; Case A: FJUMP should be completely absent (entire if produces no code)
  (has-opcode? (lambda (x) (begin (if x 1 2) 3)) "FJUMP") #f)
  (=> ; Case C: (if x display-call) with val=false → ecode=NIL → FJUMP only, no JUMP
  (has-opcode? (lambda (x) (begin (if x (display 1)) #t)) "JUMP") #f)
  (=> ; Case B: (if x 1 display-call) with val=false → tcode=NIL → TJUMP, no FJUMP
  (has-opcode? (lambda (x y) (begin (if x 1 (display y)) y)) "FJUMP") #f))

(test-group
  (=> (if #t 1 2) 1)
  (=> (if #f 1 2) 2)
  (=> ((lambda (x) (begin (if x 1 2) 3)) #t) 3)
  (=> ((lambda (x) (begin (if x 1 2) 3)) #f) 3)
  (=> ; if without else: correct behavior with both truthy and falsy pred
  ((lambda (x) (begin (if x (display "side-effect")) 42)) #f) 42)
  (define (loop n acc)
    (if (= n 0) acc (loop (- n 1) (+ acc n))))
  (=> (loop 100000 0) 5000050000))

; Pass E: NOT + branch fusion
(test-group
  (define (first-word s)
    (let loop ((i 0))
      (if (or (= i (string-length s))
              (char=? (string-ref s i) #\space))
          (substring s 0 i)
          (loop (+ i 1)))))
  (define (opcodes fn)
    (map first-word (get-code fn)))
  (define (has-opcode? fn op)
    (let loop ((code (opcodes fn)))
      (cond ((null? code) #f)
            ((string=? (car code) op) #t)
            (else (loop (cdr code))))))
  (=> ; NOT+FJUMP fused to TJUMP: NOT opcode should be absent
  (has-opcode? (lambda (x) (if (not x) 1 2)) "NOT") #f)
  (=> ; NOT+FJUMP fused to TJUMP: TJUMP should be present
  (has-opcode? (lambda (x) (if (not x) 1 2)) "TJUMP") #t)
  (=> ; Correctness: (if (not #f) ...) takes then-branch
  ((lambda (x) (if (not x) 'yes 'no)) #f) 'yes)
  (=> ; Correctness: (if (not #t) ...) takes else-branch
  ((lambda (x) (if (not x) 'yes 'no)) #t) 'no)
  (=> ; Correctness: (if (not 42) ...) — 42 is truthy
  ((lambda (x) (if (not x) 'yes 'no)) 42) 'no)
  (=> ; unless macro uses (not test), should also be fused
  (has-opcode? (lambda (x) (unless x 42)) "NOT") #f)
  (=> ; Nested not: (if (not (not x)) ...) — double NOT both fused
  ((lambda (x) (if (not (not x)) 'yes 'no)) #t) 'yes)
  (=> ((lambda (x) (if (not (not x)) 'yes 'no)) #f) 'no))

; Pass I: LVAR + CONST(integer) + ADD/SUB 2 fusion
(test-group
  (define (first-word s)
    (let loop ((i 0))
      (if (or (= i (string-length s))
              (char=? (string-ref s i) #\space))
          (substring s 0 i)
          (loop (+ i 1)))))
  (define (opcodes fn)
    (map first-word (get-code fn)))
  (define (has-opcode? fn op)
    (let loop ((code (opcodes fn)))
      (cond ((null? code) #f)
            ((string=? (car code) op) #t)
            (else (loop (cdr code))))))
  (=> ; LVAR+CONST+ADD fused to LVAR_ADD_IMM
  (has-opcode? (lambda (x) (+ x 1)) "LVAR_ADD_IMM") #t)
  (=> ; ADD opcode should be absent after fusion
  (has-opcode? (lambda (x) (+ x 1)) "ADD") #f)
  (=> ; LVAR+CONST+SUB fused to LVAR_SUB_IMM
  (has-opcode? (lambda (x) (- x 1)) "LVAR_SUB_IMM") #t)
  (=> ; SUB opcode should be absent after fusion
  (has-opcode? (lambda (x) (- x 1)) "SUB") #f)
  (=> ; Non-integer constant: no fusion (1.5 is not a long)
  (has-opcode? (lambda (x) (+ x 1.5)) "ADD") #t)
  (=> ; Correctness: increment
  ((lambda (x) (+ x 1)) 41) 42)
  (=> ; Correctness: decrement
  ((lambda (x) (- x 1)) 43) 42)
  (=> ; Correctness: set! with increment
  (let ((x 0)) (set! x (+ x 1)) x) 1)
  (=> ; Correctness: do loop with increment
  (do ((i 0 (+ i 1)) (sum 0 (+ sum i)))
      ((= i 10) sum)) 45)
  (=> ; Correctness: increment with larger immediate
  ((lambda (x) (+ x 100)) 0) 100)
  (=> ; Correctness: double value + integer immediate
  ((lambda (x) (+ x 1)) 1.5) 2.5)
  (=> ; Correctness: double value - integer immediate
  ((lambda (x) (- x 1)) 2.5) 1.5))

;; Non-tail calls (CALLS): primitive and lambda callees, the callee of a
;; global changing between them, frames, call/cc and errors inside the
;; argument evaluation.
(test-group
  (define (has-opcode? fn op)
    (let loop ((code (get-code fn)))
      (cond ((null? code) #f)
            ((string=? (substring (car code) 0 (min (string-length op)
                                                      (string-length (car code))))
                       op)
             #t)
            (else (loop (cdr code))))))
  (define h car)
  (define (use-h) (+ 1 (h '(41 0))))
  (=> (has-opcode? use-h "GCALLS") #t)
  (=> (has-opcode? use-h "SAVE") #f)
  (=> (has-opcode? (lambda (f) (+ 1 (f 2))) "CALLS") #t)
  (=> (use-h) 42)
  (set! h (lambda (x) (* 2 (cadr x))))
  (=> (use-h) 1)
  (set! h cadr)
  (=> (use-h) 1)
  (define (add4 a b c d) (+ a b c d))
  (=> (list (add4 1 2 3 4) (add4 (add4 1 1 1 1) 2 (string-length "abc") 4)) '(10 13))
  (=> ; deep non-tail recursion through a lambda
  (let loop ((n 100000)) (if (= n 0) 0 (+ 1 (loop (- n 1))))) 100000)
  (=> ; outer frame variables after non-tail calls
  (let ((a 1) (b 2))
    (let ((c (+ a (string-length "xy"))))
      (list a b c ((lambda (d) (+ a b c d)) 4)))) '(1 2 3 10))
  (=> ; escaping from inside an argument
  (+ 1 (call/cc (lambda (k) (* 10 (k 41))))) 42)
  (=> ; re-entering a continuation captured inside an argument
  (let ((k2 #f) (n 0))
    (let ((v (+ 100 (call/cc (lambda (k) (set! k2 k) 1)))))
      (set! n (+ n 1))
      (if (< n 3) (k2 n) (list v n)))) '(102 3))
  (=> ; wrong arity raised inside a non-tail call is catchable
  (guard (e (#t 'caught)) (+ 1 ((lambda (x) x) 1 2))) 'caught))

;; Fused instructions (GCALLS/GCALLJ, LVAR_CAR/CDR, LVAR_VREF,
;; LVAR_NULL_FJUMP/LVAR_PAIR_FJUMP, CONST_EQ_FJUMP) and POPENV, which
;; ends a non-tail let body instead of SAVE ... RETURN.
(test-group
  (define (has-opcode? fn op)
    (let loop ((code (get-code fn)))
      (cond ((null? code) #f)
            ((and (>= (string-length (car code)) (+ (string-length op) 1))
                  (string=? (substring (car code) 0 (+ (string-length op) 1))
                            (string-append op " ")))
             #t)
            ((string=? (car code) op) #t)
            (else (loop (cdr code))))))
  (define (msg thunk)
    (guard (e ((error-object? e) (error-object-message e))) (thunk)))
  (define (g x) (* x 2))
  (define (tail-g x) (g x))
  (define (head x) (car x))
  (define (tail x) (cdr x))
  (define (field v) (vector-ref v 2))
  (define (kind x) (if (null? x) 'null (if (pair? x) 'pair 'other)))
  (define (sym x) (if (eq? x 'a) 1 (if (eq? x 'b) 2 3)))
  (define (non-tail-let x) (+ 1 (let ((y (* x 2))) (+ y 1))))
  (=> (has-opcode? (lambda (x) (+ 1 (g x))) "GCALLS") #t)
  (=> (has-opcode? tail-g "GCALLJ") #t)
  (=> (has-opcode? head "LVAR_CAR") #t)
  (=> (has-opcode? tail "LVAR_CDR") #t)
  (=> (has-opcode? field "LVAR_VREF") #t)
  (=> (has-opcode? kind "LVAR_NULL_FJUMP") #t)
  (=> (has-opcode? kind "LVAR_PAIR_FJUMP") #t)
  (=> (has-opcode? sym "CONST_EQ_FJUMP") #t)
  (=> (has-opcode? non-tail-let "POPENV") #t)
  (=> (has-opcode? non-tail-let "SAVE") #f)
  (=> (list ((lambda (x) (+ 1 (g x))) 3) (tail-g 4)) '(7 8))
  (=> (list (head '(1 2)) (tail '(1 2)) (field (vector 'a 'b 'c 'd))) '(1 (2) c))
  (=> (map kind (list '() '(1) 5 "s" (vector))) '(null pair other other other))
  (=> (map sym (list 'a 'b 'c "a" 1)) '(1 2 3 3 3))
  (=> (non-tail-let 3) 8)
  (=> ; errors keep the name and message of the original instruction
  (list (msg (lambda () (head 5))) (msg (lambda () (tail 'x)))
        (msg (lambda () (field (vector 1 2)))) (msg (lambda () (field '(1 2 3)))))
  '("Failed in car: wrong argument type" "Failed in cdr: wrong argument type"
    "vector-ref: index out of range: 2" "Failed in vector-ref: wrong argument type"))
  (define (call-unbound) (+ 1 (no-such-procedure-xyz 2)))
  (=> (let ((m (msg call-unbound)))
        (substring m (- (string-length m) 12) (string-length m)))
      "is not bound")
  (define h car)
  (define (use-h x) (+ 0 (h x)))
  (=> (use-h '(5)) 5)
  (set! h (lambda (x) (cadr x)))
  (=> (use-h '(5 6)) 6)
  (=> ; apply of a global in tail position (GCALLJ with a flattened arg count)
  (let () (define (sum . xs) (apply + xs)) (sum 1 2 3)) 6)
  (=> ; non-tail let, let*, letrec, letrec* and inline lambda restore the frame
  (let ((a 1))
    (list (let ((b 2)) (+ a b))
          (let* ((b 2) (c (+ a b))) (* b c))
          (letrec ((f (lambda (n) (if (= n 0) a (f (- n 1)))))) (f 3))
          (letrec* ((x 5) (y (+ x a))) y)
          ((lambda (z) (+ z a)) 10)
          a))
  '(3 6 1 6 11 1))
  (=> ; non-tail let whose value is discarded
  (let ((n 0))
    (let ((x 1)) (set! n (+ n x)))
    (let ((x 2)) (set! n (+ n x)))
    n)
  3)
  (=> ; tail call inside a non-tail let body
  (+ 1 (let ((y 2)) (g y))) 5)
  (=> ; error inside a non-tail let body, caught outside
  (let ((a 1))
    (list a (guard (e (#t 'caught)) (+ 1 (let ((y 'x)) (car y)))) a))
  '(1 caught 1))
  (=> ; continuation captured in a non-tail let body, re-entered later
  (let ((k2 #f) (n 0) (a 'outer))
    (let ((r (+ 1 (let ((b 10)) (+ b (call/cc (lambda (k) (set! k2 k) 0)))))))
      (set! n (+ n 1))
      (if (< n 3) (k2 n) (list r n a))))
  '(13 3 outer))
  (=> ; deep non-tail recursion through a non-tail let
  (let loop ((n 50000)) (if (= n 0) 0 (+ 1 (let ((m (- n 1))) (loop m)))))
  50000))
