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

## Redirects

Every call follows redirects (301, 302, 303, 307, 308) and returns the final
response, except a redirect from HTTPS to plain HTTP, whose 3xx response is
returned as is. To see a redirect itself (its status, `Location` and
`Set-Cookie`), build the request with `follow-redirects?` `#f` and send it
with `http-send`:

    (http-send (make-http-request "POST" url headers body 600 #f))

A failed request (refused connection, timeout, bad host) raises an error
naming the procedure and the cause.

## HTTPS certificate verification

HTTPS server certificates are verified against the platform's trusted root
certificates. On Windows both implementations accept certificates trusted by
the Windows certificate store (e.g. corporate root CAs deployed by group
policy); the Java implementation additionally accepts certificates trusted by
the JDK's own trust store.

On Linux and other systems the Java implementation trusts, besides the JDK's
store, the system CA bundle that curl and OpenSSL use: the PEM file named by
`SSL_CERT_FILE`, else the distribution's bundle
(`/etc/ssl/certs/ca-certificates.crt`, `/etc/pki/tls/certs/ca-bundle.crt`,
`/etc/ssl/ca-bundle.pem` or `/etc/ssl/cert.pem`). A CA added with
`update-ca-certificates` (or `update-ca-trust`) is therefore trusted whichever
JDK runs. Under WSL it also reads the Windows host's certificate stores
(Root, AuthRoot and the CA intermediates, through `powershell.exe`) when a
certificate is rejected by the others, so corporate CAs deployed to Windows
are trusted inside WSL as well.

Like Windows itself, the Java implementation also downloads intermediate
certificates that the server does not send, from the CA issuer URL in the
certificate (AIA).

Setting the environment variable `SCM_TLS_INSECURE=1` (or `true` / `yes`)
disables certificate and host name verification for all requests of this
library. This is insecure and meant only as a last resort for misconfigured
intranet servers; a warning is printed to stderr when it takes effect.

Setting `SCM_TLS_DEBUG=1` makes the Java implementation print the trust stores
it loaded and, when a certificate is rejected, the chain sent by the server
and each trust store's reason to stderr.
