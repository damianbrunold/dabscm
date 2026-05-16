(define-library (scm net http cookies)
  (import (scm core) (scheme base) (srfi 13))
  (export parse-cookie-header
          cookie-ref
          format-set-cookie)
  (begin

    (define (split-on-char s ch)
      (let* ((n (string-length s))
             (acc '()))
        (let loop ((i 0) (start 0))
          (cond
            ((= i n)
             (reverse (cons (substring s start n) acc)))
            ((char=? (string-ref s i) ch)
             (let ((part (substring s start i)))
               (set! acc (cons part acc))
               (loop (+ i 1) (+ i 1))))
            (else (loop (+ i 1) start))))))

    (define (parse-cookie-header header)
      "Syntax: (parse-cookie-header header)
Library: (scm net http cookies)
Description: Parses an HTTP Cookie header value into an alist. Whitespace
  around names and values is trimmed. Values are NOT percent-decoded — the
  caller decides, because many cookie values are opaque tokens (base64,
  hex, signed blobs). #f or empty → '().
Example:
  (parse-cookie-header \"sid=abc; pref=dark\")
  => ((\"sid\" . \"abc\") (\"pref\" . \"dark\"))"
      (cond
        ((or (not header) (string=? header "")) '())
        (else
         (let ((parts (split-on-char header #\;)))
           (let loop ((ps parts) (acc '()))
             (cond
               ((null? ps) (reverse acc))
               (else
                (let* ((raw (car ps))
                       (s   (string-trim-both raw))
                       (eq-idx (string-index s #\=)))
                  (cond
                    (eq-idx
                     (loop (cdr ps)
                           (cons (cons (substring s 0 eq-idx)
                                       (substring s (+ eq-idx 1)
                                                  (string-length s)))
                                 acc)))
                    (else (loop (cdr ps) acc)))))))))))

    (define (cookie-ref cookies name)
      "Syntax: (cookie-ref cookies name)
Library: (scm net http cookies)
Description: Returns the value of the named cookie in cookies (an alist from
  parse-cookie-header), or #f if missing.
Example:
  (cookie-ref '((\"sid\" . \"abc\")) \"sid\") => \"abc\""
      (let ((p (assoc name cookies)))
        (if p (cdr p) #f)))

    (define (format-set-cookie name value max-age path . opt)
      "Syntax: (format-set-cookie name value max-age path [flag ...])
Library: (scm net http cookies)
Description: Builds a Set-Cookie header value. HttpOnly and SameSite=Strict
  are always emitted. The Secure attribute is added unless 'no-secure' is
  present in flags; this default is right for production but should be
  disabled for local HTTP development. max-age may be #f to omit the
  Max-Age attribute (session cookie).
Example:
  (format-set-cookie \"sid\" \"abc\" 3600 \"/\")
  => \"sid=abc; Path=/; Max-Age=3600; HttpOnly; SameSite=Strict; Secure\"
  (format-set-cookie \"sid\" \"abc\" #f \"/\" 'no-secure)
  => \"sid=abc; Path=/; HttpOnly; SameSite=Strict\""
      (let ((out (open-output-string)))
        (write-string name out)
        (write-char #\= out)
        (write-string value out)
        (write-string "; Path=" out)
        (write-string path out)
        (when max-age
          (write-string "; Max-Age=" out)
          (write-string (number->string max-age) out))
        (write-string "; HttpOnly; SameSite=Strict" out)
        (when (not (memv 'no-secure opt))
          (write-string "; Secure" out))
        (get-output-string out)))
))
