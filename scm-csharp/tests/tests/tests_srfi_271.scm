(import (scheme base)
        (scheme read)
        (scheme write)
        (scm test)
        (prefix (srfi 271) r:)
        (prefix (srfi 271 randomized) rr:)
        (prefix (srfi 271 determinized) d:)
        (prefix (srfi 271 determinized chacha20) c:))

(test-runner-factory scm-test-runner)

(test-begin "srfi-271")

(define (write->read obj)
  (let ((out (open-output-string)))
    (write obj out)
    (read (open-input-string (get-output-string out)))))

(define (bytevector-range from to)
  (let ((bv (make-bytevector (- to from))))
    (do ((i from (+ i 1))) ((= i to) bv)
      (bytevector-u8-set! bv (- i from) i))))

(define (key-port key) (open-input-bytevector key))

(test-group "library aliases"
  (test-eq r:make-random-port rr:make-random-port)
  (test-eq r:random-port? rr:random-port?)
  (test-eq d:make-random-port c:make-random-port)
  (test-eq d:random-port-state c:random-port-state))

(test-group "randomized ports"
  (let ((p (r:make-random-port)))
    (test-assert (r:random-port? p))
    (test-assert (input-port? p))
    (test-assert (binary-port? p))
    (test-assert (not (r:random-port? (open-input-bytevector #u8(1 2 3)))))
    (test-assert (not (r:random-port? 'x)))
    ;; never eof, large reads deliver everything asked for
    (let ((bv (read-bytevector 100000 p)))
      (test-equal 100000 (bytevector-length bv))
      ;; all byte values occur in 100000 random bytes
      (let ((seen (make-vector 256 #f)))
        (do ((i 0 (+ i 1))) ((= i 100000))
          (vector-set! seen (bytevector-u8-ref bv i) #t))
        (test-assert (let loop ((i 0))
                       (or (= i 256) (and (vector-ref seen i) (loop (+ i 1))))))))
    (test-assert (exact-integer? (read-u8 p)))
    (test-assert (exact-integer? (peek-u8 p)))
    (test-assert (u8-ready? p))
    ;; two ports differ
    (test-assert (not (equal? (read-bytevector 32 (r:make-random-port))
                              (read-bytevector 32 (r:make-random-port)))))
    ;; a randomized port is not a determinized one and vice versa
    (test-assert (not (d:random-port? p)))
    (test-assert (not (r:random-port? (d:make-random-port))))))

;; Expected bytes from an independent implementation of the RFC 8439
;; ChaCha20 block function (all-zero nonce).
(test-group "ChaCha20 keystream"
  (let ((p (d:make-random-port (key-port (bytevector-range 1 33)))))
    (test-equal #u8(177 105 126 159 198 70 30 25) (read-bytevector 8 p)))
  ;; across the first block boundary
  (let ((p (d:make-random-port (key-port (make-bytevector 32 7)))))
    (test-equal 244 (read-u8 p))
    (read-bytevector 59 p)
    (test-equal #u8(116 238 223 107 55 132 41 12 96 107) (read-bytevector 10 p)))
  ;; RFC 8439 A.1 test vectors #1 and #2 (all-zero key, blocks 0 and 1);
  ;; an all-zero key is rejected by make-random-port, so use the primitive
  (let ((p ((%primitive "make-chacha20-port") (make-bytevector 32 0) 0 0)))
    (test-equal #u8(#x76 #xb8 #xe0 #xad #xa0 #xf1 #x3d #x90
                    #x40 #x5d #x6a #xe5 #x53 #x86 #xbd #x28)
                (read-bytevector 16 p))
    (read-bytevector 48 p)
    (test-equal #u8(#x9f #x07 #xe7 #xbe #x55 #x51 #x38 #x7a
                    #x98 #xba #x97 #x7c #x73 #x2d #x08 #x0d)
                (read-bytevector 16 p))))

(test-group "determinized ports"
  (let ((p (d:make-random-port)))
    (test-assert (d:random-port? p))
    (test-assert (binary-port? p))
    (test-assert (not (d:random-port? (open-input-bytevector #u8(1)))))
    (test-equal 100000 (bytevector-length (read-bytevector 100000 p))))
  ;; same initializer data, same bytes and equal states
  (let ((p (d:make-random-port (key-port (bytevector-range 0 32))))
        (q (d:make-random-port (key-port (bytevector-range 0 32)))))
    (test-assert (d:random-port-state=? (d:random-port-state p) (d:random-port-state q)))
    (test-equal (read-bytevector 1000 p) (read-bytevector 1000 q)))
  ;; the initializer may be an endless port (only 32 bytes are used)
  (let ((p (d:make-random-port (r:make-random-port))))
    (test-assert (d:random-port? p)))
  ;; the initializer may be another determinized port
  (let* ((seed (d:make-random-port (key-port (bytevector-range 10 42))))
         (p (d:make-random-port seed))
         (q (d:make-random-port (key-port (bytevector-range 10 42)))))
    (test-equal (vector 'chacha20 (read-bytevector 32 q) 0 0)
                (d:random-port-state p)))
  ;; unseeded ports differ
  (test-assert (not (equal? (read-bytevector 32 (d:make-random-port))
                            (read-bytevector 32 (d:make-random-port)))))
  (test-error (d:make-random-port 'nonsense))
  (test-error (d:make-random-port (open-input-string "not binary"))))

(test-group "states"
  (let* ((p (d:make-random-port (key-port (bytevector-range 0 32))))
         (s0 (d:random-port-state p)))
    (test-assert (d:random-port-state? s0))
    (test-equal (vector 'chacha20 (bytevector-range 0 32) 0 0) s0)
    ;; positions after read-u8, read-bytevector and across block boundaries
    (read-u8 p)
    (test-equal 1 (vector-ref (d:random-port-state p) 3))
    (read-bytevector 100 p)
    (test-equal '(1 37) (list (vector-ref (d:random-port-state p) 2)
                              (vector-ref (d:random-port-state p) 3)))
    ;; resume from a state
    (let* ((s (d:random-port-state p))
           (q (d:make-random-port s)))
      (test-equal (read-bytevector 500 p) (read-bytevector 500 q))
      (test-assert (d:random-port-state=? (d:random-port-state p) (d:random-port-state q))))
    ;; states survive write/read
    (let* ((s (d:random-port-state p))
           (s2 (write->read s)))
      (test-assert (d:random-port-state? s2))
      (test-assert (d:random-port-state=? s s2))
      (test-equal (read-bytevector 64 (d:make-random-port s))
                  (read-bytevector 64 (d:make-random-port s2))))
    ;; the original state still replays from the start
    (let ((q (d:make-random-port s0))
          (r (d:make-random-port (key-port (bytevector-range 0 32)))))
      (test-equal (read-bytevector 200 r) (read-bytevector 200 q))))
  ;; a peeked byte is not consumed
  (let* ((p (d:make-random-port (key-port (bytevector-range 0 32))))
         (first (peek-u8 p))
         (q (d:make-random-port (d:random-port-state p))))
    (test-equal first (read-u8 q))
    (test-equal first (read-u8 p)))
  ;; ... also at a block boundary
  (let ((p (d:make-random-port (key-port (bytevector-range 0 32)))))
    (read-bytevector 64 p)
    (let* ((b (peek-u8 p))
           (s (d:random-port-state p)))
      (test-equal '(1 0) (list (vector-ref s 2) (vector-ref s 3)))
      (test-equal b (read-u8 (d:make-random-port s)))))
  (let ((p (d:make-random-port (key-port (bytevector-range 0 32)))))
    (read-bytevector 63 p)
    (let* ((b (peek-u8 p))
           (s (d:random-port-state p)))
      (test-equal '(0 63) (list (vector-ref s 2) (vector-ref s 3)))
      (test-equal b (read-u8 (d:make-random-port s)))))
  ;; state predicate and equality
  (test-assert (not (d:random-port-state? (vector 'chacha20 (make-bytevector 32 0) 0 0))))
  (test-assert (not (d:random-port-state? (vector 'chacha20 (make-bytevector 31 1) 0 0))))
  (test-assert (not (d:random-port-state? (vector 'chacha20 (make-bytevector 32 1) -1 0))))
  (test-assert (not (d:random-port-state? (vector 'chacha20 (make-bytevector 32 1) 0 64))))
  (test-assert (not (d:random-port-state? (vector 'other (make-bytevector 32 1) 0 0))))
  (test-assert (not (d:random-port-state? 'x)))
  (test-assert (d:random-port-state=? (vector 'chacha20 (make-bytevector 32 1) 0 0)))
  (test-assert (not (d:random-port-state=? (vector 'chacha20 (make-bytevector 32 1) 0 0)
                                           (vector 'chacha20 (make-bytevector 32 1) 0 1))))
  (test-error (d:random-port-state=? 'x 'y))
  (test-error (d:random-port-state (r:make-random-port)))
  (test-error (d:random-port-state (open-input-bytevector #u8(1 2)))))

(test-group "initialization errors"
  (test-assert (guard (e ((d:random-port-initialization-error? e) #t))
                 (d:make-random-port (open-input-bytevector #u8(1 2 3)))
                 #f))
  (test-assert (guard (e ((d:random-port-initialization-error? e) #t))
                 (d:make-random-port (open-input-bytevector #u8()))
                 #f))
  (test-assert (guard (e ((d:random-port-initialization-error? e) #t))
                 (d:make-random-port (open-input-bytevector (make-bytevector 32 0)))
                 #f))
  (test-assert (not (d:random-port-initialization-error? 'x)))
  (test-assert (guard (e ((d:random-port-initialization-error? e) #f) (#t #t))
                 (d:make-random-port 42))))

(test-end "srfi-271")
