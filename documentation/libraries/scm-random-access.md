# `(scm random access)`

Random-access file I/O — seek, read, write, truncate

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


## Exports

### `call-with-random-access-file`

```
Syntax: (call-with-random-access-file filename mode proc)
Library: (scm random access)
Description: Opens filename for random access in the given mode (the symbol
  read, write, or update), calls proc with the resulting handle, and closes
  the handle afterwards even if proc raises an error. Returns the result of
  proc.
Example:
  (call-with-random-access-file "data.store" 'read
    (lambda (f) (random-access-file-read f 0 16)))
```

### `close-random-access-file`

```
Syntax: (close-random-access-file f)
Library: (scm random access)
Description: Closes random-access file f, flushing and releasing the underlying file. Closing an already-closed handle is harmless. Returns an unspecified value.
Example:
  (close-random-access-file f)
```

### `open-random-access-file`

```
Syntax: (open-random-access-file filename mode)
Library: (scm random access)
Description: Opens filename for positioned (random-access) binary I/O and returns a random-access file handle. mode is a symbol or string: read opens an existing file read-only; write creates or truncates the file for read/write; update opens (creating if absent) for read/write without truncating. Raises a file-error on failure.
Example:
  (let ((f (open-random-access-file "data.store" 'write)))
    (random-access-file-write! f 0 #u8(1 2 3))
    (close-random-access-file f))
```

### `random-access-file-flush`

```
Syntax: (random-access-file-flush f)
Library: (scm random access)
Description: Flushes any buffered writes for random-access file f to the underlying storage. Returns an unspecified value.
Example:
  (random-access-file-flush f)
```

### `random-access-file-read`

```
Syntax: (random-access-file-read f offset count)
Library: (scm random access)
Description: Reads up to count bytes from random-access file f starting at byte offset and returns them as a freshly allocated bytevector. The returned bytevector is shorter than count (possibly empty) when the read reaches end of file. Does not affect any other read or write.
Example:
  (random-access-file-read f 0 4) => #u8(1 2 3 4)
```

### `random-access-file-size`

```
Syntax: (random-access-file-size f)
Library: (scm random access)
Description: Returns the current size of random-access file f in bytes.
Example:
  (random-access-file-size f) => 1024
```

### `random-access-file-truncate!`

```
Syntax: (random-access-file-truncate! f size)
Library: (scm random access)
Description: Sets the length of random-access file f to size bytes. Shrinks the file when size is smaller than the current length; extends it with zero bytes when larger. Returns an unspecified value.
Example:
  (random-access-file-truncate! f 0)
```

### `random-access-file-write!`

```
Syntax: (random-access-file-write! f offset bv [start [end]])
Library: (scm random access)
Description: Writes the bytes bv[start..end) to random-access file f starting at byte offset, extending the file when the write goes past the current end. start defaults to 0 and end to the length of bv. Returns the number of bytes written.
Example:
  (random-access-file-write! f 0 #u8(1 2 3)) => 3
```

### `random-access-file?`

```
Syntax: (random-access-file? obj)
Library: (scm random access)
Description: Returns #t if obj is a random-access file handle (as returned by open-random-access-file), otherwise #f.
Example:
  (random-access-file? (open-random-access-file "x" 'write)) => #t
  (random-access-file? 42) => #f
```

