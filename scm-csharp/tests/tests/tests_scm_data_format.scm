(import (scheme base) (scm data core) (scm data format) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-format")

(test-group "fmt-num"
  (test-equal "24'973" (fmt-num 24973.25))
  (test-equal "24'973.3" (fmt-num 24973.25 1))
  (test-equal "1'000'000.00" (fmt-num 1e6 2))
  (test-equal "999" (fmt-num 999))
  (test-equal "-1'234.5" (fmt-num -1234.5 1))
  ;; half away from zero
  (test-equal "3" (fmt-num 2.5))
  (test-equal "-3" (fmt-num -2.5))
  (test-equal "0.0" (fmt-num -0.04 1))
  (test-equal "1234" (fmt-num 1234 0 #f))
  (test-equal "NA" (fmt-num na 1))
  (parameterize ((data-locale '((thousands . ",") (decimal . "."))))
    (test-equal "1,234.5" (fmt-num 1234.5 1)))
  (parameterize ((data-locale '((thousands . ".") (decimal . ","))))
    (test-equal "1.234,5" (fmt-num 1234.5 1))))

(test-group "percent and other formats"
  (test-equal "23.5 %" (fmt-pct 0.2345))
  (test-equal "23 %" (fmt-pct 0.2345 0))
  (test-equal "+23 %" (fmt-pct-change 20316 24973))
  (test-equal "-4 %" (fmt-pct-change 100 96))
  (test-equal "0 %" (fmt-pct-change 100 99.9))
  (test-equal "n/a" (fmt-pct-change 0 5))
  (test-equal "1'235" (fmt-int 1234.5))
  (test-equal "12.3k" (fmt-si 12345))
  (test-equal "1.5M" (fmt-si 1500000))
  (test-equal "950" (fmt-si 950))
  (test-equal "2024-03-11" (fmt-date (ymd->day 2024 3 11)))
  (test-equal "11.03.2024" (fmt-date (ymd->day 2024 3 11) 'dmy)))

(test-group "fmt-value"
  (test-equal "2.5" (fmt-value 2.50))
  (test-equal "0.3333" (fmt-value (/ 1.0 3)))
  (test-equal "3" (fmt-value 3.0))
  (test-equal "42" (fmt-value 42))
  (test-equal "TRUE" (fmt-value #t))
  (test-equal "BEW8" (fmt-value 'BEW8))
  (test-equal "(a 1)" (fmt-value '(a 1)))
  (test-equal "NA" (fmt-value na))
  (parameterize ((na-string ""))
    (test-equal "" (fmt-value na))))

(test-end "scm-data-format")
