;;; SRFI 271: Random port libraries -- determinized ports using ChaCha20
;;;
;;; A port delivers the ChaCha20 keystream (20 rounds, all-zero nonce) of a
;;; 256-bit key.  Its state is an ordinary vector
;;;
;;;   #(chacha20 key counter offset)
;;;
;;; with key a 32-byte bytevector (not all zero), counter the keystream
;;; block (an exact integer in 0..2^63-1) and offset the byte within that
;;; block (0..63) that will be read next.  States are therefore write/read
;;; invariant and can be compared with equal?.

(define-library (srfi 271 determinized chacha20)
  (import (scheme base)
          (scheme case-lambda)
          (rename (only (srfi 271 randomized) make-random-port)
                  (make-random-port make-randomized-port)))
  (export make-random-port
          random-port?
          random-port-state
          random-port-state?
          random-port-state=?
          random-port-initialization-error?)
  (begin

    (define %make-chacha20-port (%primitive "make-chacha20-port"))
    (define %chacha20-port? (%primitive "chacha20-port?"))
    (define %chacha20-port-state (%primitive "chacha20-port-state"))

    (define key-length 32)
    (define max-counter (- (expt 2 63) 1))

    ;;; Initialization errors

    (define-record-type random-port-initialization-error
      (make-initialization-error message irritants)
      %initialization-error?
      (message initialization-error-message)
      (irritants initialization-error-irritants))

    (define (random-port-initialization-error? obj)
      "Syntax: (random-port-initialization-error? obj)
Library: (srfi 271 determinized)
Description: Returns #t if obj is the object raised by make-random-port when
  the initializer port does not deliver enough usable data (fewer than 32
  bytes, or 32 zero bytes), #f otherwise.
Example:
  (guard (e ((random-port-initialization-error? e) 'too-short))
    (make-random-port (open-input-bytevector #u8(1 2 3)))) => too-short"
      (%initialization-error? obj))

    ;;; States

    (define (zero-bytevector? bv)
      (let loop ((i 0))
        (or (= i (bytevector-length bv))
            (and (zero? (bytevector-u8-ref bv i))
                 (loop (+ i 1))))))

    (define (random-port-state? obj)
      "Syntax: (random-port-state? obj)
Library: (srfi 271 determinized)
Description: Returns #t if obj is a valid random port state, i.e. a vector
  #(chacha20 key counter offset) with key a bytevector of 32 bytes that are
  not all zero, counter an exact integer in [0, 2^63) and offset an exact
  integer in [0, 63].
Example:
  (random-port-state? (vector 'chacha20 (make-bytevector 32 1) 0 0)) => #t"
      (and (vector? obj)
           (= (vector-length obj) 4)
           (eq? (vector-ref obj 0) 'chacha20)
           (let ((key (vector-ref obj 1))
                 (counter (vector-ref obj 2))
                 (offset (vector-ref obj 3)))
             (and (bytevector? key)
                  (= (bytevector-length key) key-length)
                  (not (zero-bytevector? key))
                  (exact-integer? counter)
                  (<= 0 counter max-counter)
                  (exact-integer? offset)
                  (<= 0 offset 63)))))

    (define (random-port-state=? state . states)
      "Syntax: (random-port-state=? state1 state2 ...)
Library: (srfi 271 determinized)
Description: Returns #t if all the given random port states are equal.
  Ports created from equal states produce identical byte sequences.
Example:
  (let ((p (make-random-port)))
    (random-port-state=? (random-port-state p) (random-port-state p))) => #t"
      (for-each (lambda (s)
                  (unless (random-port-state? s)
                    (error "random-port-state=?: not a random port state" s)))
                (cons state states))
      (let loop ((states states))
        (or (null? states)
            (and (equal? state (car states))
                 (loop (cdr states))))))

    (define (random-port-state port)
      "Syntax: (random-port-state random-port)
Library: (srfi 271 determinized)
Description: Returns the current state of random-port.  Passing it to
  make-random-port creates a port that delivers the same bytes as
  random-port does from now on.  A byte returned by peek-u8 but not yet
  read counts as not consumed.
Example:
  (let* ((p (make-random-port))
         (q (make-random-port (random-port-state p))))
    (equal? (read-bytevector 8 p) (read-bytevector 8 q))) => #t"
      (unless (%chacha20-port? port)
        (error "random-port-state: not a determinized random port" port))
      (let ((s (%chacha20-port-state port)))
        (vector 'chacha20 (vector-ref s 0) (vector-ref s 1) (vector-ref s 2))))

    (define (random-port? obj)
      "Syntax: (random-port? obj)
Library: (srfi 271 determinized)
Description: Returns #t if obj is a random port made by make-random-port of
  this library, #f otherwise.
Example:
  (random-port? (make-random-port)) => #t"
      (%chacha20-port? obj))

    ;;; Construction

    (define (state->port state)
      (%make-chacha20-port (bytevector-copy (vector-ref state 1))
                           (vector-ref state 2)
                           (vector-ref state 3)))

    (define (port->state who port)
      (let ((key (read-bytevector key-length port)))
        (when (or (eof-object? key) (< (bytevector-length key) key-length))
          (raise (make-initialization-error
                  (string-append who ": not enough data to initialize the random port")
                  (list port))))
        (when (zero-bytevector? key)
          (raise (make-initialization-error
                  (string-append who ": initialization data is all zero")
                  (list port))))
        (vector 'chacha20 key 0 0)))

    (define make-random-port
      (case-lambda
        (()
         (state->port (port->state "make-random-port" (make-randomized-port))))
        ((initializer)
         "Syntax: (make-random-port)
       (make-random-port initializer)
Library: (srfi 271 determinized)
Description: Returns a new deterministic random port: a binary input port
  delivering an endless ChaCha20 keystream.  The initializer is either a
  random port state (the new port continues from that state) or a binary
  input port, from which 32 bytes are read as the key; if it delivers fewer
  bytes or only zeros, an error satisfying
  random-port-initialization-error? is raised.  Without an initializer the
  key is read from a randomized (cryptographically random) port.
Example:
  (read-u8 (make-random-port (open-input-bytevector (make-bytevector 32 7))))
    => 244"
         (cond ((random-port-state? initializer)
                (state->port initializer))
               ((and (input-port? initializer) (binary-port? initializer))
                (state->port (port->state "make-random-port" initializer)))
               (else
                (error "make-random-port: expected a random port state or a binary input port"
                       initializer))))))))
