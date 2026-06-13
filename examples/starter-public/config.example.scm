;; Copy to config.scm and edit for local/production use. If config.scm is
;; absent, the app falls back to this file so it runs out of the box.

;; Bind loopback only; a reverse proxy (see deploy/nginx.conf.example)
;; fronts the public interface and terminates TLS.
(define http-host "127.0.0.1")
(define http-port 8080)
