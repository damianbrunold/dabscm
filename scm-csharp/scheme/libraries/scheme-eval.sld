(define-library (scheme eval)
  (export environment
          eval)
  (cond-expand
    (dabscm-native
     ;; natively: the expander and an interpreter linked into the program
     (import (scm native eval)))
    (else
     (begin
       (define eval (%primitive "eval"))
       (define environment (%primitive "environment"))))))
