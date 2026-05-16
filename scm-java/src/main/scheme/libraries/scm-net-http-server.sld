(define-library (scm net http server)
  (import (scm core)
          (scheme base)
          (scheme char)
          (scheme write)
          (except (scheme file) file-exists? delete-file)
          (scm fs)
          (scm net http request)
          (scm net http response))
  (export tcp-http-serve
          server-stop
          server-wait
          server-install-shutdown-hook
          serve-forever
          serve-directory)
  (begin
    (define tcp-http-serve (%primitive "tcp-http-serve"))
    (define server-stop    (%primitive "server-stop"))
    (define server-wait    (%primitive "server-wait"))
    (define server-install-shutdown-hook (%primitive "server-install-shutdown-hook"))

    (define (serve-forever port handler . rest)
      "Syntax: (serve-forever port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http server)
Description: Starts an HTTP server on port with the given handler and blocks
  indefinitely. handler receives each http-request and must return an http-response.
  Optional extra arguments forward to tcp-http-serve and configure: maximum
  concurrent worker threads (default 32; excess connections rejected with 503),
  bind host (default \"0.0.0.0\"), per-connection read timeout in ms (default 30000),
  maximum request body size in bytes (default 4194304; oversize rejected with 413),
  and graceful-stop drain period in ms (default 10000). 0 or omitted means default.
  Returns only if the server is stopped from another thread via server-stop.
Example:
  (serve-forever 8080 (lambda (req) (http-ok \"hello\")))
  (serve-forever 8080 handler 16 \"127.0.0.1\")"
      (server-wait (apply tcp-http-serve port handler rest)))

    ;; --- helpers for serve-directory ---

    (define (sd-hex-value c)
      (cond ((and (char>=? c #\0) (char<=? c #\9)) (- (char->integer c) (char->integer #\0)))
            ((and (char>=? c #\a) (char<=? c #\f)) (+ 10 (- (char->integer c) (char->integer #\a))))
            ((and (char>=? c #\A) (char<=? c #\F)) (+ 10 (- (char->integer c) (char->integer #\A))))
            (else #f)))

    (define (sd-percent-decode s)
      ;; Decodes %XX sequences. Bytes > 127 are emitted as Latin-1 chars
      ;; (caller treats result purely as a path string of byte-equivalent chars).
      (let* ((n (string-length s))
             (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((>= i n) (get-output-string out))
            ((and (char=? (string-ref s i) #\%)
                  (< (+ i 2) n)
                  (sd-hex-value (string-ref s (+ i 1)))
                  (sd-hex-value (string-ref s (+ i 2))))
             (let ((hi (sd-hex-value (string-ref s (+ i 1))))
                   (lo (sd-hex-value (string-ref s (+ i 2)))))
               (write-char (integer->char (+ (* 16 hi) lo)) out)
               (loop (+ i 3))))
            (else
             (write-char (string-ref s i) out)
             (loop (+ i 1)))))))

    (define (sd-strip-query url)
      (let ((n (string-length url)))
        (let loop ((i 0))
          (cond
            ((= i n) url)
            ((char=? (string-ref url i) #\?) (substring url 0 i))
            ((char=? (string-ref url i) #\#) (substring url 0 i))
            (else (loop (+ i 1)))))))

    (define (sd-split-segments path)
      ;; Split on '/', drop empties.
      (let ((n (string-length path)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((= i n)
             (let ((acc (if (> i start) (cons (substring path start n) acc) acc)))
               (reverse acc)))
            ((char=? (string-ref path i) #\/)
             (loop (+ i 1) (+ i 1)
                   (if (> i start) (cons (substring path start i) acc) acc)))
            (else (loop (+ i 1) start acc))))))

    (define (sd-resolve-path root url-path)
      ;; Returns a safe absolute path under root, or #f if the path tries to
      ;; escape the root via .. segments.
      (let loop ((segs (sd-split-segments (sd-percent-decode url-path)))
                 (stack '()))
        (cond
          ((null? segs) (apply join-path (cons root (reverse stack))))
          ((string=? (car segs) ".") (loop (cdr segs) stack))
          ((string=? (car segs) "..")
           (if (null? stack) #f (loop (cdr segs) (cdr stack))))
          ((or (string=? (car segs) "")
               (memv #\\ (string->list (car segs)))
               (memv (integer->char 0) (string->list (car segs))))
           #f)
          (else (loop (cdr segs) (cons (car segs) stack))))))

    (define (sd-ext path)
      (let loop ((i (- (string-length path) 1)))
        (cond
          ((< i 0) "")
          ((char=? (string-ref path i) #\.) (substring path i (string-length path)))
          ((char=? (string-ref path i) #\/) "")
          (else (loop (- i 1))))))

    (define (sd-content-type path)
      (let ((e (sd-ext path)))
        (cond
          ((string=? e ".html") "text/html; charset=utf-8")
          ((string=? e ".htm")  "text/html; charset=utf-8")
          ((string=? e ".css")  "text/css; charset=utf-8")
          ((string=? e ".js")   "application/javascript; charset=utf-8")
          ((string=? e ".mjs")  "application/javascript; charset=utf-8")
          ((string=? e ".json") "application/json; charset=utf-8")
          ((string=? e ".xml")  "application/xml; charset=utf-8")
          ((string=? e ".svg")  "image/svg+xml")
          ((string=? e ".txt")  "text/plain; charset=utf-8")
          ((string=? e ".md")   "text/plain; charset=utf-8")
          ((string=? e ".scm")  "text/plain; charset=utf-8")
          ((string=? e ".sld")  "text/plain; charset=utf-8")
          ((string=? e ".png")  "image/png")
          ((string=? e ".jpg")  "image/jpeg")
          ((string=? e ".jpeg") "image/jpeg")
          ((string=? e ".gif")  "image/gif")
          ((string=? e ".webp") "image/webp")
          ((string=? e ".ico")  "image/x-icon")
          ((string=? e ".pdf")  "application/pdf")
          ((string=? e ".zip")  "application/zip")
          ((string=? e ".gz")   "application/gzip")
          ((string=? e ".woff") "font/woff")
          ((string=? e ".woff2") "font/woff2")
          ((string=? e ".ttf")  "font/ttf")
          ((string=? e ".otf")  "font/otf")
          ((string=? e ".wasm") "application/wasm")
          ((string=? e ".mp3")  "audio/mpeg")
          ((string=? e ".mp4")  "video/mp4")
          (else "application/octet-stream"))))

    (define (sd-html-escape s)
      (let* ((n (string-length s))
             (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((= i n) (get-output-string out))
            (else
             (let ((c (string-ref s i)))
               (cond ((char=? c #\<) (write-string "&lt;" out))
                     ((char=? c #\>) (write-string "&gt;" out))
                     ((char=? c #\&) (write-string "&amp;" out))
                     ((char=? c #\") (write-string "&quot;" out))
                     (else (write-char c out))))
             (loop (+ i 1)))))))

    (define (sd-read-file-bytes path)
      (let* ((size (file-size path))
             (port (open-binary-input-file path))
             (bv (read-bytevector size port)))
        (close-input-port port)
        (if (eof-object? bv) (bytevector) bv)))

    (define (sd-insert-sorted x lst)
      (cond ((null? lst) (list x))
            ((string<? x (car lst)) (cons x lst))
            (else (cons (car lst) (sd-insert-sorted x (cdr lst))))))

    (define (sd-sort-strings lst)
      (let loop ((in lst) (out '()))
        (if (null? in) out
            (loop (cdr in) (sd-insert-sorted (car in) out)))))

    (define (sd-make-listing-html dir url-path)
      (let* ((sorted-files (sd-sort-strings (directory-files dir)))
             (sorted-subs  (sd-sort-strings (directory-directories dir)))
             (out (open-output-string))
             (title (string-append "Index of " url-path)))
        (write-string "<!doctype html><html><head><meta charset=\"utf-8\"><title>" out)
        (write-string (sd-html-escape title) out)
        (write-string "</title></head><body><h1>" out)
        (write-string (sd-html-escape title) out)
        (write-string "</h1><ul>" out)
        (let ((trim (or (string=? url-path "/") (string=? url-path ""))))
          (when (not trim)
            (write-string "<li><a href=\"../\">../</a></li>" out)))
        (for-each
          (lambda (name)
            (write-string "<li><a href=\"" out)
            (write-string (sd-html-escape name) out)
            (write-string "/\">" out)
            (write-string (sd-html-escape name) out)
            (write-string "/</a></li>" out))
          sorted-subs)
        (for-each
          (lambda (name)
            (write-string "<li><a href=\"" out)
            (write-string (sd-html-escape name) out)
            (write-string "\">" out)
            (write-string (sd-html-escape name) out)
            (write-string "</a></li>" out))
          sorted-files)
        (write-string "</ul></body></html>" out)
        (get-output-string out)))

    (define (sd-handle root req)
      (let* ((raw-url (http-request-url req))
             (url-path (sd-strip-query raw-url))
             (resolved (sd-resolve-path root url-path)))
        (cond
          ((not resolved)
           (make-http-response 403
             (list (cons "Content-Type" "text/plain; charset=utf-8"))
             "Forbidden"))
          ((directory-exists? resolved)
           (let ((index (join-path resolved "index.html")))
             (cond
               ((file-exists? index)
                (make-http-response 200
                  (list (cons "Content-Type" "text/html; charset=utf-8"))
                  (sd-read-file-bytes index)))
               ((and (> (string-length url-path) 0)
                     (not (char=? (string-ref url-path
                                              (- (string-length url-path) 1))
                                  #\/)))
                ;; Redirect to add trailing slash so relative links work.
                (make-http-response 301
                  (list (cons "Location" (string-append url-path "/"))
                        (cons "Content-Type" "text/plain; charset=utf-8"))
                  "Moved"))
               (else
                (make-http-response 200
                  (list (cons "Content-Type" "text/html; charset=utf-8"))
                  (sd-make-listing-html resolved url-path))))))
          ((file-exists? resolved)
           (make-http-response 200
             (list (cons "Content-Type" (sd-content-type resolved)))
             (sd-read-file-bytes resolved)))
          (else
           (make-http-response 404
             (list (cons "Content-Type" "text/plain; charset=utf-8"))
             "Not Found")))))

    (define (serve-directory . args)
      "Syntax: (serve-directory [path [port]])
Library: (scm net http server)
Description: Starts an HTTP server that serves files from the given directory
  (default \".\") on the given port (default 8080) and blocks indefinitely.
  Directory requests serve index.html if present, otherwise an HTML listing.
  Content-Type is inferred from the file extension. Path traversal via .. is
  rejected with 403. This procedure never returns normally.
Example:
  (serve-directory)
  (serve-directory \".\")
  (serve-directory \".\" 8080)"
      (let* ((path (if (and (pair? args) (string? (car args))) (car args) "."))
             (port (cond ((and (pair? args) (string? (car args)) (pair? (cdr args)))
                          (cadr args))
                         ((and (pair? args) (integer? (car args)))
                          (car args))
                         (else 8080)))
             (root (normalized-path path)))
        (when (not (directory-exists? root))
          (error "serve-directory: not a directory" path))
        (display "Serving ")
        (display root)
        (display " on http://localhost:")
        (display port)
        (display "/")
        (newline)
        (serve-forever port (lambda (req) (sd-handle root req)))))))
