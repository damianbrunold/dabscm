;; Copy to config.scm and edit for real use. If config.scm is absent the
;; app falls back to this file so it runs out of the box for local testing.
;;
;; Generate a fresh token-secret with:
;;   scm -e '(import (scm crypto)) (display (base64-encode (random-bytes 32)))'

;; Bind loopback only; a reverse proxy fronts the public interface.
(define http-host "127.0.0.1")
(define http-port 8084)

(define users-file "data/users.scm")
(define items-file "data/items.scm")

;; HMAC key that signs bearer tokens (base64 of 32 random bytes).
(define token-secret "bdC1oL1nkZBWqRAzObeM/dEJyFol5jbSDSyKWmJYZI8=")
(define token-max-age (* 60 60 12))   ; 12 hours
