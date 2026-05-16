# `(scm fs)`

Filesystem operations — paths, directories, files

## Exports

### `absolute-path`

```
Syntax: (absolute-path path)
Library: (scm system)
Description: Returns the absolute (fully qualified) form of the given path string.
Example:
  (absolute-path ".") => "/current/working/dir"
```

### `base-name`

```
Syntax: (base-name path)
Library: (scm system)
Description: Returns the file name (including extension) from the given path string, without the directory part.
Example:
  (base-name "/usr/share/doc/readme.txt") => "readme.txt"
```

### `copy-directory`

```
Syntax: (copy-directory src dest)
Library: (scm system)
Description: Recursively copies the directory at src to dest. Returns unspecified on success, #f on failure.
Example:
  (copy-directory "/src/dir" "/dst/dir")
```

### `copy-file`

```
Syntax: (copy-file src dest)
Library: (scm system)
Description: Copies the file at src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.
Example:
  (copy-file "data.txt" "backup.txt")
```

### `current-directory`

```
Syntax: (current-directory)
Library: (scm system)
Description: Returns the current working directory as a string.
Example:
  (current-directory) => "/home/user/projects"
```

### `delete-directory`

```
Syntax: (delete-directory dir)
Library: (scm system)
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
Library: (scm system)
Description: Returns a list of subdirectory names (not full paths) in the directory dirname.
Example:
  (directory-directories "/usr") => ("bin" "lib" "share" ...)
```

### `directory-exists?`

```
Syntax: (directory-exists? dirname)
Library: (scm system)
Description: Returns #t if the given path names an existing directory, otherwise returns #f.
Example:
  (directory-exists? "/tmp") => #t
  (directory-exists? "/nonexistent") => #f
```

### `directory-files`

```
Syntax: (directory-files dirname)
Library: (scm system)
Description: Returns a list of file names (not full paths) in the directory dirname.
Example:
  (directory-files "/tmp") => ("file1.txt" "file2.txt" ...)
```

### `directory-name`

```
Syntax: (directory-name path)
Library: (scm system)
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
Library: (scm system)
Description: Returns the last modification time of the file as a millisecond timestamp (milliseconds since the .NET epoch).
Example:
  (file-modification-timestamp "data.txt") => 1700000000000
```

### `file-size`

```
Syntax: (file-size file)
Library: (scm system)
Description: Returns the size of the named file in bytes as an exact integer, or #f if the file cannot be accessed.
Example:
  (file-size "/etc/hosts") => 221
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

### `make-directory`

```
Syntax: (make-directory path)
Library: (scm system)
Description: Creates the directory named by path, including all intermediate directories.
Example:
  (make-directory "/tmp/new/dir")
```

### `move-directory`

```
Syntax: (move-directory src dest)
Library: (scm system)
Description: Moves (renames) the directory from src to dest. Returns unspecified on success, #f on failure.
Example:
  (move-directory "/tmp/old" "/tmp/new")
```

### `move-file`

```
Syntax: (move-file src dest)
Library: (scm system)
Description: Moves (renames) the file from src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.
Example:
  (move-file "old.txt" "new.txt")
```

### `normalized-path`

```
Syntax: (normalized-path path)
Library: (scm system)
Description: Returns the normalized form of path. If absolute, returns the full path; if relative, returns the relative path from the current directory.
Example:
  (normalized-path "./foo/../bar") => "bar"
```

### `path-sep`

*(no documentation)*

### `special-folder-application-data`

```
Syntax: (special-folder-application-data)
Library: (scm system)
Description: Returns the path of the user's application data directory as a string.
Example:
  (special-folder-application-data) => "/home/user/.config"
```

### `special-folder-documents`

```
Syntax: (special-folder-documents)
Library: (scm system)
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

### `which`

```
Syntax: (which program)
Library: (scm system)
Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found.
Example:
  (which "ls") => "/usr/bin/ls"
  (which "nonexistent") => #f
```

