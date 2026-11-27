---
title: SRFI 151: bitwise operations
part: libraries
order: 151
libraries: (srfi 151)
summary: and, or, xor and not on integers, shifts, testing and setting single bits, bit fields, counting bits; permission flags and packing an RGB color.
---
# SRFI 151: bitwise operations

SRFI 151 treats exact integers as sequences of bits (two's complement, so
negative numbers have infinitely many leading ones). It works on integers
of any size.

```scheme
(import (scheme base) (srfi 151))
```

## The basic operations

```scheme
(bitwise-and #b1100 #b1010)            ;; => 8
(bitwise-ior #b1100 #b1010)            ;; => 14
(bitwise-xor #b1100 #b1010)            ;; => 6
(bitwise-not 0)                        ;; => -1
(arithmetic-shift 1 10)                ;; => 1024
(arithmetic-shift 1024 -3)             ;; => 128
(number->string (bitwise-and #xff00 #x0ff0) 16) ;; => "f00"
```

`#b` and `#x` write numbers in binary and hex. `arithmetic-shift` shifts
left for a positive count and right for a negative one.

## Single bits

Bits are numbered from 0, the least significant:

```scheme
(bit-set? 0 5)                         ;; => #t
(bit-set? 1 5)                         ;; => #f
(copy-bit 1 5 #t)                      ;; => 7
(copy-bit 0 5 #f)                      ;; => 4
(bit-count 255)                        ;; => 8
(integer-length 255)                   ;; => 8
(first-set-bit 40)                     ;; => 3
(bits->list 6)                         ;; => (#f #t #t)
(list->bits '(#t #f #t))               ;; => 5
```

`integer-length` is the number of bits needed; `first-set-bit` the
position of the lowest one bit (40 is `101000`).

## Bit fields

A *field* is a range of bits, from `start` (included) to `end` (excluded):

```scheme
(bit-field #b110110 1 4)               ;; => 3
(bit-field-set #b100000 1 4)           ;; => 46
(bit-field-clear #b111111 1 4)         ;; => 49
(bit-field-replace #b100000 #b101 1 4) ;; => 42
(bit-field-any? #b100000 1 4)          ;; => #f
```

## Example: permission flags

Represent permissions as bits, the way file modes do:

```scheme
(define read 4)
(define write 2)
(define exec 1)

(define (perm . flags) (apply bitwise-ior flags))
(define (has? mode flag) (not (zero? (bitwise-and mode flag))))
(define (revoke mode flag) (bitwise-and mode (bitwise-not flag)))

(define mode (perm read write))
(has? mode write)                      ;; => #t
(has? mode exec)                       ;; => #f
(revoke mode write)                    ;; => 4

;; a Unix mode: owner, group, others, three bits each
(define (unix-mode owner group other)
  (bitwise-ior (arithmetic-shift owner 6) (arithmetic-shift group 3) other))
(number->string (unix-mode (perm read write exec) (perm read exec) (perm read)) 8)
;; => "754"
```

## Example: packing a color

An RGB color in one integer, 8 bits per channel:

```scheme
(define (rgb r g b) (bitwise-ior (arithmetic-shift r 16) (arithmetic-shift g 8) b))
(define (red c) (bit-field c 16 24))
(define (green c) (bit-field c 8 16))
(define (blue c) (bit-field c 0 8))

(define orange (rgb 255 165 0))
(number->string orange 16)             ;; => "ffa500"
(list (red orange) (green orange) (blue orange)) ;; => (255 165 0)
```

## Big integers

Everything works beyond 64 bits:

```scheme
(bit-count (- (expt 2 100) 1))         ;; => 100
(arithmetic-shift 1 100)               ;; => 1267650600228229401496703205376
```

## Where next

- `(scm bytevector)` for reading and writing integers in bytevectors.
- Reference: `(srfi 151)`.
