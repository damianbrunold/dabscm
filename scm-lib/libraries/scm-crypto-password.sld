(define-library (scm crypto password)
  (import (scm core)
          (scheme base)
          (scm string)
          (scm crypto))
  (export password-hash
          password-verify
          password-needs-rehash?
          password-pbkdf2-iterations)
  (begin

    ;; Stored form of new hashes (self-describing, so the cost can be
    ;; raised later without breaking existing entries):
    ;;
    ;;   pbkdf2$<iterations>$<salt-base64>$<hash-base64>
    ;;
    ;; Also verified (never written), so users imported from a Flask /
    ;; Werkzeug app keep their passwords:
    ;;
    ;;   pbkdf2:sha256:<iterations>$<salt>$<hex-hash>
    ;;   scrypt:<n>:<r>:<p>$<salt>$<hex-hash>
    ;;
    ;; where the Werkzeug salt is a plain ASCII string used as its bytes.

    (define salt-bytes 16)
    (define key-bytes 32)

    (define password-pbkdf2-iterations
      (make-parameter 600000))

    (define (password-hash plain)
      "Syntax: (password-hash plain)
Library: (scm crypto password)
Description: Hashes the password string plain with PBKDF2-HMAC-SHA256, a
  fresh 16-byte random salt and (password-pbkdf2-iterations) iterations
  (default 600000). Returns the self-describing string
  pbkdf2$<iterations>$<salt-base64>$<hash-base64>; store it as is and
  check it with password-verify.
Example:
  (password-hash \"correct horse\") => \"pbkdf2$600000$3HBY...$j+N/...\""
      (let* ((iterations (password-pbkdf2-iterations))
             (salt (random-bytes salt-bytes))
             (dk (pbkdf2-sha256 (string->utf8 plain) salt iterations key-bytes)))
        (string-append "pbkdf2$" (number->string iterations) "$"
                       (base64-encode salt) "$" (base64-encode dk))))

    ;; --- parsing: each returns the matcher's arguments, or #f ---

    (define (positive-integer s)
      (let ((n (string->number s)))
        (and n (exact-integer? n) (> n 0) n)))

    ;; native: (iterations salt digest)
    (define (parse-native parts)
      (and (= 4 (length parts))
           (string=? (car parts) "pbkdf2")
           (let ((iterations (positive-integer (list-ref parts 1))))
             (and iterations
                  (list iterations
                        (base64-decode (list-ref parts 2))
                        (base64-decode (list-ref parts 3)))))))

    ;; Werkzeug pbkdf2: (iterations salt digest)
    (define (parse-werkzeug-pbkdf2 parts)
      (and (= 3 (length parts))
           (let ((method (string-split-char (car parts) #\:)))
             (and (= 3 (length method))
                  (string=? (car method) "pbkdf2")
                  (string=? (cadr method) "sha256")
                  (let ((iterations (positive-integer (list-ref method 2))))
                    (and iterations
                         (list iterations
                               (string->utf8 (list-ref parts 1))
                               (hex->bytevector (list-ref parts 2)))))))))

    ;; Werkzeug scrypt: (n r p salt digest)
    (define (parse-werkzeug-scrypt parts)
      (and (= 3 (length parts))
           (let ((method (string-split-char (car parts) #\:)))
             (and (= 4 (length method))
                  (string=? (car method) "scrypt")
                  (let ((n (positive-integer (list-ref method 1)))
                        (r (positive-integer (list-ref method 2)))
                        (p (positive-integer (list-ref method 3))))
                    (and n r p
                         (list n r p
                               (string->utf8 (list-ref parts 1))
                               (hex->bytevector (list-ref parts 2)))))))))

    (define (pbkdf2-matches? plain iterations salt digest)
      (and (> (bytevector-length digest) 0)
           (constant-time-bytevector=?
            (pbkdf2-sha256 (string->utf8 plain) salt iterations
                           (bytevector-length digest))
            digest)))

    (define (scrypt-matches? plain n r p salt digest)
      (and (> (bytevector-length digest) 0)
           (constant-time-bytevector=?
            (scrypt (string->utf8 plain) salt n r p (bytevector-length digest))
            digest)))

    ;; Spends the cost of one real verification, so a login for an
    ;; unknown user takes as long as one with a wrong password.
    (define (dummy-work plain)
      (pbkdf2-sha256 (string->utf8 (if (string? plain) plain ""))
                     (make-bytevector salt-bytes 0)
                     (password-pbkdf2-iterations) key-bytes)
      #f)

    (define (password-verify plain stored)
      "Syntax: (password-verify plain stored)
Library: (scm crypto password)
Description: Returns #t if the password string plain matches stored, else
  #f. stored may be a hash from password-hash or a Werkzeug
  pbkdf2:sha256:<iterations>$... or scrypt:<n>:<r>:<p>$... hash. The
  comparison is constant-time, and a malformed stored value yields #f
  rather than an error. Pass #f as stored for an unknown user: the call
  then does the work of a real check and returns #f, so response times
  do not reveal which usernames exist.
Example:
  (password-verify \"correct horse\" (password-hash \"correct horse\")) => #t
  (password-verify \"guess\" #f) => #f"
      (cond
        ((not (and (string? plain) (string? stored))) (dummy-work plain))
        (else
         (guard (e (#t #f))
           (let* ((parts (string-split-char stored #\$))
                  (native (parse-native parts)))
             (cond
               (native (apply pbkdf2-matches? plain native))
               ((parse-werkzeug-pbkdf2 parts)
                => (lambda (w) (apply pbkdf2-matches? plain w)))
               ((parse-werkzeug-scrypt parts)
                => (lambda (w) (apply scrypt-matches? plain w)))
               (else (dummy-work plain))))))))

    (define (password-needs-rehash? stored)
      "Syntax: (password-needs-rehash? stored)
Library: (scm crypto password)
Description: Returns #t unless stored is a password-hash string with at
  least (password-pbkdf2-iterations) iterations. After a successful
  password-verify, store (password-hash plain) when this is #t: that
  upgrades Werkzeug hashes and hashes made with a lower cost.
Example:
  (password-needs-rehash? (password-hash \"pw\")) => #f
  (password-needs-rehash? \"pbkdf2$200000$c2FsdA==$aGFzaA==\") => #t"
      (not (and (string? stored)
                (guard (e (#t #f))
                  (let ((native (parse-native (string-split-char stored #\$))))
                    (and native
                         (>= (car native) (password-pbkdf2-iterations))))))))
))
