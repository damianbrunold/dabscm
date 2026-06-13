;; Copy to config.scm and edit for real use. If config.scm is absent the
;; app falls back to this file so it runs out of the box for local testing.
;;
;; IMPORTANT for production: generate your own cookie-secret and set
;; secure-cookies? to #t (requires HTTPS). Generate a secret with:
;;   scm -e '(import (scm crypto)) (display (base64-encode (random-bytes 32)))'

;; Bind loopback only; a reverse proxy fronts the public interface.
(define http-host "127.0.0.1")
(define http-port 8082)

(define static-dir "static")
(define data-file  "data/items.json")
(define users-file "data/users.scm")

;; HMAC key that signs session cookies (base64 of 32 random bytes).
(define cookie-secret "ylWhB8zT2lIrdW7KfWOQofO28V3CIlbonggj2LrO384=")
(define cookie-name   "starter_session")
(define session-max-age (* 60 60 24 7))   ; 7 days
(define secure-cookies? #f)               ; set #t behind HTTPS
