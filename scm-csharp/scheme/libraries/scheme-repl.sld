(define-library (scheme repl)
  (export interaction-environment)
  (begin
    (define (interaction-environment)
      "Syntax: (interaction-environment)
Library: (scheme repl)
Description: Returns the environment specifier for the interactive REPL
environment, which in this implementation is (user main). This environment
includes all standard bindings and is the namespace in which the REPL
evaluates expressions. In a program (a script run with scm), which has no
REPL, it stands for the program's own top level, where load also defines.
The returned specifier can be passed to eval.
Example:
  (interaction-environment) => (user main)
  (eval '(+ 1 2) (interaction-environment)) => 3"
      '(user main))))
