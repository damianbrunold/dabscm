(define-library (scm net http multipart)
  (import (scm core)
          (scheme base)
          (scheme write)
          (srfi 1)
          (srfi 13))
  (export multipart-boundary
          parse-multipart
          parse-multipart-bytes
          part-ref)
  (begin

    ;; multipart/form-data parser (RFC 7578).
    ;;
    ;; Two entry points:
    ;;   parse-multipart        — input is a string in which each character
    ;;                            corresponds to one byte (i.e. the HTTP
    ;;                            server delivered the body undecoded).
    ;;   parse-multipart-bytes  — input is a bytevector. Use this when the
    ;;                            body may contain binary attachments
    ;;                            (images, PDFs, ...), so they survive
    ;;                            unmolested.
    ;;
    ;; Each returned part is an alist with keys 'name, 'filename,
    ;; 'content-type, 'body. For parse-multipart-bytes the body is a
    ;; (sub-)bytevector; for parse-multipart it is a string.

    (define (assoc-val alist key)
      (let ((p (assoc key alist)))
        (cond (p (cdr p)) (else #f))))

    (define (unquote-param s)
      (let ((n (string-length s)))
        (cond
          ((and (>= n 2)
                (char=? (string-ref s 0) #\")
                (char=? (string-ref s (- n 1)) #\"))
           (substring s 1 (- n 1)))
          (else s))))

    (define (find-substring haystack needle start)
      ;; Allocation-free char-by-char scan. Returns start index of
      ;; needle, or #f. Using (substring haystack i j) per position
      ;; would make parsing megabyte-scale uploads quadratic.
      (let* ((hn (string-length haystack))
             (nn (string-length needle))
             (limit (- hn nn))
             (n0 (cond ((= nn 0) #\space)
                       (else (string-ref needle 0)))))
        (cond
          ((= nn 0) start)
          (else
           (let outer ((i start))
             (cond
               ((> i limit) #f)
               ((not (char=? (string-ref haystack i) n0))
                (outer (+ i 1)))
               (else
                (let inner ((j 1))
                  (cond
                    ((= j nn) i)
                    ((char=? (string-ref haystack (+ i j))
                             (string-ref needle j))
                     (inner (+ j 1)))
                    (else (outer (+ i 1))))))))))))

    (define (multipart-boundary ct)
      "Syntax: (multipart-boundary content-type)
Library: (scm net http multipart)
Description: Extracts the boundary= parameter from a Content-Type header
  value. Returns the boundary string (without surrounding quotes), or #f
  if content-type is not multipart/form-data or has no boundary.
Example:
  (multipart-boundary \"multipart/form-data; boundary=abc123\") => \"abc123\"
  (multipart-boundary \"text/plain\") => #f"
      (cond
        ((not (string? ct)) #f)
        ((not (string-contains (string-downcase ct) "multipart/form-data")) #f)
        (else
         (let ((idx (string-contains (string-downcase ct) "boundary=")))
           (cond
             ((not idx) #f)
             (else
              (let* ((start   (+ idx (string-length "boundary=")))
                     (rest    (substring ct start (string-length ct)))
                     (trimmed (string-trim-both rest)))
                (cond
                  ((and (> (string-length trimmed) 0)
                        (char=? (string-ref trimmed 0) #\"))
                   (let ((close (string-index trimmed #\" 1)))
                     (cond
                       (close (substring trimmed 1 close))
                       (else  #f))))
                  (else
                   (let ((semi (string-index trimmed #\;)))
                     (string-trim-both
                       (substring trimmed 0
                                  (or semi (string-length trimmed))))))))))))))

    (define (parse-content-disposition v)
      (let loop ((s v) (name #f) (filename #f))
        (cond
          ((string=? s "") (values (or name "") filename))
          (else
           (let* ((semi  (string-index s #\;))
                  (piece (cond (semi (string-trim-both (substring s 0 semi)))
                               (else (string-trim-both s))))
                  (rest  (cond (semi (substring s (+ semi 1)
                                                (string-length s)))
                               (else ""))))
             (cond
               ((string-prefix? "name=" piece)
                (loop rest
                      (unquote-param
                        (substring piece 5 (string-length piece)))
                      filename))
               ((string-prefix? "filename=" piece)
                (loop rest name
                      (unquote-param
                        (substring piece 9 (string-length piece)))))
               (else (loop rest name filename))))))))

    (define (parse-part-headers section)
      (let loop ((rest section) (acc '()))
        (cond
          ((string=? rest "") (reverse acc))
          (else
           (let ((nl (find-substring rest "\r\n" 0)))
             (let* ((line (cond (nl (substring rest 0 nl)) (else rest)))
                    (next (cond (nl (substring rest (+ nl 2)
                                              (string-length rest)))
                                (else ""))))
               (let ((colon (string-index line #\:)))
                 (cond
                   ((not colon) (loop next acc))
                   (else
                    (let ((k (string-downcase
                              (string-trim-both
                                (substring line 0 colon))))
                          (v (string-trim-both
                              (substring line (+ colon 1)
                                         (string-length line)))))
                      (loop next (cons (cons k v) acc))))))))))))

    (define (parse-multipart body boundary)
      "Syntax: (parse-multipart body boundary)
Library: (scm net http multipart)
Description: Parses a multipart/form-data body (passed as a byte-per-char
  string) with the given boundary string. Returns a list of part alists,
  each with keys 'name, 'filename (or #f), 'content-type (or #f), 'body.
  Use parse-multipart-bytes when handling binary uploads.
Example:
  (parse-multipart body (multipart-boundary (http-request-header req \"Content-Type\")))"
      (cond
        ((or (not (string? body)) (not (string? boundary))
             (string=? boundary ""))
         '())
        (else
         (let* ((delim       (string-append "--" boundary))
                (delim-crlf  (string-append "\r\n" delim))
                (first (find-substring body delim 0)))
           (cond
             ((not first) '())
             (else
              (let loop ((pos (+ first (string-length delim)))
                         (parts '()))
                (cond
                  ((and (>= (- (string-length body) pos) 2)
                        (string=? (substring body pos (+ pos 2)) "--"))
                   (reverse parts))
                  ((and (>= (- (string-length body) pos) 2)
                        (string=? (substring body pos (+ pos 2)) "\r\n"))
                   (let* ((hdr-start (+ pos 2))
                          (hdr-end (find-substring body "\r\n\r\n" hdr-start)))
                     (cond
                       ((not hdr-end) (reverse parts))
                       (else
                        (let* ((body-start (+ hdr-end 4))
                               (next (find-substring body delim-crlf
                                                     body-start)))
                          (cond
                            ((not next) (reverse parts))
                            (else
                             (let* ((part-body
                                      (substring body body-start next))
                                    (headers
                                      (parse-part-headers
                                        (substring body hdr-start hdr-end)))
                                    (cd (or (assoc-val headers
                                                       "content-disposition")
                                            ""))
                                    (ct (assoc-val headers
                                                   "content-type")))
                               (call-with-values
                                 (lambda () (parse-content-disposition cd))
                                 (lambda (name filename)
                                   (loop (+ next (string-length delim-crlf))
                                         (cons
                                           (list (cons 'name name)
                                                 (cons 'filename filename)
                                                 (cons 'content-type ct)
                                                 (cons 'body part-body))
                                           parts))))))))))))
                  (else (reverse parts))))))))))

    (define (part-ref part key)
      "Syntax: (part-ref part key)
Library: (scm net http multipart)
Description: Returns the value of key ('name, 'filename, 'content-type, 'body)
  in a part alist, or #f if missing.
Example:
  (part-ref p 'name) => \"avatar\"
  (part-ref p 'filename) => \"face.png\""
      (let ((p (assq key part)))
        (cond (p (cdr p)) (else #f))))

    ;; ============================================================
    ;; Bytevector-based parser.
    ;; ============================================================

    (define (string->ascii-bytevector s)
      (let* ((n (string-length s))
             (bv (make-bytevector n)))
        (let loop ((i 0))
          (cond
            ((= i n) bv)
            (else
             (bytevector-u8-set! bv i (char->integer (string-ref s i)))
             (loop (+ i 1)))))))

    (define (bv-find bv needle start)
      (let* ((hn (bytevector-length bv))
             (nn (bytevector-length needle))
             (limit (- hn nn)))
        (cond
          ((= nn 0) start)
          (else
           (let outer ((i start))
             (cond
               ((> i limit) #f)
               ((not (= (bytevector-u8-ref bv i)
                        (bytevector-u8-ref needle 0)))
                (outer (+ i 1)))
               (else
                (let inner ((j 1))
                  (cond
                    ((= j nn) i)
                    ((= (bytevector-u8-ref bv (+ i j))
                        (bytevector-u8-ref needle j))
                     (inner (+ j 1)))
                    (else (outer (+ i 1))))))))))))

    (define (bv-subcopy bv start end)
      (let* ((n (- end start))
             (out (make-bytevector n)))
        (bytevector-copy! out 0 bv start end)
        out))

    (define (bv->string-ascii bv)
      (let* ((n (bytevector-length bv))
             (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((= i n) (get-output-string out))
            (else
             (write-char (integer->char (bytevector-u8-ref bv i)) out)
             (loop (+ i 1)))))))

    (define (parse-multipart-bytes body boundary)
      "Syntax: (parse-multipart-bytes body boundary)
Library: (scm net http multipart)
Description: Like parse-multipart but operates on a bytevector body. Part
  bodies in the result are bytevectors (subcopies of the input), so binary
  uploads (images, PDFs, ...) round-trip exactly.
Example:
  (parse-multipart-bytes (http-request-body-bytes req)
                         (multipart-boundary
                           (http-request-header req \"Content-Type\")))"
      (cond
        ((or (not (bytevector? body)) (not (string? boundary))
             (string=? boundary ""))
         '())
        (else
         (let* ((delim       (string->ascii-bytevector
                               (string-append "--" boundary)))
                (delim-crlf  (string->ascii-bytevector
                               (string-append "\r\n--" boundary)))
                (hdr-end-bv  (string->ascii-bytevector "\r\n\r\n"))
                (first (bv-find body delim 0)))
           (cond
             ((not first) '())
             (else
              (let loop ((pos (+ first (bytevector-length delim)))
                         (parts '()))
                (let ((n (bytevector-length body)))
                  (cond
                    ((and (>= (- n pos) 2)
                          (= (bytevector-u8-ref body pos)       (char->integer #\-))
                          (= (bytevector-u8-ref body (+ pos 1)) (char->integer #\-)))
                     (reverse parts))
                    ((and (>= (- n pos) 2)
                          (= (bytevector-u8-ref body pos)       (char->integer #\return))
                          (= (bytevector-u8-ref body (+ pos 1)) (char->integer #\newline)))
                     (let* ((hdr-start (+ pos 2))
                            (hdr-end (bv-find body hdr-end-bv hdr-start)))
                       (cond
                         ((not hdr-end) (reverse parts))
                         (else
                          (let* ((body-start (+ hdr-end 4))
                                 (next (bv-find body delim-crlf body-start)))
                            (cond
                              ((not next) (reverse parts))
                              (else
                               (let* ((part-body (bv-subcopy body body-start next))
                                      (hdrs-str (bv->string-ascii
                                                  (bv-subcopy body hdr-start hdr-end)))
                                      (headers (parse-part-headers hdrs-str))
                                      (cd (or (assoc-val headers
                                                         "content-disposition")
                                              ""))
                                      (ct (assoc-val headers "content-type")))
                                 (call-with-values
                                   (lambda () (parse-content-disposition cd))
                                   (lambda (name filename)
                                     (loop (+ next (bytevector-length delim-crlf))
                                           (cons
                                             (list (cons 'name name)
                                                   (cons 'filename filename)
                                                   (cons 'content-type ct)
                                                   (cons 'body part-body))
                                             parts))))))))))))
                    (else (reverse parts)))))))))))
))
