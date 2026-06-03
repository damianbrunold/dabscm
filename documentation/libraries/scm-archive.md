# `(scm archive)`

Archive and compression — tar, gzip, bzip2, xz, and zip operations

## Exports

### `bunzip2`

```
Syntax: (bunzip2 path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .bz2) in place via
  the native bunzip2 command. Option 'keep retains the .bz2 original.
Example:
  (bunzip2 "big.log.bz2")
```

### `bzip2`

```
Syntax: (bzip2 path [option ...])
Library: (scm archive)
Description: Compresses path into path.bz2 using the native bzip2 command.
  Option 'keep retains the original file (-k).
Example:
  (bzip2 "big.log")
```

### `close-input-zip`

```
Syntax: (close-input-zip zip)
Library: (scm zip)
Description: Closes the given ZIP input archive, releasing all underlying resources.
Example:
  (let ((z (open-input-zip-file "archive.zip")))
    (close-input-zip z))
```

### `close-output-zip`

```
Syntax: (close-output-zip zip)
Library: (scm core)
Description: Closes the given zip output archive, flushing and releasing all underlying resources.
Example:
  (let ((z (open-output-zip-file "archive.zip")))
    (close-output-zip z))
```

### `deflate-compress`

```
Syntax: (deflate-compress bytevector [level])
Library: (scm compression)
Description: Compresses bytevector using raw DEFLATE (RFC 1951) and returns
  a bytevector. The optional level is an integer 0-9: 0 = no compression,
  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.
Example:
  (utf8->string (deflate-decompress (deflate-compress (string->utf8 "hello")))) => "hello"
```

### `deflate-decompress`

```
Syntax: (deflate-decompress bytevector)
Library: (scm compression)
Description: Decompresses a raw DEFLATE-compressed (RFC 1951) bytevector
  and returns the original bytevector.
Example:
  (utf8->string (deflate-decompress (deflate-compress (string->utf8 "hello")))) => "hello"
```

### `gunzip`

```
Syntax: (gunzip path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .gz) in place.
  Option 'keep retains the .gz original (-k).
Example:
  (gunzip "big.log.gz")
```

### `gzip`

```
Syntax: (gzip path [option ...])
Library: (scm archive)
Description: Compresses path into path.gz using the native gzip command
  when available; falls back to gzip-compress on the file bytes.
  Option 'keep retains the original file (-k).
Example:
  (gzip "big.log")
```

### `gzip-compress`

```
Syntax: (gzip-compress bytevector [level])
Library: (scm compression)
Description: Compresses bytevector using GZip format (RFC 1952) and returns
  a bytevector. The optional level is an integer 0-9: 0 = no compression,
  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.
Example:
  (utf8->string (gzip-decompress (gzip-compress (string->utf8 "hello")))) => "hello"
```

### `gzip-decompress`

```
Syntax: (gzip-decompress bytevector)
Library: (scm compression)
Description: Decompresses a GZip-compressed (RFC 1952) bytevector and returns
  the original bytevector.
Example:
  (utf8->string (gzip-decompress (gzip-compress (string->utf8 "hello")))) => "hello"
```

### `open-input-zip-file`

```
Syntax: (open-input-zip-file filename)
Library: (scm zip)
Description: Opens an existing ZIP archive at filename for reading and returns a ZIP reader object.
Example:
  (define z (open-input-zip-file "archive.zip"))
  (zip-entry-names z)
  (close-input-zip z)
```

### `open-output-zip-file`

```
Syntax: (open-output-zip-file filename)
Library: (scm core)
Description: Creates a new ZIP archive at the given filename and returns a ZIP writer object. Entries can be added using zip-add-text-entry or zip-add-binary-entry.
Example:
  (define z (open-output-zip-file "archive.zip"))
  (zip-add-text-entry z "hello.txt" "Hello, world!")
  (close-output-zip z)
```

### `tar-create`

```
Syntax: (tar-create archive paths [option ...])
Library: (scm archive)
Description: Creates a tar archive at path archive containing the listed
  paths. archive's extension determines compression: .tar.gz/.tgz uses
  gzip; .tar.bz2/.tbz uses bzip2; otherwise plain tar.
  Options: 'gzip (force -z), 'bzip2 (force -j), 'verbose (-v),
  '(work-dir . dir) (run as if cwd = dir).
  Shells out to the native tar command.
Example:
  (tar-create "backup.tar.gz" '("src" "docs"))
```

### `tar-extract`

```
Syntax: (tar-extract archive [option ...])
Library: (scm archive)
Description: Extracts archive into the current directory (or 'work-dir).
  Compression is auto-detected from extension or forced via 'gzip / 'bzip2.
  Options: '(work-dir . dir), 'verbose.
Example:
  (tar-extract "backup.tar.gz" '(work-dir . "/tmp/restore"))
```

### `tar-list`

```
Syntax: (tar-list archive [option ...])
Library: (scm archive)
Description: Returns a list of entry names contained in archive.
  Compression is auto-detected; force with 'gzip or 'bzip2.
Example:
  (tar-list "backup.tar.gz")
```

### `unxz`

```
Syntax: (unxz path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .xz) in place via
  the native unxz command. Option 'keep retains the .xz original.
Example:
  (unxz "big.log.xz")
```

### `xz`

```
Syntax: (xz path [option ...])
Library: (scm archive)
Description: Compresses path into path.xz using the native xz command.
  Option 'keep retains the original file (-k).
Example:
  (xz "big.log")
```

### `zip-add-binary-entry`

```
Syntax: (zip-add-binary-entry zip name [timestamp])
Library: (scm zip)
Description: Creates a new binary entry named name in the ZIP archive zip and
  returns an output binary port for writing to it. The optional timestamp is a
  Unix epoch in seconds.
Example:
  (let ((port (zip-add-binary-entry zip "data.bin"))) (write-bytevector bv port))
```

### `zip-add-stored-entry`

```
Syntax: (zip-add-stored-entry zip name bytevector [timestamp])
Library: (scm zip)
Description: Creates a new uncompressed (STORED) entry named name in the
  ZIP archive zip and writes the entire bytevector as its content. Unlike
  zip-add-binary-entry, the data is stored without compression and must be
  provided in full. The optional timestamp is a Unix epoch in seconds.
  Returns void.
Example:
  (zip-add-stored-entry zip "mimetype" (string->utf8 "application/xml") 0)
```

### `zip-add-text-entry`

```
Syntax: (zip-add-text-entry zip name [timestamp])
Library: (scm zip)
Description: Creates a new text entry named name in the ZIP archive zip and
  returns a UTF-8 textual output port for writing to it. The optional timestamp
  is a Unix epoch in seconds.
Example:
  (let ((port (zip-add-text-entry zip "readme.txt"))) (display "Hello" port))
```

### `zip-entry-names`

```
Syntax: (zip-entry-names zip)
Library: (scm zip)
Description: Returns a list of entry name strings in the ZIP archive zip.
Example:
  (zip-entry-names z) => ("file1.txt" "dir/file2.txt")
```

### `zip-files-equal?`

```
Syntax: (zip-files-equal? file1 file2)
Library: (scm zip)
Description: Returns #t if the two ZIP files have the same entry names and identical
  entry contents (compared as bytevectors), #f otherwise. Metadata differences such
  as version-made-by or external attributes are ignored.
Example:
  (zip-files-equal? "a.xlsx" "b.xlsx") => #t
```

### `zip-read-entry-bytevector`

```
Syntax: (zip-read-entry-bytevector zip name)
Library: (scm zip)
Description: Reads the contents of the entry named name from the ZIP archive zip and returns it as a bytevector.
Example:
  (zip-read-entry-bytevector z "hello.txt") => #u8(72 101 108 108 111)
```

### `zlib-compress`

```
Syntax: (zlib-compress bytevector [level])
Library: (scm compression)
Description: Compresses bytevector using ZLib framing (RFC 1950) and returns
  a bytevector. The optional level is an integer 0-9: 0 = no compression,
  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.
Example:
  (utf8->string (zlib-decompress (zlib-compress (string->utf8 "hello")))) => "hello"
```

### `zlib-decompress`

```
Syntax: (zlib-decompress bytevector)
Library: (scm compression)
Description: Decompresses a ZLib-framed (RFC 1950) bytevector and returns
  the original bytevector.
Example:
  (utf8->string (zlib-decompress (zlib-compress (string->utf8 "hello")))) => "hello"
```

