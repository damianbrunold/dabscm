;;; SRFI 271: Random port libraries -- randomized ports
;;;
;;; Random ports are binary input ports that never return an eof object.
;;; The ports of this library deliver cryptographically random bytes from
;;; the host's secure random number generator (Java SecureRandom, .NET
;;; RandomNumberGenerator); they have no observable state.

(define-library (srfi 271 randomized)
  (import (scheme base))
  (export make-random-port random-port?)
  (begin

    (define %make-secure-random-port (%primitive "make-secure-random-port"))
    (define %secure-random-port? (%primitive "secure-random-port?"))

    (define (make-random-port)
      "Syntax: (make-random-port)
Library: (srfi 271 randomized), (srfi 271)
Description: Returns a new random port: a binary input port delivering an
  endless stream of cryptographically random bytes from the operating
  system's secure random number generator.  It never returns an eof object.
Example:
  (bytevector-length (read-bytevector 16 (make-random-port))) => 16"
      (%make-secure-random-port))

    (define (random-port? obj)
      "Syntax: (random-port? obj)
Library: (srfi 271 randomized), (srfi 271)
Description: Returns #t if obj is a random port made by make-random-port
  of this library, #f otherwise.
Example:
  (random-port? (make-random-port)) => #t
  (random-port? (open-input-bytevector #u8(1 2))) => #f"
      (%secure-random-port? obj))))
