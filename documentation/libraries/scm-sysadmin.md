# `(scm sysadmin)`

System administration toolkit aggregating fs, archive, remote, logging, and more

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


## Exports

### `absolute-path`

```
Syntax: (absolute-path path)
Library: (scm fs)
Description: Returns the absolute (fully qualified) form of the given path string.
Example:
  (absolute-path ".") => "/current/working/dir"
```

### `awk`

```
Syntax: (awk action src [option ...])
Library: (scm text)
Description: For each line of src, splits the line into fields and calls
  action with three arguments: the field list, the 1-based line number,
  and the original line. Returns the list of action results (with #f
  results filtered out, matching awk's pattern-action style where lines
  without a print produce no output).
  Options:
    '(delimiter . str) — field separator (default any run of whitespace)
    '(filter . pred)   — only call action when (pred fields line-no line)
                         returns true; equivalent to an awk pattern
Example:
  ;; print second field of each line
  (awk (lambda (fs n l) (list-ref fs 1)) "data.tsv")
  ;; filter and reformat /etc/passwd: name:uid for shells of /bin/bash
  (awk (lambda (fs n l)
         (string-append (list-ref fs 0) ":" (list-ref fs 2)))
       "/etc/passwd"
       '(delimiter . ":")
       `(filter . ,(lambda (fs n l)
                     (and (> (length fs) 6)
                          (string=? (list-ref fs 6) "/bin/bash")))))
```

### `base-name`

```
Syntax: (base-name path)
Library: (scm fs)
Description: Returns the file name (including extension) from the given path string, without the directory part.
Example:
  (base-name "/usr/share/doc/readme.txt") => "readme.txt"
```

### `base64-decode`

```
Syntax: (base64-decode string)
Library: (scm crypto)
Description: Decodes a base64-encoded string and returns a bytevector.
Example:
  (base64-decode "SGVsbG8=") => #u8(72 101 108 108 111)
```

### `base64-encode`

```
Syntax: (base64-encode bytevector)
Library: (scm crypto)
Description: Returns the base64-encoded string of a bytevector.
Example:
  (base64-encode #u8(72 101 108 108 111)) => "SGVsbG8="
```

### `bunzip2`

```
Syntax: (bunzip2 path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .bz2) in place via
  the native bunzip2 command. Option 'keep retains the .bz2 original.
Example:
  (bunzip2 "big.log.bz2")
```

### `bytevector->hex`

```
Syntax: (bytevector->hex bv)
Library: (scm crypto)
Description: Returns the lowercase hexadecimal string representation of the
  bytevector bv (two hex digits per byte, no separators).
Example:
  (bytevector->hex #u8(0 15 255)) => "000fff"
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

### `cat`

```
Syntax: (cat src ...)
Library: (scm text)
Description: Returns the concatenated contents of all src arguments as a
  single string, joining lines with newline. Each src is a filename, port,
  or list of strings.
Example:
  (cat "a.txt" "b.txt")
```

### `cd`

```
Syntax: (set-current-directory! path)
Library: (scm core)
Description: Sets the process working directory hint to path. Returns the new directory as a string on success, #f on failure. Note: in the JVM the OS-level cwd cannot be changed for already-loaded native code; the value is recorded so that subsequent relative-path operations and child-process invocations behave as if cwd were path.
Example:
  (set-current-directory! "/tmp") => "/tmp"
```

### `chmod`

```
Syntax: (chmod path mode [option ...])
Library: (scm fs)
Description: Changes file mode bits via the native chmod command. mode is
  either an octal string (e.g. "755") or a symbolic spec ("u+x").
  Options: 'recursive (-R). On Windows this is a best-effort no-op when
  no native chmod is available.
Example:
  (chmod "script.sh" "755")
  (chmod "dir" "700" 'recursive)
```

### `chown`

```
Syntax: (chown path owner [option ...])
Library: (scm fs)
Description: Changes the owner (and optionally group) of path. owner is a
  string like "user" or "user:group". Options: 'recursive (-R).
  Returns #t on success, #f otherwise. Best-effort no-op on Windows.
Example:
  (chown "file" "alice:staff")
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

### `close-json`

```
Syntax: (close-json reader)
Library: (scm core)
Description: Closes the given JSON reader, releasing any underlying resources.
Example:
  (let ((r (open-json-file "data.json")))
    (close-json r))
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

### `copy-directory`

```
Syntax: (copy-directory src dest)
Library: (scm fs)
Description: Recursively copies the directory at src to dest. Returns unspecified on success, #f on failure.
Example:
  (copy-directory "/src/dir" "/dst/dir")
```

### `copy-file`

```
Syntax: (copy-file src dest)
Library: (scm fs)
Description: Copies the file at src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.
Example:
  (copy-file "data.txt" "backup.txt")
```

### `cp`

```
Syntax: (cp src dst [option ...])
Library: (scm fs)
Description: Copies src to dst. Options: 'recursive (-r) to copy a directory.
  When src is a directory and 'recursive is not given, signals an error.
Example:
  (cp "a.txt" "b.txt")
  (cp "src/" "dst/" 'recursive)
```

### `csv-line->fields`

```
Syntax: (csv-line->fields str sep) (csv-line->fields str sep 'trim)
Library: (scm core)
Description: Splits a CSV line string using the given separator, stripping surrounding double-quotes from each field. When 'trim is given as a third argument, also trims whitespace from each field.
Example:
  (csv-line->fields "a,b,c" ",") => ("a" "b" "c")
  (csv-line->fields "\"hello\",world" ",") => ("hello" "world")
```

### `curl`

```
Syntax: (curl url [option ...])
Library: (scm net-remote)
Description: Performs an HTTP(S) request via the native curl command.
  By default returns the response body as a string. Options:
    '(method . str)        — HTTP method (default GET)
    '(headers . list)      — list of header strings "Name: value"
    '(data . str)          — request body (sets method to POST if unset)
    '(output . path)       — write body to file; returns #t/#f
    '(timeout . seconds)
    'silent                — suppress progress (-s)
    'follow-redirects      — -L
    'fail-on-error         — -f (non-2xx exit non-zero)
    'include-status        — return (status . body) instead of body
    'pure                  — force pure-Scheme path (uses (scm net http client));
                             does not honor follow-redirects, timeout, fail-on-error
Example:
  (curl "https://example.com/api"
        '(method . "POST")
        '(headers . ("Content-Type: application/json"))
        '(data . "{\"x\":1}")
        'silent)
```

### `current-directory`

```
Syntax: (current-directory)
Library: (scm fs)
Description: Returns the current working directory as a string.
Example:
  (current-directory) => "/home/user/projects"
```

### `current-pid`

```
Syntax: (current-pid)
Library: (scm system)
Description: Returns the OS process id of the current Scheme process.
Example:
  (current-pid) => 12345
```

### `cut`

```
Syntax: (cut src [option ...])
Library: (scm text)
Description: Selects fields from each line of src. Options:
  '(fields . (n ...)) — 1-based field indices to keep (required);
  '(delimiter . str) — field separator (default tab).
Example:
  (cut "/etc/passwd" '(fields . (1 3)) '(delimiter . ":"))
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

### `delete-directory`

```
Syntax: (delete-directory dir)
Library: (scm fs)
Description: Recursively deletes the directory at dir. Returns unspecified on success, #f on failure.
Example:
  (delete-directory "/tmp/old-dir")
```

### `delete-file`

```
Syntax: (delete-file filename)
Library: (scheme file)
Description: Deletes the named file. Returns unspecified if successful, #f if the file could not be deleted.
Example:
  (delete-file "temp.txt")
```

### `df`

```
Syntax: (df [path])
Library: (scm fs-find)
Description: Returns a list of alists describing mounted filesystems.
  Each entry has keys: filesystem, size, used, available, use% (string),
  mount. Shells out to the native df command; returns '() if unavailable.
  When a path argument is given, restricts to that filesystem.
Example:
  (df)
  (df "/home")
```

### `diff`

```
Syntax: (diff a b [option ...])
Library: (scm text)
Description: Compares two text inputs a and b and returns a unified-diff
  string (or #t when 'brief and inputs are identical, #f when different).
  a and b may each be a filename string, an input port, or a list of
  lines. Options:
    'unified                 — produce unified diff (default; -u)
    'brief                   — return #t/#f only (-q)
    'ignore-case             — case-insensitive comparison (-i)
    'ignore-whitespace       — ignore whitespace differences (-w, native only)
    '(context-lines . n)     — n lines of context (default 3, -U n)
    '(label-a . str)         — label for file a in the header
    '(label-b . str)         — label for file b in the header
    'pure                    — force pure-Scheme path (LCS-based)
  When the native diff command is on PATH and both inputs are filenames,
  diff shells out for full feature parity.
Example:
  (diff "old.txt" "new.txt")
  (diff a-lines b-lines 'brief)
```

### `directory-directories`

```
Syntax: (directory-directories dirname)
Library: (scm fs)
Description: Returns a list of subdirectory names (not full paths) in the directory dirname.
Example:
  (directory-directories "/usr") => ("bin" "lib" "share" ...)
```

### `directory-exists?`

```
Syntax: (directory-exists? dirname)
Library: (scm fs)
Description: Returns #t if the given path names an existing directory, otherwise returns #f.
Example:
  (directory-exists? "/tmp") => #t
  (directory-exists? "/nonexistent") => #f
```

### `directory-files`

```
Syntax: (directory-files dirname)
Library: (scm fs)
Description: Returns a list of file names (not full paths) in the directory dirname.
Example:
  (directory-files "/tmp") => ("file1.txt" "file2.txt" ...)
```

### `directory-name`

```
Syntax: (directory-name path)
Library: (scm fs)
Description: Returns the directory part of the given path as an absolute path string, or #f if there is no parent directory.
Example:
  (directory-name "/usr/share/readme.txt") => "/usr/share"
```

### `du`

```
Syntax: (du path [option ...])
Library: (scm fs-find)
Description: Returns the total size in bytes of path. If path is a
  directory the size is the recursive sum of all contained files.
  Option 'apparent (default) counts file-size; 'block-size sums via
  the native du command for filesystem block-aligned totals when
  available.
Example:
  (du "/var/log")
```

### `env-list`

```
Syntax: (env-list)
Library: (scm system)
Description: Returns an alist of all environment variables as (name . value)
  pairs. Equivalent to SRFI-98 get-environment-variables.
Example:
  (env-list) => (("PATH" . "/usr/bin") ...)
```

### `file-exists?`

```
Syntax: (file-exists? filename)
Library: (scheme file)
Description: Returns #t if the named file exists, otherwise returns #f.
Example:
  (file-exists? "/etc/hosts") => #t
  (file-exists? "/nonexistent") => #f
```

### `file-modification-date`

```
Syntax: (file-modification-date filename)
Library: (scm fs)
Description: Returns the last modification time of the file as seconds since the Unix epoch (UTC).
Example:
  (file-modification-date "data.txt") => 1700000000
```

### `file-modification-timestamp`

```
Syntax: (file-modification-timestamp filename)
Library: (scm fs)
Description: Returns the last modification time of the file as a millisecond timestamp (milliseconds since the Unix epoch, UTC).
Example:
  (file-modification-timestamp "data.txt") => 1700000000000
```

### `file-size`

```
Syntax: (file-size file)
Library: (scm fs)
Description: Returns the size of the named file in bytes as an exact integer, or #f if the file cannot be accessed.
Example:
  (file-size "/etc/hosts") => 221
```

### `find-file`

```
Syntax: (find-file root [option ...])
Library: (scm fs-find)
Description: Recursively walks the filesystem starting at root and returns
  the list of matching paths. Options:
    '(name . glob)         — match the basename against a glob pattern
    '(type . sym)          — restrict to 'file or 'directory
    '(maxdepth . n)        — limit recursion depth (root is depth 0)
    '(mindepth . n)        — exclude entries shallower than n
    '(predicate . proc)    — additional (string -> bool) test
    '(action . proc)       — invoke proc on each matching path
Example:
  (find-file "." '(name . "*.scm") '(type . file))
  (find-file "/var/log" `(predicate . ,(lambda (p) (> (file-size p) 1024))))
```

### `format-duration`

```
Syntax: (format-duration seconds)
Library: (scm duration)
Description: Human-readable inverse of parse-duration. Emits a d/h/m suffix
  when seconds divides evenly by 86400/3600/60; otherwise emits a plain
  seconds value with the s suffix. Non-integer or negative input is
  rendered as the integer itself (or empty string for non-numbers).
Example:
  (format-duration 3600)  => "1h"
  (format-duration 86400) => "1d"
  (format-duration 90)    => "90s"
  (format-duration 0)     => "0s"
```

### `format-iso8601`

```
Syntax: (format-iso8601 unix-seconds)
Library: (scm datetime)
Description: Formats a Unix-seconds integer as an ISO 8601 UTC string
  ('YYYY-MM-DDTHH:MM:SSZ'). Negative inputs (pre-1970) are not supported.
Example:
  (format-iso8601 1715862896) => "2024-05-16T12:34:56Z"
  (format-iso8601 (parse-iso8601 "2024-05-16T14:34:56+02:00"))
    => "2024-05-16T12:34:56Z"
```

### `get-bytes`

```
Syntax: (get-bytes obj [encoding])
Library: (scm core)
Description: Returns the byte representation of obj (string, symbol, or bytevector) as a bytevector.
  encoding is an optional string or symbol specifying the character encoding (default: utf-8).
  Supported encodings: utf-8, utf-8-bom, latin-1, utf-16, utf-16-le.
Example:
  (get-bytes "hello")
  (get-bytes "hello" "latin-1")
```

### `get-environment-variable`

```
Syntax: (get-environment-variable name)
Library: (scm system) (scheme process-context) (srfi 98)
Description: Returns the value of the environment variable named name as a string, or #f if it is not set.
Example:
  (get-environment-variable "HOME") => "/home/user"
  (get-environment-variable "UNDEFINED_VAR") => #f
```

### `getopt`

```
Syntax: (getopt argv spec)
Library: (scm system)
Description: Parses command-line arguments. argv is a list of strings;
  spec is a list of option descriptors, each one of:
    (long-name short-char takes-value? [default])
  where long-name is a string (without the --), short-char is a character
  (or #f), takes-value? is a boolean, and default is the value used when
  the option is absent (defaults to #f for non-value flags, #f for
  value-taking options). Returns (alist . positionals) where alist maps
  long-name strings to the supplied values (#t for absent boolean flags
  is replaced by the default). Unknown options raise an error.
Example:
  (getopt '("-v" "--name" "foo" "a" "b")
          '(("verbose" #\v #f)
            ("name"    #\n #t "anon")))
  => ((("verbose" . #t) ("name" . "foo")) . ("a" "b"))
```

### `glob`

```
Syntax: (glob pattern)
Library: (scm glob)
Description: Returns a sorted list of file and directory paths matching
  the glob pattern. Supports * (any characters except path separator),
  ? (single character), [...] character classes, and ** (recursive
  globstar matching zero or more directory levels). Dotfiles are not
  matched by *, ?, or ** unless the pattern segment explicitly starts
  with a dot. Returns an empty list if no matches are found or the
  base directory does not exist.
Example:
  (glob "src/*.scm") => ("src/bar.scm" "src/foo.scm")
  (glob "**/*.sld") => ("lib/a.sld" "lib/sub/b.sld")
```

### `glob-match?`

```
Syntax: (glob-match? pattern string)
Library: (scm glob)
Description: Tests whether string matches the glob pattern. Supports *
  (any characters except path separator), ? (single character except path
  separator), [...] character classes with ranges and negation ([!...]),
  and ** (matches zero or more path segments including separators).
  This is a pure string operation with no filesystem access.
Example:
  (glob-match? "*.scm" "foo.scm")       => #t
  (glob-match? "src/**/*.scm" "src/lib/foo.scm") => #t
  (glob-match? "[abc].txt" "b.txt")     => #t
```

### `grep`

```
Syntax: (grep pattern src [option ...])
Library: (scm text)
Description: Returns the list of lines in src matching pattern. src may
  be a filename string, a list of strings, or an input port. Options:
  'ignore-case (-i), 'invert-match (-v), 'line-number (-n) (returns
  (list line-no line) pairs), 'count (-c) (returns integer match count),
  'fixed-strings (-F) (literal match; this is also the default in pure
  mode), 'pure (force pure-Scheme path).
  When 'pure is not set and the native grep command is on PATH and src
  is a filename, grep shells out to it for full POSIX regex support.
Example:
  (grep "ERROR" "log.txt" 'ignore-case 'line-number)
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

### `head`

```
Syntax: (head src [option ...])
Library: (scm text)
Description: Returns the first n lines of src (default 10). Options:
  '(lines . n) sets the count.
Example:
  (head "log.txt" '(lines . 5))
```

### `hex->bytevector`

```
Syntax: (hex->bytevector s)
Library: (scm crypto)
Description: Parses a hexadecimal string (case-insensitive, no separators)
  into a bytevector. Raises an error on odd length or non-hex characters.
Example:
  (hex->bytevector "000fff") => #u8(0 15 255)
  (hex->bytevector "DEADBEEF") => #u8(222 173 190 239)
```

### `hexdump`

```
Syntax: (hexdump bv [option ...])
Library: (scm text)
Description: Formats a bytevector as a canonical hex+ASCII dump (similar
  to xxd or hexdump -C), returning a string. Options:
    '(width . n)    — bytes per row (default 16)
    '(offset . n)   — starting offset for the address column (default 0)
    'no-ascii       — omit the trailing ASCII gutter
Example:
  (display (hexdump (string->utf8 "hello world")))
```

### `join-path`

```
Syntax: (join-path part ...)
Library: (scm fs)
Description: Joins one or more path component strings into a single path
  string using the platform's path separator character.
Example:
  (join-path "/usr" "local" "bin") => "/usr/local/bin"  ; on Unix
```

### `json-attribute`

```
Syntax: (json-attribute object name) (json-attribute object name default)
Library: (scm core)
Description: Returns the value of the named attribute from a JSON object. Returns default (or #f) if the attribute does not exist.
Example:
  (let ((obj (json-next-object reader)))
    (json-attribute obj 'name "unknown"))
```

### `json-next-object`

```
Syntax: (json-next-object reader)
Library: (scm core)
Description: Reads and returns the next JSON object from the given JSON reader, or #f if there are no more objects.
Example:
  (let ((r (open-json-file "data.json")))
    (json-next-object r))
```

### `kill`

```
Syntax: (kill pid [force?])
Library: (scm system)
Description: Sends a termination request to the process with the given
  pid. With force? = #f (default) requests a normal termination
  (SIGTERM on Unix); with force? = #t kills forcefully (SIGKILL on Unix).
  Returns #t if the request was delivered, #f if the process does not
  exist or the caller lacks permission to signal it.
Example:
  (kill 12345)        ; graceful
  (kill 12345 #t)     ; force
```

### `ln`

```
Syntax: (ln target name [option ...])
Library: (scm fs)
Description: Creates a link at name pointing to target. Options:
  'symbolic (-s) creates a symbolic link, otherwise a hard link;
  'force (-f) replaces an existing destination.
Example:
  (ln "/usr/bin/python3" "/usr/local/bin/python" 'symbolic 'force)
```

### `log-access`

```
Syntax: (log-access method url status duration-ms)
Library: (scm log)
Description: Writes a single access log line: an INFO line in the http
  module of the form 'METHOD URL -> STATUS (Nms)'. status and duration-ms
  are integers.
Example:
  (log-access "GET" "/notes/42" 200 14)
```

### `log-error`

```
Syntax: (log-error module msg)
Library: (scm log)
Description: Writes a single ERROR-level log line tagged with module.
Example:
  (log-error "db" "connection refused")
```

### `log-info`

```
Syntax: (log-info module msg)
Library: (scm log)
Description: Writes a single INFO-level log line tagged with module to
  (log-port). module and msg are strings.
Example:
  (log-info "auth" "login ok for user 42")
```

### `log-port`

*(no documentation)*

### `log-warn`

```
Syntax: (log-warn module msg)
Library: (scm log)
Description: Writes a single WARN-level log line tagged with module.
Example:
  (log-warn "feeds" "fetch timed out, will retry")
```

### `make-directory`

```
Syntax: (make-directory path)
Library: (scm fs)
Description: Creates the directory named by path, including all intermediate directories.
Example:
  (make-directory "/tmp/new/dir")
```

### `md5-hash`

```
Syntax: (md5-hash obj)
Library: (scm crypto)
Description: Returns the MD5 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.
Example:
  (md5-hash "hello") => "5d41402abc4b2a76b9719d911017c592"
```

### `mktemp`

```
Syntax: (mktemp [option ...])
Library: (scm fs)
Description: Creates a uniquely-named empty file in the temp directory and
  returns its path. Option '(prefix . str) sets the filename prefix
  (default "tmp").
Example:
  (mktemp) => "/tmp/tmp-12345-1aff3..."
```

### `mktempdir`

```
Syntax: (mktempdir [option ...])
Library: (scm fs)
Description: Creates a uniquely-named empty directory in the temp directory
  and returns its path. Option '(prefix . str) sets the dir-name prefix.
Example:
  (mktempdir) => "/tmp/tmp-12345-1aff3..."
```

### `move-directory`

```
Syntax: (move-directory src dest)
Library: (scm fs)
Description: Moves (renames) the directory from src to dest. Returns unspecified on success, #f on failure.
Example:
  (move-directory "/tmp/old" "/tmp/new")
```

### `move-file`

```
Syntax: (move-file src dest)
Library: (scm fs)
Description: Moves (renames) the file from src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.
Example:
  (move-file "old.txt" "new.txt")
```

### `mv`

```
Syntax: (mv src dst [option ...])
Library: (scm fs)
Description: Moves/renames src to dst. Works on files and directories.
Example:
  (mv "old.txt" "new.txt")
```

### `normalized-path`

```
Syntax: (normalized-path path)
Library: (scm fs)
Description: Returns the normalized form of path. If absolute, returns the full path; if relative, returns the relative path from the current directory.
Example:
  (normalized-path "./foo/../bar") => "bar"
```

### `now`

```
Syntax: (now)
Syntax: (now format)
Library: (scm datetime)
Description: Returns the current local date and time as a string. Time is
  24-hour. Default format is ISO 'YYYY-MM-DD HH:MM'. format='short returns
  'YYYYMMDD-HHMM'; format='dmyhs returns 'DD.MM.YYYY HH.MM'.
Example:
  (now)        => "2026-05-27 07:32"
  (now 'short) => "20260527-0732"
  (now 'dmyhm) => "27.05.2026 07:32"
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

### `open-json-file`

```
Syntax: (open-json-file filename)
Library: (scm core)
Description: Opens the named JSON file and returns a JSON reader object. An optional list-id symbol may be specified to identify list nodes.
Example:
  (define r (open-json-file "data.json"))
  (json-next-object r) => next parsed JSON object
```

### `open-json-string`

```
Syntax: (open-json-string s)
Library: (scm json)
Description: Returns a JSON reader object that parses the JSON contained in the string s. An optional list-id symbol or string may be specified to identify list nodes.
Example:
  (define r (open-json-string "{\"a\": 1}"))
  (json-next-object r) => parsed object
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

### `parent-pid`

```
Syntax: (parent-pid)
Library: (scm system)
Description: Returns the OS process id of the parent of the current
  Scheme process, or #f if it cannot be determined.
Example:
  (parent-pid) => 12340
```

### `parse-duration`

```
Syntax: (parse-duration s)
Library: (scm duration)
Description: Parses a duration string into a non-negative integer number of
  seconds. Accepts a bare integer (interpreted as seconds), or an integer
  suffixed with one of s/m/h/d (seconds/minutes/hours/days). Returns #f
  if s is not a string, is empty, or does not parse.
Example:
  (parse-duration "30")  => 30
  (parse-duration "30s") => 30
  (parse-duration "10m") => 600
  (parse-duration "3h")  => 10800
  (parse-duration "1d")  => 86400
  (parse-duration "x")   => #f
```

### `parse-iso8601`

```
Syntax: (parse-iso8601 s)
Library: (scm datetime)
Description: Parses an ISO 8601 / RFC 3339 date string (e.g. used by Atom
  feeds) and returns Unix seconds, or #f on failure. Accepts date-only
  ('2024-05-16'), date+time with 'T' or space separator, and a trailing
  timezone offset (Z, +02:00, -0500). Fractional seconds are ignored.
Example:
  (parse-iso8601 "2024-05-16T12:34:56Z")      => 1715862896
  (parse-iso8601 "2024-05-16T14:34:56+02:00") => 1715862896
  (parse-iso8601 "2024-05-16")                => 1715817600
  (parse-iso8601 "bogus") => #f
```

### `parse-pubdate`

```
Syntax: (parse-pubdate s)
Library: (scm datetime)
Description: Best-effort date parser for feed pubdates. Tries ISO 8601 first
  if s looks ISO-shaped (hyphen at position 4), otherwise RFC 822. Falls
  back to the other format on failure. Returns Unix seconds, or #f.
Example:
  (parse-pubdate "2024-05-16T12:34:56Z")             => 1715862896
  (parse-pubdate "Thu, 16 May 2024 12:34:56 +0000")  => 1715862896
  (parse-pubdate "") => #f
```

### `parse-rfc822`

```
Syntax: (parse-rfc822 s)
Library: (scm datetime)
Description: Parses an RFC 822 / RFC 2822 date string (e.g. used by RSS 2.0
  pubDate elements) and returns Unix seconds, or #f on failure. The leading
  day-of-week prefix is optional. Two-digit years are mapped to 20XX.
Example:
  (parse-rfc822 "Thu, 16 May 2024 12:34:56 +0200") => 1715855696
  (parse-rfc822 "16 May 2024 12:34:56 GMT")       => 1715862896
  (parse-rfc822 "bogus") => #f
```

### `path-sep`

*(no documentation)*

### `percent-decode`

```
Syntax: (percent-decode s [plus-as-space?])
Library: (scm uri)
Description: Decodes percent-escaped UTF-8 in s. When plus-as-space? is
  true (the default), '+' is treated as space — appropriate for
  application/x-www-form-urlencoded bodies and query strings. Pass #f to
  preserve '+' literally (e.g. for URL path segments).
Example:
  (percent-decode "a%20b") => "a b"
  (percent-decode "a+b") => "a b"
  (percent-decode "a+b" #f) => "a+b"
```

### `percent-encode`

```
Syntax: (percent-encode s)
Library: (scm uri)
Description: Encodes string s as UTF-8 and percent-escapes every byte
  outside the RFC 3986 unreserved set (A-Z a-z 0-9 - _ . ~). Suitable for
  building query values and path segments.
Example:
  (percent-encode "a b/c") => "a%20b%2Fc"
  (percent-encode "hello") => "hello"
```

### `pgrep`

```
Syntax: (pgrep pattern [full?])
Library: (scm system)
Description: Returns a list of pids whose command matches the substring
  pattern. By default matches against the process name. If full? is #t,
  matches against the full command line (where the platform supplies it).
  Pattern matching is case-sensitive substring.
Example:
  (pgrep "java") => (1234 5678)
```

### `pkill`

```
Syntax: (pkill pattern [force? [full?]])
Library: (scm system)
Description: Sends a termination request to every process whose command
  matches the substring pattern. By default matches against the process
  name; if full? is #t, matches against the full command line. With
  force? = #t kills forcefully (SIGKILL on Unix). Returns the number of
  processes that were successfully signaled. Does NOT match the current
  Scheme process.
Example:
  (pkill "sleep") => 2
```

### `process-alive?`

```
Syntax: (process-alive? handle)
Library: (scm system)
Description: Returns #t if the process started by start-program is still running, #f if it has exited.
Example:
  (process-alive? p) => #t
```

### `process-kill`

```
Syntax: (process-kill handle [force?])
Library: (scm system)
Description: Stops a process started by start-program. With force? = #f (default) requests a normal termination (SIGTERM on Unix, TerminateProcess on Windows via Process.destroy). With force? = #t kills forcefully (SIGKILL on Unix). Returns #t.
Example:
  (process-kill p)        ; graceful where supported
  (process-kill p #t)     ; force
```

### `process-pid`

```
Syntax: (process-pid handle)
Library: (scm system)
Description: Returns the OS process id of a process handle returned by start-program.
Example:
  (process-pid p) => 12345
```

### `process-wait`

```
Syntax: (process-wait handle [timeout-ms])
Library: (scm system)
Description: Waits for the process to exit. Without timeout-ms, blocks until exit and returns the exit code as an integer. With timeout-ms, waits at most that long; returns the exit code on exit, or #f if the process is still running when the timeout elapses.
Example:
  (process-wait p)            => 0
  (process-wait p 5000)       => 0 or #f
```

### `ps`

```
Syntax: (ps)
Library: (scm system)
Description: Returns a list of alists describing the processes currently
  visible on the system. Each alist has the keys:
    pid         — process id (integer)
    ppid        — parent pid (integer) or #f
    command     — process command as a string, or #f
    user        — owning user (string) or #f
    start-time  — epoch milliseconds (integer) or #f
    cpu-time    — accumulated cpu time in seconds (inexact) or #f
  Fields the platform cannot supply or that the current user cannot
  access are #f. Order is unspecified.
Example:
  (length (ps)) => 312
```

### `ps-info`

```
Syntax: (ps-info pid)
Library: (scm system)
Description: Returns an alist describing the process with the given pid,
  or #f if no such process exists or it cannot be inspected. See (ps)
  for the field set.
Example:
  (cdr (assq 'command (ps-info (current-pid)))) => "scm"
```

### `readlink`

```
Syntax: (readlink path)
Library: (scm fs)
Description: Returns the target of the symbolic link at path as a string,
  or #f if path is not a symlink or cannot be read. Uses native readlink.
Example:
  (readlink "/usr/local/bin/python") => "/usr/bin/python3"
```

### `rm`

```
Syntax: (rm path [option ...])
Library: (scm fs)
Description: Removes path. Options: 'recursive (-r) to remove a directory
  and its contents; 'force (-f) to suppress errors when path is missing.
Example:
  (rm "foo.txt")
  (rm "build" 'recursive 'force)
```

### `rsync`

```
Syntax: (rsync src dst [option ...])
Library: (scm net-remote)
Description: Invokes rsync to synchronise src to dst. Either may be a
  local path or a remote spec (user@host:/path or rsync://...). Options:
    'archive         — -a (recursive + preserve everything)
    'recursive       — -r
    'delete          — --delete (remove dst files not in src)
    'verbose         — -v
    'dry-run         — -n
    'compress        — -z
    '(exclude . list) — list of patterns to pass as --exclude
    '(rsh . cmd)     — remote-shell command, e.g. "ssh -p 2222"
Example:
  (rsync "build/" "deploy@web1:/srv/app/" 'archive 'delete 'verbose)
```

### `run`

```
Syntax: (run prog arg ...)
Library: (scm system)
Description: Varargs wrapper around run-program. Runs the external program
  prog with the given arguments and returns its exit code.
Example:
  (run "echo" "hello") => 0
```

### `run!`

```
Syntax: (run! prog arg ...)
Library: (scm system)
Description: Like run, but raises an error when the program exits non-zero
  or fails to launch. Returns 0 on success.
Example:
  (run! "true") => 0
```

### `run-parallel`

```
Syntax: (run-parallel fn values)
Library: (scm system)
Description: Runs fn in parallel over each element of values using one thread per
  element and returns the results as a list in the same order. Exceptions raised
  in any thread are propagated when joining.
Example:
  (run-parallel (lambda (x) (* x x)) '(1 2 3 4)) => (1 4 9 16)
```

### `run-program`

```
Syntax: (run-program cmd)
Library: (scm system)
Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns its exit code as an exact integer. Returns #f on failure.
Example:
  (run-program '("echo" "hello")) => 0
```

### `run-program/capture`

```
Syntax: (run-program/capture cmd [options])
Library: (scm system)
Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns a list (exit-code stdout stderr) where stdout and stderr are captured as strings. options is an alist with optional keys: 'work-dir <path>, 'stdin <string> (text to write to the child's standard input). Returns #f on failure.
Example:
  (run-program/capture '("echo" "hello")) => (0 "hello\n" "")
```

### `run?`

```
Syntax: (run? prog arg ...)
Library: (scm system)
Description: Returns #t when the program exits with status 0, #f otherwise.
  Useful for predicates like (run? "test" "-f" path).
Example:
  (run? "test" "-f" "/etc/hosts") => #t
```

### `scp`

```
Syntax: (scp src dst [option ...])
Library: (scm net-remote)
Description: Copies files between hosts via the native scp command.
  src or dst may be local paths or remote specs of the form
  user@host:/path. Options:
    'recursive       — pass -r for directory copy
    '(port . int)    — remote SSH port (-P)
    '(key . path)    — identity file (-i)
    'preserve        — preserve times/modes (-p)
    'quiet           — suppress progress (-q)
Example:
  (scp "build.tar.gz" "deploy@web1:/srv/releases/" '(port . 2222))
```

### `sed`

```
Syntax: (sed pattern replacement src [option ...])
Library: (scm text)
Description: Substitutes pattern with replacement in each line of src.
  Options: 'global (g flag, replace all occurrences per line; default is
  first occurrence only), 'ignore-case (i flag), 'pure (force pure path).
  When the native sed command is on PATH and 'pure is not set, sed shells
  out to it. The pure path treats pattern as a literal string.
Example:
  (sed "foo" "bar" "in.txt" 'global)
```

### `sh`

```
Syntax: (sh prog arg ...)
Library: (scm system)
Description: Runs the program and returns its captured stdout as a string.
  Raises an error on non-zero exit. Trailing newlines are preserved.
Example:
  (sh "date" "+%Y") => "2026\n"
```

### `sh-lines`

```
Syntax: (sh-lines prog arg ...)
Library: (scm system)
Description: Like sh but returns stdout split into a list of lines
  (the trailing empty line from a final newline is dropped).
Example:
  (sh-lines "ls" "/tmp") => ("file1" "file2")
```

### `sha1-hash`

```
Syntax: (sha1-hash obj)
Library: (scm crypto)
Description: Returns the SHA-1 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.
Example:
  (sha1-hash "hello") => "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d"
```

### `sha256-hash`

```
Syntax: (sha256-hash obj)
Library: (scm crypto)
Description: Returns the SHA-256 hash of obj as a bytevector. Accepts strings, symbols, or bytevectors.
Example:
  (sha256-hash "hello") => #u8(...)
```

### `shell-quote`

```
Syntax: (shell-quote s)
Library: (scm system)
Description: Returns s quoted such that it can be safely passed as a single
  argument to a POSIX shell (e.g. via /bin/sh -c). Wraps the string in
  single quotes and escapes any embedded single quotes.
Example:
  (shell-quote "it's fine") => "'it'\\''s fine'"
```

### `sleep`

```
Syntax: (sleep seconds)
Library: (scm system)
Description: Pauses the current thread for the given number of seconds
  (which may be fractional). Returns an unspecified value. Uses SRFI 18
  thread-sleep! internally.
Example:
  (sleep 1.5)
```

### `sort-lines`

```
Syntax: (sort-lines src [option ...])
Library: (scm text)
Description: Returns the lines of src sorted lexicographically. Options:
  'reverse (-r), 'numeric (-n), 'unique (-u).
  Named sort-lines (not sort) to avoid clashing with srfi 132 sort.
Example:
  (sort-lines "names.txt" 'reverse)
```

### `special-folder-application-data`

```
Syntax: (special-folder-application-data)
Library: (scm fs)
Description: Returns the path of the user's application data or config directory as a string.
Example:
  (special-folder-application-data) => "/home/user/.config"
```

### `special-folder-documents`

```
Syntax: (special-folder-documents)
Library: (scm fs)
Description: Returns the path of the user's documents directory as a string.
Example:
  (special-folder-documents) => "/home/user/Documents"
```

### `special-folder-temp`

```
Syntax: (special-folder-temp)
Library: (scm fs)
Description: Returns the platform temp directory path as a string.
Example: (special-folder-temp) => "/tmp"
```

### `special-folder-user-home`

```
Syntax: (special-folder-user-home)
Library: (scm fs)
Description: Returns the path of the user home directory as a string.
Example:
  (special-folder-user-home) => "/home/user"
```

### `ssh`

```
Syntax: (ssh host command [option ...])
Library: (scm net-remote)
Description: Runs command (a string) on the remote host via the native
  ssh command and returns (exit-code stdout stderr). host can be
  "hostname" or "user@hostname". Options:
    '(user . str)   — overrides user (alternative to user@host form)
    '(port . int)   — SSH port (default 22)
    '(key . path)   — identity file (-i)
    '(stdin . str)  — fed to remote command's stdin
    '(extra-args . list) — additional raw flags appended before host
Example:
  (ssh "deploy@web1" "systemctl status nginx" '(port . 2222))
```

### `start-program`

```
Syntax: (start-program cmd-and-args [options])
Library: (scm system)
Description: Starts an external program without waiting for it to finish and returns a process handle (a native value). cmd-and-args is a list (program arg1 arg2 ...). options is an alist with optional keys: 'work-dir <path>, 'log-file <path> (redirects stdout+stderr to this file). Use process-pid, process-kill, process-wait, process-alive? on the handle.
Example:
  (define p (start-program '("sleep" "30")))
  (process-kill p)
  (process-wait p)
```

### `stat`

```
Syntax: (stat path)
Library: (scm fs)
Description: Returns an alist describing path with keys exists, type
  (one of file/directory/missing), size, mtime, and mode (octal string
  on Unix; #f on Windows or when stat is unavailable).
Example:
  (stat "/etc/hosts")
```

### `sys-machine-name`

```
Syntax: (sys-machine-name)
Library: (scm system)
Description: Returns the hostname of the current machine as a string.
Example:
  (sys-machine-name) => "myhost"
```

### `sys-num-cpu-cores`

```
Syntax: (sys-num-cpu-cores)
Library: (scm system)
Description: Returns the number of logical CPU cores available to the current process as an integer.
Example:
  (sys-num-cpu-cores) => 8
```

### `sys-os-version`

```
Syntax: (sys-os-version)
Library: (scm system)
Description: Returns a list describing the operating system: (platform version-string major minor service-pack).
Example:
  (sys-os-version) => (linux "Unix 5.15.0.0" 5 15 "")
```

### `sys-platform`

```
Syntax: (sys-platform)
Library: (scm system)
Description: Returns a symbol identifying the current operating system platform: windows, linux, or unknown.
Example:
  (sys-platform) => linux
```

### `sys-scm-technology`

```
Syntax: (sys-scm-technology)
Library: (scm system)
Description: Returns a symbol identifying the SCM implementation technology: csharp or java.
Example:
  (sys-scm-technology) => java
```

### `sys-scm-version`

```
Syntax: (sys-scm-version)
Library: (scm system)
Description: Returns the SCM interpreter version as a string.
Example:
  (sys-scm-version) => "0.0.1"
```

### `sys-user-name`

```
Syntax: (sys-user-name)
Library: (scm system)
Description: Returns the name of the currently logged-in user as a string.
Example:
  (sys-user-name) => "alice"
```

### `tail`

```
Syntax: (tail src [option ...])
Library: (scm text)
Description: Returns the last n lines of src (default 10). Options:
  '(lines . n) sets the count.
Example:
  (tail "log.txt" '(lines . 5))
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

### `tee`

```
Syntax: (tee text file ...)
Library: (scm text)
Description: Writes text (a string, or a list of strings joined by
  newline) to each file path, and returns text. Mirrors `tee` reading
  stdin and writing to multiple destinations.
Example:
  (tee "hello\n" "/tmp/a" "/tmp/b")
```

### `time`

```
Syntax: (time)
Syntax: (time format)
Library: (scm datetime)
Description: Returns the current local time as a string. Time is 24-hour.
  Default format is ISO 'HH:MM'. format='short returns 'HHMM'.
Example:
  (time)        => "07:32"
  (time 'short) => "0732"
```

### `timestamp`

```
Syntax: (timestamp)
Library: (scm datetime)
Description: Returns the current time as the number of milliseconds since the epoch (January 1, year 1).
Example:
  (timestamp) => 63850000000000
```

### `timestamp->string`

```
Syntax: (timestamp->string ms format?)
Library: (scm datetime)
Description: Formats a timestamp (milliseconds) as a date string. The optional format may be isodatetime, isodate, datetime, date, or a custom .NET format string; defaults to isodatetime.
Example:
  (timestamp->string (timestamp)) => "20260318-153045"
  (timestamp->string (timestamp) 'isodate) => "20260318"
```

### `today`

```
Syntax: (today)
Syntax: (today format)
Library: (scm datetime)
Description: Returns the current local date as a string. Default format is
  ISO 'YYYY-MM-DD'. format='short returns 'YYYYMMDD' (no separators);
  format='dmy returns 'DD.MM.YYYY'.
Example:
  (today)        => "2026-05-27"
  (today 'short) => "20260527"
  (today 'dmy)   => "27.05.2026"
```

### `touch`

```
Syntax: (touch path [option ...])
Library: (scm fs)
Description: Creates path as an empty file if it does not exist. When path
  already exists and a native touch command is available on PATH, its
  modification time is updated. Option 'no-create (-c) skips creation of
  missing files. Returns #t on success, #f otherwise.
Example:
  (touch "/tmp/foo")
```

### `tr`

```
Syntax: (tr from to [option ...])
Library: (scm text)
Description: Returns a procedure that translates characters in a string:
  each char in `from` is replaced by the char at the same index in `to`.
  When called on a string, returns the translated string. Option 'delete
  drops chars in `from` instead (to may be "").
Example:
  ((tr "abc" "xyz") "banana") => "yxnxnx"
```

### `tree`

```
Syntax: (tree root [option ...])
Library: (scm fs-find)
Description: Returns a string with a pretty ASCII tree of the directory at
  root, similar to the tree(1) command. Options:
    '(maxdepth . n)  — limit depth shown (root is depth 0)
    'dirs-only       — only show directories
Example:
  (display (tree "." '(maxdepth . 2)))
```

### `uniq`

```
Syntax: (uniq lines)
Library: (scm text)
Description: Returns lines with consecutive duplicates collapsed to a
  single entry. Matches the behavior of Linux uniq (input should usually
  be sorted first).
Example:
  (uniq '("a" "a" "b" "a")) => ("a" "b" "a")
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

### `uuidgen`

```
Syntax: (uuidgen)
Library: (scm system)
Description: Returns a random RFC 4122 version 4 UUID as a string in
  canonical 8-4-4-4-12 hyphenated form. Uses cryptographically random
  bytes; version and variant bits are set per the spec.
Example:
  (uuidgen) => "e3b0c442-98fc-4c14-9afb-f4ca495991b9"
```

### `watch`

```
Syntax: (watch thunk [option ...])
Library: (scm system)
Description: Repeatedly invokes the zero-argument thunk, sleeping between
  invocations. Returns when thunk raises or when the iteration limit is
  reached. Options:
    '(interval . seconds) — seconds between calls (default 2)
    '(count . n)          — stop after n iterations (default: forever)
Example:
  (watch (lambda () (display (sh "date")) (newline))
         '(interval . 5) '(count . 3))
```

### `wc`

```
Syntax: (wc src [option ...])
Library: (scm text)
Description: Returns an alist with keys lines, words, chars for src.
  Options: 'lines-only ('-l), 'words-only ('-w), 'chars-only ('-c) return
  just that integer instead of the full alist.
Example:
  (wc "log.txt") => ((lines . 1234) (words . 9876) (chars . 54321))
```

### `wget`

```
Syntax: (wget url [option ...])
Library: (scm net-remote)
Description: Downloads url via the native wget command. Options:
    '(output . path)   — save as this filename (-O)
    'quiet             — -q
    'continue          — -c (resume partial)
    'no-check-cert     — --no-check-certificate
    '(timeout . secs)  — --timeout
    'pure              — force pure-Scheme HTTP (uses (scm net http client));
                         does not honor continue/no-check-cert/timeout
Example:
  (wget "https://example.com/file.tar.gz" '(output . "/tmp/x.tgz"))
```

### `which`

```
Syntax: (which program)
Library: (scm fs)
Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found.
Example:
  (which "ls") => "/usr/bin/ls"
  (which "nonexistent") => #f
```

### `xargs`

```
Syntax: (xargs proc items [option ...])
Library: (scm fs-find)
Description: Applies proc to chunks of items in turn. By default proc is
  called once per item. Option '(batch-size . n) calls proc with sublists
  of up to n items at a time. Returns the list of results.
Example:
  (xargs delete-file (find-file "/tmp" '(name . "*.bak")))
  (xargs (lambda (batch) (run-program (cons "rm" batch)))
         '("a" "b" "c" "d") '(batch-size . 2))
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

