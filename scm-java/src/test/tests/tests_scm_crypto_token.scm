(import (scheme base) (scheme char) (scm crypto) (scm crypto token) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-crypto-token")

(define key (random-bytes 32))
(define key-b64 (base64-encode key))
(define other (random-bytes 32))

(define (url-safe? s)
  (let loop ((i 0))
    (or (= i (string-length s))
        (let ((c (string-ref s i)))
          (and (or (char-alphabetic? c) (char-numeric? c) (memv c '(#\- #\_ #\.)))
               (loop (+ i 1)))))))

;; Replace the character at i with one that differs from it.
(define (flip s i)
  (let ((c (string-ref s i)))
    (string-append (substring s 0 i)
                   (string (if (char=? c #\A) #\B #\A))
                   (substring s (+ i 1) (string-length s)))))

(test-group "round trip"
  (let ((datum '((uid . 42) (name . "Zoë") (roles "admin" "user"))))
    (test-equal datum (token-verify key (token-sign key datum 60)))
    (test-equal datum (token-verify key-b64 (token-sign key-b64 datum 60)))
    (test-equal "string" (token-verify key (token-sign key "string" 60)))
    (test-equal 7 (token-verify key (token-sign key 7 #f))))
  (test-assert "url-safe" (url-safe? (token-sign key (make-string 100 #\?) 60))))

(test-group "rejected tokens"
  (let ((tok (token-sign key '((uid . 1)) 60)))
    (test-equal #f (token-verify other tok))
    (test-equal #f (token-verify key (flip tok 3)))
    (test-equal #f (token-verify key (flip tok (- (string-length tok) 2))))
    (test-equal #f (token-verify key (substring tok 0 (- (string-length tok) 1))))
    (test-equal #f (token-verify key (string-append tok "x")))
    (test-equal #f (token-verify key ""))
    (test-equal #f (token-verify key "."))
    (test-equal #f (token-verify key "no-dot"))
    (test-equal #f (token-verify key "a.b.c"))
    (test-equal #f (token-verify key "!!!.***"))
    (test-equal #f (token-verify key #f))
    (test-equal #f (token-verify key 42))))

(test-group "expiry"
  (test-equal #f (token-verify key (token-sign key 'x -1)))
  (test-equal #f (token-verify key (token-sign key 'x 0)))
  (test-equal 'x (token-verify key (token-sign key 'x 3600))))

(test-group "purpose"
  (let ((tok (token-sign key 'x 60 '((purpose . "session")))))
    (test-equal 'x (token-verify key tok '((purpose . "session"))))
    (test-equal #f (token-verify key tok '((purpose . "reset"))))
    (test-equal #f (token-verify key tok))))

(test-group "key rotation"
  (let ((old-tok (token-sign other 'x 60))
        (new-tok (token-sign (list key other) 'y 60)))
    (test-equal 'x (token-verify (list key other) old-tok))
    (test-equal 'y (token-verify key new-tok))
    (test-equal #f (token-verify other new-tok))))

(test-group "token-secrets"
  (test-equal (list key) (token-secrets key))
  (test-equal (list key) (token-secrets key-b64))
  (test-equal (list key other) (token-secrets (list key other)))
  (test-error (token-secrets "REPLACE_WITH_BASE64_SECRET"))
  (test-error (token-secrets (random-bytes 8)))
  (test-error (token-secrets '()))
  (test-error (token-secrets 42))
  (test-error (token-sign "short" 'x 60)))

(test-end "scm-crypto-token")
