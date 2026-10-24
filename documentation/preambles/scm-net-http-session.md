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
