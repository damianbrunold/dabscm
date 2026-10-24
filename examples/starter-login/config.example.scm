;; starter-login configuration: a list of (define name value) forms, read
;; as data by src/app-config.sld. bin/server.scm reads config.scm; the first
;; run creates it from this file, with a fresh session-secret.

;; Bind loopback only; a reverse proxy (deploy/nginx.conf.example) fronts
;; the public interface and terminates TLS.
(define http-host "127.0.0.1")
(define http-port 8071)

;; Path the app is mounted under, e.g. "/team"; "" for the host root. The
;; reverse proxy must pass paths through unchanged.
(define url-prefix "")

;; Signs the session cookies (base64 of 32 random bytes). To rotate it,
;; list the new key first: ("new" "old"); sessions signed with the old key
;; stay valid until you remove it. bin/gen-secret.scm prints a new key.
(define session-secret "REPLACE_WITH_BASE64_SECRET")
(define session-max-age (* 60 60 24 7))   ; 7 days

;; Cookies are sent over HTTPS only when #t. Keep #f for http://127.0.0.1
;; during development; deploy/install.sh sets #t.
(define secure-cookies? #f)

;; Relative paths are relative to the app directory. data-dir holds the
;; user store (users.scm) and must be writable.
(define static-dir "static")
(define items-file "data/items.json")
(define data-dir "data")
