(import (scheme base) (scm datetime) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-datetime")

(test-group "parse-iso8601"
  (test-equal 0 (parse-iso8601 "1970-01-01T00:00:00Z"))
  ;; 2024-05-16T12:34:56Z is 1715862896 unix
  (test-equal 1715862896 (parse-iso8601 "2024-05-16T12:34:56Z"))
  ;; same moment in +02:00 is 14:34:56
  (test-equal 1715862896 (parse-iso8601 "2024-05-16T14:34:56+02:00"))
  ;; date-only (UTC midnight)
  (test-equal 1715817600 (parse-iso8601 "2024-05-16"))
  ;; space separator instead of T
  (test-equal 1715862896 (parse-iso8601 "2024-05-16 12:34:56Z"))
  ;; surrounding whitespace
  (test-equal 1715862896 (parse-iso8601 "  2024-05-16T12:34:56Z  "))
  (test-equal #f (parse-iso8601 ""))
  (test-equal #f (parse-iso8601 "bogus"))
  (test-equal #f (parse-iso8601 "2024/05/16")))

(test-group "parse-rfc822"
  ;; pubdate from sample.rss
  (test-equal 1715855696 (parse-rfc822 "Thu, 16 May 2024 12:34:56 +0200"))
  ;; same moment, UTC
  (test-equal 1715862896 (parse-rfc822 "Thu, 16 May 2024 12:34:56 GMT"))
  ;; without day-of-week prefix
  (test-equal 1715862896 (parse-rfc822 "16 May 2024 12:34:56 GMT"))
  ;; 2-digit year is mapped to 20XX
  (test-equal 1715862896 (parse-rfc822 "Thu, 16 May 24 12:34:56 GMT"))
  ;; legacy zone EST = UTC-5h
  (test-equal 1715862896 (parse-rfc822 "Thu, 16 May 2024 07:34:56 EST"))
  (test-equal #f (parse-rfc822 ""))
  (test-equal #f (parse-rfc822 "Thu, 16 May")))

(test-group "parse-pubdate"
  ;; ISO-shaped input goes to parse-iso8601 first
  (test-equal 1715862896 (parse-pubdate "2024-05-16T12:34:56Z"))
  ;; non-ISO goes to parse-rfc822
  (test-equal 1715862896 (parse-pubdate "Thu, 16 May 2024 12:34:56 GMT"))
  (test-equal #f (parse-pubdate ""))
  (test-equal #f (parse-pubdate #f)))

(test-group "format-iso8601"
  (test-equal "1970-01-01T00:00:00Z" (format-iso8601 0))
  (test-equal "2024-05-16T12:34:56Z" (format-iso8601 1715862896))
  (test-equal "2024-05-16T00:00:00Z" (format-iso8601 1715817600)))

(test-group "iso-roundtrip"
  (test-equal 1715862896
              (parse-iso8601 (format-iso8601 1715862896)))
  ;; rfc822 → iso → unix → iso
  (test-equal "2024-05-16T12:34:56Z"
              (format-iso8601
                (parse-rfc822 "Thu, 16 May 2024 12:34:56 GMT"))))

(test-group "today"
  (let ((iso (today)))
    (test-assert (string? iso))
    (test-equal 10 (string-length iso))
    (test-equal #\- (string-ref iso 4))
    (test-equal #\- (string-ref iso 7)))
  (let ((short (today 'short)))
    (test-equal 8 (string-length short)))
  (let ((dmy (today 'dmy)))
    (test-equal 10 (string-length dmy))
    (test-equal #\. (string-ref dmy 2))
    (test-equal #\. (string-ref dmy 5))))

(test-group "now"
  (let ((iso (now)))
    (test-assert (string? iso))
    (test-equal 16 (string-length iso))
    (test-equal #\space (string-ref iso 10))
    (test-equal #\: (string-ref iso 13)))
  (let ((short (now 'short)))
    (test-equal 13 (string-length short))
    (test-equal #\- (string-ref short 8)))
  (let ((dmyhm (now 'dmyhm)))
    (test-equal 16 (string-length dmyhm))
    (test-equal #\. (string-ref dmyhm 2))
    (test-equal #\space (string-ref dmyhm 10))
    (test-equal #\: (string-ref dmyhm 13))))

(test-group "time"
  (let ((iso (time)))
    (test-assert (string? iso))
    (test-equal 5 (string-length iso))
    (test-equal #\: (string-ref iso 2)))
  (let ((short (time 'short)))
    (test-equal 4 (string-length short))))

(test-end "scm-datetime")
