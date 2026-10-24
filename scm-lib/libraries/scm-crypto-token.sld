(define-library (scm crypto token)
  (import (scm core)
          (scheme base)
          (scheme read)
          (scheme write)
          (scheme time)
          (scm crypto))
  (export token-sign
          token-verify
          token-secrets)
  (begin

    ;; Token = <payload>.<mac>, both URL-safe base64 without padding:
    ;;
    ;;   payload = utf8 (write (expiry . datum)), expiry = epoch seconds | #f
    ;;   mac     = HMAC-SHA256(key, utf8 purpose ++ "\n" ++ payload-bytes)
    ;;
    ;; The MAC is checked (constant-time) before the payload is read, so
    ;; bytes from a client never reach the reader unless we signed them.

    (define min-secret-bytes 16)

    ;; --- URL-safe base64 -------------------------------------------------

    (define (b64url-encode bv)
      (let* ((s (base64-encode bv))
             (end (let loop ((n (string-length s)))
                    (if (and (> n 0) (char=? (string-ref s (- n 1)) #\=))
                        (loop (- n 1))
                        n))))
        (string-map (lambda (c)
                      (case c ((#\+) #\-) ((#\/) #\_) (else c)))
                    (substring s 0 end))))

    (define (b64url-char? c)
      (or (char<=? #\A c #\Z) (char<=? #\a c #\z) (char<=? #\0 c #\9)
          (char=? c #\-) (char=? c #\_)))

    ;; #f unless s is well-formed URL-safe base64 (no padding).
    (define (b64url-decode s)
      (let ((n (string-length s)))
        (and (> n 0)
             (not (= (modulo n 4) 1))
             (let loop ((i 0))
               (or (= i n) (and (b64url-char? (string-ref s i)) (loop (+ i 1)))))
             (base64-decode
              (string-append
               (string-map (lambda (c)
                             (case c ((#\-) #\+) ((#\_) #\/) (else c)))
                           s)
               (make-string (modulo (- 4 (modulo n 4)) 4) #\=))))))

    ;; --- secrets --------------------------------------------------------

    (define (secret->bytes s)
      (let ((bv (cond
                  ((bytevector? s) s)
                  ((string? s)
                   (guard (e (#t (error "token: secret is not valid base64" s)))
                     (base64-decode s)))
                  (else (error "token: secret must be a bytevector or base64 string" s)))))
        (when (< (bytevector-length bv) min-secret-bytes)
          (error "token: secret must be at least 16 bytes"))
        bv))

    (define (token-secrets secret)
      "Syntax: (token-secrets secret)
Library: (scm crypto token)
Description: Normalises secret to a non-empty list of key bytevectors.
  secret is a bytevector, a base64 string, or a list of those (newest
  first, for key rotation). Raises an error for an empty list, invalid
  base64 or a key shorter than 16 bytes, so a bad configuration fails at
  startup rather than on the first request. token-sign and token-verify
  call it themselves; call it once at startup to validate a config value.
Example:
  (token-secrets (base64-encode (random-bytes 32))) => (#u8(...))"
      (cond
        ((null? secret) (error "token: no secret given"))
        ((pair? secret) (map secret->bytes secret))
        (else (list (secret->bytes secret)))))

    ;; --- sign / verify --------------------------------------------------

    (define (opt-ref opts key default)
      (let ((p (and (pair? opts) (assq key (car opts)))))
        (if p (cdr p) default)))

    (define (now) (exact (floor (current-second))))

    (define (mac key purpose payload)
      (hmac-sha256 key (bytevector-append (string->utf8 purpose)
                                          (bytevector 10)
                                          payload)))

    (define (token-sign secret datum max-age . opts)
      "Syntax: (token-sign secret datum max-age [opts])
Library: (scm crypto token)
Description: Returns a signed, URL-safe token carrying datum, which must
  survive write/read (strings, numbers, symbols, booleans and lists of
  them; e.g. an alist) and must not be #f, which token-verify returns for
  a rejected token. max-age is the lifetime in seconds, or #f for no
  expiry. secret is as for token-secrets; the first key signs. opts is an
  alist: (purpose . string) binds the token to one use (default \"\"), so
  token-verify with another purpose rejects it. The datum is signed, not
  encrypted: anyone holding the token can read it.
Example:
  (token-sign key '((uid . 42)) 3600 '((purpose . \"session\")))
  => \"KDE3NjE...\""
      (let* ((key (car (token-secrets secret)))
             (expiry (and max-age (+ (now) max-age)))
             (payload (string->utf8
                       (let ((p (open-output-string)))
                         (write (cons expiry datum) p)
                         (get-output-string p)))))
        (string-append (b64url-encode payload) "."
                       (b64url-encode (mac key (opt-ref opts 'purpose "") payload)))))

    (define (read-only-datum s)
      (let* ((p (open-input-string s))
             (d (read p)))
        (and (not (eof-object? d))
             (eof-object? (read p))
             d)))

    (define (token-verify secret token . opts)
      "Syntax: (token-verify secret token [opts])
Library: (scm crypto token)
Description: Returns the datum of token if it was made by token-sign with
  one of the keys in secret and the same purpose, and has not expired;
  otherwise #f. Never raises for a bad token (tampered, truncated, expired,
  wrong purpose, or not a token at all). opts as for token-sign.
Example:
  (token-verify key tok '((purpose . \"session\"))) => ((uid . 42))
  (token-verify key \"garbage\") => #f"
      (let ((keys (token-secrets secret))
            (purpose (opt-ref opts 'purpose "")))
        (and (string? token)
             (guard (e (#t #f))
               (let ((dot (let loop ((i 0))
                            (cond ((= i (string-length token)) #f)
                                  ((char=? (string-ref token i) #\.) i)
                                  (else (loop (+ i 1)))))))
                 (and dot
                      (let ((payload (b64url-decode (substring token 0 dot)))
                            (got (b64url-decode
                                  (substring token (+ dot 1) (string-length token)))))
                        (and payload got
                             (let loop ((ks keys))
                               (cond
                                 ((null? ks) #f)
                                 ((constant-time-bytevector=? (mac (car ks) purpose payload) got)
                                  (let ((d (read-only-datum (utf8->string payload))))
                                    (and (pair? d)
                                         (or (not (car d))
                                             (and (exact-integer? (car d))
                                                  (> (car d) (now))))
                                         (cdr d))))
                                 (else (loop (cdr ks)))))))))))))
))
