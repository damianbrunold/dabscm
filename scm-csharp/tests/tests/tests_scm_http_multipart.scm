(import (scheme base)
        (scm net http multipart)
        (scm net http request)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-multipart")

(test-group "multipart-boundary"
  (test-equal #f (multipart-boundary #f))
  (test-equal #f (multipart-boundary "text/plain"))
  (test-equal "abc123"
              (multipart-boundary "multipart/form-data; boundary=abc123"))
  ;; quoted boundary
  (test-equal "with space"
              (multipart-boundary
               "multipart/form-data; boundary=\"with space\""))
  ;; case-insensitive content-type matching
  (test-equal "abc" (multipart-boundary "Multipart/Form-Data; Boundary=abc"))
  ;; boundary followed by another parameter
  (test-equal "abc"
              (multipart-boundary
               "multipart/form-data; boundary=abc; charset=utf-8")))

(define example-body
  (string-append "--xx\r\n" "Content-Disposition: form-data; name=\"a\"\r\n"
                 "\r\n" "1\r\n" "--xx\r\n"
                 "Content-Disposition: form-data; name=\"file\"; filename=\"hi.txt\"\r\n"
                 "Content-Type: text/plain\r\n" "\r\n" "hello\r\n"
                 "--xx--\r\n"))

(test-group "parse-multipart"
  (let ((parts (parse-multipart example-body "xx")))
    (test-equal 2 (length parts))
    (test-equal "a" (part-ref (car parts) 'name))
    (test-equal #f (part-ref (car parts) 'filename))
    (test-equal "1" (part-ref (car parts) 'body))
    (test-equal "file" (part-ref (cadr parts) 'name))
    (test-equal "hi.txt" (part-ref (cadr parts) 'filename))
    (test-equal "text/plain" (part-ref (cadr parts) 'content-type))
    (test-equal "hello" (part-ref (cadr parts) 'body))))

(test-group "parse-multipart degenerate"
  (test-equal '() (parse-multipart "" "xx"))
  (test-equal '() (parse-multipart #f "xx"))
  (test-equal '() (parse-multipart example-body ""))
  ;; mismatched boundary → no parts found
  (test-equal '() (parse-multipart example-body "nope")))

(test-group "parse-multipart-bytes"
  (let* ((bv (string->utf8 example-body))
         (parts (parse-multipart-bytes bv "xx")))
    (test-equal 2 (length parts))
    (test-equal #t (bytevector? (part-ref (car parts) 'body)))
    (test-equal "1" (utf8->string (part-ref (car parts) 'body)))
    (test-equal "hello" (utf8->string (part-ref (cadr parts) 'body)))
    (test-equal "hi.txt" (part-ref (cadr parts) 'filename))))

(test-group "a request made with a string body has its bytes"
  ;; so a handler reading http-request-body-bytes can be tested with
  ;; requests built by make-http-request
  (let* ((body "--b\r\nContent-Disposition: form-data; name=\"f\"; filename=\"ü.txt\"\r\n\r\nGrüße\r\n--b--\r\n")
         (req (make-http-request "POST" "/" '() body)))
    (test-equal (string->utf8 body) (http-request-body-bytes req))
    (let ((parts (parse-multipart-bytes (http-request-body-bytes req) "b")))
      (test-equal "ü.txt" (part-ref (car parts) 'filename))
      (test-equal (string->utf8 "Grüße") (part-ref (car parts) 'body))))
  (test-equal #f (http-request-body-bytes (make-http-request "GET" "/" '() #f)))
  (test-equal "AB" (http-request-body (make-http-request "POST" "/" '() (bytevector 65 66)))))

(test-end "scm-http-multipart")
