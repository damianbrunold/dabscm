## Overview

`(scm net http route)` adds request routing on top of the HTTP server: map method
+ path patterns to handlers, capture path parameters, and parse query strings. It
turns a bare request handler into a small web application.

## Common uses

Define routes and run the app:

A handler receives the request and the captured path parameters:

```scheme
(import (scm net http route) (scm net http response))

(get! "/" (lambda (req params) (http-ok "home")))
(get! "/users/:id"
      (lambda (req params)
        (http-ok (string-append "user " (params-ref params "id")))))
(post! "/users" (lambda (req params) (http-ok "created")))

(run-app 8080)
```

Helpers for working with URLs:

```scheme
(url-path "/users/42?limit=10")          ;; => "/users/42"
(parse-query-string "limit=10&page=2")   ;; => (("limit" . "10") ("page" . "2"))
```

For a lower-level explicit router use `make-router`, `router-add!`, and
`router-dispatch`.
