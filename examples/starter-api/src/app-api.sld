;; (app api) — JSON/REST routes, the bearer-token guard, and the
;; middleware stack. Every response is JSON; errors use one envelope:
;;
;;   { "error": { "code": "...", "message": "..." } }
;;
;; make-app returns the server-level handler (lambda (req) resp):
;; bin/server.scm serves it, and the tests call it directly.

(define-library (app api)
  (import (scheme base)
          (srfi 18)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm net http middleware)
          (scm json simple)
          (app users)
          (app items)
          (app auth))
  (export make-app)
  (begin

    ;; --- JSON responses ----------------------------------------------

    (define (json-status status value)
      (make-http-response
       status '(("Content-Type" . "application/json; charset=utf-8"))
       (json->string value)))

    (define (json-ok value) (json-status 200 value))

    (define (api-error status code message)
      (json-status status
        (list (cons "error" (list (cons "code" code)
                                  (cons "message" message))))))

    ;; The request body as a JSON object (an alist), or #f if it is not one.
    (define (json-body req)
      (let ((body (guard (e (#t #f))
                    (json-parse (or (http-request-body req) "")))))
        (and (list? body) body)))

    (define (add-header resp name value)
      (make-http-response (http-response-status resp)
                          (cons (cons name value) (http-response-headers resp))
                          (http-response-body resp)))

    ;; The router answers unknown paths and methods in plain text; give
    ;; them the JSON envelope (keeping the Allow header of a 405).
    (define (with-json-errors handler)
      (lambda (req)
        (let ((resp (handler req)))
          (case (http-response-status resp)
            ((404) (api-error 404 "not_found" "No such endpoint"))
            ((405) (add-header (api-error 405 "method_not_allowed" "Method not allowed")
                               "Allow" (http-response-header resp "Allow")))
            (else resp)))))

    ;; A JSON API needs no scripts, styles or frames at all.
    (define api-csp "default-src 'none'; frame-ancestors 'none'")

    ;; A failed password check costs the client half a second, which slows
    ;; down guessing.
    (define (penalty) (thread-sleep! 0.5))

    (define (setting settings key)
      (let ((p (assq key settings)))
        (if p (cdr p) (error "make-app: missing setting" key))))

    (define (make-app settings)
      "Syntax: (make-app settings)
Library: (app api)
Description: Builds the API's request handler. settings is an alist:
  url-prefix (\"\" at the host root), users-file and items-file (absolute
  paths), token-secret, token-max-age (seconds)."
      (let* ((prefix (setting settings 'url-prefix))
             (items-file (setting settings 'items-file))
             (auth (make-auth (setting settings 'token-secret)
                              (setting settings 'token-max-age)
                              (setting settings 'users-file)))
             (router (make-router)))

        (define (route! method path handler)
          (router-add! router method (string-append prefix path) handler))

        ;; Runs handler with the token's user as a third argument, or
        ;; answers 401.
        (define (with-token handler)
          (lambda (req params)
            (let ((user (token-user auth (http-request-bearer-token req))))
              (if user
                  (handler req params user)
                  (add-header (api-error 401 "unauthorized" "Missing or invalid bearer token")
                              "WWW-Authenticate" "Bearer")))))

        (define (item-id params)
          (let ((n (string->number (or (params-ref params "id") ""))))
            (and (exact-integer? n) n)))

        ;; POST /api/login  {"username": ..., "password": ...}
        (route! "POST" "/api/login"
          (lambda (req params)
            (let ((body (json-body req)))
              (if (not body)
                  (api-error 400 "bad_request" "Body must be a JSON object")
                  (let ((username (json-ref body "username" #f))
                        (password (json-ref body "password" #f)))
                    (if (not (and (string? username) (string? password)))
                        (api-error 400 "bad_request" "username and password are required")
                        (let ((user (sign-in auth username password)))
                          (if user
                              (json-ok (list (cons "token" (issue-token auth user))
                                             (cons "token_type" "Bearer")
                                             (cons "expires_in" (auth-max-age auth))))
                              (begin
                                (penalty)
                                (api-error 401 "invalid_credentials"
                                           "Invalid username or password"))))))))))

        ;; GET /api/me
        (route! "GET" "/api/me"
          (with-token
            (lambda (req params user)
              (json-ok (list (cons "username" (user-name user)))))))

        ;; GET /api/items
        (route! "GET" "/api/items"
          (with-token
            (lambda (req params user)
              (json-ok (list->vector (map item->json (load-items items-file)))))))

        ;; POST /api/items  {"name": ..., "count": ...}
        (route! "POST" "/api/items"
          (with-token
            (lambda (req params user)
              (let ((body (json-body req)))
                (if (not body)
                    (api-error 400 "bad_request" "Body must be a JSON object")
                    (let ((name (json-ref body "name" #f))
                          (count (json-ref body "count" #f)))
                      (cond
                        ((not (and (string? name) (<= 1 (string-length name) 200)))
                         (api-error 422 "invalid_field"
                                    "name must be a string of 1 to 200 characters"))
                        ((not (and (exact-integer? count) (>= count 0)))
                         (api-error 422 "invalid_field"
                                    "count must be a non-negative integer"))
                        (else
                         (json-status 201
                           (item->json (add-item! items-file name count)))))))))))

        ;; GET /api/items/:id
        (route! "GET" "/api/items/:id"
          (with-token
            (lambda (req params user)
              (let* ((id (item-id params))
                     (it (and id (find-item items-file id))))
                (if it
                    (json-ok (item->json it))
                    (api-error 404 "not_found" "No item with that id"))))))

        ;; DELETE /api/items/:id
        (route! "DELETE" "/api/items/:id"
          (with-token
            (lambda (req params user)
              (let ((id (item-id params)))
                (if (and id (delete-item! items-file id))
                    (make-http-response 204 '() "")
                    (api-error 404 "not_found" "No item with that id"))))))

        ;; Outside the prefix: the health probe talks to the app directly.
        (router-add! router "GET" "/healthz"
          (lambda (req params) (text-response "ok\n")))

        ;; Outermost first: log every request; add the security headers and
        ;; keep responses (tokens, data) out of caches; JSON envelopes for
        ;; unknown routes; errors logged in full but answered with a
        ;; generic 500.
        (with-access-log
         (with-response-headers
          (with-security-headers
           (with-json-errors
            (with-error-handler
             (router->handler router)
             (lambda (req) (api-error 500 "internal_error" "Internal server error"))))
           api-csp)
          '(("Cache-Control" . "no-store"))))))))
