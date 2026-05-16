(define-library (scm net http route)
  (import (scm core)
          (scheme base)
          (scheme char)
          (scm string)
          (srfi 13)
          (scm net http server)
          (scm net http request)
          (scm net http response))
  (export make-router
          router-add!
          router-dispatch
          route!
          get!
          post!
          put!
          delete!
          run-app
          run-app-with-router
          start-app
          start-app-with-router
          params-ref
          url-path
          url-query-string
          parse-query-string
          url-query-params)
  (begin

    ;; --- URL utilities ---

    (define (url-path url)
      "Syntax: (url-path url)
Library: (scm net http route)
Description: Returns the path component of a URL string, stripping scheme+host
  and query string. Works with both absolute paths (/foo?q=1) and full URLs.
  Percent-encoded characters are not decoded.
Example:
  (url-path \"/users/42?limit=10\") => \"/users/42\"
  (url-path \"http://example.com/users/42\") => \"/users/42\""
      ;; If URL starts with "http", skip past the third "/" (end of scheme+host)
      (let* ((s (if (and (>= (string-length url) 4)
                         (string=? (substring url 0 4) "http"))
                    (let loop ((i 0) (slashes 0))
                      (cond
                        ((= i (string-length url)) url)
                        ((and (char=? (string-ref url i) #\/)
                              (= slashes 2))
                         (substring url i (string-length url)))
                        ((char=? (string-ref url i) #\/)
                         (loop (+ i 1) (+ slashes 1)))
                        (else (loop (+ i 1) slashes))))
                    url))
             (n (string-length s)))
        (let loop ((i 0))
          (cond
            ((= i n) s)
            ((char=? (string-ref s i) #\?) (substring s 0 i))
            (else (loop (+ i 1)))))))

    (define (url-query-string url)
      "Syntax: (url-query-string url)
Library: (scm net http route)
Description: Returns the query string portion of url (after '?'), or \"\" if absent.
Example:
  (url-query-string \"/users?limit=10&page=2\") => \"limit=10&page=2\"
  (url-query-string \"/users\") => \"\""
      (let ((n (string-length url)))
        (let loop ((i 0))
          (cond
            ((= i n) "")
            ((char=? (string-ref url i) #\?)
             (substring url (+ i 1) n))
            (else (loop (+ i 1)))))))

    (define (parse-query-string qs)
      "Syntax: (parse-query-string qs)
Library: (scm net http route)
Description: Parses a query string (e.g. \"a=1&b=2\") into an alist of
  (key . value) string pairs. Percent-encoded characters are not decoded in v1.
  Returns '() for an empty string.
Example:
  (parse-query-string \"limit=10&page=2\") => ((\"limit\" . \"10\") (\"page\" . \"2\"))
  (parse-query-string \"\") => ()"
      (if (string=? qs "")
          '()
          (map (lambda (pair)
                 (let ((n (string-length pair)))
                   (let loop ((i 0))
                     (cond
                       ((= i n) (cons pair ""))
                       ((char=? (string-ref pair i) #\=)
                        (cons (substring pair 0 i)
                              (substring pair (+ i 1) n)))
                       (else (loop (+ i 1)))))))
               (string-split qs "&"))))

    (define (url-query-params url)
      "Syntax: (url-query-params url)
Library: (scm net http route)
Description: Parses and returns the query parameters of url as an alist of
  (key . value) pairs. Combines url-query-string and parse-query-string.
Example:
  (url-query-params \"/search?q=hello&n=5\") => ((\"q\" . \"hello\") (\"n\" . \"5\"))"
      (parse-query-string (url-query-string url)))

    ;; --- Path matching ---

    (define (split-path path)
      (let loop ((segs (string-split path "/")) (acc '()))
        (cond
          ((null? segs) (reverse acc))
          ((string=? (car segs) "") (loop (cdr segs) acc))
          (else (loop (cdr segs) (cons (car segs) acc))))))

    (define (match-path pattern-segs actual-segs)
      ;; Returns params alist on match, #f on no match.
      (let loop ((pat pattern-segs) (act actual-segs) (params '()))
        (cond
          ((and (null? pat) (null? act))
           (reverse params))
          ((null? pat) #f)
          ((string=? (car pat) "*")
           (reverse (cons (cons "*" (string-join act "/")) params)))
          ((null? act) #f)
          ((and (> (string-length (car pat)) 0)
                (char=? (string-ref (car pat) 0) #\:))
           (loop (cdr pat) (cdr act)
                 (cons (cons (substring (car pat) 1 (string-length (car pat)))
                             (car act))
                       params)))
          ((string=? (car pat) (car act))
           (loop (cdr pat) (cdr act) params))
          (else #f))))

    ;; --- Router ---

    (define (make-router)
      "Syntax: (make-router)
Library: (scm net http route)
Description: Creates and returns a new router. Use router-add! to register routes
  and router-dispatch to dispatch requests, or run-app-with-router to start a server.
Example:
  (define r (make-router))
  (router-add! r \"GET\" \"/hello/:name\" (lambda (req p) (http-ok (params-ref p \"name\"))))
  (run-app-with-router r 8080)"
      (let ((routes '()))
        (define (add! method pattern handler)
          (set! routes (append routes
                               (list (list (string-upcase method)
                                           (split-path pattern)
                                           handler)))))
        (define (dispatch req)
          (let* ((method (string-upcase (http-request-method req)))
                 (path   (url-path (http-request-url req)))
                 (segs   (split-path path)))
            (let loop ((rs routes))
              (if (null? rs)
                  (http-not-found)
                  (let* ((r       (car rs))
                         (matched (and (string=? (car r) method)
                                       (match-path (cadr r) segs))))
                    (if matched
                        ((caddr r) req matched)
                        (loop (cdr rs))))))))
        (lambda (msg . args)
          (cond
            ((eq? msg 'add!)     (apply add! args))
            ((eq? msg 'dispatch) (apply dispatch args))
            (else (error "make-router: unknown message" msg))))))

    (define (router-add! router method pattern handler)
      "Syntax: (router-add! router method pattern handler)
Library: (scm net http route)
Description: Registers a route on router. method is e.g. \"GET\" (case-insensitive).
  pattern is a path like \"/users/:id\" where :id captures a segment. * as the
  last segment captures the remaining path. handler is (lambda (req params) ...)
  where params is an alist of captured path parameters.
Example:
  (router-add! r \"GET\" \"/users/:id\"
    (lambda (req params)
      (http-ok (params-ref params \"id\"))))"
      (router 'add! method pattern handler))

    (define (router-dispatch router req)
      "Syntax: (router-dispatch router req)
Library: (scm net http route)
Description: Dispatches an http-request to the first matching route in router.
  Returns an http-response. Returns 404 Not Found if no route matches.
Example:
  (router-dispatch my-router req)"
      (router 'dispatch req))

    (define (params-ref params key)
      "Syntax: (params-ref params key)
Library: (scm net http route)
Description: Returns the value for key in the path params alist, or #f if not found.
Example:
  (params-ref params \"id\") => \"42\""
      (let ((pair (assoc key params)))
        (if pair (cdr pair) #f)))

    ;; --- Default router and convenience API ---

    (define *default-router* (make-router))

    (define (route! method pattern handler)
      "Syntax: (route! method pattern handler)
Library: (scm net http route)
Description: Registers a route on the module-level default router. method is e.g.
  \"GET\" (case-insensitive). See router-add! for pattern and handler details.
Example:
  (route! \"PATCH\" \"/items/:id\" (lambda (req p) (http-ok \"patched\")))"
      (*default-router* 'add! method pattern handler))

    (define (get! pattern handler)
      "Syntax: (get! pattern handler)
Library: (scm net http route)
Description: Registers a GET route on the default router.
Example:
  (get! \"/users/:id\" (lambda (req params) (http-ok (params-ref params \"id\"))))"
      (route! "GET" pattern handler))

    (define (post! pattern handler)
      "Syntax: (post! pattern handler)
Library: (scm net http route)
Description: Registers a POST route on the default router.
Example:
  (post! \"/users\" (lambda (req params) (http-ok \"created\")))"
      (route! "POST" pattern handler))

    (define (put! pattern handler)
      "Syntax: (put! pattern handler)
Library: (scm net http route)
Description: Registers a PUT route on the default router.
Example:
  (put! \"/users/:id\" (lambda (req params) (http-ok \"updated\")))"
      (route! "PUT" pattern handler))

    (define (delete! pattern handler)
      "Syntax: (delete! pattern handler)
Library: (scm net http route)
Description: Registers a DELETE route on the default router.
Example:
  (delete! \"/users/:id\" (lambda (req params) (http-ok \"deleted\")))"
      (route! "DELETE" pattern handler))

    (define (run-app port . rest)
      "Syntax: (run-app port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Starts an HTTP server on port using the default router and blocks
  indefinitely. Register routes with get!, post!, put!, delete!, or route! before
  calling run-app. Optional arguments are forwarded to serve-forever / tcp-http-serve;
  see (scm net http server) for details and defaults.
Example:
  (get! \"/\" (lambda (req p) (http-ok \"Hello, world!\")))
  (run-app 8080)
  (run-app 8080 16 \"127.0.0.1\")"
      (apply serve-forever port (lambda (req) (*default-router* 'dispatch req)) rest))

    (define (run-app-with-router router port . rest)
      "Syntax: (run-app-with-router router port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Starts an HTTP server on port using the given router and blocks
  indefinitely. Use make-router and router-add! to build the router before calling.
  Optional arguments are forwarded to serve-forever / tcp-http-serve.
Example:
  (define r (make-router))
  (router-add! r \"GET\" \"/\" (lambda (req p) (http-ok \"hi\")))
  (run-app-with-router r 8080)"
      (apply serve-forever port (lambda (req) (router 'dispatch req)) rest))

    (define (start-app port . rest)
      "Syntax: (start-app port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Like run-app, but returns the server object immediately instead of
  blocking. Use this when you need to install a shutdown hook or otherwise act on
  the server before waiting. Pair with server-wait to block.
Example:
  (get! \"/\" (lambda (req p) (http-ok \"hi\")))
  (define s (start-app 8080))
  (server-install-shutdown-hook s)
  (server-wait s)"
      (apply tcp-http-serve port (lambda (req) (*default-router* 'dispatch req)) rest))

    (define (start-app-with-router router port . rest)
      "Syntax: (start-app-with-router router port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Like run-app-with-router, but returns the server object immediately
  instead of blocking. Pair with server-wait to block.
Example:
  (define s (start-app-with-router my-router 8080))
  (server-install-shutdown-hook s)
  (server-wait s)"
      (apply tcp-http-serve port (lambda (req) (router 'dispatch req)) rest))))
