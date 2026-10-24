;; Tests for the web app: sign-in, sessions, profile, prefix. Requests go
;; straight to the handler from make-app, no server or socket.
;; Run: scm tests/test_pure_web.scm

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
        (scm net http request)
        (scm net http response))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app users) (app web))

(test-runner-factory scm-test-runner)
(test-begin "starter-login web")

(define tmp (mktempdir '(prefix . "starter-login-test")))
(define users-file (string-append tmp "/data/users.scm"))

(define (app-with prefix)
  (make-app `((url-prefix . ,prefix)
              (static-dir . ,(string-append root "/static"))
              (items-file . ,(string-append root "/data/items.json"))
              (users-file . ,users-file)
              (session-secret . ,(base64-encode (random-bytes 32)))
              (session-max-age . 3600)
              (secure-cookies? . #f))))

;; Fast hashes keep the test quick; production uses the 600k default.
(define fast-iterations 1000)

;; Requests are logged to the log port; keep the test output clean.
(define (send app method url cookie . form)
  (parameterize ((log-port (open-output-string))
                 (password-pbkdf2-iterations fast-iterations))
    (app (make-http-request
          method url
          (append (if cookie (list (cons "Cookie" cookie)) '())
                  (if (pair? form)
                      '(("Content-Type" . "application/x-www-form-urlencoded"))
                      '()))
          (if (pair? form) (car form) #f)))))

(define (status r) (http-response-status r))
(define (location r) (http-response-header r "Location"))
(define (body r)
  (let ((b (http-response-body r)))
    (if (bytevector? b) (utf8->string b) b)))
(define (has? s part) (and (string? s) (string-contains-from s part 0) #t))

;; "name=value" from the response's Set-Cookie header, for the next request.
(define (cookie-of r)
  (let ((h (http-response-header r "Set-Cookie")))
    (and h (car (string-split-char h #\;)))))

(parameterize ((password-pbkdf2-iterations fast-iterations))
  (save-user! users-file "alice" (password-hash "correct horse")))
(define app (app-with ""))

(test-group "signed out"
  (let ((r (send app "GET" "/" #f)))
    (test-equal 303 (status r))
    (test-equal "/login" (location r)))
  (test-equal 200 (status (send app "GET" "/login" #f)))
  (test-equal "ok\n" (body (send app "GET" "/healthz" #f))))

(test-group "failed sign-in"
  (let ((r (send app "POST" "/login" #f "username=alice&password=wrong")))
    (test-equal 200 (status r))
    (test-assert (has? (body r) "Invalid username or password"))
    (test-equal #f (http-response-header r "Set-Cookie")))
  (test-assert "unknown user"
    (has? (body (send app "POST" "/login" #f "username=bob&password=x"))
          "Invalid username or password")))

(define cookie
  (let ((r (send app "POST" "/login" #f "username=alice&password=correct+horse")))
    (test-equal "sign-in redirects home" "/" (location r))
    (let ((h (http-response-header r "Set-Cookie")))
      (test-assert "HttpOnly" (has? h "HttpOnly"))
      (test-assert "SameSite" (has? h "SameSite=Strict"))
      (test-assert "Path" (has? h "Path=/")))
    (cookie-of r)))

(test-group "signed in"
  (let ((r (send app "GET" "/" cookie)))
    (test-equal 200 (status r))
    (test-assert (has? (body r) "Signed in as <strong>alice</strong>"))
    (test-assert "no inline script" (not (has? (body r) "<script>")))
    (test-assert "no style attribute" (not (has? (body r) " style="))))
  (test-equal "/" (location (send app "GET" "/login" cookie)))
  (test-equal 200 (status (send app "GET" "/profile" cookie)))
  (test-equal 303 (status (send app "GET" "/" "starter_login_session=forged.token"))))

(test-group "change password"
  (test-assert "wrong current password"
    (has? (body (send app "POST" "/profile/password" cookie
                      "current=nope&new=newpassword&confirm=newpassword"))
          "Current password is incorrect"))
  (test-assert "too short"
    (has? (body (send app "POST" "/profile/password" cookie
                      "current=correct+horse&new=short&confirm=short"))
          "at least 8"))
  (test-assert "mismatch"
    (has? (body (send app "POST" "/profile/password" cookie
                      "current=correct+horse&new=newpassword&confirm=other"))
          "do not match"))
  (let* ((r (send app "POST" "/profile/password" cookie
                  "current=correct+horse&new=newpassword&confirm=newpassword"))
         (fresh (cookie-of r)))
    (test-equal "/profile?updated" (location r))
    (test-assert "old session ended" (equal? "/login" (location (send app "GET" "/" cookie))))
    (test-equal "new session works" 200 (status (send app "GET" "/" fresh)))
    (test-assert (has? (body (send app "GET" "/profile?updated" fresh)) "Password updated"))
    (test-equal "new password signs in" "/"
      (location (send app "POST" "/login" #f "username=alice&password=newpassword")))
    (test-group "sign out"
      (let ((r (send app "POST" "/logout" fresh)))
        (test-equal "/login" (location r))
        (test-assert "cookie cleared" (has? (http-response-header r "Set-Cookie") "Max-Age=0"))))
    (test-group "deleted user"
      (delete-user! users-file "alice")
      (test-equal "/login" (location (send app "GET" "/" fresh))))))

(test-group "outdated hashes are upgraded at sign-in"
  (parameterize ((password-pbkdf2-iterations 500))
    (save-user! users-file "carol" (password-hash "carols password")))
  (test-assert (password-needs-rehash? (user-hash (find-user users-file "carol"))))
  (send app "POST" "/login" #f "username=carol&password=carols+password")
  (test-assert (not (parameterize ((password-pbkdf2-iterations fast-iterations))
                      (password-needs-rehash? (user-hash (find-user users-file "carol")))))))

(test-group "url prefix"
  (let* ((app (app-with "/team"))
         (r (send app "POST" "/team/login" #f "username=carol&password=carols+password")))
    (test-equal "/team/" (location r))
    (test-assert "cookie scoped to the prefix"
      (has? (http-response-header r "Set-Cookie") "Path=/team/"))
    (test-equal "/team/login" (location (send app "GET" "/team/" #f)))
    (test-assert (has? (body (send app "GET" "/team/" (cookie-of r)))
                       "href=\"/team/static/css/app.css?v="))
    (test-equal 404 (status (send app "GET" "/login" #f)))))

(delete-file users-file)
(delete-directory (string-append tmp "/data"))
(delete-directory tmp)

(test-end "starter-login web")
