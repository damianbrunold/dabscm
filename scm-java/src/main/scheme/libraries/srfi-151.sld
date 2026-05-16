(define-library (srfi 151)
  (import (scheme base))
  (export bitwise-not bitwise-and bitwise-ior bitwise-xor bitwise-eqv
          bitwise-nand bitwise-nor bitwise-andc1 bitwise-andc2
          bitwise-orc1 bitwise-orc2
          arithmetic-shift bit-count integer-length bitwise-if
          bit-set? copy-bit bit-swap any-bit-set? every-bit-set?
          first-set-bit
          bit-field bit-field-any? bit-field-every?
          bit-field-clear bit-field-set
          bit-field-replace bit-field-replace-same
          bit-field-rotate bit-field-reverse
          bits->list list->bits bits->vector vector->bits bits
          bitwise-fold bitwise-for-each bitwise-unfold
          make-bitwise-generator)
  (begin
    ;;; Core primitives
    (define bitwise-not (%primitive "bitwise-not"))
    (define bitwise-and (%primitive "bitwise-and"))
    (define bitwise-ior (%primitive "bitwise-ior"))
    (define bitwise-xor (%primitive "bitwise-xor"))
    (define arithmetic-shift (%primitive "arithmetic-shift"))
    (define bit-count (%primitive "bit-count"))
    (define integer-length (%primitive "integer-length"))

    ;;; Derived logic operations
    (define (bitwise-eqv . args)
      (bitwise-not (apply bitwise-xor args)))

    (define (bitwise-nand i j)
      (bitwise-not (bitwise-and i j)))

    (define (bitwise-nor i j)
      (bitwise-not (bitwise-ior i j)))

    (define (bitwise-andc1 i j)
      (bitwise-and (bitwise-not i) j))

    (define (bitwise-andc2 i j)
      (bitwise-and i (bitwise-not j)))

    (define (bitwise-orc1 i j)
      (bitwise-ior (bitwise-not i) j))

    (define (bitwise-orc2 i j)
      (bitwise-ior i (bitwise-not j)))

    ;;; Bitwise if (merge)
    (define (bitwise-if mask i j)
      (bitwise-ior (bitwise-and mask i)
                   (bitwise-and (bitwise-not mask) j)))

    ;;; Single-bit operations
    (define (bit-set? index i)
      (not (zero? (bitwise-and (arithmetic-shift 1 index) i))))

    (define (copy-bit index i boolean)
      (if boolean
          (bitwise-ior i (arithmetic-shift 1 index))
          (bitwise-and i (bitwise-not (arithmetic-shift 1 index)))))

    (define (bit-swap index1 index2 i)
      (let ((b1 (bit-set? index1 i))
            (b2 (bit-set? index2 i)))
        (copy-bit index1 (copy-bit index2 i b1) b2)))

    (define (any-bit-set? test-bits i)
      (not (zero? (bitwise-and test-bits i))))

    (define (every-bit-set? test-bits i)
      (= test-bits (bitwise-and test-bits i)))

    (define (first-set-bit i)
      (if (zero? i)
          -1
          (let loop ((n 0) (v i))
            (if (not (zero? (bitwise-and v 1)))
                n
                (loop (+ n 1) (arithmetic-shift v -1))))))

    ;;; Bit field operations
    (define (bit-field-mask start end)
      (bitwise-and (bitwise-not (arithmetic-shift -1 end))
                   (arithmetic-shift -1 start)))

    (define (bit-field i start end)
      (bitwise-and (arithmetic-shift i (- start))
                   (bitwise-not (arithmetic-shift -1 (- end start)))))

    (define (bit-field-any? i start end)
      (not (zero? (bitwise-and i (bit-field-mask start end)))))

    (define (bit-field-every? i start end)
      (let ((mask (bit-field-mask start end)))
        (= mask (bitwise-and i mask))))

    (define (bit-field-clear i start end)
      (bitwise-and i (bitwise-not (bit-field-mask start end))))

    (define (bit-field-set i start end)
      (bitwise-ior i (bit-field-mask start end)))

    (define (bit-field-replace dst src start end)
      (let ((mask (bit-field-mask start end)))
        (bitwise-ior (bitwise-and dst (bitwise-not mask))
                     (bitwise-and (arithmetic-shift src start) mask))))

    (define (bit-field-replace-same dst src start end)
      (let ((mask (bit-field-mask start end)))
        (bitwise-ior (bitwise-and dst (bitwise-not mask))
                     (bitwise-and src mask))))

    (define (bit-field-rotate i count start end)
      (let* ((width (- end start))
             (field (bit-field i start end))
             (c (modulo count width))
             (rotated (bitwise-ior
                       (bitwise-and (arithmetic-shift field c)
                                    (bitwise-not (arithmetic-shift -1 width)))
                       (arithmetic-shift field (- c width)))))
        (bit-field-replace i rotated start end)))

    (define (bit-field-reverse i start end)
      (let loop ((n start) (result (bit-field-clear i start end)) (field (bit-field i start end)) (width (- end start)))
        (if (zero? width)
            result
            (loop (+ n 1)
                  (if (not (zero? (bitwise-and field 1)))
                      (copy-bit (+ start (- width 1)) result #t)
                      result)
                  (arithmetic-shift field -1)
                  (- width 1)))))

    ;;; Conversion
    (define (bits->list i . args)
      (let ((len (if (null? args) (integer-length i) (car args))))
        (let loop ((n (- len 1)) (acc '()))
          (if (< n 0)
              acc
              (loop (- n 1) (cons (bit-set? n i) acc))))))

    (define (list->bits bools)
      (let loop ((bs bools) (result 0) (index 0))
        (if (null? bs)
            result
            (loop (cdr bs)
                  (if (car bs)
                      (copy-bit index result #t)
                      result)
                  (+ index 1)))))

    (define (bits->vector i . args)
      (list->vector (apply bits->list i args)))

    (define (vector->bits v)
      (list->bits (vector->list v)))

    (define (bits . bools)
      (list->bits bools))

    ;;; Fold, for-each, unfold
    (define (bitwise-fold proc seed i)
      (let ((len (integer-length i)))
        (let loop ((n 0) (acc seed))
          (if (>= n len)
              acc
              (loop (+ n 1) (proc (bit-set? n i) acc))))))

    (define (bitwise-for-each proc i)
      (let ((len (integer-length i)))
        (let loop ((n 0))
          (when (< n len)
            (proc (bit-set? n i))
            (loop (+ n 1))))))

    (define (bitwise-unfold stop? mapper successor seed)
      (let loop ((state seed) (index 0) (result 0))
        (if (stop? state)
            result
            (loop (successor state)
                  (+ index 1)
                  (if (mapper state)
                      (copy-bit index result #t)
                      result)))))

    (define (make-bitwise-generator i)
      (let ((n i))
        (lambda ()
          (let ((bit (not (zero? (bitwise-and n 1)))))
            (set! n (arithmetic-shift n -1))
            bit))))))
