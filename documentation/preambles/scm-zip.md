## Overview

`(scm zip)` reads and writes ZIP archives. Entries are written through output
ports (text or binary) and read back by name; the `call-with-…` forms open and
reliably close the archive for you.

## Writing

`zip-add-text-entry` / `zip-add-binary-entry` return a port you write the entry's
contents to:

```scheme
(import (scm zip))

(call-with-output-zip "out.zip"
  (lambda (z)
    (let ((p (zip-add-text-entry z "hello.txt")))
      (display "hi there" p))))
```

## Reading

```scheme
(call-with-input-zip "out.zip"
  (lambda (z) (zip-entry-names z)))            ;; => ("hello.txt")

(call-with-input-zip "out.zip"
  (lambda (z) (utf8->string (zip-read-entry-bytevector z "hello.txt"))))
;; => "hi there"
```

`zip-add-stored-entry` writes an uncompressed entry, and `zip-files-equal?`
compares two archives by content (handy in tests).
