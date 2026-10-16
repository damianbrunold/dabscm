;;; SRFI 271: Random port libraries
;;;
;;; (srfi 271) is (srfi 271 randomized).  See also (srfi 271 determinized)
;;; for seedable ports whose state can be saved and restored.

(define-library (srfi 271)
  (import (srfi 271 randomized))
  (export make-random-port random-port?))
