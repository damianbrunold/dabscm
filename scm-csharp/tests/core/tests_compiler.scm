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
  (=> (has-opcode? use-h "CALLS") #t)
  (=> (has-opcode? use-h "SAVE") #f)
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
