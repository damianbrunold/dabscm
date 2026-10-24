# `(scm net http session)`

## Overview

`(scm net http session)` keeps a login session in a signed cookie, with no
server-side session store. The cookie holds a `(scm crypto token)` token and
is always `HttpOnly` and `SameSite=Strict`, and `Secure` unless configured
off for local HTTP. `SameSite=Strict` also stops other sites from posting
forms with the user's session, so no separate CSRF token is needed.

The session only proves who signed in and when. Whether that user still
exists or may still log in is for the app to check on each request.

## Common uses

```scheme
(import (scm net http session) (scm net http response))

(define sessions (make-session-config "app_session" secret (* 60 60 12)))

;; after a successful login
(make-http-response 303
  (list (cons "Location" "/") (session-set-cookie sessions '((uid . 42))))
  "")

;; in a handler
(let ((s (session-ref sessions req)))     ; #f when not signed in
  (if s (show-home (cdr (assq 'uid s))) (http-see-other "/login")))

;; logout
(make-http-response 303
  (list (cons "Location" "/login") (session-clear-cookie sessions)) "")
```

An app mounted under a URL prefix passes `'((path . "/prefix/"))` so the
cookie is only sent to it.


## Exports

### `make-session-config`

```
Syntax: (make-session-config cookie-name secret max-age [opts])
Library: (scm net http session)
Description: Builds the configuration for signed-cookie sessions.
  secret is a bytevector, a base64 string, or a list of them (newest
  first) as for token-secrets; an invalid or short secret raises here, at
  startup. max-age is the session lifetime in seconds. opts is an alist:
  (path . "/") scopes the cookie (use "/prefix/" when the app is
  mounted under a URL prefix), (secure? . #t) sets the Secure attribute
  (set #f only for local HTTP), (purpose . "session") is the token
  purpose.
Example:
  (make-session-config "app_session" secret (* 60 60 12)
                       '((path . "/app/") (secure? . #f)))
```

### `session-clear-cookie`

```
Syntax: (session-clear-cookie cfg)
Library: (scm net http session)
Description: Returns a ("Set-Cookie" . value) header pair that removes
  the session cookie (logout).
Example:
  (make-http-response 303
    (list (cons "Location" "/login") (session-clear-cookie cfg)) "")
```

### `session-config-max-age`

*(no documentation)*

### `session-config?`

*(no documentation)*

### `session-ref`

```
Syntax: (session-ref cfg req)
Library: (scm net http session)
Description: Returns the datum stored in req's session cookie, or #f if
  there is no cookie or it is invalid or expired.
Example:
  (session-ref cfg req) => ((uid . 42) (name . "alice"))
```

### `session-set-cookie`

```
Syntax: (session-set-cookie cfg datum)
Library: (scm net http session)
Description: Returns a ("Set-Cookie" . value) header pair that starts a
  session carrying datum (see token-sign for what datum may be). Add it to
  the response, typically the redirect after a successful login.
Example:
  (make-http-response 303
    (list (cons "Location" "/") (session-set-cookie cfg '((uid . 42))))
    "")
```

