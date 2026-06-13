;; (app api) — JSON/REST routes, bearer-token guard, and the server.
;; Every response is JSON. Errors use one envelope:
;;   { "error": { "code": "...", "message": "..." } }

(define-library (app api)
  (import (scheme base)
          (scheme write)
          (srfi 18)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm json simple)
          (app auth)
          (app store))
  (export make-api-config serve)
  (begin

    (define-record-type api-config
      (make-api-config host port auth users-file items-file)
      api-config?
      (host cfg-host)
      (port cfg-port)
      (auth cfg-auth)
      (users-file cfg-users-file)
      (items-file cfg-items-file))

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

    ;; Parse a JSON request body into an alist; #f on malformed input.
    (define (json-body req)
      (guard (e (#t #f))
        (json-parse (or (http-request-body req) ""))))

    ;; --- auth guard ---------------------------------------------------

    (define (with-auth C handler)
      (lambda (req params)
        (let* ((tok (bearer-token req))
               (sub (and tok (token-subject (cfg-auth C) tok))))
          (if sub
              (handler req params sub)
              (api-error 401 "unauthorized"
                         "Missing or invalid bearer token")))))

    (define (parse-id params)
      (let ((s (params-ref params "id")))
        (and s (string->number s))))

    ;; --- server -------------------------------------------------------

    (define (serve C)
      (let ((auth (cfg-auth C))
            (router (make-router)))

        (router-add! router "GET" "/healthz"
          (lambda (req params) (text-response "ok\n")))

        ;; POST /api/login  { "username": ..., "password": ... }
        (router-add! router "POST" "/api/login"
          (lambda (req params)
            (let ((body (json-body req)))
              (if (not body)
                  (api-error 400 "bad_request" "Body must be a JSON object")
                  (let* ((username (json-ref body "username" ""))
                         (password (json-ref body "password" ""))
                         (user (find-user (load-users (cfg-users-file C)) username)))
                    (if (and user (verify-password password (user-hash user)))
                        (json-ok (list (cons "token" (issue-token auth username))
                                       (cons "token_type" "Bearer")
                                       (cons "expires_in" (auth-max-age auth))))
                        (begin
                          (thread-sleep! 0.5)
                          (api-error 401 "invalid_credentials"
                                     "Invalid username or password"))))))))

        ;; GET /api/me
        (router-add! router "GET" "/api/me"
          (with-auth C
            (lambda (req params sub)
              (json-ok (list (cons "username" sub))))))

        ;; GET /api/items
        (router-add! router "GET" "/api/items"
          (with-auth C
            (lambda (req params sub)
              (json-ok
               (list->vector
                (map item->alist (load-items (cfg-items-file C))))))))

        ;; POST /api/items  { "name": ..., "count": ... }
        (router-add! router "POST" "/api/items"
          (with-auth C
            (lambda (req params sub)
              (let ((body (json-body req)))
                (if (not body)
                    (api-error 400 "bad_request" "Body must be a JSON object")
                    (let ((name (json-ref body "name" #f))
                          (count (json-ref body "count" #f)))
                      (cond
                        ((not (and (string? name) (> (string-length name) 0)))
                         (api-error 422 "invalid_field" "name must be a non-empty string"))
                        ((not (and (integer? count) (>= count 0)))
                         (api-error 422 "invalid_field" "count must be a non-negative integer"))
                        (else
                         (json-status 201
                           (item->alist
                            (add-item! (cfg-items-file C) name count)))))))))))

        ;; GET /api/items/:id
        (router-add! router "GET" "/api/items/:id"
          (with-auth C
            (lambda (req params sub)
              (let* ((id (parse-id params))
                     (it (and id (find-item (load-items (cfg-items-file C)) id))))
                (if it
                    (json-ok (item->alist it))
                    (api-error 404 "not_found" "No item with that id"))))))

        ;; DELETE /api/items/:id
        (router-add! router "DELETE" "/api/items/:id"
          (with-auth C
            (lambda (req params sub)
              (let ((id (parse-id params)))
                (if (and id (delete-item! (cfg-items-file C) id))
                    (make-http-response 204 '() "")
                    (api-error 404 "not_found" "No item with that id"))))))

        (display (string-append "starter-api listening on http://"
                                (cfg-host C) ":"
                                (number->string (cfg-port C)) "\n"))
        (run-app-with-router router (cfg-port C) 0 (cfg-host C))))))
