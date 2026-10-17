(import (scheme base) (scm crypto) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "crypto")

;; AES-CBC with 16-byte key
(test-group "aes-cbc-128"
  (define key16 (random-bytes 16))
  (define iv    (random-bytes 16))
  (define pt16  #u8(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))
  (test-equal #t (bytevector? (aes-cbc-encrypt key16 iv pt16)))
  (test-equal 0 (remainder (bytevector-length (aes-cbc-encrypt key16 iv pt16)) 16))
  (test-equal #u8(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16) (aes-cbc-decrypt key16 iv (aes-cbc-encrypt key16 iv pt16))))

;; AES-CBC with 24-byte key
(test-group "aes-cbc-192"
  (define key24 (random-bytes 24))
  (define iv24  (random-bytes 16))
  (define pt24  #u8(0 1 2 3 4 5 6 7))
  (test-equal #u8(0 1 2 3 4 5 6 7) (aes-cbc-decrypt key24 iv24 (aes-cbc-encrypt key24 iv24 pt24))))

;; AES-CBC with 32-byte key
(test-group "aes-cbc-256"
  (define key32 (random-bytes 32))
  (define iv32  (random-bytes 16))
  (define pt32  #u8(255 254 253 252))
  (test-equal #u8(255 254 253 252) (aes-cbc-decrypt key32 iv32 (aes-cbc-encrypt key32 iv32 pt32))))

;; AES-GCM with 16-byte key
(test-group "aes-gcm-128"
  (define gkey   (random-bytes 16))
  (define gnonce (random-bytes 12))
  (define gpt    #u8(10 20 30 40 50))
  (test-equal #t (bytevector? (aes-gcm-encrypt gkey gnonce gpt)))
  (test-equal 21 (bytevector-length (aes-gcm-encrypt gkey gnonce gpt)))
  (test-equal #u8(10 20 30 40 50) (aes-gcm-decrypt gkey gnonce (aes-gcm-encrypt gkey gnonce gpt))))

;; AES-GCM with 32-byte key and AAD
(test-group "aes-gcm-256-aad"
  (define gkey2   (random-bytes 32))
  (define gnonce2 (random-bytes 12))
  (define gpt2    #u8(1 2 3))
  (define gaad    #u8(9 8 7 6))
  (test-equal #u8(1 2 3) (aes-gcm-decrypt gkey2 gnonce2 (aes-gcm-encrypt gkey2 gnonce2 gpt2 gaad) gaad)))

;; AES-GCM with empty plaintext
(test-group "aes-gcm-empty"
  (define gkey3   (random-bytes 16))
  (define gnonce3 (random-bytes 12))
  (test-equal 16 (bytevector-length (aes-gcm-encrypt gkey3 gnonce3 #u8())))
  (test-equal #u8() (aes-gcm-decrypt gkey3 gnonce3 (aes-gcm-encrypt gkey3 gnonce3 #u8()))))

;; AES-ECB with 16-byte key
(test-group "aes-ecb-128"
  (define ekey16 (random-bytes 16))
  (define ept16  #u8(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15))
  (test-equal #t (bytevector? (aes-ecb-encrypt ekey16 ept16)))
  (test-equal #u8(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15) (aes-ecb-decrypt ekey16 (aes-ecb-encrypt ekey16 ept16))))

;; AES-ECB with 32-byte key
(test-group "aes-ecb-256"
  (define ekey32 (random-bytes 32))
  (define ept32  #u8(42 43 44))
  (test-equal #u8(42 43 44) (aes-ecb-decrypt ekey32 (aes-ecb-encrypt ekey32 ept32))))

;; ChaCha20-Poly1305
(test-group "chacha20poly1305"
  (define ckey   (random-bytes 32))
  (define cnonce (random-bytes 12))
  (define cpt    #u8(11 22 33 44 55 66))
  (test-equal #t (bytevector? (chacha20poly1305-encrypt ckey cnonce cpt)))
  (test-equal 22 (bytevector-length (chacha20poly1305-encrypt ckey cnonce cpt)))
  (test-equal #u8(11 22 33 44 55 66) (chacha20poly1305-decrypt ckey cnonce (chacha20poly1305-encrypt ckey cnonce cpt))))

;; ChaCha20-Poly1305 with AAD
(test-group "chacha20poly1305-aad"
  (define ckey2   (random-bytes 32))
  (define cnonce2 (random-bytes 12))
  (define cpt2    #u8(1 2 3 4 5))
  (define caad    #u8(10 20 30))
  (test-equal #u8(1 2 3 4 5) (chacha20poly1305-decrypt ckey2 cnonce2 (chacha20poly1305-encrypt ckey2 cnonce2 cpt2 caad) caad)))

;; RSA keypair generation and encrypt/decrypt
(test-group "rsa"
  (define kp   (rsa-generate-keypair 2048))
  (define rpub  (car kp))
  (define rpriv (cadr kp))
  (test-equal #t (list? kp))
  (test-equal 2 (length kp))
  (test-equal #t (bytevector? rpub))
  (test-equal #t (bytevector? rpriv))
  (test-equal #t (bytevector? (rsa-encrypt rpub #u8(1 2 3 4 5))))
  (test-equal #u8(1 2 3 4 5) (rsa-decrypt rpriv (rsa-encrypt rpub #u8(1 2 3 4 5)))))

(test-group "bytevector->hex"
  (test-equal "" (bytevector->hex #u8()))
  (test-equal "00" (bytevector->hex #u8(0)))
  (test-equal "000fff" (bytevector->hex #u8(0 15 255)))
  (test-equal "deadbeef" (bytevector->hex #u8(222 173 190 239))))

(test-group "hex->bytevector"
  (test-equal #u8() (hex->bytevector ""))
  (test-equal #u8(0 15 255) (hex->bytevector "000fff"))
  (test-equal #u8(222 173 190 239) (hex->bytevector "DEADBEEF"))
  (test-equal #u8(222 173 190 239) (hex->bytevector "deadbeef"))
  (let ((bv (random-bytes 32)))
    (test-equal bv (hex->bytevector (bytevector->hex bv)))))

(test-group "constant-time-bytevector=?"
  (test-equal #t (constant-time-bytevector=? #u8() #u8()))
  (test-equal #t (constant-time-bytevector=? #u8(1 2 3) #u8(1 2 3)))
  (test-equal #f (constant-time-bytevector=? #u8(1 2 3) #u8(1 2 4)))
  (test-equal #f (constant-time-bytevector=? #u8(1 2 3) #u8(1 2)))
  (test-equal #f (constant-time-bytevector=? #u8(1 2) #u8(1 2 3))))

(test-group "random-string"
  (test-equal 6 (string-length (random-string "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" 6)))
  (test-equal 0 (string-length (random-string "abc" 0)))
  (let* ((cs "ab")
         (s  (random-string cs 64)))
    (test-equal #t
      (let loop ((i 0))
        (cond
          ((= i (string-length s)) #t)
          ((or (char=? (string-ref s i) #\a)
               (char=? (string-ref s i) #\b))
           (loop (+ i 1)))
          (else #f))))))

(test-group "scrypt"
  ;; RFC 7914 section 12 test vectors
  (test-equal "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906"
    (bytevector->hex (scrypt "" #u8() 16 1 1 64)))
  (test-equal "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640"
    (bytevector->hex (scrypt "password" (string->utf8 "NaCl") 1024 8 16 64)))
  (test-equal "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887"
    (bytevector->hex (scrypt (string->utf8 "pleaseletmein") (string->utf8 "SodiumChloride") 16384 8 1 64)))
  ;; Werkzeug's default parameters, non-ASCII password (UTF-8)
  (test-equal "99897f8444a2c1077f6f1d7d149ea7d107f9841bf90ecb1d4c946b0286ea994db262bd896fd2ecbbb5ce39a33eedb94bf25dd92c25e8db7507fc597dfa341ffa"
    (bytevector->hex (scrypt "p\xe4;sswort" (string->utf8 "salt") 32768 8 1 64)))
  (test-error (scrypt "pw" #u8() 1000 8 1 64)))

(test-end "crypto")
