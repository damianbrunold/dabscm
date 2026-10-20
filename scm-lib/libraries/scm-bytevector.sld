(define-library (scm bytevector)
  (import (scm core))
  (export bytevector-u16-ref
          bytevector-u16-set!
          bytevector-s16-ref
          bytevector-s16-set!
          bytevector-u32-ref
          bytevector-u32-set!
          bytevector-s32-ref
          bytevector-s32-set!
          bytevector-ieee-single-ref
          bytevector-ieee-single-set!
          bytevector-ieee-double-ref
          bytevector-ieee-double-set!)
  (begin
    (define bytevector-u16-ref          (%primitive "bytevector-u16-ref"))
    (define bytevector-u16-set!         (%primitive "bytevector-u16-set!"))
    (define bytevector-s16-ref          (%primitive "bytevector-s16-ref"))
    (define bytevector-s16-set!         (%primitive "bytevector-s16-set!"))
    (define bytevector-u32-ref          (%primitive "bytevector-u32-ref"))
    (define bytevector-u32-set!         (%primitive "bytevector-u32-set!"))
    (define bytevector-s32-ref          (%primitive "bytevector-s32-ref"))
    (define bytevector-s32-set!         (%primitive "bytevector-s32-set!"))
    (define bytevector-ieee-single-ref  (%primitive "bytevector-ieee-single-ref"))
    (define bytevector-ieee-single-set! (%primitive "bytevector-ieee-single-set!"))
    (define bytevector-ieee-double-ref  (%primitive "bytevector-ieee-double-ref"))
    (define bytevector-ieee-double-set! (%primitive "bytevector-ieee-double-set!"))))
