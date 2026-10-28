(import (scheme base)
        (scheme file)
        (scm fs)
        (scm string)
        (scm net http request)
        (scm net http response)
        (scm net http route)
        (scm net http static)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-static")

(define dir (mktempdir '(prefix . "scm-static-test")))
(define (write-file! rel content)
  (call-with-output-file (string-append dir "/" rel)
    (lambda (p) (write-string content p))))
(make-directory (string-append dir "/css"))
(write-file! "css/app.css" "body{}")
(write-file! "a b.txt" "spaced")
(write-file! ".env" "SECRET=1")
(write-file! "Zürich.txt" "z")
;; a file outside the served directory
(define outside (string-append (directory-name dir) "/scm-static-outside.txt"))
(call-with-output-file outside (lambda (p) (write-string "outside" p)))

(define router (make-router))
(router-add! router "GET" "/static/*" (make-static-handler dir))

(define (get url . headers)
  (router-dispatch router (make-http-request "GET" url (if (pair? headers) (car headers) '()) #f)))
(define (status url) (http-response-status (get url)))
(define (body-text resp) (utf8->string (http-response-body resp)))

(test-group "mime-type"
  (test-equal "text/css; charset=utf-8" (mime-type "x/app.css"))
  (test-equal "text/javascript; charset=utf-8" (mime-type "app.js"))
  (test-equal "image/png" (mime-type "LOGO.PNG"))
  (test-equal "font/woff2" (mime-type "f.woff2"))
  (test-equal "application/octet-stream" (mime-type "noext"))
  (test-equal "application/octet-stream" (mime-type "dir.d/noext")))

(test-group "serving"
  (let ((r (get "/static/css/app.css")))
    (test-equal 200 (http-response-status r))
    (test-equal "body{}" (body-text r))
    (test-equal "text/css; charset=utf-8" (http-response-header r "Content-Type"))
    (test-equal "nosniff" (http-response-header r "X-Content-Type-Options"))
    (test-equal "public, max-age=300" (http-response-header r "Cache-Control")))
  (test-equal "spaced" (body-text (get "/static/a%20b.txt")))
  (test-equal "z" (body-text (get "/static/Z%C3%BCrich.txt")))
  (test-equal "public, max-age=31536000, immutable"
              (http-response-header (get "/static/css/app.css?v=123") "Cache-Control")))

(test-group "refused paths are 404"
  (test-equal 404 (status "/static/missing.css"))
  (test-equal 404 (status "/static/css"))
  (test-equal 404 (status "/static/"))
  (test-equal 404 (status "/static/.env"))
  (test-equal 404 (status "/static/%2eenv"))
  (test-equal 404 (status "/static/../scm-static-outside.txt"))
  (test-equal 404 (status "/static/%2e%2e/scm-static-outside.txt"))
  (test-equal 404 (status "/static/css/%2e%2e/%2e%2e/scm-static-outside.txt"))
  (test-equal 404 (status "/static/%2e%2e%2fscm-static-outside.txt"))
  (test-equal 404 (status "/static/..%5cscm-static-outside.txt"))
  ;; the router drops empty segments: this is just css/app.css
  (test-equal 200 (status "/static/css//app.css"))
  (test-equal 404 (status "/static/css/app.css%00"))
  (test-equal 404 (status "/static/%zz")))

(test-group "conditional requests"
  (let* ((r (get "/static/css/app.css"))
         (etag (http-response-header r "ETag")))
    (test-assert (string? etag))
    (test-equal 304 (http-response-status
                     (get "/static/css/app.css" (list (cons "If-None-Match" etag)))))
    (test-equal 304 (http-response-status
                     (get "/static/css/app.css"
                          (list (cons "If-None-Match" (string-append "\"x\", " etag))))))
    (test-equal 200 (http-response-status
                     (get "/static/css/app.css" '(("If-None-Match" . "W/\"0-0\"")))))))

(test-group "file-response"
  (let ((r (file-response (string-append dir "/a b.txt")
                          '((filename . "Bericht ä.txt") (cache-control . "no-store")))))
    (test-equal 200 (http-response-status r))
    (test-equal "no-store" (http-response-header r "Cache-Control"))
    (test-equal "attachment; filename=\"Bericht _.txt\"; filename*=UTF-8''Bericht%20%C3%A4.txt"
                (http-response-header r "Content-Disposition")))
  (test-equal 404 (http-response-status (file-response (string-append dir "/nope"))))
  (test-equal 404 (http-response-status (file-response dir))))

(test-group "byte ranges"
  (let ((range (lambda (h . more)
                 (get "/static/css/app.css" (cons (cons "Range" h) (if (pair? more) (car more) '()))))))
    ;; "body{}" is 6 bytes
    (let ((r (range "bytes=1-3")))
      (test-equal 206 (http-response-status r))
      (test-equal "bytes 1-3/6" (http-response-header r "Content-Range"))
      (test-equal "ody" (body-text r)))
    (test-equal "{}" (body-text (range "bytes=4-")))
    (test-equal "{}" (body-text (range "bytes=-2")))
    (test-equal "bytes 0-5/6" (http-response-header (range "bytes=0-99") "Content-Range"))
    (test-equal 416 (http-response-status (range "bytes=6-")))
    (test-equal "bytes */6" (http-response-header (range "bytes=6-") "Content-Range"))
    ;; Malformed or several ranges: the whole file.
    (test-equal 200 (http-response-status (range "bytes=0-1,3-4")))
    (test-equal 200 (http-response-status (range "items=0-1")))
    (test-equal 200 (http-response-status (range "bytes=3-1")))
    ;; If-Range: only for the current version.
    (let ((etag (http-response-header (get "/static/css/app.css") "ETag")))
      (test-equal 206 (http-response-status (range "bytes=1-3" `(("If-Range" . ,etag)))))
      (test-equal 200 (http-response-status (range "bytes=1-3" '(("If-Range" . "\"old\""))))))
    (test-equal "bytes" (http-response-header (get "/static/css/app.css") "Accept-Ranges"))
    (test-equal "video/mp4" (mime-type "clip.MP4"))))

(test-group "make-static-url"
  (let ((u (make-static-url dir "/app/static/")))
    (test-assert (string-contains-from (u "css/app.css") "/app/static/css/app.css?v=" 0))
    (test-equal "/app/static/none.js" (u "none.js"))))

(delete-file outside)
(delete-directory dir)

(test-end "scm-http-static")
