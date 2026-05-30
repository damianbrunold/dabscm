# `(scm fs)`

Filesystem operations — paths, directories, files

## Exports

### `absolute-path`

```
Syntax: (absolute-path path)
Library: (scm fs)
Description: Returns the absolute (fully qualified) form of the given path string.
Example:
  (absolute-path ".") => "/current/working/dir"
```

### `base-name`

```
Syntax: (base-name path)
Library: (scm fs)
Description: Returns the file name (including extension) from the given path string, without the directory part.
Example:
  (base-name "/usr/share/doc/readme.txt") => "readme.txt"
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

### `current-directory`

```
Syntax: (current-directory)
Library: (scm fs)
Description: Returns the current working directory as a string.
Example:
  (current-directory) => "/home/user/projects"
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

### `directory-directories`

```
Syntax: (directory-directories dirname)
Library: (scm fs)
Description: Returns a list of subdirectory names (not full paths) in the directory dirname.
Example:
  (directory-directories "/usr") => ("bin" "lib" "share" ...)
```

### `directory-entries`

```
Syntax: (directory-entries dirname)
Library: (scm fs)
Description: Returns a list of (name . type) pairs for the entries in dirname, where name is the entry name (not a full path) and type is one of the symbols file, directory, or symlink. Symlinks are reported as symlink regardless of what they point to (they are not followed).
Example:
  (directory-entries "/tmp") => (("a.txt" . file) ("sub" . directory) ("link" . symlink) ...)
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

### `file-exists?`

```
Syntax: (file-exists? filename)
Library: (scheme file)
Description: Returns #t if the named file exists, otherwise returns #f.
Example:
  (file-exists? "/etc/hosts") => #t
  (file-exists? "/nonexistent") => #f
```

### `file-lock`

```
Syntax: (file-lock path)
Library: (scm fs)
Description: Acquires an exclusive, OS-managed advisory lock on the file at
  path, creating the file (and any parent directories) if needed. Returns a
  lock handle on success, or #f if another process already holds the lock.
  Release it with file-unlock; the lock is also released automatically when
  the process exits, so it never goes stale.
Example:
  (define h (file-lock "/tmp/app.lock"))
  (when h (file-unlock h))
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

### `file-symlink?`

```
Syntax: (file-symlink? path)
Library: (scm fs)
Description: Returns #t if path names a symbolic link itself (without following it), otherwise #f. Returns #t even for a dangling link whose target is missing, and #f if path does not exist.
Example:
  (file-symlink? "/usr/local/bin/python") => #t
```

### `file-unlock`

```
Syntax: (file-unlock handle)
Library: (scm fs)
Description: Releases a lock acquired by file-lock. Returns #t if handle was a
  live file lock, #f otherwise.
Example:
  (file-unlock (file-lock "/tmp/app.lock")) => #t
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

### `make-directory`

```
Syntax: (make-directory path)
Library: (scm fs)
Description: Creates the directory named by path, including all intermediate directories.
Example:
  (make-directory "/tmp/new/dir")
```

### `make-symlink`

```
Syntax: (make-symlink target linkpath)
Library: (scm fs)
Description: Creates a symbolic link at linkpath whose target is the string target, stored verbatim (target need not exist). Does not replace an existing linkpath. Returns unspecified on success, #f on failure. On Windows, requires symlink-creation privilege (Developer Mode or elevation).
Example:
  (make-symlink "../bin/python3" "/usr/local/bin/python")
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

### `path-exists?`

```
Syntax: (path-exists? path)
Library: (scm fs)
Description: Returns #t if path exists as a file, directory, or symbolic link (a dangling link still counts), without following links; otherwise #f. This is the lexists-style check.
Example:
  (path-exists? "/etc/hosts") => #t
```

### `path-sep`

*(no documentation)*

### `read-symlink`

```
Syntax: (read-symlink path)
Library: (scm fs)
Description: Returns the raw target string stored in the symbolic link at path, exactly as recorded (not resolved or canonicalized). Returns #f if path is not a symbolic link or cannot be read.
Example:
  (read-symlink "/usr/local/bin/python") => "../bin/python3"
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

### `set-file-modification-time!`

```
Syntax: (set-file-modification-time! path millis)
Library: (scm fs)
Description: Sets the last-modification time of the file or directory at path to millis (milliseconds since the Unix epoch, UTC). Returns unspecified on success, #f on failure. The unit matches the value returned by file-modification-timestamp.
Example:
  (set-file-modification-time! "dir" (file-modification-timestamp "src"))
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

### `which`

```
Syntax: (which program)
Library: (scm fs)
Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found.
Example:
  (which "ls") => "/usr/bin/ls"
  (which "nonexistent") => #f
```

