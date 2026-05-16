(import (scheme base) (scm uri) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-uri")

(test-group "percent-encode"
  (test-equal "" (percent-encode ""))
  (test-equal "hello" (percent-encode "hello"))
  (test-equal "a%20b" (percent-encode "a b"))
  (test-equal "a%2Fb" (percent-encode "a/b"))
  (test-equal "a%2Bb" (percent-encode "a+b"))
  (test-equal "a%26b%3Dc" (percent-encode "a&b=c"))
  ;; unreserved set stays literal
  (test-equal "AZaz09-_.~" (percent-encode "AZaz09-_.~"))
  ;; non-ASCII gets UTF-8-encoded then percent-escaped
  (test-equal "%C3%A4" (percent-encode "ä")))

(test-group "percent-decode"
  (test-equal "" (percent-decode ""))
  (test-equal "a b" (percent-decode "a%20b"))
  (test-equal "a/b" (percent-decode "a%2Fb"))
  ;; '+' is treated as space by default (form-urlencoded)
  (test-equal "a b" (percent-decode "a+b"))
  (test-equal "a+b" (percent-decode "a+b" #f))
  ;; lowercase hex is also accepted
  (test-equal "a/b" (percent-decode "a%2fb"))
  (test-equal "ä" (percent-decode "%C3%A4"))
  ;; malformed % at end is passed through literally
  (test-equal "a%" (percent-decode "a%")))

(test-group "percent-roundtrip"
  (test-equal "hello world" (percent-decode (percent-encode "hello world")))
  (test-equal "a/b?c=d&e=f"
              (percent-decode (percent-encode "a/b?c=d&e=f")))
  (test-equal "Grüße" (percent-decode (percent-encode "Grüße"))))

(test-end "scm-uri")
