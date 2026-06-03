## Overview

`(scm html builder)` renders HTML from an SXML-style tree. Strings and numbers in
content position are escaped automatically — the default is safe, so forgetting to
escape a user value cannot produce XSS. Already-trusted HTML is opted in
explicitly with `raw`.

## Tree shape

- `"text"` → escaped text
- `(tag body ...)` → `<tag>body…</tag>`
- `(tag (@ (attr value) ...) body ...)` → element with attributes
- `(raw "<b>x</b>")` → emitted verbatim (trusted)

## Common uses

```scheme
(import (scm html builder))

(html->string '(p "a & b" (b "x")))
;; => "<p>a &amp; b<b>x</b></p>"

(html->string `(div ,(raw "<b>bold</b>")))
;; => "<div><b>bold</b></div>"
```

`html->port` writes directly to a port. `html5` wraps a tree into a full document
with the `<!doctype html>` declaration — render the result with `html->string`:

```scheme
(html->string (html5 '(body "hi")))
;; => "<!doctype html>\n<html><body>hi</body></html>"
```
