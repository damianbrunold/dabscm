(define-library (scm uri)
  (import (scm core) (scheme base))
  (export percent-encode
          percent-decode)
  (begin

    (define (hex-digit? c)
      (or (and (char>=? c #\0) (char<=? c #\9))
          (and (char>=? c #\a) (char<=? c #\f))
          (and (char>=? c #\A) (char<=? c #\F))))

    (define (hex-value c)
      (cond ((and (char>=? c #\0) (char<=? c #\9))
             (- (char->integer c) (char->integer #\0)))
            ((and (char>=? c #\a) (char<=? c #\f))
             (+ 10 (- (char->integer c) (char->integer #\a))))
            ((and (char>=? c #\A) (char<=? c #\F))
             (+ 10 (- (char->integer c) (char->integer #\A))))
            (else (error "percent-decode: not a hex digit" c))))

    (define (unreserved? c)
      (or (and (char>=? c #\a) (char<=? c #\z))
          (and (char>=? c #\A) (char<=? c #\Z))
          (and (char>=? c #\0) (char<=? c #\9))
          (char=? c #\-) (char=? c #\_) (char=? c #\.) (char=? c #\~)))

    (define hex-digits "0123456789ABCDEF")

    (define (write-hex-byte n out)
      (write-char #\% out)
      (write-char (string-ref hex-digits (quotient n 16)) out)
      (write-char (string-ref hex-digits (modulo n 16)) out))

    (define (percent-encode s)
      "Syntax: (percent-encode s)
Library: (scm uri)
Description: Encodes string s as UTF-8 and percent-escapes every byte
  outside the RFC 3986 unreserved set (A-Z a-z 0-9 - _ . ~). Suitable for
  building query values and path segments.
Example:
  (percent-encode \"a b/c\") => \"a%20b%2Fc\"
  (percent-encode \"hello\") => \"hello\""
      (let* ((bv (string->utf8 s))
             (n  (bytevector-length bv))
             (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((= i n) (get-output-string out))
            (else
             (let* ((b (bytevector-u8-ref bv i))
                    (c (integer->char b)))
               (cond ((and (< b 128) (unreserved? c)) (write-char c out))
                     (else (write-hex-byte b out)))
               (loop (+ i 1))))))))

    (define (percent-decode s . opt)
      "Syntax: (percent-decode s [plus-as-space?])
Library: (scm uri)
Description: Decodes percent-escaped UTF-8 in s. When plus-as-space? is
  true (the default), '+' is treated as space — appropriate for
  application/x-www-form-urlencoded bodies and query strings. Pass #f to
  preserve '+' literally (e.g. for URL path segments).
Example:
  (percent-decode \"a%20b\") => \"a b\"
  (percent-decode \"a+b\") => \"a b\"
  (percent-decode \"a+b\" #f) => \"a+b\""
      (let* ((plus-as-space? (if (null? opt) #t (car opt)))
             (n (string-length s))
             (bv (make-bytevector n 0)))
        (let loop ((i 0) (j 0))
          (cond
            ((= i n) (utf8->string bv 0 j))
            ((and (char=? (string-ref s i) #\%)
                  (< (+ i 2) n)
                  (hex-digit? (string-ref s (+ i 1)))
                  (hex-digit? (string-ref s (+ i 2))))
             (bytevector-u8-set! bv j
               (+ (* 16 (hex-value (string-ref s (+ i 1))))
                  (hex-value (string-ref s (+ i 2)))))
             (loop (+ i 3) (+ j 1)))
            ((and plus-as-space? (char=? (string-ref s i) #\+))
             (bytevector-u8-set! bv j 32)
             (loop (+ i 1) (+ j 1)))
            (else
             (let ((c (string-ref s i)))
               (cond ((< (char->integer c) 128)
                      (bytevector-u8-set! bv j (char->integer c))
                      (loop (+ i 1) (+ j 1)))
                     (else
                      (let ((cb (string->utf8 (string c))))
                        (let copy ((k 0) (j j))
                          (cond
                            ((= k (bytevector-length cb)) (loop (+ i 1) j))
                            (else
                             (bytevector-u8-set! bv j (bytevector-u8-ref cb k))
                             (copy (+ k 1) (+ j 1))))))))))))))
))
