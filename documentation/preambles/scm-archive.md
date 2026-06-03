## Overview

`(scm archive)` works with whole-file archives and compressed files: it creates,
extracts, and lists tar archives and compresses/decompresses individual files
with gzip, bzip2, and xz. It also re-exports the in-memory ZIP and compression
helpers from `(scm zip)` and `(scm compression)`. The tar/bzip2/xz operations
shell out to the corresponding native tools.

## Common uses

Create, list, and extract a tar archive:

```scheme
(import (scm archive))

(tar-create "backup.tar.gz" '("src" "docs"))
(tar-list "backup.tar.gz")                      ;; => list of entry names
(tar-extract "backup.tar.gz" '(work-dir . "/tmp/restore"))
```

Compress and decompress a single file:

```scheme
(gzip "big.log")        ;; => big.log.gz
(gunzip "big.log.gz")   ;; => big.log
```

`bzip2` / `bunzip2` and `xz` / `unxz` work the same way for those formats.
