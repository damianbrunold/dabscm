(define-library (scm net http static)
  (import (scm core)
          (scheme base)
          (scheme char)
          (scheme file)
          (scm string)
          (scm uri)
          (scm fs)
          (scm net http request)
          (scm net http response)
          (scm net http route))
  (export mime-type
          file-response
          make-static-handler
          make-static-url)
  (begin

    ;; --- content types ----------------------------------------------------

    (define mime-types
      '(("html"  . "text/html; charset=utf-8")
        ("htm"   . "text/html; charset=utf-8")
        ("css"   . "text/css; charset=utf-8")
        ("js"    . "text/javascript; charset=utf-8")
        ("mjs"   . "text/javascript; charset=utf-8")
        ("json"  . "application/json; charset=utf-8")
        ("map"   . "application/json; charset=utf-8")
        ("txt"   . "text/plain; charset=utf-8")
        ("csv"   . "text/csv; charset=utf-8")
        ("xml"   . "application/xml; charset=utf-8")
        ("svg"   . "image/svg+xml")
        ("png"   . "image/png")
        ("jpg"   . "image/jpeg")
        ("jpeg"  . "image/jpeg")
        ("gif"   . "image/gif")
        ("webp"  . "image/webp")
        ("avif"  . "image/avif")
        ("ico"   . "image/x-icon")
        ("pdf"   . "application/pdf")
        ("zip"   . "application/zip")
        ("mp4"   . "video/mp4")
        ("m4v"   . "video/mp4")
        ("webm"  . "video/webm")
        ("ogv"   . "video/ogg")
        ("mov"   . "video/quicktime")
        ("mp3"   . "audio/mpeg")
        ("m4a"   . "audio/mp4")
        ("oga"   . "audio/ogg")
        ("ogg"   . "audio/ogg")
        ("wav"   . "audio/wav")
        ("pptx"  . "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        ("docx"  . "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        ("xlsx"  . "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        ("woff"  . "font/woff")
        ("woff2" . "font/woff2")
        ("wasm"  . "application/wasm")))

    (define (extension path)
      (let loop ((i (- (string-length path) 1)))
        (cond
          ((< i 0) "")
          ((char=? (string-ref path i) #\.)
           (string-map char-downcase (substring path (+ i 1) (string-length path))))
          ((memv (string-ref path i) '(#\/ #\\)) "")
          (else (loop (- i 1))))))

    (define (mime-type path)
      "Syntax: (mime-type path)
Library: (scm net http static)
Description: Returns the Content-Type for path from its extension (case
  insensitive). Text types carry charset=utf-8; an unknown extension gives
  application/octet-stream.
Example:
  (mime-type \"static/app.css\") => \"text/css; charset=utf-8\"
  (mime-type \"logo.PNG\") => \"image/png\""
      (let ((p (assoc (extension path) mime-types)))
        (if p (cdr p) "application/octet-stream")))

    ;; --- single files -----------------------------------------------------

    (define (opt-ref opts key default)
      (let ((p (assq key opts)))
        (if p (cdr p) default)))

    (define (etag-for path)
      (string-append "W/\"" (number->string (file-modification-timestamp path))
                     "-" (number->string (file-size path)) "\""))

    (define (trim s)
      (let* ((n (string-length s))
             (a (let loop ((i 0))
                  (if (and (< i n) (char-whitespace? (string-ref s i))) (loop (+ i 1)) i)))
             (b (let loop ((j n))
                  (if (and (> j a) (char-whitespace? (string-ref s (- j 1)))) (loop (- j 1)) j))))
        (substring s a b)))

    ;; Weak comparison (RFC 9110): W/ prefixes are ignored.
    (define (strip-weak t)
      (if (and (>= (string-length t) 2) (string=? (substring t 0 2) "W/"))
          (substring t 2 (string-length t))
          t))

    (define (etag-matches? header etag)
      (and header
           (let ((want (strip-weak etag)))
             (let loop ((tags (string-split-char header #\,)))
               (and (pair? tags)
                    (let ((t (trim (car tags))))
                      (or (string=? t "*")
                          (string=? (strip-weak t) want)
                          (loop (cdr tags)))))))))

    ;; --- byte ranges (RFC 9110 section 14) ------------------------------
    ;; One range per request: "bytes=a-b", "bytes=a-" or "bytes=-n".
    ;; Returns (start . end) with end inclusive, 'unsatisfiable, or #f when
    ;; the header is absent, malformed or asks for several ranges (then
    ;; the whole file is sent, as the RFC allows).

    (define (digits? s)
      (and (> (string-length s) 0)
           (let loop ((i 0))
             (or (= i (string-length s))
                 (and (char-numeric? (string-ref s i)) (loop (+ i 1)))))))

    (define (parse-range header size)
      (and header
           (let ((h (trim header)))
             (and (>= (string-length h) 6)
                  (string=? (string-downcase (substring h 0 6)) "bytes=")
                  (let* ((spec (trim (substring h 6 (string-length h))))
                         (dash (let loop ((i 0))
                                 (cond ((= i (string-length spec)) #f)
                                       ((char=? (string-ref spec i) #\-) i)
                                       (else (loop (+ i 1)))))))
                    (and dash
                         (not (memv #\, (string->list spec)))
                         (let ((a (trim (substring spec 0 dash)))
                               (b (trim (substring spec (+ dash 1) (string-length spec)))))
                           (cond
                             ;; "-n": the last n bytes
                             ((and (string=? a "") (digits? b))
                              (let ((n (string->number b)))
                                (if (or (= n 0) (= size 0))
                                    'unsatisfiable
                                    (cons (max 0 (- size n)) (- size 1)))))
                             ((and (digits? a) (or (string=? b "") (digits? b)))
                              (let ((start (string->number a))
                                    (end (if (string=? b "") (- size 1)
                                             (min (string->number b) (- size 1)))))
                                (cond ((>= start size) 'unsatisfiable)
                                      ((< end start) #f)
                                      (else (cons start end)))))
                             (else #f)))))))))

    ;; A Range applies unless If-Range names another version (a date
    ;; If-Range never matches: no Last-Modified is sent).
    (define (range-applies? req etag)
      (let ((if-range (http-request-header req "If-Range")))
        (or (not if-range)
            (string=? (trim if-range) etag))))

    ;; attachment; filename="<ascii fallback>"; filename*=UTF-8''<encoded>
    (define (content-disposition name)
      (string-append
       "attachment; filename=\""
       (string-map (lambda (c)
                     (if (and (char<=? #\space c #\~) (not (memv c '(#\" #\\))))
                         c
                         #\_))
                   name)
       "\"; filename*=UTF-8''" (percent-encode name)))

    (define (file-response path . opts)
      "Syntax: (file-response path [opts])
Library: (scm net http static)
Description: Returns a 200 response with the file at path, or 404 if it
  does not exist or is a directory. The body is sent from the file (see
  make-http-file-response), so files of any size work. The response
  carries the file's Content-Type (mime-type), a weak ETag from its
  modification time and size, Accept-Ranges: bytes and
  X-Content-Type-Options: nosniff. opts is an alist: (request . req)
  answers 304 Not Modified when req's If-None-Match matches, and a single
  Range (bytes=a-b, a-, -n) with 206 Partial Content and Content-Range, or
  416 when it lies outside the file (If-Range is honoured), so audio and
  video can seek and downloads resume; (cache-control . string) sets Cache-Control (default
  \"no-cache\": cache, but revalidate); (content-type . string) overrides
  the type; (filename . string) makes it a download with that name.
  path must not come from the client unchecked; make-static-handler does
  the checking for a directory of assets.
Example:
  (file-response \"/var/lib/app/reports/r1.pdf\"
                 `((request . ,req) (filename . \"Report 2026.pdf\")))"
      (let ((opts (if (pair? opts) (car opts) '())))
        (if (not (and (file-exists? path) (not (directory-exists? path))))
            (http-not-found)
            (let* ((etag (etag-for path))
                   (req (opt-ref opts 'request #f))
                   (filename (opt-ref opts 'filename #f))
                   (headers
                    (append
                     (list (cons "ETag" etag)
                           (cons "Cache-Control" (opt-ref opts 'cache-control "no-cache"))
                           (cons "X-Content-Type-Options" "nosniff"))
                     (if filename
                         (list (cons "Content-Disposition" (content-disposition filename)))
                         '()))))
              (if (and req (etag-matches? (http-request-header req "If-None-Match") etag))
                  (make-http-response 304 headers "")
                  (let* ((size (file-size path))
                         (headers (append
                                   (list (cons "Content-Type"
                                               (opt-ref opts 'content-type (mime-type path)))
                                         (cons "Accept-Ranges" "bytes"))
                                   headers))
                         (range (and req
                                     (member (http-request-method req) '("GET" "HEAD"))
                                     (range-applies? req etag)
                                     (parse-range (http-request-header req "Range") size))))
                    (cond
                      ((not range) (make-http-file-response 200 headers path))
                      ((eq? range 'unsatisfiable)
                       (make-http-response
                        416
                        (cons (cons "Content-Range"
                                    (string-append "bytes */" (number->string size)))
                              headers)
                        ""))
                      (else
                       (let ((start (car range)) (end (cdr range)))
                         (make-http-file-response
                          206
                          (cons (cons "Content-Range"
                                      (string-append "bytes " (number->string start) "-"
                                                     (number->string end) "/"
                                                     (number->string size)))
                                headers)
                          path start (+ (- end start) 1)))))))))))

    ;; --- a directory of assets --------------------------------------------

    ;; The router hands "*" over raw. Decode each segment and refuse
    ;; anything that could leave dir or reach hidden files: empty, ".",
    ;; "..", dot-files, and segments holding '/', '\' or NUL once decoded.
    ;; Returns the decoded relative path or #f.
    (define (safe-relative-path raw)
      (and (string? raw)
           (guard (e (#t #f))
             (let loop ((segs (string-split-char raw #\/)) (acc '()))
               (if (null? segs)
                   (and (pair? acc)
                        (let join ((xs (reverse acc)) (out ""))
                          (if (null? xs)
                              out
                              (join (cdr xs)
                                    (if (string=? out "")
                                        (car xs)
                                        (string-append out "/" (car xs)))))))
                   (let ((seg (percent-decode (car segs) #f)))
                     (and (> (string-length seg) 0)
                          (not (char=? (string-ref seg 0) #\.))
                          (let check ((i 0))
                            (or (= i (string-length seg))
                                (and (not (memv (string-ref seg i)
                                                (list #\/ #\\ (integer->char 0))))
                                     (check (+ i 1)))))
                          (loop (cdr segs) (cons seg acc)))))))))

    (define (versioned? req)
      (guard (e (#t #f))
        (and (assoc "v" (url-query-params (http-request-url req))) #t)))

    (define (make-static-handler dir . opts)
      "Syntax: (make-static-handler dir [opts])
Library: (scm net http static)
Description: Returns a router handler that serves the files under dir for
  a route ending in the * wildcard, e.g.
  (router-add! r \"GET\" \"/static/*\" (make-static-handler \"static\")).
  Paths are percent-decoded per segment; empty segments, \".\", \"..\",
  dot-files and segments containing / \\ or NUL get 404, as do missing
  files and directories. A request with a v= query parameter (see
  make-static-url) is cached for a year as immutable; others get the
  (cache-control . string) option, default \"public, max-age=300\". ETag
  and If-None-Match (304) work as in file-response.
Example:
  (router-add! router \"GET\" \"/static/*\"
    (make-static-handler \"/opt/app/static\" '((cache-control . \"no-cache\"))))"
      (let ((opts (if (pair? opts) (car opts) '())))
        (lambda (req params)
          (let ((rel (safe-relative-path (params-ref params "*"))))
            (if (not rel)
                (http-not-found)
                (file-response
                 (string-append dir "/" rel)
                 (list (cons 'request req)
                       (cons 'cache-control
                             (if (versioned? req)
                                 "public, max-age=31536000, immutable"
                                 (opt-ref opts 'cache-control "public, max-age=300"))))))))))

    (define (make-static-url dir base-url)
      "Syntax: (make-static-url dir base-url)
Library: (scm net http static)
Description: Returns a procedure (lambda (rel) ...) that builds the URL of
  the asset rel under dir, as served at base-url, with ?v=<modification
  time> appended. The version changes whenever the file does, so pages can
  let browsers cache assets for good (make-static-handler does) and still
  never run a stale copy. The file is checked on every call, so edits need
  no restart; a missing file gets no version.
Example:
  (define static-url (make-static-url \"static\" \"/app/static\"))
  (static-url \"site.css\") => \"/app/static/site.css?v=1761290000000\""
      (let ((base (let loop ((b base-url))
                    (if (and (> (string-length b) 0)
                             (char=? (string-ref b (- (string-length b) 1)) #\/))
                        (loop (substring b 0 (- (string-length b) 1)))
                        b))))
        (lambda (rel)
          (let ((full (string-append dir "/" rel)))
            (string-append base "/" rel
                           (if (and (file-exists? full) (not (directory-exists? full)))
                               (string-append "?v=" (number->string
                                                     (file-modification-timestamp full)))
                               ""))))))
))
