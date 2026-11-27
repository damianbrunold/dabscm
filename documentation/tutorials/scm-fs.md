---
title: (scm fs), (scm fs-find), (scm glob): the file system
part: libraries
order: 1009
libraries: (scm fs) (scm fs-find) (scm glob)
summary: Paths, file information, directories, copying and moving, temporary files, symbolic links, special folders; finding files by name, type and predicate; tree listings, disk usage; glob patterns; a backup rotation.
---
# (scm fs), (scm fs-find), (scm glob): the file system

The [files and directories](techniques-03-files.md) chapter covers reading
and writing; this one goes through the file-system libraries. All examples
work in a temporary directory.

```scheme
(import (scheme base) (scheme file) (srfi 1) (srfi 132)
        (scm fs) (scm fs-find) (scm glob))

(define root (mktempdir '(prefix . "fs")))
(define (at . parts) (apply join-path root parts))
(define (write-text path text)
  (call-with-output-file path (lambda (out) (write-string text out))))
```

## Paths

Pure string operations, nothing is read from disk:

```scheme
(join-path "a" "b" "c.txt")                 ;; => "a/b/c.txt"
(base-name "/srv/www/index.html")           ;; => "index.html"
(directory-name "/srv/www/index.html")      ;; => "/srv/www"
(normalized-path "a/./b/../c")              ;; => "a/c"
(string? path-sep)                          ;; => #t
(string? (absolute-path "x"))               ;; => #t
```

`absolute-path` resolves against the current directory; `real-path` also
resolves symbolic links.

## Creating and inspecting

```scheme
(make-directory (at "docs"))
(write-text (at "docs" "a.txt") "alpha")
(write-text (at "docs" "b.md") "# b")
(make-directory (at "docs" "old"))
(write-text (at "docs" "old" "c.txt") "gamma, older")

(file-exists? (at "docs" "a.txt"))          ;; => #t
(directory-exists? (at "docs" "old"))       ;; => #t
(file-size (at "docs" "a.txt"))             ;; => 5
(list-sort string<? (directory-files (at "docs")))       ;; => ("a.txt" "b.md")
(directory-directories (at "docs"))         ;; => ("old")
(integer? (file-modification-timestamp (at "docs" "a.txt"))) ;; => #t
```

`directory-files` lists files only, `directory-directories` the
subdirectories, `directory-entries` both.

## Copying, moving, deleting

```scheme
(copy-file (at "docs" "a.txt") (at "docs" "a.bak"))
(move-file (at "docs" "a.bak") (at "a.bak"))
(file-exists? (at "a.bak"))                 ;; => #t
(copy-directory (at "docs") (at "docs-copy"))
(file-exists? (at "docs-copy" "old" "c.txt")) ;; => #t
(rm (at "docs-copy") 'recursive)
(directory-exists? (at "docs-copy"))        ;; => #f
(delete-file (at "a.bak"))
```

`rm`, `cp` and `mv` take shell-like options: `'recursive` and `'force`.

## Temporary files and special folders

```scheme
(define tmp (mktemp '(prefix . "upload")))
(file-exists? tmp)                          ;; => #t
(delete-file tmp)
(string? (special-folder-user-home))        ;; => #t
(string? (special-folder-application-data)) ;; => #t
```

Use `special-folder-application-data` for settings, so a program finds them
on Linux, Windows and macOS alike.

## Finding files

`find-file` walks a tree with criteria, all of which must hold:

```scheme
(define (names paths) (list-sort string<? (map base-name paths)))

(names (find-file root '(name . "*.txt")))  ;; => ("a.txt" "c.txt")
(names (find-file (at "docs") '(type . directory))) ;; => ("docs" "old")
(names (find-file root '(name . "*.txt")
                  `(predicate . ,(lambda (p) (> (file-size p) 6)))))
;; => ("c.txt")
```

The starting directory itself is part of the walk, so it shows up among the
directories. Criteria: `(name . glob)`, `(type . file)` or `(type . directory)`,
`(predicate . procedure)`. `tree` draws a directory tree, `du` totals sizes
and `df` reports free space:

```scheme
(> (du root) 0)                             ;; => #t
```

## Glob patterns

```scheme
(glob-match? "*.txt" "notes.txt")           ;; => #t
(glob-match? "report-??.pdf" "report-07.pdf") ;; => #t
(glob-match? "[abc]*" "beta")               ;; => #t
(glob-match? "docs/**/*.txt" "docs/old/c.txt") ;; => #t
(names (glob (join-path root "docs" "*")))  ;; => ("a.txt" "b.md" "old")
(names (glob (join-path root "**" "*.txt"))) ;; => ("a.txt" "c.txt")
```

`*` matches any run of characters within a name, `?` one character,
`[...]` a character class (`[!...]` negated) and `**` any number of
directory levels. `glob` returns files and directories; names starting with
a dot are only matched by a pattern that starts with a dot.

## Example: rotating backups

Keep only the newest three backups of a file:

```scheme
(make-directory (at "backups"))
(for-each (lambda (day) (write-text (at "backups" (string-append "db-2025-11-" day ".bak")) day))
          '("20" "21" "22" "23" "24"))

(define (rotate dir pattern keep)
  (let* ((files (list-sort string>? (glob (join-path dir pattern))))
         (old (if (> (length files) keep) (drop files keep) '())))
    (for-each delete-file old)
    (length old)))

(rotate (at "backups") "db-*.bak" 3)        ;; => 2
(names (glob (join-path root "backups" "*.bak")))
;; => ("db-2025-11-22.bak" "db-2025-11-23.bak" "db-2025-11-24.bak")
```

ISO dates in file names sort correctly as strings, so the newest files come
first after a descending sort.

```scheme
(rm root 'recursive)
```

## Where next

- [Files and directories](techniques-03-files.md), [`(scm archive)`](scm-archive.md).
- Reference: `(scm fs)`, `(scm fs-find)`, `(scm glob)`.
