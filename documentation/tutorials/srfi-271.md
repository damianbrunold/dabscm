---
title: SRFI 271: random ports
part: libraries
order: 271
libraries: (srfi 271) (srfi 271 randomized) (srfi 271 determinized) (srfi 271 determinized chacha20) (srfi 151)
summary: Cryptographically random bytes from a binary port, tokens and identifiers, reproducible byte streams with a saveable state.
---
# SRFI 271: random ports

SRFI 271 provides random bytes as a binary input port that never ends.
Any procedure that reads a binary port can read random data:
`read-u8`, `read-bytevector`, your own parsers.

- `(srfi 271)` (the same as `(srfi 271 randomized)`) delivers
  cryptographically secure random bytes from the operating system. Use it
  for keys, tokens and passwords.
- `(srfi 271 determinized)` delivers a reproducible stream from a seed,
  with a state you can save and resume. Use it for simulations and tests.

```scheme
(import (scheme base) (srfi 151) (srfi 271)
        (prefix (srfi 271 determinized) d:))
```

## Secure random bytes

```scheme
(define rp (make-random-port))
(random-port? rp)                         ;; => #t
(bytevector-length (read-bytevector 16 rp)) ;; => 16
(<= 0 (read-u8 rp) 255)                   ;; => #t
```

The port never returns an end-of-file object.

### Example: tokens and identifiers

A URL-safe token from 16 random bytes, and a random version-4 UUID:

```scheme
(define alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

(define (token n)
  (let ((bytes (read-bytevector n rp)))
    (let loop ((i 0) (acc '()))
      (if (= i n)
          (list->string (reverse acc))
          (loop (+ i 1)
                (cons (string-ref alphabet (modulo (bytevector-u8-ref bytes i) 64)) acc))))))

(string-length (token 16))                ;; => 16

(define (hex2 b) (let ((s (number->string b 16))) (if (< b 16) (string-append "0" s) s)))

(define (uuid4)
  (let ((b (read-bytevector 16 rp)))
    ;; version 4 in the high nibble of byte 6, variant 10 in the top bits of byte 8
    (bytevector-u8-set! b 6 (bitwise-ior #x40 (bitwise-and (bytevector-u8-ref b 6) #x0f)))
    (bytevector-u8-set! b 8 (bitwise-ior #x80 (bitwise-and (bytevector-u8-ref b 8) #x3f)))
    (let loop ((i 0) (acc ""))
      (if (= i 16)
          acc
          (loop (+ i 1)
                (string-append acc (if (memv i '(4 6 8 10)) "-" "") (hex2 (bytevector-u8-ref b i))))))))

(define id (uuid4))
(string-length id)                        ;; => 36
(string-ref id 14)                        ;; => #\4
```

The UUID sets the version (4) and variant bits as RFC 9562 asks, with
`bitwise-and` and `bitwise-ior` from [SRFI 151](srfi-151.md).

## Reproducible streams

A determinized port is seeded from 32 bytes read from another binary port:

```scheme
(define (seeded-port seed-byte)
  (d:make-random-port (open-input-bytevector (make-bytevector 32 seed-byte))))

(equal? (read-bytevector 8 (seeded-port 7)) (read-bytevector 8 (seeded-port 7))) ;; => #t
(equal? (read-bytevector 8 (seeded-port 7)) (read-bytevector 8 (seeded-port 8))) ;; => #f
```

### Saving and resuming

`random-port-state` captures where a port is; a port made from the state
continues from exactly there:

```scheme
(define p (seeded-port 1))
(read-bytevector 100 p)                   ; advance somewhere
(define saved (d:random-port-state p))
(define next-from-p (read-bytevector 8 p))
(equal? next-from-p (read-bytevector 8 (d:make-random-port saved))) ;; => #t
```

That lets a long simulation checkpoint its random stream together with its
other state, and continue later with exactly the same numbers.

A seed of only zero bytes, or fewer than 32 bytes, is rejected:

```scheme
(guard (e ((d:random-port-initialization-error? e) 'bad-seed))
  (d:make-random-port (open-input-bytevector (make-bytevector 32 0))))
;; => bad-seed
```

## Where next

- [SRFI 27 and 194](srfi-27.md) for random numbers and distributions.
- `(scm crypto token)` for signed, expiring tokens.
- Reference: `(srfi 271)`, `(srfi 271 determinized)`; the stream of the
  determinized ports comes from `(srfi 271 determinized chacha20)`.
