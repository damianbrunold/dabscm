;; Copy to config.scm and edit. If config.scm is absent the app falls back
;; to this file, but the placeholder DB password below will not connect —
;; create config.scm for any real use.
;;
;; Generate a fresh cookie-secret with:
;;   scm -e '(import (scm crypto)) (display (base64-encode (random-bytes 32)))'

;; Bind loopback only; a reverse proxy fronts the public interface.
(define http-host "127.0.0.1")
(define http-port 8083)

(define static-dir     "static")
(define migrations-dir "migrations")

;; PostgreSQL connection (TCP). The role needs CREATE privileges on the
;; database the first time, so migrations can build the schema.
(define db-host "127.0.0.1")
(define db-port 5432)
(define db-user "starter_admin")
(define db-password "change-me")
(define db-name "starter_admin")
(define db-pool-capacity 8)

;; HMAC key that signs session cookies (base64 of 32 random bytes).
(define cookie-secret "WHwCLOJTvTKGg6nLEFM4zDdJAz9amy5GVS/vEL7PrEU=")
(define cookie-name   "starter_session")
(define session-max-age (* 60 60 24 7))    ; 7 days
(define secure-cookies? #f)                ; set #t behind HTTPS

;; Seeded by bin/seed-admin.scm (idempotent). Change the password after the
;; first login, or set a strong one here before seeding.
(define admin-username "admin")
(define admin-password "change-me-now")
