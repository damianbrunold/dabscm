## Overview

`(scm random access)` opens files for random-access (seekable) reading and
writing of bytes: read or write at an arbitrary offset, query or truncate the
size, and flush. It underpins on-disk data structures such as `(scm store)`.

## Common uses

```scheme
(import (scm random access))

(call-with-random-access-file "data.bin" 'write
  (lambda (f)
    (random-access-file-write! f 0 #u8(1 2 3 4))))

(call-with-random-access-file "data.bin" 'read
  (lambda (f)
    (random-access-file-read f 0 4)))      ;; => #u8(1 2 3 4)
```

`call-with-random-access-file` opens the file in the given mode and closes it
afterwards. `random-access-file-size`, `random-access-file-truncate!`, and
`random-access-file-flush` manage the file's length and durability.
