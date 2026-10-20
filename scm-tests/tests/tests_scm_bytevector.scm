(import (scheme base)
        (scm test)
        (scm bytevector))

(test-runner-factory scm-test-runner)

(test-begin "scm bytevector")

(test-group "16-bit"
  (test-equal 513 (bytevector-u16-ref (bytevector 1 2) 0 'little))
  (test-equal 258 (bytevector-u16-ref (bytevector 1 2) 0 'big))
  (test-equal 65535 (bytevector-u16-ref (bytevector 255 255) 0 'big))
  (test-equal -1 (bytevector-s16-ref (bytevector 255 255) 0 'big))
  (test-equal -32768 (bytevector-s16-ref (bytevector 0 128) 0 'little))
  (test-equal 32767 (bytevector-s16-ref (bytevector 127 255) 0 'big))
  (let ((bv (make-bytevector 3 0)))
    (bytevector-u16-set! bv 1 513 'big)
    (test-equal (bytevector 0 2 1) bv)
    (bytevector-s16-set! bv 0 -2 'little)
    (test-equal (bytevector 254 255 1) bv)))

(test-group "32-bit"
  (test-equal 9994 (bytevector-u32-ref (bytevector 0 0 39 10) 0 'big))
  (test-equal 4294967295 (bytevector-u32-ref (bytevector 255 255 255 255) 0 'little))
  (test-equal -1 (bytevector-s32-ref (bytevector 255 255 255 255) 0 'little))
  (test-equal -2147483648 (bytevector-s32-ref (bytevector 128 0 0 0) 0 'big))
  ;; unaligned index
  (test-equal 5 (bytevector-s32-ref (bytevector 9 5 0 0 0) 1 'little))
  (let ((bv (make-bytevector 4 0)))
    (bytevector-u32-set! bv 0 4294967295 'big)
    (test-equal (bytevector 255 255 255 255) bv)
    (bytevector-s32-set! bv 0 -2147483648 'little)
    (test-equal (bytevector 0 0 0 128) bv)
    (bytevector-u32-set! bv 0 256 'little)
    (test-equal (bytevector 0 1 0 0) bv)))

(test-group "ieee"
  (test-equal 1.0 (bytevector-ieee-single-ref (bytevector 0 0 128 63) 0 'little))
  (test-equal -2.5 (bytevector-ieee-single-ref (bytevector 192 32 0 0) 0 'big))
  (test-equal 1.0 (bytevector-ieee-double-ref (bytevector 0 0 0 0 0 0 240 63) 0 'little))
  (test-equal 1.0 (bytevector-ieee-double-ref (bytevector 63 240 0 0 0 0 0 0) 0 'big))
  (let ((bv (make-bytevector 9 0)))
    (bytevector-ieee-double-set! bv 1 2683256.125 'little)
    (test-equal 2683256.125 (bytevector-ieee-double-ref bv 1 'little))
    (bytevector-ieee-double-set! bv 1 -0.1 'big)
    (test-equal -0.1 (bytevector-ieee-double-ref bv 1 'big))
    ;; exact arguments are stored as their inexact value
    (bytevector-ieee-double-set! bv 0 3 'big)
    (test-equal 3.0 (bytevector-ieee-double-ref bv 0 'big))
    (bytevector-ieee-single-set! bv 0 1.0 'big)
    (test-equal (bytevector 63 128 0 0) (bytevector-copy bv 0 4))))

(test-group "errors"
  (test-error (bytevector-u16-ref (bytevector 1) 0 'big))
  (test-error (bytevector-u32-ref (bytevector 1 2 3 4) 1 'big))
  (test-error (bytevector-u32-ref (bytevector 1 2 3 4) -1 'big))
  (test-error (bytevector-u32-ref (bytevector 1 2 3 4) 0 'middle))
  (test-error (bytevector-u16-set! (make-bytevector 2 0) 0 65536 'big))
  (test-error (bytevector-u16-set! (make-bytevector 2 0) 0 -1 'big))
  (test-error (bytevector-s16-set! (make-bytevector 2 0) 0 32768 'big))
  (test-error (bytevector-u32-set! (make-bytevector 4 0) 0 1.5 'big))
  (test-error (bytevector-ieee-double-set! (make-bytevector 8 0) 1 1.0 'big)))

(test-end "scm bytevector")
