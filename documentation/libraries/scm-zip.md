# `(scm zip)`

ZIP archive creation and entry writing

## Exports

### `call-with-input-zip`

```
Syntax: (call-with-input-zip filename proc)
Library: (scm zip)
Description: Opens an existing ZIP archive at filename, calls proc with the zip
  handle, and ensures the archive is closed when proc returns or raises an
  error. Returns the result of proc.
Example:
  (call-with-input-zip "archive.zip" (lambda (z) (zip-entry-names z))) => ("file.txt")
```

### `call-with-output-zip`

```
Syntax: (call-with-output-zip filename proc)
Library: (scm zip)
Description: Opens a new ZIP archive at filename, calls proc with the zip
  handle, and ensures the archive is closed when proc returns or raises an
  error. Returns the result of proc.
Example:
  (call-with-output-zip "out.zip" (lambda (z) ...)) => unspecified
```

### `call-with-output-zip-bytevector`

```
Syntax: (call-with-output-zip-bytevector proc)
Library: (scm zip)
Description: Creates a new in-memory ZIP archive, calls proc with the zip
  handle, closes the archive, and returns the accumulated bytes as a bytevector.
  The archive is closed even if proc raises an error.
Example:
  (call-with-output-zip-bytevector
    (lambda (z) (call-with-output-zip-entry z "hello.txt"
                  (lambda (p) (display "hi" p))))) => #u8(...)
```

### `call-with-output-zip-entry`

```
Syntax: (call-with-output-zip-entry zip entry-name proc [time])
Library: (scm zip)
Description: Adds a new text entry named entry-name to the ZIP archive zip,
  calls proc with the output port for that entry, and ensures the port is
  flushed when proc returns or raises an error. The optional time argument
  is a Unix timestamp (integer seconds); if omitted the current time is used.
  Returns the result of proc.
Example:
  (call-with-output-zip-entry z "readme.txt"
    (lambda (p) (display "hello" p))) => unspecified
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

### `get-output-zip-bytevector`

```
Syntax: (get-output-zip-bytevector zip)
Library: (scm zip)
Description: Returns the contents of an in-memory ZIP archive as a bytevector. Must be called after close-output-zip to ensure all entries are flushed.
Example:
  (let ((z (open-output-zip-bytevector)))
    (close-output-zip z)
    (get-output-zip-bytevector z))
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

### `open-output-zip-bytevector`

```
Syntax: (open-output-zip-bytevector)
Library: (scm zip)
Description: Creates a new in-memory ZIP archive and returns a ZIP writer object. After writing entries and calling close-output-zip, use get-output-zip-bytevector to retrieve the bytes.
Example:
  (let ((z (open-output-zip-bytevector)))
    (zip-add-text-entry z "hello.txt")
    (close-output-zip z)
    (get-output-zip-bytevector z))
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

