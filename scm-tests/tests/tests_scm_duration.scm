(import (scheme base) (scm duration) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-duration")

(test-group "parse-duration"
  (test-equal 30    (parse-duration "30"))
  (test-equal 30    (parse-duration "30s"))
  (test-equal 600   (parse-duration "10m"))
  (test-equal 10800 (parse-duration "3h"))
  (test-equal 86400 (parse-duration "1d"))
  (test-equal 0     (parse-duration "0"))
  ;; surrounding whitespace is trimmed
  (test-equal 60    (parse-duration "  60  "))
  (test-equal 60    (parse-duration " 1m "))
  ;; invalid inputs return #f
  (test-equal #f    (parse-duration ""))
  (test-equal #f    (parse-duration "abc"))
  (test-equal #f    (parse-duration #f))
  (test-equal #f    (parse-duration "30x")))

(test-group "format-duration"
  (test-equal "0s"    (format-duration 0))
  (test-equal "30s"   (format-duration 30))
  (test-equal "90s"   (format-duration 90))
  (test-equal "1m"    (format-duration 60))
  (test-equal "1h"    (format-duration 3600))
  (test-equal "1d"    (format-duration 86400))
  ;; chooses the largest unit that divides cleanly
  (test-equal "2d"    (format-duration 172800)))

(test-group "duration-roundtrip"
  (test-equal 60    (parse-duration (format-duration 60)))
  (test-equal 3600  (parse-duration (format-duration 3600)))
  (test-equal 86400 (parse-duration (format-duration 86400)))
  (test-equal 90    (parse-duration (format-duration 90))))

(test-end "scm-duration")
