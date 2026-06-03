## Overview

`(scm fs)` is the filesystem toolkit: path manipulation, directory listing and
creation, file copy/move/delete, metadata (existence, size, times, permissions),
and the current working directory. It's the foundation other libraries
(`(scm fs-find)`, `(scm archive)`, `(scm sysadmin)`) build on.

## Common uses

Path manipulation (pure string operations):

```scheme
(import (scm fs))

(join-path "/usr" "local" "bin")   ;; => "/usr/local/bin"
(base-name "/a/b/c.txt")           ;; => "c.txt"
(directory-name "/a/b/c.txt")      ;; => "/a/b"
```

Working with files and directories:

```scheme
(file-exists? "notes.txt")     ;; => #t / #f
(directory-files ".")          ;; => list of names in the directory
(copy-file "a.txt" "b.txt")
(touch "/tmp/marker")
(delete-file "b.txt")
```

`current-directory` / `cd` manage the working directory; `chmod`, `chown`,
`copy-directory`, and `delete-directory` round out the toolkit.
