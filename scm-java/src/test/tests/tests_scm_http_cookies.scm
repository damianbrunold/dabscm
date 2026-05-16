(import (scheme base) (scm net http cookies) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-cookies")

(test-group "parse-cookie-header"
  (test-equal '() (parse-cookie-header ""))
  (test-equal '() (parse-cookie-header #f))
  (test-equal '(("sid" . "abc")) (parse-cookie-header "sid=abc"))
  (test-equal '(("sid" . "abc") ("pref" . "dark"))
              (parse-cookie-header "sid=abc; pref=dark"))
  ;; whitespace around the whole '; '-separated entry is trimmed, but
  ;; whitespace around the '=' is preserved (matches the verbatim
  ;; dabsite behavior; servers may send extra padding that callers can
  ;; trim if they care)
  (test-equal '(("a " . " 1") ("b" . "2"))
              (parse-cookie-header "  a = 1  ;  b=2 "))
  ;; cookie values are kept verbatim (no percent-decoding)
  (test-equal '(("sig" . "a%2Fb"))
              (parse-cookie-header "sig=a%2Fb"))
  ;; entries without '=' are skipped
  (test-equal '(("a" . "1"))
              (parse-cookie-header "a=1; bare")))

(test-group "cookie-ref"
  (define c '(("sid" . "abc") ("pref" . "dark")))
  (test-equal "abc" (cookie-ref c "sid"))
  (test-equal #f    (cookie-ref c "missing")))

(test-group "format-set-cookie"
  (test-equal "sid=abc; Path=/; Max-Age=3600; HttpOnly; SameSite=Strict; Secure"
              (format-set-cookie "sid" "abc" 3600 "/"))
  ;; max-age=#f → no Max-Age attribute (session cookie)
  (test-equal "sid=abc; Path=/; HttpOnly; SameSite=Strict; Secure"
              (format-set-cookie "sid" "abc" #f "/"))
  ;; no-secure flag drops the Secure attribute (for local-HTTP dev)
  (test-equal "sid=abc; Path=/; Max-Age=60; HttpOnly; SameSite=Strict"
              (format-set-cookie "sid" "abc" 60 "/" 'no-secure)))

(test-end "scm-http-cookies")
