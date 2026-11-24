(import (scheme base)
        (scm json simple)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-json-simple")

(test-group "json-parse: scalars"
  (test-equal 42 (json-parse "42"))
  (test-equal -7 (json-parse "-7"))
  (test-equal 2.5 (json-parse "2.5"))
  (test-equal 1000.0 (json-parse "1e3"))
  (test-equal #t (json-parse "true"))
  (test-equal #f (json-parse "false"))
  (test-equal 'null (json-parse "null"))
  (test-equal "hi" (json-parse "\"hi\""))
  (test-equal "a\nb\t\"c" (json-parse "\"a\\nb\\t\\\"c\""))
  (test-equal "é" (json-parse "\"\\u00e9\""))
  ;; leading/trailing whitespace tolerated
  (test-equal 5 (json-parse "  5  ")))

(test-group "json-parse: arrays"
  (test-equal #() (json-parse "[]"))
  (test-equal #(1 2 3) (json-parse "[1, 2, 3]"))
  (test-equal #(1 #(2 3)) (json-parse "[1, [2, 3]]")))

(test-group "json-parse: objects"
  (test-equal '() (json-parse "{}"))
  (test-equal '(("a" . 1) ("b" . 2)) (json-parse "{\"a\": 1, \"b\": 2}"))
  ;; key order is preserved
  (test-equal '(("b" . 1) ("a" . 2)) (json-parse "{\"b\": 1, \"a\": 2}"))
  (test-equal '(("k" . #(1 2)) ("m" . (("x" . #t))))
              (json-parse "{\"k\": [1, 2], \"m\": {\"x\": true}}"))
  ;; the dabbak state-file shape round-trips
  (test-equal '(("/p/a" . #(10 1700000000)) ("/p/b" . #(20 1700000005)))
              (json-parse
               "{\"/p/a\": [10, 1700000000], \"/p/b\": [20, 1700000005]}")))

(test-group "json->string: compact"
  (test-equal "42" (json->string 42))
  (test-equal "true" (json->string #t))
  (test-equal "false" (json->string #f))
  (test-equal "null" (json->string 'null))
  (test-equal "\"a\\nb\\\"c\"" (json->string "a\nb\"c"))
  (test-equal "[1,2,3]" (json->string #(1 2 3)))
  (test-equal "[]" (json->string #()))
  (test-equal "{}" (json->string '()))
  (test-equal "{\"a\":1,\"b\":true}" (json->string '(("a" . 1) ("b" . #t)))))

(test-group "json->pretty-string: 2-space indent"
  (test-equal "{}" (json->pretty-string '()))
  (test-equal "[]" (json->pretty-string #()))
  (test-equal "{\n  \"a\": 1,\n  \"b\": [\n    1,\n    2\n  ]\n}"
              (json->pretty-string '(("a" . 1) ("b" . #(1 2))))))

(test-group "round-trip parse <-> string"
  (test-equal '(("/p/a" . #(10 1700000000)))
              (json-parse (json->string '(("/p/a" . #(10 1700000000))))))
  (test-equal #(1 "two" #t null #(3 4))
              (json-parse (json->string #(1 "two" #t null #(3 4)))))
  ;; pretty output also re-parses to the same value
  (test-equal '(("a" . 1) ("b" . #(1 2)))
              (json-parse (json->pretty-string '(("a" . 1) ("b" . #(1 2)))))))

(test-group "json-read: from a port"
  (test-equal #(1 2 3) (json-read (open-input-string "[1, 2, 3]")))
  (test-equal '(("x" . 1)) (json-read (open-input-string "{\"x\": 1}")))
  (test-assert (eof-object? (json-read (open-input-string "")))))

(test-group "json-null?"
  (test-equal #t (json-null? (json-parse "null")))
  (test-equal #f (json-null? #f))
  (test-equal #f (json-null? '()))
  (test-equal #f (json-null? 0)))

(test-group "json-ref"
  (test-equal 2 (json-ref '(("a" . 1) ("b" . 2)) "b"))
  (test-equal #f (json-ref '(("a" . 1)) "z"))
  (test-equal 'missing (json-ref '(("a" . 1)) "z" 'missing))
  (test-equal #f (json-ref '() "a")))

(test-group "json-parse: malformed input raises"
  (test-error (json-parse "{"))
  (test-error (json-parse "[1, 2"))
  (test-error (json-parse "tru"))
  (test-error (json-parse "")))

;; strict as RFC 8259 (and Python's json): the same messages in all three
;; implementations
(define (json-error-text s)
  (guard (e ((error-object? e) (error-object-message e))) (json-parse s) #f))

(test-group "json-parse: strict"
  (test-equal "json: unexpected trailing characters" (json-error-text "{\"a\": 1} x"))
  (test-equal '(("a" . 1)) (json-parse "{\"a\": 1}  \n"))
  (test-equal "json: leading zero in number" (json-error-text "[01]"))
  (test-equal "json: leading zero in number" (json-error-text "[-01]"))
  (test-equal #(0 0 0.5 -500.0) (json-parse "[0, -0, 0.5, -0.5e3]"))
  (test-equal "json: bad number" (json-error-text "[-]"))
  (test-equal "json: bad number" (json-error-text "[1.]"))
  (test-equal "json: bad number" (json-error-text "[1e]"))
  (test-equal "json: unexpected char ." (json-error-text "[.5]"))
  (test-equal "json: control character in string" (json-error-text (string #\" #\a (integer->char 1) #\")))
  (test-equal (string #\a (integer->char 1)) (json-parse "\"a\\u0001\""))
  (test-equal "json: expected low surrogate" (json-error-text "\"\\ud83d\\u0041\""))
  (test-equal "json: unexpected char N" (json-error-text "[NaN]")))

(test-end "scm-json-simple")
