# `(scm net http static)`

## Overview

`(scm net http static)` serves files: a directory of assets (CSS, JS,
images) behind a router wildcard, or single files for download routes. It
sets the content type, an ETag (answering `If-None-Match` with 304) and
`X-Content-Type-Options: nosniff`, and refuses paths that could leave the
directory or reach hidden files. Files are sent from disk, whatever their
size, and a `Range` request gets 206 Partial Content (or 416), so videos
can seek and downloads resume.

`make-static-url` builds asset URLs with `?v=<modification time>`. Such
requests are cached by browsers for a year, and because the version changes
whenever the file does, a page never runs a stale copy.

## Common uses

```scheme
(import (scm net http route) (scm net http static))

(define static-url (make-static-url "static" "/static"))

(router-add! router "GET" "/static/*" (make-static-handler "static"))

;; in a page:  (link (@ (rel "stylesheet") (href ,(static-url "site.css"))))

;; a download route
(router-add! router "GET" "/reports/:id"
  (lambda (req params)
    (file-response (report-path (params-ref params "id"))
                   `((request . ,req) (filename . "report.pdf")))))
```


## Exports

### `file-response`

```
Syntax: (file-response path [opts])
Library: (scm net http static)
Description: Returns a 200 response with the file at path, or 404 if it
  does not exist or is a directory. The body is sent from the file (see
  make-http-file-response), so files of any size work. The response
  carries the file's Content-Type (mime-type), a weak ETag from its
  modification time and size, Accept-Ranges: bytes and
  X-Content-Type-Options: nosniff. opts is an alist: (request . req)
  answers 304 Not Modified when req's If-None-Match matches, and a single
  Range (bytes=a-b, a-, -n) with 206 Partial Content and Content-Range, or
  416 when it lies outside the file (If-Range is honoured), so audio and
  video can seek and downloads resume; (cache-control . string) sets Cache-Control (default
  "no-cache": cache, but revalidate); (content-type . string) overrides
  the type; (filename . string) makes it a download with that name.
  path must not come from the client unchecked; make-static-handler does
  the checking for a directory of assets.
Example:
  (file-response "/var/lib/app/reports/r1.pdf"
                 `((request . ,req) (filename . "Report 2026.pdf")))
```

### `make-static-handler`

```
Syntax: (make-static-handler dir [opts])
Library: (scm net http static)
Description: Returns a router handler that serves the files under dir for
  a route ending in the * wildcard, e.g.
  (router-add! r "GET" "/static/*" (make-static-handler "static")).
  Paths are percent-decoded per segment; empty segments, ".", "..",
  dot-files and segments containing / \ or NUL get 404, as do missing
  files and directories. A request with a v= query parameter (see
  make-static-url) is cached for a year as immutable; others get the
  (cache-control . string) option, default "public, max-age=300". ETag
  and If-None-Match (304) work as in file-response.
Example:
  (router-add! router "GET" "/static/*"
    (make-static-handler "/opt/app/static" '((cache-control . "no-cache"))))
```

### `make-static-url`

```
Syntax: (make-static-url dir base-url)
Library: (scm net http static)
Description: Returns a procedure (lambda (rel) ...) that builds the URL of
  the asset rel under dir, as served at base-url, with ?v=<modification
  time> appended. The version changes whenever the file does, so pages can
  let browsers cache assets for good (make-static-handler does) and still
  never run a stale copy. The file is checked on every call, so edits need
  no restart; a missing file gets no version.
Example:
  (define static-url (make-static-url "static" "/app/static"))
  (static-url "site.css") => "/app/static/site.css?v=1761290000000"
```

### `mime-type`

```
Syntax: (mime-type path)
Library: (scm net http static)
Description: Returns the Content-Type for path from its extension (case
  insensitive). Text types carry charset=utf-8; an unknown extension gives
  application/octet-stream.
Example:
  (mime-type "static/app.css") => "text/css; charset=utf-8"
  (mime-type "logo.PNG") => "image/png"
```

