(define-library (scm crypto)
  (import (scm core))
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
          rsa-decrypt)
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
    (define rsa-decrypt            (%primitive "rsa-decrypt"))))
