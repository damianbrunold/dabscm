# `(scm fs-find)`

## Exports

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

