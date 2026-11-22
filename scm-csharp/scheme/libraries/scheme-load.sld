(define-library (scheme load)
  (export load)
  (cond-expand
    (dabscm-native
     ;; natively: over the eval linked into the program
     (import (scm native eval)))
    (else
     (begin (define load (%primitive "load"))))))
