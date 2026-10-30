(import (scheme base) (scm data core) (scm data format) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-core")

(test-group "na"
  (test-assert (na? na))
  (test-assert (not (na? 0)))
  (test-assert (not (na? #f))))

(test-group "dates"
  (test-equal 0 (day-number (ymd->day 1970 1 1)))
  (test-equal -1 (day-number (ymd->day 1969 12 31)))
  (test-equal '(2024 2 29) (day->ymd (ymd->day 2024 2 29)))
  (test-equal '(2000 3 1) (day->ymd (day-from-number (+ 1 (day-number (ymd->day 2000 2 29))))))
  (test-equal 5 (day-weekday (ymd->day 2026 10 30)))
  (test-equal 7 (day-weekday (ymd->day 1970 1 4)))
  (test-equal '(2024 3 11) (day->ymd (string->day "2024-03-11")))
  (test-equal '(2024 3 11) (day->ymd (string->day "11.03.2024")))
  (test-equal '(2024 3 11) (day->ymd (string->day "20240311")))
  (test-equal #f (string->day "2024-02-30"))
  (test-equal #f (string->day "hello"))
  (test-equal "2024-03-11" (day->string (ymd->day 2024 3 11)))
  (test-equal "11.03.2024" (day->string (ymd->day 2024 3 11) 'dmy)))

(test-group "types"
  (test-equal 'int (value-type 3))
  (test-equal 'real (value-type 3.0))
  (test-equal 'real (value-type 1/2))
  (test-equal 'string (value-type "x"))
  (test-equal 'na (value-type na))
  (test-equal 'date (value-type (ymd->day 2024 1 1)))
  (test-equal 'real (column-type (vector 1 2.5 na)))
  (test-equal 'na (column-type (vector na na)))
  (test-equal 'mixed (column-type (vector 1 "x")))
  (test-equal 'list (column-type (vector '(a) '()))))

(test-group "parsing"
  (test-equal 1.5 (parse-cell "1,5" 'real #\,))
  (test-equal 12 (parse-cell " 12 " 'int))
  (test-assert (na? (parse-cell "1.5" 'int)))
  (test-equal #t (parse-cell "TRUE" 'bool))
  (test-equal #f (parse-cell "f" 'bool))
  (test-equal 'BEW8 (parse-cell "BEW8" 'symbol))
  (let ((v (infer-column (vector "1" "" "3"))))
    (test-equal 1 (vector-ref v 0))
    (test-assert (na? (vector-ref v 1))))
  (test-equal 'real (column-type (infer-column (vector "1" "2.5"))))
  (test-equal 'real (column-type (infer-column (vector "1,5" "2") '("NA") #\,)))
  (test-equal 'bool (column-type (infer-column (vector "t" "f" ""))))
  (test-equal 'date (column-type (infer-column (vector "2024-01-01" "11.03.2024"))))
  ;; leading zeros and other text keep the column a string
  (test-equal 'string (column-type (infer-column (vector "8001" "Zürich"))))
  (test-equal "007" (vector-ref (infer-column (vector "007" "x")) 0))
  (test-equal 'string (column-type (infer-column (vector "007" "12"))))
  (test-equal 'real (column-type (infer-column (vector "0.5" "0")))))

(test-end "scm-data-core")
