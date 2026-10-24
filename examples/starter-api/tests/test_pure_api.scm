;; Tests for the JSON API: sign-in, tokens, the items resource, the error
;; envelope, the URL prefix. Requests go straight to the handler from
;; make-app, no server or socket. Run: scm tests/test_pure_api.scm

(import (scheme base)
        (scheme file)
        (scheme process-context)
        (scm module)
        (scm fs)
        (scm log)
        (scm string)
        (scm test)
        (scm crypto)
        (scm crypto password)
        (scm crypto token)
        (scm json simple)
        (scm net http request)
        (scm net http response))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app users) (app api))

(test-runner-factory scm-test-runner)
(test-begin "starter-api")

(define tmp (mktempdir '(prefix . "starter-api-test")))
(define users-file (string-append tmp "/users.scm"))
(define items-file (string-append tmp "/items.scm"))
(define secret (base64-encode (random-bytes 32)))

(define (app-with prefix)
  (make-app `((url-prefix . ,prefix)
              (users-file . ,users-file)
              (items-file . ,items-file)
              (token-secret . ,secret)
              (token-max-age . 3600))))

;; Fast hashes keep the test quick; production uses the 600k default.
(define fast-iterations 1000)

;; (send app method url token [json-body]); requests are logged to the log
;; port, kept out of the test output.
(define (send app method url token . body)
  (parameterize ((log-port (open-output-string))
                 (password-pbkdf2-iterations fast-iterations))
    (app (make-http-request
          method url
          (append (if token (list (cons "Authorization" (string-append "Bearer " token))) '())
                  (if (pair? body) '(("Content-Type" . "application/json")) '()))
          (if (pair? body) (car body) #f)))))

(define (status r) (http-response-status r))
(define (json r)
  (let ((b (http-response-body r)))
    (json-parse (if (bytevector? b) (utf8->string b) b))))
(define (error-code r) (json-ref (json-ref (json r) "error" '()) "code" #f))

(parameterize ((password-pbkdf2-iterations fast-iterations))
  (save-user! users-file "alice" (password-hash "alicepassword")))
(define app (app-with ""))

(define (login app name password)
  (send app "POST" "/api/login" #f
        (string-append "{\"username\":\"" name "\",\"password\":\"" password "\"}")))

(define token (json-ref (json (login app "alice" "alicepassword")) "token" #f))

(test-group "login"
  (test-assert (string? token))
  (let ((r (login app "alice" "alicepassword")))
    (test-equal 200 (status r))
    (test-equal "Bearer" (json-ref (json r) "token_type" #f))
    (test-equal 3600 (json-ref (json r) "expires_in" #f))
    (test-equal "no-store" (http-response-header r "Cache-Control")))
  (test-equal "invalid_credentials" (error-code (login app "alice" "wrong")))
  (test-equal "invalid_credentials" (error-code (login app "nobody" "x")))
  (test-equal "bad_request" (error-code (send app "POST" "/api/login" #f "[1,2]")))
  (test-equal "bad_request" (error-code (send app "POST" "/api/login" #f "{\"username\":1}")))
  (test-equal "bad_request" (error-code (send app "POST" "/api/login" #f "not json"))))

(test-group "tokens"
  (test-equal "alice" (json-ref (json (send app "GET" "/api/me" token)) "username" #f))
  (let ((r (send app "GET" "/api/me" #f)))
    (test-equal 401 (status r))
    (test-equal "unauthorized" (error-code r))
    (test-equal "Bearer" (http-response-header r "WWW-Authenticate")))
  (test-equal 401 (status (send app "GET" "/api/me" "garbage")))
  (test-equal 401 (status (send app "GET" "/api/me" (string-append token "x"))))
  ;; Same key, other purpose: not an API token.
  (test-equal 401 (status (send app "GET" "/api/me"
                                (token-sign secret '((sub . "alice")) 60
                                            '((purpose . "session")))))))

(test-group "items"
  (test-equal '#() (json (send app "GET" "/api/items" token)))
  (let ((r (send app "POST" "/api/items" token "{\"name\":\"Cogs\",\"count\":7}")))
    (test-equal 201 (status r))
    (test-equal '(("id" . 1) ("name" . "Cogs") ("count" . 7)) (json r)))
  (send app "POST" "/api/items" token "{\"name\":\"Gears\",\"count\":2}")
  (test-equal 2 (vector-length (json (send app "GET" "/api/items" token))))
  (test-equal "Gears" (json-ref (json (send app "GET" "/api/items/2" token)) "name" #f))
  (test-equal "not_found" (error-code (send app "GET" "/api/items/9" token)))
  (test-equal "not_found" (error-code (send app "GET" "/api/items/x" token)))
  (test-equal "invalid_field"
    (error-code (send app "POST" "/api/items" token "{\"name\":\"\",\"count\":1}")))
  (test-equal "invalid_field"
    (error-code (send app "POST" "/api/items" token "{\"name\":\"A\",\"count\":1.5}")))
  (test-equal "invalid_field"
    (error-code (send app "POST" "/api/items" token "{\"name\":\"A\",\"count\":-1}")))
  (test-equal 204 (status (send app "DELETE" "/api/items/1" token)))
  (test-equal 404 (status (send app "DELETE" "/api/items/1" token)))
  (test-equal 401 (status (send app "DELETE" "/api/items/2" #f))))

(test-group "error envelope"
  (test-equal "not_found" (error-code (send app "GET" "/api/nothing" token)))
  (let ((r (send app "PUT" "/api/items" token "{}")))
    (test-equal 405 (status r))
    (test-equal "method_not_allowed" (error-code r))
    (test-equal "GET, POST" (http-response-header r "Allow")))
  (test-assert (string-contains-from
                (http-response-header (send app "GET" "/api/me" token) "Content-Security-Policy")
                "default-src 'none'" 0)))

(test-group "tokens are revoked with the password or the user"
  (parameterize ((password-pbkdf2-iterations fast-iterations))
    (save-user! users-file "alice" (password-hash "anotherpassword")))
  (test-equal 401 (status (send app "GET" "/api/me" token)))
  (let ((fresh (json-ref (json (login app "alice" "anotherpassword")) "token" #f)))
    (test-equal 200 (status (send app "GET" "/api/me" fresh)))
    (delete-user! users-file "alice")
    (test-equal 401 (status (send app "GET" "/api/me" fresh)))))

(test-group "errors are logged, not shown"
  (call-with-output-file items-file (lambda (p) (write-string "(((" p)))
  (parameterize ((password-pbkdf2-iterations fast-iterations))
    (save-user! users-file "bob" (password-hash "bobspassword")))
  (let* ((t (json-ref (json (login app "bob" "bobspassword")) "token" #f))
         (log (open-output-string))
         (r (parameterize ((log-port log))
              (app (make-http-request "GET" "/api/items" 
                                      (list (cons "Authorization" (string-append "Bearer " t)))
                                      #f)))))
    (test-equal 500 (status r))
    (test-equal "internal_error" (error-code r))
    (test-assert (string-contains-from (get-output-string log) "ERROR [http] GET /api/items" 0))))

(test-group "url prefix"
  (let* ((app (app-with "/inventory"))
         (t (json-ref (json (send app "POST" "/inventory/api/login" #f
                                  "{\"username\":\"bob\",\"password\":\"bobspassword\"}"))
                      "token" #f)))
    (test-equal "bob" (json-ref (json (send app "GET" "/inventory/api/me" t)) "username" #f))
    (test-equal 404 (status (send app "GET" "/api/me" t)))
    (test-equal 200 (status (send app "GET" "/healthz" #f)))))

(for-each (lambda (f) (when (file-exists? f) (delete-file f))) (list users-file items-file))
(delete-directory tmp)

(test-end "starter-api")
