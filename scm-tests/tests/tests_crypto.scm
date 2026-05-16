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

(test-end "crypto")
