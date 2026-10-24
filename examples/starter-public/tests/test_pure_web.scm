;; Tests for (app web): requests go straight to the handler from make-app,
;; no server or socket. Run: scm tests/test_pure_web.scm

(import (scheme base)
        (scheme file)
        (scheme process-context)
        (scm module)
        (scm fs)
        (scm log)
        (scm string)
        (scm test)
        (scm net http request)
        (scm net http response))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app web))

(test-runner-factory scm-test-runner)
(test-begin "starter-public web")

(define tmp (mktempdir '(prefix . "starter-public-test")))
(define data-file (string-append tmp "/items.json"))
(call-with-output-file data-file
  (lambda (p)
    (write-string "[{\"name\": \"<script>x</script>\", \"count\": 3}]" p)))

(define (app-with prefix file)
  (make-app `((url-prefix . ,prefix)
              (static-dir . ,(string-append root "/static"))
              (data-file . ,file))))

;; Requests are logged to the log port; keep the test output clean.
(define (get app url)
  (parameterize ((log-port (open-output-string)))
    (app (make-http-request "GET" url '() #f))))

(define (body resp)
  (let ((b (http-response-body resp)))
    (if (bytevector? b) (utf8->string b) b)))

(define (has? s part) (and (string-contains-from s part 0) #t))

(define app (app-with "" data-file))

(test-group "home page"
  (let ((r (get app "/")))
    (test-equal 200 (http-response-status r))
    (test-assert "data is escaped" (has? (body r) "&lt;script&gt;x&lt;/script&gt;"))
    (test-assert "lang" (has? (body r) "<html lang=\"en\">"))
    (test-assert "versioned stylesheet" (has? (body r) "/static/css/app.css?v="))
    (test-assert "security headers"
      (has? (http-response-header r "Content-Security-Policy") "script-src 'self'"))))

(test-group "strict CSP holds"
  ;; Every <script> must load a file and no element may carry style="".
  (let ((html (body (get app "/"))))
    (test-assert "no inline script" (not (has? html "<script>")))
    (test-assert "no style attribute" (not (has? html " style=")))))

(test-group "static and health"
  (let ((r (get app "/static/css/app.css")))
    (test-equal 200 (http-response-status r))
    (test-equal "text/css; charset=utf-8" (http-response-header r "Content-Type")))
  (test-equal 404 (http-response-status (get app "/static/../config.example.scm")))
  (test-equal 404 (http-response-status (get app "/nope")))
  (test-equal "ok\n" (body (get app "/healthz"))))

(test-group "url prefix"
  (let ((app (app-with "/inventory/" data-file)))
    (test-equal 200 (http-response-status (get app "/inventory/")))
    (test-equal 200 (http-response-status (get app "/inventory")))
    (test-equal 404 (http-response-status (get app "/")))
    (test-assert (has? (body (get app "/inventory/")) "href=\"/inventory/static/css/app.css?v="))
    (test-equal 200 (http-response-status (get app "/inventory/static/js/theme-init.js")))
    (test-equal "ok\n" (body (get app "/healthz")))))

(test-group "errors are logged, not shown"
  (let* ((app (app-with "" (string-append tmp "/missing.json")))
         (log (open-output-string))
         (r (parameterize ((log-port log))
              (app (make-http-request "GET" "/" '() #f)))))
    (test-equal 500 (http-response-status r))
    (test-assert "error page" (has? (body r) "Something went wrong"))
    (test-assert "no detail in page" (not (has? (body r) "missing.json")))
    (test-assert "detail in log" (has? (get-output-string log) "ERROR [http] GET /"))
    (test-assert "access log" (has? (get-output-string log) "GET / -> 500"))))

(delete-file data-file)
(delete-directory tmp)

(test-end "starter-public web")
