## Overview

`(scm net http client)` is an HTTP client. The convenience procedures cover the
common verbs (`http-get`, `http-post`, `http-put`, `http-delete`), plus JSON
variants that set the appropriate `Accept` / `Content-Type` headers. For full
control build a request with `(scm net http request)` and send it with
`http-send`. Every call returns an `http-response`.

## Common uses

```scheme
(import (scm net http client))

(http-get "http://example.com/")                  ;; => an http-response
(http-post "http://example.com/items" "payload")  ;; POST a body

;; JSON helpers — http-get-json sends Accept: application/json,
;; http-post-json sends a JSON string body with Content-Type: application/json:
(http-get-json "http://example.com/api/items")
(http-post-json "http://example.com/api/items" "{\"name\":\"Ada\"}")
```

Responses are the records described in `(scm net http response)` — read their
status, headers, and body with that library's accessors (and parse a JSON body
yourself with `(scm json simple)`).

## HTTPS certificate verification

HTTPS server certificates are verified against the platform's trusted root
certificates. On Windows both implementations accept certificates trusted by
the Windows certificate store (e.g. corporate root CAs deployed by group
policy); the Java implementation additionally accepts certificates trusted by
the JDK's own trust store.

Setting the environment variable `SCM_TLS_INSECURE=1` (or `true` / `yes`)
disables certificate and host name verification for all requests of this
library. This is insecure and meant only as a last resort for misconfigured
intranet servers; a warning is printed to stderr when it takes effect.
