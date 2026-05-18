(define-library (scm qr)
  (import (scm core) (scheme base) (scheme write) (scm png) (srfi 151))
  (export qr-encode
          qr-matrix?
          qr-matrix-size
          qr-matrix-ref
          qr-matrix-version
          qr-matrix-ec-level
          qr-matrix-mask
          qr->png
          qr->svg
          qr->ascii)
  (begin

    ;; --------------------------------------------------------------
    ;; Pure-Scheme QR-code encoder. ISO/IEC 18004.
    ;;
    ;; Supports versions 1..40, error-correction levels L/M/Q/H, and
    ;; byte mode (8-bit data, encoded as UTF-8 when input is a string).
    ;; A single byte-mode segment is emitted; numeric/alphanumeric
    ;; sub-modes are not used (byte mode handles them correctly, with
    ;; a small size penalty). Mask selection follows the spec penalty
    ;; rules.
    ;;
    ;; The implementation follows the structure of Project Nayuki's
    ;; reference encoder: build function patterns + reserved mask,
    ;; encode and interleave data codewords, lay them out in zig-zag,
    ;; apply each of 8 masks and pick the lowest-penalty one.
    ;;
    ;; Public entry points:
    ;;   (qr-encode data [ec-level [version]]) -> qr-matrix
    ;;   (qr->png matrix [module-px [quiet-modules]]) -> PNG bytevector
    ;;   (qr->svg matrix [module-px [quiet-modules]]) -> SVG string
    ;;   (qr->ascii matrix) -> string (debug / terminal preview)
    ;; --------------------------------------------------------------

    ;; ===============================================================
    ;; Spec tables (versions 1..40)
    ;; ===============================================================

    (define total-codewords-table
      #(26 44 70 100 134 172 196 242 292 346
        404 466 532 581 655 733 815 901 991 1085
        1156 1258 1364 1474 1588 1706 1828 1921 2051 2185
        2323 2465 2611 2761 2876 3034 3196 3362 3532 3706))

    ;; ec codewords per block, [version-1][ec-index: L=0 M=1 Q=2 H=3]
    (define ec-codewords-per-block-table
      #(#( 7 10 13 17) #(10 16 22 28) #(15 26 18 22) #(20 18 26 16)
        #(26 24 18 22) #(18 16 24 28) #(20 18 18 26) #(24 22 22 26)
        #(30 22 20 24) #(18 26 24 28) #(20 30 28 24) #(24 22 26 28)
        #(26 22 24 22) #(30 24 20 24) #(22 24 30 24) #(24 28 24 30)
        #(28 28 28 28) #(30 26 28 28) #(28 26 26 26) #(28 26 30 28)
        #(28 26 28 30) #(28 28 30 24) #(30 28 30 30) #(30 28 30 30)
        #(26 28 30 30) #(28 28 28 30) #(30 28 30 30) #(30 28 30 30)
        #(30 28 30 30) #(30 28 30 30) #(30 28 30 30) #(30 28 30 30)
        #(30 28 30 30) #(30 28 30 30) #(30 28 30 30) #(30 28 30 30)
        #(30 28 30 30) #(30 28 30 30) #(30 28 30 30) #(30 28 30 30)))

    (define num-blocks-table
      #(#( 1  1  1  1) #( 1  1  1  1) #( 1  1  2  2) #( 1  2  2  4)
        #( 1  2  4  4) #( 2  4  4  4) #( 2  4  6  5) #( 2  4  6  6)
        #( 2  5  8  8) #( 4  5  8  8) #( 4  5  8 11) #( 4  8 10 11)
        #( 4  9 16 16) #( 4  9 12 16) #( 6 10 12 18) #( 6 10 17 16)
        #( 6 11 16 19) #( 6 13 18 21) #( 7 14 21 25) #( 8 16 20 25)
        #( 8 17 23 25) #( 9 17 23 34) #( 9 18 25 30) #(10 20 27 32)
        #(12 21 29 35) #(12 23 34 37) #(12 25 34 40) #(13 26 35 42)
        #(14 28 38 45) #(15 29 40 48) #(16 31 43 51) #(17 33 45 54)
        #(18 35 48 57) #(19 37 51 60) #(19 38 53 63) #(20 40 56 66)
        #(21 43 59 70) #(22 45 62 74) #(24 47 65 77) #(25 49 68 81)))

    (define alignment-positions-table
      #(()
        (6 18) (6 22) (6 26) (6 30) (6 34)
        (6 22 38) (6 24 42) (6 26 46) (6 28 50) (6 30 54)
        (6 32 58) (6 34 62) (6 26 46 66) (6 26 48 70) (6 26 50 74)
        (6 30 54 78) (6 30 56 82) (6 30 58 86) (6 34 62 90)
        (6 28 50 72 94) (6 26 50 74 98) (6 30 54 78 102) (6 28 54 80 106)
        (6 32 58 84 110) (6 30 58 86 114) (6 34 62 90 118)
        (6 26 50 74 98 122) (6 30 54 78 102 126) (6 26 52 78 104 130)
        (6 30 56 82 108 134) (6 34 60 86 112 138) (6 30 58 86 114 142)
        (6 34 62 90 118 146)
        (6 30 54 78 102 126 150) (6 24 50 76 102 128 154)
        (6 28 54 80 106 132 158) (6 32 58 84 110 136 162)
        (6 26 54 82 110 138 166) (6 30 58 86 114 142 170)))

    (define (ec-index ec-level)
      (case ec-level
        ((l L #\l #\L 0) 0)
        ((m M #\m #\M 1) 1)
        ((q Q #\q #\Q 2) 2)
        ((h H #\h #\H 3) 3)
        (else (error "qr: unknown ec-level" ec-level))))

    (define (ec-level->format-bits ec)
      ;; format-info encoding: L=01, M=00, Q=11, H=10
      (case ec ((0) #b01) ((1) #b00) ((2) #b11) ((3) #b10)))

    (define (table-ref v1 v2 v ec)
      (vector-ref (vector-ref v1 (- v 1)) ec))

    (define (version-data-codewords version ec)
      (let* ((total (vector-ref total-codewords-table (- version 1)))
             (ecpb  (table-ref ec-codewords-per-block-table 0 version ec))
             (blocks (table-ref num-blocks-table 0 version ec)))
        (- total (* ecpb blocks))))

    (define (char-count-bits version)
      (if (<= version 9) 8 16))

    (define (module-size version) (+ 17 (* 4 version)))

    ;; ===============================================================
    ;; Bit stream (variable-width append)
    ;; ===============================================================

    (define (new-bs) (vector 0 0 '()))   ; #(bit-count partial-byte byte-list-reversed)

    (define (bs-put! bs value width)
      (let loop ((cnt (vector-ref bs 0))
                 (pb  (vector-ref bs 1))
                 (bl  (vector-ref bs 2))
                 (i (- width 1)))
        (if (< i 0)
            (begin (vector-set! bs 0 cnt) (vector-set! bs 1 pb) (vector-set! bs 2 bl))
            (let* ((bit (bitwise-and (arithmetic-shift value (- i)) 1))
                   (pb2 (bitwise-ior (arithmetic-shift pb 1) bit))
                   (cnt2 (+ cnt 1)))
              (if (= cnt2 8)
                  (loop 0 0 (cons pb2 bl) (- i 1))
                  (loop cnt2 pb2 bl (- i 1)))))))

    (define (bs-bit-count bs) (vector-ref bs 0))

    (define (bs->bytes bs)
      (let* ((cnt (vector-ref bs 0))
             (pb  (vector-ref bs 1))
             (bl  (vector-ref bs 2))
             (bl  (if (zero? cnt) bl (cons (arithmetic-shift pb (- 8 cnt)) bl)))
             (lst (reverse bl))
             (out (make-bytevector (length lst) 0)))
        (let loop ((i 0) (l lst))
          (if (null? l) out
              (begin (bytevector-u8-set! out i (car l))
                     (loop (+ i 1) (cdr l)))))))

    ;; ===============================================================
    ;; Version selection
    ;; ===============================================================

    (define (data-bits-required data-len version)
      (+ 4 (char-count-bits version) (* 8 data-len)))

    (define (choose-version data-len ec)
      (let loop ((v 1))
        (cond ((> v 40) (error "qr: data too large for byte-mode QR" data-len))
              ((<= (data-bits-required data-len v)
                   (* 8 (version-data-codewords v ec)))
               v)
              (else (loop (+ v 1))))))

    ;; ===============================================================
    ;; Encode data codewords
    ;; ===============================================================

    (define (encode-data bytes version ec)
      (let* ((bs (new-bs))
             (cap-bits (* 8 (version-data-codewords version ec)))
             (nbytes (bytevector-length bytes)))
        (bs-put! bs #b0100 4)                              ; mode: byte
        (bs-put! bs nbytes (char-count-bits version))
        (let loop ((i 0))
          (when (< i nbytes)
            (bs-put! bs (bytevector-u8-ref bytes i) 8)
            (loop (+ i 1))))
        (bs-put! bs 0 (max 0 (min 4 (- cap-bits (bs-bit-count bs)))))
        (let* ((cnt (bs-bit-count bs))
               (pad (modulo (- 8 (modulo cnt 8)) 8)))
          (bs-put! bs 0 pad))
        (let* ((bv (bs->bytes bs))
               (need-bytes (quotient cap-bits 8))
               (out (make-bytevector need-bytes 0)))
          (bytevector-copy! out 0 bv 0 (bytevector-length bv))
          (let loop ((i (bytevector-length bv)) (toggle #t))
            (if (>= i need-bytes)
                out
                (begin (bytevector-u8-set! out i (if toggle #xEC #x11))
                       (loop (+ i 1) (not toggle))))))))

    ;; ===============================================================
    ;; Reed-Solomon over GF(256), primitive polynomial 0x11D.
    ;; ===============================================================

    (define gf-exp (make-vector 512 0))
    (define gf-log (make-vector 256 0))

    (define (init-gf!)
      (let loop ((i 0) (x 1))
        (if (= i 255)
            'ok
            (begin (vector-set! gf-exp i x)
                   (vector-set! gf-log x i)
                   (let* ((x2 (arithmetic-shift x 1))
                          (x3 (if (>= x2 256) (bitwise-xor x2 #x11D) x2)))
                     (loop (+ i 1) x3)))))
      (let loop ((i 255))
        (when (< i 512)
          (vector-set! gf-exp i (vector-ref gf-exp (- i 255)))
          (loop (+ i 1)))))

    (init-gf!)

    (define (gf-mul a b)
      (if (or (zero? a) (zero? b))
          0
          (vector-ref gf-exp (+ (vector-ref gf-log a) (vector-ref gf-log b)))))

    (define (rs-generator nsym)
      ;; Returns a vector of length nsym+1, coefficients from highest to
      ;; lowest degree, with leading coefficient 1.
      ;; g(x) = (x - α^0)(x - α^1)...(x - α^(nsym-1))
      (let ((g (make-vector (+ nsym 1) 0)))
        (vector-set! g 0 1)
        ;; current length of meaningful coefficients (highest stored at index 0..len-1)
        (let outer ((i 0) (len 1))
          (if (= i nsym)
              g
              (let ((alpha (vector-ref gf-exp i))
                    (new (make-vector (+ nsym 1) 0)))
                ;; new = g shifted up by 1 (multiply by x), xor g*alpha
                (let kloop ((k 0))
                  (when (<= k len)
                    (let ((above (if (= k 0) 0 (vector-ref g (- k 1))))
                          (here  (if (< k len) (vector-ref g k) 0)))
                      ;; new[k] = (x*g)[k] xor (α^i * g)[k]
                      ;;        = here xor (α^i * above)
                      (vector-set! new k (bitwise-xor here (gf-mul above alpha)))
                      (kloop (+ k 1)))))
                (let kloop ((k 0))
                  (when (<= k len)
                    (vector-set! g k (vector-ref new k))
                    (kloop (+ k 1))))
                (outer (+ i 1) (+ len 1)))))))

    (define (rs-encode-block data ec-length)
      ;; Returns ec-length bytes of Reed-Solomon parity for `data`.
      (let* ((gen (rs-generator ec-length))      ; length = ec-length + 1
             (dlen (bytevector-length data))
             (buf (make-vector (+ dlen ec-length) 0)))
        (let loop ((i 0))
          (when (< i dlen)
            (vector-set! buf i (bytevector-u8-ref data i))
            (loop (+ i 1))))
        (let iloop ((i 0))
          (when (< i dlen)
            (let ((coef (vector-ref buf i)))
              (when (not (zero? coef))
                (let jloop ((j 1))
                  (when (<= j ec-length)
                    (vector-set! buf (+ i j)
                                 (bitwise-xor (vector-ref buf (+ i j))
                                              (gf-mul (vector-ref gen j) coef)))
                    (jloop (+ j 1))))))
            (iloop (+ i 1))))
        (let ((out (make-bytevector ec-length 0)))
          (let loop ((k 0))
            (if (= k ec-length) out
                (begin (bytevector-u8-set! out k (vector-ref buf (+ dlen k)))
                       (loop (+ k 1))))))))

    ;; ===============================================================
    ;; Block splitting + interleaving
    ;; ===============================================================

    (define (split-into-blocks data version ec)
      (let* ((ecpb (table-ref ec-codewords-per-block-table 0 version ec))
             (nblocks (table-ref num-blocks-table 0 version ec))
             (total-data (bytevector-length data))
             (short-len (quotient total-data nblocks))
             (n-long (- total-data (* short-len nblocks)))
             (n-short (- nblocks n-long)))
        (let loop ((i 0) (off 0) (dblocks '()) (eblocks '()))
          (if (= i nblocks)
              (list (reverse dblocks) (reverse eblocks) ecpb)
              (let* ((blen (if (< i n-short) short-len (+ short-len 1)))
                     (blk (make-bytevector blen 0)))
                (bytevector-copy! blk 0 data off (+ off blen))
                (loop (+ i 1) (+ off blen)
                      (cons blk dblocks)
                      (cons (rs-encode-block blk ecpb) eblocks)))))))

    (define (interleave-blocks dblocks eblocks)
      (let* ((max-d (apply max (map bytevector-length dblocks)))
             (max-e (apply max (map bytevector-length eblocks)))
             (out-len (+ (apply + (map bytevector-length dblocks))
                         (apply + (map bytevector-length eblocks))))
             (out (make-bytevector out-len 0))
             (idx 0))
        (let iloop ((i 0))
          (when (< i max-d)
            (for-each (lambda (b)
                        (when (< i (bytevector-length b))
                          (bytevector-u8-set! out idx (bytevector-u8-ref b i))
                          (set! idx (+ idx 1))))
                      dblocks)
            (iloop (+ i 1))))
        (let iloop ((i 0))
          (when (< i max-e)
            (for-each (lambda (b)
                        (when (< i (bytevector-length b))
                          (bytevector-u8-set! out idx (bytevector-u8-ref b i))
                          (set! idx (+ idx 1))))
                      eblocks)
            (iloop (+ i 1))))
        out))

    ;; ===============================================================
    ;; Matrix helpers (0=light, 1=dark; reserved tracked separately)
    ;; ===============================================================

    (define (make-square-matrix size init)
      (let ((m (make-vector size #f)))
        (let loop ((i 0))
          (if (= i size) m
              (begin (vector-set! m i (make-vector size init))
                     (loop (+ i 1)))))))

    (define (m-ref m y x) (vector-ref (vector-ref m y) x))
    (define (m-set! m y x v) (vector-set! (vector-ref m y) x v))

    (define (set-fn! m mark y x dark)
      (m-set! m y x (if dark 1 0))
      (m-set! mark y x #t))

    ;; ===============================================================
    ;; Function patterns
    ;; ===============================================================

    (define (draw-finder! m mark cy cx size)
      (let yloop ((dy -4))
        (when (<= dy 4)
          (let xloop ((dx -4))
            (when (<= dx 4)
              (let ((y (+ cy dy)) (x (+ cx dx)))
                (when (and (<= 0 y (- size 1)) (<= 0 x (- size 1)))
                  (let* ((d (max (abs dy) (abs dx)))
                         (dark (or (<= d 1) (= d 3))))
                    (set-fn! m mark y x dark))))
              (xloop (+ dx 1))))
          (yloop (+ dy 1)))))

    (define (draw-alignment! m mark cy cx)
      (let yloop ((dy -2))
        (when (<= dy 2)
          (let xloop ((dx -2))
            (when (<= dx 2)
              (let ((d (max (abs dy) (abs dx))))
                (set-fn! m mark (+ cy dy) (+ cx dx) (not (= d 1))))
              (xloop (+ dx 1))))
          (yloop (+ dy 1)))))

    (define (draw-timing! m mark size)
      (let loop ((i 0))
        (when (< i size)
          (unless (m-ref mark 6 i)
            (set-fn! m mark 6 i (even? i)))
          (unless (m-ref mark i 6)
            (set-fn! m mark i 6 (even? i)))
          (loop (+ i 1)))))

    (define (reserve-format! mark size)
      ;; Around top-left finder: row 8 cols 0..8, col 8 rows 0..8 (skip those already function).
      (let loop ((i 0))
        (when (<= i 8)
          (m-set! mark 8 i #t)
          (m-set! mark i 8 #t)
          (loop (+ i 1))))
      ;; Around bottom-left and top-right finders.
      (let loop ((i 0))
        (when (< i 8)
          (m-set! mark (- size 1 i) 8 #t)
          (m-set! mark 8 (- size 1 i) #t)
          (loop (+ i 1)))))

    (define (reserve-version! mark size version)
      (when (>= version 7)
        (let yloop ((y 0))
          (when (< y 6)
            (let xloop ((x 0))
              (when (< x 3)
                (m-set! mark y (+ (- size 11) x) #t)
                (m-set! mark (+ (- size 11) x) y #t)
                (xloop (+ x 1))))
            (yloop (+ y 1))))))

    (define (draw-function-patterns! m mark version)
      (let ((size (module-size version)))
        (draw-finder! m mark 3 3 size)
        (draw-finder! m mark 3 (- size 4) size)
        (draw-finder! m mark (- size 4) 3 size)
        (draw-timing! m mark size)
        (let ((positions (vector-ref alignment-positions-table (- version 1))))
          (for-each
            (lambda (cy)
              (for-each
                (lambda (cx)
                  (unless (or (and (< cy 8) (< cx 8))
                              (and (< cy 8) (> cx (- size 9)))
                              (and (> cy (- size 9)) (< cx 8)))
                    (draw-alignment! m mark cy cx)))
                positions))
            positions))
        (reserve-format! mark size)
        (reserve-version! mark size version)
        ;; Dark module.
        (set-fn! m mark (- size 8) 8 #t)))

    ;; ===============================================================
    ;; Data placement (zig-zag, Nayuki's algorithm)
    ;; ===============================================================

    (define (place-data! m mark version bits)
      (let* ((size (module-size version))
             (nbits (* 8 (bytevector-length bits)))
             (bit-at (lambda (i)
                       (bitwise-and 1
                         (arithmetic-shift
                           (bytevector-u8-ref bits (quotient i 8))
                           (- (- 7 (modulo i 8))))))))
        (let rcol ((right (- size 1)) (i 0))
          (cond
            ((<= right 0) 'done)
            (else
             (let ((right (if (= right 6) 5 right)))
               (let vloop ((vert 0) (i i))
                 (if (= vert size)
                     (rcol (- right 2) i)
                     (let jloop ((j 0) (i i))
                       (if (= j 2)
                           (vloop (+ vert 1) i)
                           (let* ((x (- right j))
                                  (upward? (zero? (bitwise-and (+ right 1) 2)))
                                  (y (if upward? (- size 1 vert) vert)))
                             (if (m-ref mark y x)
                                 (jloop (+ j 1) i)
                                 (if (< i nbits)
                                     (begin
                                       (m-set! m y x (bit-at i))
                                       (jloop (+ j 1) (+ i 1)))
                                     (jloop (+ j 1) i))))))))))))))

    ;; ===============================================================
    ;; Masks
    ;; ===============================================================

    (define (mask-bit pattern y x)
      (case pattern
        ((0) (zero? (modulo (+ y x) 2)))
        ((1) (zero? (modulo y 2)))
        ((2) (zero? (modulo x 3)))
        ((3) (zero? (modulo (+ y x) 3)))
        ((4) (zero? (modulo (+ (quotient y 2) (quotient x 3)) 2)))
        ((5) (zero? (+ (modulo (* y x) 2) (modulo (* y x) 3))))
        ((6) (zero? (modulo (+ (modulo (* y x) 2) (modulo (* y x) 3)) 2)))
        ((7) (zero? (modulo (+ (modulo (+ y x) 2) (modulo (* y x) 3)) 2)))))

    (define (apply-mask! m mark size pattern)
      (let yloop ((y 0))
        (when (< y size)
          (let xloop ((x 0))
            (when (< x size)
              (unless (m-ref mark y x)
                (when (mask-bit pattern y x)
                  (m-set! m y x (bitwise-xor (m-ref m y x) 1))))
              (xloop (+ x 1))))
          (yloop (+ y 1)))))

    (define mask-penalty-pattern #(1 0 1 1 1 0 1))

    (define (mask-penalty m size)
      (let ((p1 0) (p2 0) (p3 0) (p4 0))
        (define (count-runs get)
          (let loop ((i 1) (run 1) (last (get 0)))
            (if (>= i size)
                (when (>= run 5) (set! p1 (+ p1 (- run 2))))
                (let ((c (get i)))
                  (if (= c last)
                      (loop (+ i 1) (+ run 1) last)
                      (begin (when (>= run 5) (set! p1 (+ p1 (- run 2))))
                             (loop (+ i 1) 1 c)))))))
        (define (matches-pat? get)
          (let loop ((i 0))
            (cond ((= i 7) #t)
                  ((= (get i) (vector-ref mask-penalty-pattern i)) (loop (+ i 1)))
                  (else #f))))
        (define (light-run? get from to)
          (let loop ((i from))
            (cond ((= i to) #t)
                  ((not (zero? (get i))) #f)
                  (else (loop (+ i 1))))))
        ;; Rule 1: runs of same color in rows and columns.
        (let loop ((y 0))
          (when (< y size)
            (count-runs (lambda (x) (m-ref m y x)))
            (loop (+ y 1))))
        (let loop ((x 0))
          (when (< x size)
            (count-runs (lambda (y) (m-ref m y x)))
            (loop (+ x 1))))
        ;; Rule 2: 2x2 same-color blocks.
        (let yloop ((y 0))
          (when (< y (- size 1))
            (let xloop ((x 0))
              (when (< x (- size 1))
                (let ((a (m-ref m y x))
                      (b (m-ref m y (+ x 1)))
                      (c (m-ref m (+ y 1) x))
                      (d (m-ref m (+ y 1) (+ x 1))))
                  (when (and (= a b) (= b c) (= c d))
                    (set! p2 (+ p2 3))))
                (xloop (+ x 1))))
            (yloop (+ y 1))))
        ;; Rule 3: finder-like pattern (1011101) with 4 light modules adjacent.
        (let yloop ((y 0))
          (when (< y size)
            (let xloop ((x 0))
              (when (<= (+ x 6) (- size 1))
                (when (matches-pat? (lambda (i) (m-ref m y (+ x i))))
                  (when (or (and (<= (+ x 11) size)
                                 (light-run? (lambda (i) (m-ref m y (+ x i))) 7 11))
                            (and (>= x 4)
                                 (light-run? (lambda (i) (m-ref m y (+ x i))) -4 0)))
                    (set! p3 (+ p3 40))))
                (xloop (+ x 1))))
            (yloop (+ y 1))))
        (let xloop ((x 0))
          (when (< x size)
            (let yloop ((y 0))
              (when (<= (+ y 6) (- size 1))
                (when (matches-pat? (lambda (i) (m-ref m (+ y i) x)))
                  (when (or (and (<= (+ y 11) size)
                                 (light-run? (lambda (i) (m-ref m (+ y i) x)) 7 11))
                            (and (>= y 4)
                                 (light-run? (lambda (i) (m-ref m (+ y i) x)) -4 0)))
                    (set! p3 (+ p3 40))))
                (yloop (+ y 1))))
            (xloop (+ x 1))))
        ;; Rule 4: dark-module proportion.
        (let* ((total (* size size))
               (dark
                 (let yloop ((y 0) (acc 0))
                   (if (= y size) acc
                       (let xloop ((x 0) (acc acc))
                         (if (= x size) (yloop (+ y 1) acc)
                             (xloop (+ x 1) (+ acc (m-ref m y x))))))))
               (percent (quotient (* 100 dark) total))
               (diff (abs (- percent 50)))
               (k (quotient diff 5)))
          (set! p4 (* k 10)))
        (+ p1 p2 p3 p4)))

    ;; ===============================================================
    ;; Format and version info (BCH)
    ;; ===============================================================

    (define (bch-divide data data-bits gen gen-bits)
      ;; Polynomial long division in GF(2). Returns the remainder.
      (let ((d (arithmetic-shift data (- gen-bits 1))))
        (let loop ((d d) (i (- data-bits 1)))
          (if (< i 0)
              d
              (if (not (zero? (bitwise-and d (arithmetic-shift 1 (+ i gen-bits -1)))))
                  (loop (bitwise-xor d (arithmetic-shift gen i)) (- i 1))
                  (loop d (- i 1)))))))

    (define (format-bits ec-bits mask-pattern)
      (let* ((data (bitwise-ior (arithmetic-shift ec-bits 3) mask-pattern))
             (rem  (bch-divide data 5 #b10100110111 11))
             (combined (bitwise-ior (arithmetic-shift data 10) rem)))
        (bitwise-xor combined #b101010000010010)))

    (define (version-info-bits version)
      (let ((rem (bch-divide version 6 #b1111100100101 13)))
        (bitwise-ior (arithmetic-shift version 12) rem)))

    (define (place-format-info! m version ec-bits mask-pattern)
      ;; Bit placement follows Project Nayuki's reference encoder
      ;; (matrix coordinates (row, col) here are (y, x) in Nayuki).
      (let* ((size (module-size version))
             (bits (format-bits ec-bits mask-pattern))
             (bit (lambda (i) (bitwise-and 1 (arithmetic-shift bits (- i))))))
        ;; First copy: along col 8 (rows 0..5, 7, 8) and row 8 (cols 7, 5..0).
        (let loop ((i 0))
          (when (<= i 5)
            (m-set! m i 8 (bit i))
            (loop (+ i 1))))
        (m-set! m 7 8 (bit 6))
        (m-set! m 8 8 (bit 7))
        (m-set! m 8 7 (bit 8))
        (let loop ((i 9))
          (when (< i 15)
            (m-set! m 8 (- 14 i) (bit i))
            (loop (+ i 1))))
        ;; Second copy: row 8 from col (size-1) leftward, then col 8 down from row (size-7).
        (let loop ((i 0))
          (when (< i 8)
            (m-set! m 8 (- size 1 i) (bit i))
            (loop (+ i 1))))
        (let loop ((i 8))
          (when (< i 15)
            (m-set! m (+ (- size 15) i) 8 (bit i))
            (loop (+ i 1))))))

    (define (place-version-info! m version)
      (when (>= version 7)
        (let* ((size (module-size version))
               (bits (version-info-bits version))
               (bit (lambda (i) (bitwise-and 1 (arithmetic-shift bits (- i))))))
          (let loop ((i 0))
            (when (< i 18)
              (let* ((r (modulo i 3))
                     (c (quotient i 3))
                     (b (bit i)))
                ;; Top-right block: row=c, col=size-11+r
                (m-set! m c (+ (- size 11) r) b)
                ;; Bottom-left block: row=size-11+r, col=c
                (m-set! m (+ (- size 11) r) c b))
              (loop (+ i 1)))))))

    ;; ===============================================================
    ;; qr-matrix record + main encode
    ;; ===============================================================

    (define-record-type qr-matrix
      (make-qr-matrix size cells version ec-level mask)
      qr-matrix?
      (size qr-matrix-size)
      (cells qr-matrix-cells)
      (version qr-matrix-version)
      (ec-level qr-matrix-ec-level)
      (mask qr-matrix-mask))

    (define (qr-matrix-ref qm y x)
      (vector-ref (vector-ref (qr-matrix-cells qm) y) x))

    (define (qr-encode data . rest)
      "Syntax: (qr-encode data [ec-level [version]])
Library: (scm qr)
Description: Encodes data as a QR code and returns a qr-matrix record.
  data may be a string (encoded as UTF-8) or a bytevector. ec-level
  defaults to 'M and must be one of 'L 'M 'Q 'H. version defaults to
  the smallest version that fits.
Example:
  (qr->svg (qr-encode \"https://example.org\") 4 4)"
      (let* ((ec-sym (if (pair? rest) (car rest) 'M))
             (ver-arg (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) #f))
             (bv (cond ((string? data) (string->utf8 data))
                       ((bytevector? data) data)
                       (else (error "qr-encode: data must be string or bytevector" data))))
             (ec (ec-index ec-sym))
             (version (or ver-arg (choose-version (bytevector-length bv) ec))))
        (encode-with-version bv ec version)))

    (define (encode-with-version bv ec version)
      (let* ((codewords   (encode-data bv version ec))
             (blocks      (split-into-blocks codewords version ec))
             (interleaved (interleave-blocks (car blocks) (cadr blocks)))
             (size        (module-size version))
             (m           (make-square-matrix size 0))
             (mark        (make-square-matrix size #f)))
        (draw-function-patterns! m mark version)
        (place-data! m mark version interleaved)
        (place-version-info! m version)
        ;; Try all 8 masks; pick the one with lowest penalty.
        (let* ((best
                (let loop ((p 0) (best 0) (best-pen #f))
                  (if (= p 8)
                      best
                      (begin
                        (apply-mask! m mark size p)
                        (place-format-info! m version (ec-level->format-bits ec) p)
                        (let ((pen (mask-penalty m size)))
                          (apply-mask! m mark size p)
                          (if (or (not best-pen) (< pen best-pen))
                              (loop (+ p 1) p pen)
                              (loop (+ p 1) best best-pen))))))))
          (apply-mask! m mark size best)
          (place-format-info! m version (ec-level->format-bits ec) best)
          (make-qr-matrix size m version ec best))))

    ;; ===============================================================
    ;; Rendering
    ;; ===============================================================

    (define (qr->png qm . rest)
      "Syntax: (qr->png matrix [module-px [quiet-modules]])
Library: (scm qr)
Description: Renders a qr-matrix as an 8-bit grayscale PNG bytevector.
  module-px is the side length in pixels of one module (default 8).
  quiet-modules is the border width in modules (default 4, per spec).
Example:
  (write-png-file \"qr.png\" (qr->png (qr-encode \"hello\")))"
      (let* ((mod-px (if (pair? rest) (car rest) 8))
             (quiet (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) 4))
             (modules (qr-matrix-size qm))
             (cells (qr-matrix-cells qm))
             (full (+ modules (* 2 quiet)))
             (width (* full mod-px))
             (height width)
             (pixels (make-bytevector (* width height) 255)))
        (let yloop ((my 0))
          (when (< my modules)
            (let xloop ((mx 0))
              (when (< mx modules)
                (when (= 1 (vector-ref (vector-ref cells my) mx))
                  (let py-loop ((py 0))
                    (when (< py mod-px)
                      (let px-loop ((px 0))
                        (when (< px mod-px)
                          (let ((y (+ (* (+ my quiet) mod-px) py))
                                (x (+ (* (+ mx quiet) mod-px) px)))
                            (bytevector-u8-set! pixels (+ (* y width) x) 0))
                          (px-loop (+ px 1))))
                      (py-loop (+ py 1)))))
                (xloop (+ mx 1))))
            (yloop (+ my 1))))
        (png-encode-grayscale width height pixels)))

    (define (qr->svg qm . rest)
      "Syntax: (qr->svg matrix [module-px [quiet-modules]])
Library: (scm qr)
Description: Renders a qr-matrix as an SVG string. module-px sets the
  width/height attribute scale (default 8 px per module). quiet-modules
  is the border in modules (default 4).
Example:
  (display (qr->svg (qr-encode \"hi\")))"
      (let* ((mod-px (if (pair? rest) (car rest) 8))
             (quiet (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) 4))
             (modules (qr-matrix-size qm))
             (cells (qr-matrix-cells qm))
             (full (+ modules (* 2 quiet)))
             (side (* full mod-px))
             (out (open-output-string)))
        (display "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 " out)
        (display full out) (display " " out) (display full out)
        (display "\" width=\"" out) (display side out)
        (display "\" height=\"" out) (display side out)
        (display "\" shape-rendering=\"crispEdges\">" out)
        (display "<rect width=\"100%\" height=\"100%\" fill=\"#fff\"/>" out)
        (display "<path fill=\"#000\" d=\"" out)
        (let yloop ((my 0))
          (when (< my modules)
            (let xloop ((mx 0))
              (when (< mx modules)
                (when (= 1 (vector-ref (vector-ref cells my) mx))
                  (display "M" out) (display (+ mx quiet) out)
                  (display " " out) (display (+ my quiet) out)
                  (display "h1v1h-1z" out))
                (xloop (+ mx 1))))
            (yloop (+ my 1))))
        (display "\"/></svg>" out)
        (get-output-string out)))

    (define (qr->ascii qm)
      "Syntax: (qr->ascii matrix)
Library: (scm qr)
Description: Renders a qr-matrix using two-character cells suitable for
  terminal preview. Each module becomes '  ' (light) or '##' (dark).
  Adds a 1-module quiet zone.
Example:
  (display (qr->ascii (qr-encode \"hi\")))"
      (let* ((size (qr-matrix-size qm))
             (cells (qr-matrix-cells qm))
             (out (open-output-string)))
        (let yloop ((y -1))
          (when (<= y size)
            (let xloop ((x -1))
              (when (<= x size)
                (let ((dark (and (<= 0 y (- size 1)) (<= 0 x (- size 1))
                                 (= 1 (vector-ref (vector-ref cells y) x)))))
                  (display (if dark "##" "  ") out))
                (xloop (+ x 1))))
            (newline out)
            (yloop (+ y 1))))
        (get-output-string out)))

    ))
