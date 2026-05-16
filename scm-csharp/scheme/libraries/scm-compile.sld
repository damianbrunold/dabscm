(define-library (scm compile)
  (import (scm core))
  (export atom?
          bound?
          compile
          constant?
          disassemble
          gensym
          get-code
          get-lambda-env
          get-token
          instruction-arg1
          instruction-arg2
          instruction-opcode
          lambda?
          macro?
          make-instruction
          primitive?
          set-code!)
  (begin
    (define compile (%primitive "compile"))
    (define disassemble (%primitive "disassemble"))
    (define get-code (%primitive "get-code"))
    (define set-code! (%primitive "set-code!"))
    (define instruction-arg1 (%primitive "instruction-arg1"))
    (define instruction-arg2 (%primitive "instruction-arg2"))
    (define instruction-opcode (%primitive "instruction-opcode"))
    (define make-instruction (%primitive "make-instruction"))
    (define bound? (%primitive "bound?"))
    (define lambda? (%primitive "lambda?"))
    (define primitive? (%primitive "primitive?"))
    (define gensym (%primitive "gensym"))
    (define get-lambda-env (%primitive "get-lambda-env"))
    (define get-token (%primitive "get-token"))

    (define (macro? obj)
      "Syntax: (macro? obj)
Library: (scm compile)
Description: Returns #t if obj is a macro (a pair whose car is the symbol
'macro and whose cadr is a procedure), otherwise returns #f.
Example:
  (macro? (list 'macro (lambda (x) x))) => #t
  (macro? car) => #f"
      (and (pair? obj)
           (eq? (car obj) 'macro)
           (lambda? (cadr obj))))

    (define (atom? obj)
      "Syntax: (atom? obj)
Library: (scm compile)
Description: Returns #t if obj is an atomic value: a number, boolean, char,
string, or symbol. Returns #f for pairs, vectors, and other compound objects.
Example:
  (atom? 42)   => #t
  (atom? 'x)   => #t
  (atom? '(1)) => #f"
      (or (number? obj)
          (boolean? obj)
          (char? obj)
          (string? obj)
          (symbol? obj)))))
