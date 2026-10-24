;; starter-public configuration: a list of (define name value) forms, read
;; as data by src/app-config.sld. bin/server.scm reads config.scm; the first
;; run creates it from this file. Every setting is optional.

;; Bind loopback only; a reverse proxy (deploy/nginx.conf.example) fronts
;; the public interface and terminates TLS.
(define http-host "127.0.0.1")
(define http-port 8070)

;; Path the app is mounted under, e.g. "/inventory"; "" for the host root.
;; The reverse proxy must pass paths through unchanged.
(define url-prefix "")

;; Relative paths are relative to the app directory.
(define static-dir "static")
(define data-file "data/items.json")
