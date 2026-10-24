;; starter-api configuration: a list of (define name value) forms, read as
;; data by src/app-config.sld. bin/server.scm reads config.scm; the first
;; run creates it from this file, with a fresh token-secret.

;; Bind loopback only; a reverse proxy (deploy/nginx.conf.example) fronts
;; the public interface and terminates TLS.
(define http-host "127.0.0.1")
(define http-port 8073)

;; Path the API is mounted under, e.g. "/inventory" for /inventory/api/...;
;; "" for the host root. The reverse proxy must pass paths through unchanged.
(define url-prefix "")

;; Signs the bearer tokens (base64 of 32 random bytes). To rotate it, list
;; the new key first: ("new" "old"); tokens signed with the old key stay
;; valid until you remove it. bin/gen-secret.scm prints a new key.
(define token-secret "REPLACE_WITH_BASE64_SECRET")
(define token-max-age (* 60 60 12))   ; 12 hours

;; Holds users.scm and items.scm and must be writable. Relative paths are
;; relative to the app directory.
(define data-dir "data")
