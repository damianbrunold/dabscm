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
