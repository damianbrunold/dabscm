---
title: "Web applications: forms, sessions, middleware, static files, uploads"
part: libraries
order: 1027
libraries: (scm net http forms) (scm net http cookies) (scm net http session) (scm net http middleware) (scm net http static) (scm net http multipart)
summary: Reading form posts, password logins, signed-cookie sessions, a notes app with login and Post/Redirect/Get tested through a small cookie-keeping browser, error pages, access logs and security headers, static assets with cache busting, downloads, file uploads.
---
# Web applications: forms, sessions, middleware, static files, uploads

The [server tutorial](scm-http-server.md) covers handlers and routing. A
web application for people, not programs, needs more:

| library | does |
|---|---|
| `(scm net http forms)` | reads submitted HTML forms |
| `(scm net http cookies)` | reads `Cookie`, writes `Set-Cookie` |
| `(scm net http session)` | keeps a login in a signed cookie |
| `(scm net http middleware)` | error pages, access log, security headers |
| `(scm net http static)` | serves CSS, scripts, images and downloads |
| `(scm net http multipart)` | reads file uploads |

```scheme
(import (scheme base) (scheme file) (scheme write) (only (srfi 13) string-contains string-index)
        (scm fs) (scm log) (scm crypto) (scm crypto password) (scm html builder)
        (scm net http request) (scm net http response) (scm net http route)
        (scm net http forms) (scm net http cookies) (scm net http session)
        (scm net http middleware) (scm net http static) (scm net http multipart))
```

## Forms

A browser sends a form as `name=value` pairs joined by `&`, with special
characters percent-encoded and spaces as `+`:

```scheme
(parse-www-form "tea=Sencha&rating=4&notes=grassy%2C+sweet")
;; => (("tea" . "Sencha") ("rating" . "4") ("notes" . "grassy, sweet"))

(define form (parse-www-form "tea=Gyokuro&tag-green=on&tag-japan=on"))
(form-ref form "tea")                       ;; => "Gyokuro"
(form-ref form "rating" "3")                ;; => "3"
(map car (form-refs-by-prefix form "tag-")) ;; => ("tag-green" "tag-japan")
```

A checkbox is only sent when it is ticked, so a default is the normal
case; `form-refs-by-prefix` collects a group of them. In a handler,
`http-request-form` parses the body of the request:

```scheme
(define post (make-http-request "POST" "/notes"
                                '(("Content-Type" . "application/x-www-form-urlencoded"))
                                "tea=Assam&rating=5"))
(http-request-form post)                    ;; => (("tea" . "Assam") ("rating" . "5"))
```

Every value is a string, and anyone can send any value: check the input
before using it.

```scheme
(define (rating-of form)
  (let ((n (string->number (form-ref form "rating" ""))))
    (and n (exact-integer? n) (<= 1 n 5) n)))

(rating-of (parse-www-form "rating=4"))     ;; => 4
(rating-of (parse-www-form "rating=11"))    ;; => #f
(rating-of (parse-www-form "rating=%3Cb%3E")) ;; => #f
```

## Passwords

Store only a slow, salted hash of each password. `(scm crypto password)`
makes and checks one (the [crypto tutorial](scm-crypto.md) has more):

```scheme
(define users `(("ada" . ,(password-hash "correct horse battery"))))
(define no-user (password-hash "nobody has this password"))

(define (check-login name password)
  (let ((u (assoc name users)))
    ;; check a hash even for unknown names, so that the time taken
    ;; does not tell which names exist
    (and (password-verify password (if u (cdr u) no-user)) u name)))

(check-login "ada" "correct horse battery") ;; => "ada"
(check-login "ada" "guess")                 ;; => #f
(check-login "bob" "correct horse battery") ;; => #f
```

## Sessions

After a login, the browser has to prove on every request who it is.
`(scm net http session)` puts the user in a cookie signed with a secret
key; a changed cookie fails the check, and there is no session store on
the server:

```scheme
(define sessions
  (make-session-config "notes_session" (random-bytes 32) (* 8 60 60) '((secure? . #f))))

(define set-cookie (session-set-cookie sessions '((user . "ada"))))
(car set-cookie)                            ;; => "Set-Cookie"

(define (cookie-attributes header)          ; what follows name=value
  (substring header (string-index header #\;) (string-length header)))
(cookie-attributes (cdr set-cookie))        ;; => "; Path=/; Max-Age=28800; HttpOnly; SameSite=Strict"
```

- `HttpOnly` keeps scripts in the page from reading the cookie.
- `SameSite=Strict` stops other sites from sending requests with it, so
  forms need no extra CSRF token.
- `Secure` (HTTPS only) is on by default; it is switched off here with
  `(secure? . #f)` because the examples use plain HTTP.

The browser sends the cookie back in a `Cookie` header, and
`session-ref` checks it:

```scheme
(define (cookie-of header)                  ; "name=value" of a Set-Cookie value
  (substring header 0 (string-index header #\;)))

(define (request-with cookie)
  (make-http-request "GET" "/" (list (cons "Cookie" cookie)) #f))

(session-ref sessions (request-with (cookie-of (cdr set-cookie)))) ;; => ((user . "ada"))
(session-ref sessions (request-with "notes_session=forged.signature")) ;; => #f
(session-ref sessions (make-http-request "GET" "/" '() #f)) ;; => #f
```

The cookie is signed, not encrypted: the user can read what it holds, so
keep it to an id. A real application reads its secret from its
configuration (`random-bytes` here means every restart logs everyone
out). `session-clear-cookie` logs out, and `(scm net http cookies)` reads
and writes other cookies, a theme or a language:

```scheme
(parse-cookie-header "notes_session=abc; theme=dark") ;; => (("notes_session" . "abc") ("theme" . "dark"))
(cookie-ref (parse-cookie-header "notes_session=abc; theme=dark") "theme") ;; => "dark"
(format-set-cookie "theme" "dark" (* 365 24 60 60) "/" 'no-secure)
;; => "theme=dark; Path=/; Max-Age=31536000; HttpOnly; SameSite=Strict"
```

## Example: tasting notes with a login

Signed-in users write tasting notes; everyone else is sent to the login
page. After a successful POST the app redirects (303 See Other), so
reloading the page does not submit the form again: this is
Post/Redirect/Get.

```scheme
(define notes '())                          ; (user tea rating), newest first

(define (page title . body)
  (html-response
   (html->string `(html (head (title ,title)) (body (h1 ,title) ,@body)))))

(define (current-user req)
  (let ((s (session-ref sessions req)))
    (and s (cdr (assq 'user s)))))

(define (login-page req params)
  (page "Sign in"
        `(form (@ (method "post") (action "/login"))
               (input (@ (name "user"))) (input (@ (name "password") (type "password")))
               (button "Sign in"))))

(define (login req params)
  (let* ((form (http-request-form req))
         (user (check-login (form-ref form "user" "") (form-ref form "password" ""))))
    (if user
        (make-http-response 303 (list (cons "Location" "/") (session-set-cookie sessions `((user . ,user)))) "")
        (http-see-other "/login?failed=1"))))

(define (home req params)
  (let ((user (current-user req)))
    (if (not user)
        (http-see-other "/login")
        (page (string-append user "'s notes")
              `(ul ,@(map (lambda (n) `(li ,(cadr n) ": " ,(number->string (caddr n)) "/5"))
                          (filter-notes user)))))))

(define (filter-notes user)
  (let loop ((ns notes) (acc '()))
    (cond ((null? ns) (reverse acc))
          ((equal? (car (car ns)) user) (loop (cdr ns) (cons (car ns) acc)))
          (else (loop (cdr ns) acc)))))

(define (add-note req params)
  (let ((user (current-user req)) (form (http-request-form req)))
    (cond ((not user) (http-forbidden))
          ((not (rating-of form)) (http-bad-request "rating must be 1 to 5"))
          (else (set! notes (cons (list user (form-ref form "tea" "?") (rating-of form)) notes))
                (http-see-other "/")))))

(define (logout req params)
  (make-http-response 303 (list (cons "Location" "/login") (session-clear-cookie sessions)) ""))

(define app (make-router))
(router-add! app "GET" "/login" login-page)
(router-add! app "POST" "/login" login)
(router-add! app "GET" "/" home)
(router-add! app "POST" "/notes" add-note)
(router-add! app "POST" "/logout" logout)
```

To try it out without a browser, a few lines play one: they keep the
cookie a response sets and send it with every following request.

```scheme
(define jar #f)                             ; the session cookie, "name=value"

(define (browse method path . body)
  (let* ((headers (append (if jar (list (cons "Cookie" jar)) '())
                          (if (null? body) '()
                              '(("Content-Type" . "application/x-www-form-urlencoded")))))
         (resp (router-dispatch app (make-http-request method path headers
                                                       (if (null? body) #f (car body)))))
         (set (http-response-header resp "Set-Cookie")))
    (when set
      (set! jar (if (string-contains set "Max-Age=0") #f (cookie-of set))))
    resp))

(http-response-header (browse "GET" "/") "Location") ;; => "/login"
(http-response-header (browse "POST" "/login" "user=ada&password=guess") "Location")
;; => "/login?failed=1"
(http-response-header (browse "POST" "/login" "user=ada&password=correct+horse+battery") "Location")
;; => "/"
(http-response-status (browse "POST" "/notes" "tea=Sencha&rating=4")) ;; => 303
(http-response-status (browse "POST" "/notes" "tea=Matcha&rating=9")) ;; => 400
(browse "POST" "/notes" "tea=<b>Bancha</b>&rating=5")
(http-response-body (browse "GET" "/"))
;; => "<html><head><title>ada&#39;s notes</title></head><body><h1>ada&#39;s notes</h1><ul><li>&lt;b&gt;Bancha&lt;/b&gt;: 5/5</li><li>Sencha: 4/5</li></ul></body></html>"
(browse "POST" "/logout")
jar                                         ;; => #f
(http-response-status (browse "POST" "/notes" "tea=Assam&rating=3")) ;; => 403
```

The note with HTML in its name shows as text: `(scm html builder)`
escapes it (and the apostrophe, which matters inside attributes).

## Error pages, logs and security headers

`(scm net http middleware)` wraps a handler in another handler:

- `with-error-handler` turns an error into a 500 page and logs it: the
  visitor never sees the error message.
- `with-access-log` logs one line per request.
- `with-security-headers` adds headers that tell browsers to load
  scripts, styles and frames only from the site itself.

```scheme
(router-add! app "GET" "/broken" (lambda (req params) (error "database unreachable" "notes")))

(define handler
  (with-access-log
   (with-security-headers
    (with-error-handler (router->handler app)
                        (lambda (req) (page "Sorry" '(p "Something went wrong. Please try again later.")))))))

(define log (open-output-string))
(define broken
  (parameterize ((log-port log))
    (handler (make-http-request "GET" "/broken?id=7" '() #f))))
(http-response-status broken)               ;; => 500
(http-response-header broken "X-Frame-Options") ;; => "DENY"
(integer? (string-contains (http-response-body broken) "Something went wrong")) ;; => #t
```

The log has the error and the access line, and no query string, which
may hold search terms or tokens:

```scheme
(define logged (get-output-string log))
(define (contains? text part) (and (string-contains text part) #t))

(contains? logged "ERROR [http] GET /broken raised: database unreachable") ;; => #t
(contains? logged "INFO  [http] GET /broken -> 500") ;; => #t
(contains? logged "id=7")                   ;; => #f
```

The order matters: the error handler goes innermost, so the access log
sees the 500 it produced. Logging goes through `(scm log)`, to the error
port unless `log-port` says otherwise.

## Static files

CSS, scripts and images come from a directory, served under a wildcard
route. `make-static-url` adds the file's modification time to the URL, so
browsers may cache assets for a year and still get each new version:

```scheme
(define site (mktempdir '(prefix . "notes-site")))
(make-directory (join-path site "static"))
(call-with-output-file (join-path site "static/site.css")
  (lambda (p) (write-string "body { font-family: sans-serif; }" p)))

(router-add! app "GET" "/static/*" (make-static-handler (join-path site "static")))
(define static-url (make-static-url (join-path site "static") "/static"))

(define css-url (static-url "site.css"))
(contains? css-url "/static/site.css?v=")   ;; => #t

(define css (router-dispatch app (make-http-request "GET" css-url '() #f)))
(http-response-header css "Content-Type")   ;; => "text/css; charset=utf-8"
(http-response-header css "Cache-Control")  ;; => "public, max-age=31536000, immutable"
```

A browser that has the file already asks with its ETag and gets a short
304 Not Modified. Paths that try to leave the directory, and hidden files,
get 404:

```scheme
(define again (router-dispatch app (make-http-request "GET" "/static/site.css"
                                                      (list (cons "If-None-Match" (http-response-header css "ETag"))) #f)))
(http-response-status again)                ;; => 304
(http-response-status (router-dispatch app (make-http-request "GET" "/static/../secret" '() #f))) ;; => 404
(http-response-status (router-dispatch app (make-http-request "GET" "/static/.env" '() #f))) ;; => 404
(mime-type "logo.SVG")                      ;; => "image/svg+xml"
```

`file-response` sends a single file, and `(filename . …)` makes it a
download:

```scheme
(call-with-output-file (join-path site "notes.csv") (lambda (p) (write-string "tea,rating\nSencha,4\n" p)))
(define download (file-response (join-path site "notes.csv") '((filename . "my notes.csv"))))
(http-response-header download "Content-Disposition") ;; => "attachment; filename=\"my notes.csv\"; filename*=UTF-8''my%20notes.csv"
```

The second form of the name is for names with non-ASCII characters,
which the first cannot carry everywhere. Range requests work too (pass `(request . req)`), so videos can seek and
broken downloads resume.

## Uploads

A form with `enctype="multipart/form-data"` sends files. Each part has a
name, for a file a file name and content type, and a body:

```scheme
(define upload-body
  (string-append
   "--b0undary\r\nContent-Disposition: form-data; name=\"tea\"\r\n\r\nSencha\r\n"
   "--b0undary\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"cup.txt\"\r\n"
   "Content-Type: text/plain\r\n\r\na picture of a cup\r\n--b0undary--\r\n"))

(define upload (make-http-request "POST" "/photos"
                                  '(("Content-Type" . "multipart/form-data; boundary=b0undary"))
                                  upload-body))

(define (save-upload req dir)
  (let* ((boundary (multipart-boundary (http-request-header req "Content-Type")))
         (parts (parse-multipart-bytes (http-request-body-bytes req) boundary))
         (file (let loop ((ps parts))
                 (cond ((null? ps) #f)
                       ((part-ref (car ps) 'filename) (car ps))
                       (else (loop (cdr ps)))))))
    (and file
         (let ((out (open-binary-output-file (join-path dir "photo-1.bin"))))
           (write-bytevector (part-ref file 'body) out)
           (close-port out)
           (list (part-ref file 'filename) (part-ref file 'content-type)
                 (bytevector-length (part-ref file 'body)))))))

(save-upload upload site)                   ;; => ("cup.txt" "text/plain" 18)
(rm site 'recursive)
```

- `parse-multipart-bytes` keeps binary files intact; `parse-multipart`
  is for text-only forms.
- Never use the uploaded file name as a path: it comes from the client.
  Store under a name of your own, as here, and keep the original name as
  data.
- Check what arrived (`(scm image)`'s `image-info` for pictures).
- Bodies above 4 MB get 413 unless the server is started with a larger
  limit; bodies above 1 MB are spooled to a temporary file
  (`http-request-body-file`), which can be moved into place.

## Putting it together

```scheme no-test
(define server
  (tcp-http-serve 8080 handler 32 "127.0.0.1" 0 (* 50 1024 1024)))   ; uploads up to 50 MB
(server-install-shutdown-hook server)
(server-wait server)
```

`scm new-app starter-login` writes a complete application along these
lines: users in a database, login, sessions, templates, static assets and
tests ([scaffold](scm-scaffold.md)).

## Where next

- [HTML](scm-html.md) for pages, [templating](scm-templating.md),
  [crypto](scm-crypto.md) for passwords and tokens,
  [databases](scm-database.md) for keeping the notes.
- Reference: `(scm net http forms)`, `(scm net http cookies)`,
  `(scm net http session)`, `(scm net http middleware)`,
  `(scm net http static)`, `(scm net http multipart)`.
