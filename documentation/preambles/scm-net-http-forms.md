## Overview

`(scm net http forms)` parses `application/x-www-form-urlencoded` bodies and
query strings into an alist of decoded key/value pairs, with helpers for looking
values up.

## Common uses

```scheme
(import (scm net http forms))

(parse-www-form "name=Ada&age=37")
;; => (("name" . "Ada") ("age" . "37"))

(form-ref '(("a" . "1")) "a")        ;; => "1"
(form-ref '() "a" "-")               ;; => "-"   (default when absent)
```

`form-refs-by-prefix` collects all entries whose key starts with a given prefix —
useful for grouped fields like `opt-a`, `opt-b`:

```scheme
(form-refs-by-prefix '(("opt-a" . "1") ("name" . "x") ("opt-b" . "2")) "opt-")
;; => the opt-* entries
```
