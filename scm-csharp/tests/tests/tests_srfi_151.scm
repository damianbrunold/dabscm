(import (scheme base)
        (scheme write)
        (scm test)
        (srfi 151))

(test-runner-factory scm-test-runner)

(test-begin "srfi-151")

;; Basic logic operations
(test-group "bitwise-not"
  (test-equal -1 (bitwise-not 0))
  (test-equal 0 (bitwise-not -1))
  (test-equal -11 (bitwise-not 10))
  (test-equal 10 (bitwise-not -11)))

(test-group "bitwise-and"
  (test-equal -1 (bitwise-and))
  (test-equal 10 (bitwise-and 14 10))
  (test-equal 8 (bitwise-and 14 10 12))
  (test-equal #xf0 (bitwise-and #xf0 #xff)))

(test-group "bitwise-ior"
  (test-equal 0 (bitwise-ior))
  (test-equal 14 (bitwise-ior 10 12))
  (test-equal 7 (bitwise-ior 1 2 4)))

(test-group "bitwise-xor"
  (test-equal 0 (bitwise-xor))
  (test-equal 6 (bitwise-xor 10 12))
  (test-equal #xf0 (bitwise-xor #xff #x0f)))

;; Derived logic operations
(test-group "derived logic operations"
  (test-equal -1 (bitwise-eqv))
  (test-equal -7 (bitwise-eqv 10 12))
  (test-equal -11 (bitwise-nand 14 10))
  (test-equal -15 (bitwise-nor 10 12))
  (test-equal 0 (bitwise-andc1 14 10))
  (test-equal 4 (bitwise-andc1 10 12))
  (test-equal 4 (bitwise-andc2 14 10))
  (test-equal -3 (bitwise-orc1 10 12))
  (test-equal -5 (bitwise-orc2 10 12)))

;; Arithmetic shift
(test-group "arithmetic-shift"
  (test-equal 32 (arithmetic-shift 8 2))
  (test-equal 8 (arithmetic-shift 32 -2))
  (test-equal -1 (arithmetic-shift -1 -1))
  (test-equal 0 (arithmetic-shift 0 10))
  (test-equal 1 (arithmetic-shift 1 0))
  (test-equal -1 (arithmetic-shift -8 -3)))

;; Bit count and integer-length
(test-group "bit-count and integer-length"
  (test-equal 0 (bit-count 0))
  (test-equal 2 (bit-count 10))
  (test-equal 2 (bit-count -11))
  (test-equal 3 (bit-count 7))
  (test-equal 0 (bit-count -1))
  (test-equal 0 (integer-length 0))
  (test-equal 1 (integer-length 1))
  (test-equal 3 (integer-length 7))
  (test-equal 4 (integer-length 8))
  (test-equal 0 (integer-length -1))
  (test-equal 3 (integer-length -8)))

;; bitwise-if
(test-group "bitwise-if"
  (test-equal 9 (bitwise-if 3 1 8))
  (test-equal #b1011 (bitwise-if #b1100 #b1010 #b0011)))

;; Single-bit operations
(test-group "single-bit operations"
  (test-equal #t (bit-set? 0 1))
  (test-equal #f (bit-set? 1 1))
  (test-equal #t (bit-set? 3 10))
  (test-equal #f (bit-set? 2 10))
  (test-equal 1 (copy-bit 0 0 #t))
  (test-equal 4 (copy-bit 2 0 #t))
  (test-equal 0 (copy-bit 0 1 #f))
  (test-equal #b1011 (copy-bit 2 #b1111 #f))
  (test-equal 1 (bit-swap 0 2 4)))

;; any-bit-set?, every-bit-set?, first-set-bit
(test-group "any-bit-set?, every-bit-set?, first-set-bit"
  (test-equal #t (any-bit-set? 3 6))
  (test-equal #f (any-bit-set? 1 4))
  (test-equal #t (every-bit-set? 3 7))
  (test-equal #f (every-bit-set? 3 6))
  (test-equal -1 (first-set-bit 0))
  (test-equal 0 (first-set-bit 1))
  (test-equal 2 (first-set-bit 4))
  (test-equal 2 (first-set-bit 12)))

;; Bit field operations
(test-group "bit field operations"
  (test-equal 6 (bit-field #b101101 1 4))
  (test-equal 3 (bit-field #b101101 2 4))
  (test-equal #t (bit-field-any? #b101101 0 2))
  (test-equal #f (bit-field-any? #b101100 0 2))
  (test-equal #t (bit-field-every? #b101111 0 4))
  (test-equal #f (bit-field-every? #b101101 0 4))
  (test-equal #b100001 (bit-field-clear #b101101 1 4))
  (test-equal #b101110 (bit-field-set #b100000 1 4))
  (test-equal #b100101 (bit-field-replace #b101101 #b010 1 4))
  (test-equal #b110001 (bit-field-replace-same #b111111 #b000000 1 4)))

;; Bit field rotate and reverse
(test-group "bit field rotate and reverse"
  (test-equal #b011 (bit-field-rotate #b101 1 0 3))
  (test-equal #b110 (bit-field-rotate #b101 -1 0 3))
  (test-equal #b100111 (bit-field-reverse #b101101 1 4)))

;; Conversion operations
(test-group "conversion operations"
  (test-equal '(#f #t #f #t) (bits->list 10))
  (test-equal '(#f #t #f #t #f #f) (bits->list 10 6))
  (test-equal 5 (list->bits '(#t #f #t #f)))
  (test-equal 10 (list->bits '(#f #t #f #t)))
  (test-equal 5 (bits #t #f #t #f))
  (test-equal 10 (bits #f #t #f #t)))

;; Vector conversion
(test-group "vector conversion"
  (test-equal #(#f #t #f #t) (bits->vector 10))
  (test-equal 5 (vector->bits #(#t #f #t #f))))

;; Fold, for-each, unfold
(test-group "bitwise-fold and bitwise-for-each"
  (define result '())
  ;; count set bits via fold
  (test-equal 2 (bitwise-fold (lambda (b count) (if b (+ count 1) count)) 0 10))
  (test-equal '(#f #t #f #t)
    (begin
      (bitwise-for-each (lambda (b) (set! result (cons b result))) 10)
      (reverse result))))

(test-group "bitwise-unfold"
  ;; unfold: build integer from predicate
  (test-equal 10
    (bitwise-unfold (lambda (s) (= s 0))
                    (lambda (s) (odd? s))
                    (lambda (s) (quotient s 2))
                    10)))

;; Generator
(test-group "make-bitwise-generator"
  (define g (make-bitwise-generator 10))
  (test-equal #f (g))
  (test-equal #t (g))
  (test-equal #f (g))
  (test-equal #t (g)))

(test-end "srfi-151")
