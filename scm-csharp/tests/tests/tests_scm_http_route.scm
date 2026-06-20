(import (scheme base)
        (scm net http route)
        (scm net http request)
        (scm net http response)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-route")

(test-group "url-query-string"
  (test-equal "limit=10&page=2" (url-query-string "/users?limit=10&page=2"))
  (test-equal "" (url-query-string "/users")))

(test-group "parse-query-string"
  (test-equal '() (parse-query-string ""))
  (test-equal '(("limit" . "10") ("page" . "2"))
              (parse-query-string "limit=10&page=2"))
  ;; key with no '=' gets empty-string value
  (test-equal '(("flag" . "")) (parse-query-string "flag"))
  ;; percent-decoding applies to keys and values, as UTF-8
  (test-equal '(("q" . "Zürich"))
              (parse-query-string "q=Z%C3%BCrich"))
  (test-equal '(("nä me" . "Ada Lovelace"))
              (parse-query-string "n%C3%A4+me=Ada+Lovelace"))
  ;; '+' decodes to space
  (test-equal '(("q" . "a b")) (parse-query-string "q=a+b"))
  ;; %2F stays a literal slash in the value
  (test-equal '(("q" . "a/b")) (parse-query-string "q=a%2Fb")))

(test-group "url-query-params"
  (test-equal '(("q" . "Zürich") ("n" . "5"))
              (url-query-params "/search?q=Z%C3%BCrich&n=5"))
  (test-equal '() (url-query-params "/search")))

(test-group "path params are percent-decoded"
  (define r (make-router))
  (define (dispatch url)
    (http-response-body
      (router-dispatch r (make-http-request "GET" url '() #f))))
  (router-add! r "GET" "/h/:name"
    (lambda (req params) (http-ok (params-ref params "name"))))
  (router-add! r "GET" "/files/*"
    (lambda (req params) (http-ok (params-ref params "*"))))
  ;; :named segment decoded as UTF-8
  (test-equal "Män" (dispatch "/h/M%C3%A4n"))
  ;; %2F inside a segment is a literal slash, not a delimiter (split happens
  ;; before decode, so the route still matches /h/:name)
  (test-equal "a/b" (dispatch "/h/a%2Fb"))
  ;; '+' is literal in a path segment (NOT space, unlike query strings)
  (test-equal "a+b" (dispatch "/h/a+b"))
  ;; plain segment unchanged
  (test-equal "42" (dispatch "/h/42"))
  ;; '*' wildcard captures the remaining path raw (still percent-encoded)
  (test-equal "a%2Fb/c" (dispatch "/files/a%2Fb/c")))

(test-end "scm-http-route")
