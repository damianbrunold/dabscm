;;; SRFI 271: Random port libraries -- determinized ports
;;;
;;; The default deterministic algorithm is ChaCha20, see
;;; (srfi 271 determinized chacha20).

(define-library (srfi 271 determinized)
  (import (srfi 271 determinized chacha20))
  (export make-random-port
          random-port?
          random-port-state
          random-port-state?
          random-port-state=?
          random-port-initialization-error?))
