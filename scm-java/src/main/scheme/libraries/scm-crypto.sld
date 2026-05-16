(define-library (scm crypto)
  (import (scm core) (scheme base) (srfi 151))
  (export sha1-hash
          md5-hash
          sha256-hash
          hmac-sha256
          pbkdf2-sha256
          base64-encode
          base64-decode
          random-bytes
          xor-key
          aes-cbc-encrypt
          aes-cbc-decrypt
          aes-gcm-encrypt
          aes-gcm-decrypt
          aes-ecb-encrypt
          aes-ecb-decrypt
          chacha20poly1305-encrypt
          chacha20poly1305-decrypt
          rsa-generate-keypair
          rsa-encrypt
          rsa-decrypt
          bytevector->hex
          hex->bytevector
          constant-time-bytevector=?
          random-string)
  (begin
    (define sha1-hash              (%primitive "sha1-hash"))
    (define md5-hash               (%primitive "md5-hash"))
    (define sha256-hash            (%primitive "sha256-hash"))
    (define hmac-sha256            (%primitive "hmac-sha256"))
    (define pbkdf2-sha256          (%primitive "pbkdf2-sha256"))
    (define base64-encode          (%primitive "base64-encode"))
    (define base64-decode          (%primitive "base64-decode"))
    (define random-bytes           (%primitive "random-bytes"))
    (define xor-key                (%primitive "xor-key"))
    (define aes-cbc-encrypt        (%primitive "aes-cbc-encrypt"))
    (define aes-cbc-decrypt        (%primitive "aes-cbc-decrypt"))
    (define aes-gcm-encrypt        (%primitive "aes-gcm-encrypt"))
    (define aes-gcm-decrypt        (%primitive "aes-gcm-decrypt"))
    (define aes-ecb-encrypt        (%primitive "aes-ecb-encrypt"))
    (define aes-ecb-decrypt        (%primitive "aes-ecb-decrypt"))
    (define chacha20poly1305-encrypt (%primitive "chacha20poly1305-encrypt"))
    (define chacha20poly1305-decrypt (%primitive "chacha20poly1305-decrypt"))
    (define rsa-generate-keypair   (%primitive "rsa-generate-keypair"))
    (define rsa-encrypt            (%primitive "rsa-encrypt"))
    (define rsa-decrypt            (%primitive "rsa-decrypt"))

    (define hex-digits "0123456789abcdef")

    (define (bytevector->hex bv)
      "Syntax: (bytevector->hex bv)
Library: (scm crypto)
Description: Returns the lowercase hexadecimal string representation of the
  bytevector bv (two hex digits per byte, no separators).
Example:
  (bytevector->hex #u8(0 15 255)) => \"000fff\""
      (let* ((n (bytevector-length bv))
             (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((= i n) (get-output-string out))
            (else
             (let ((b (bytevector-u8-ref bv i)))
               (write-char (string-ref hex-digits (quotient b 16)) out)
               (write-char (string-ref hex-digits (modulo b 16)) out)
               (loop (+ i 1))))))))

    (define (hex-value c)
      (cond ((and (char>=? c #\0) (char<=? c #\9))
             (- (char->integer c) (char->integer #\0)))
            ((and (char>=? c #\a) (char<=? c #\f))
             (+ 10 (- (char->integer c) (char->integer #\a))))
            ((and (char>=? c #\A) (char<=? c #\F))
             (+ 10 (- (char->integer c) (char->integer #\A))))
            (else (error "hex->bytevector: not a hex digit" c))))

    (define (hex->bytevector s)
      "Syntax: (hex->bytevector s)
Library: (scm crypto)
Description: Parses a hexadecimal string (case-insensitive, no separators)
  into a bytevector. Raises an error on odd length or non-hex characters.
Example:
  (hex->bytevector \"000fff\") => #u8(0 15 255)
  (hex->bytevector \"DEADBEEF\") => #u8(222 173 190 239)"
      (let* ((n (string-length s))
             (bv (make-bytevector (quotient n 2) 0)))
        (when (odd? n) (error "hex->bytevector: odd-length hex string"))
        (let loop ((i 0) (j 0))
          (cond
            ((= i n) bv)
            (else
             (bytevector-u8-set! bv j
               (+ (* 16 (hex-value (string-ref s i)))
                  (hex-value (string-ref s (+ i 1)))))
             (loop (+ i 2) (+ j 1)))))))

    (define (constant-time-bytevector=? a b)
      "Syntax: (constant-time-bytevector=? a b)
Library: (scm crypto)
Description: Compares two bytevectors in constant time relative to their
  length when equal-length. Returns #f for different lengths (this does
  leak length, just not content). Use for comparing MACs, password hashes,
  or any secret-derived bytes.
Example:
  (constant-time-bytevector=? #u8(1 2 3) #u8(1 2 3)) => #t
  (constant-time-bytevector=? #u8(1 2 3) #u8(1 2 4)) => #f"
      (cond
        ((not (= (bytevector-length a) (bytevector-length b))) #f)
        (else
         (let ((n (bytevector-length a)))
           (let loop ((i 0) (acc 0))
             (cond
               ((= i n) (= acc 0))
               (else
                (loop (+ i 1)
                      (bitwise-ior acc
                                   (bitwise-xor (bytevector-u8-ref a i)
                                                (bytevector-u8-ref b i)))))))))))

    (define (random-string charset length)
      "Syntax: (random-string charset length)
Library: (scm crypto)
Description: Returns a random string of the given length drawn from charset,
  using random-bytes as the entropy source. Each output character is the
  byte taken modulo (string-length charset); for cryptographic uses prefer
  a charset length that is a power of two to avoid modulo bias, or a
  charset of length ≤ 64 (the bias is then ≲ 1 in 4 billion per char).
Example:
  (random-string \"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\" 6) ; e.g. \"K3Z9PA\"
  (random-string \"0123456789abcdef\" 32) ; 128 random bits as hex"
      (let* ((cs-len (string-length charset))
             (bv     (random-bytes length))
             (out    (open-output-string)))
        (when (= cs-len 0)
          (error "random-string: empty charset"))
        (let loop ((i 0))
          (cond
            ((= i length) (get-output-string out))
            (else
             (write-char (string-ref charset
                                     (modulo (bytevector-u8-ref bv i) cs-len))
                         out)
             (loop (+ i 1)))))))
))
