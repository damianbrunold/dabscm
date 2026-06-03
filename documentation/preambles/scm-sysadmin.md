## Overview

`(scm sysadmin)` is a convenience bundle for system-administration scripting. It
imports and re-exports a curated set of libraries so a single import gives you the
tools you typically reach for in an ops script: filesystem and find
(`(scm fs)`, `(scm fs-find)`), text processing (`(scm text)`), archives
(`(scm archive)`), remote access (`(scm net-remote)`), process/OS control
(`(scm system)`), date/time and durations (`(scm datetime)`, `(scm duration)`),
logging (`(scm log)`), globbing (`(scm glob)`), crypto (`(scm crypto)`), URIs
(`(scm uri)`), and JSON/CSV (`(scm json)`, `(scm csv)`).

## Common uses

```scheme
(import (scm sysadmin))

;; everything from the bundled libraries is now available:
(for-each
  (lambda (f) (log-info "cleanup" f) (delete-file f))
  (find-file "/tmp" '(name . "*.old") '(type . file)))
```

See the individual libraries listed above for the full set of available
procedures; `(scm sysadmin)` simply saves you from importing them one by one.
