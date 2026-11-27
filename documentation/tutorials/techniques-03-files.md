---
title: Files and directories
part: techniques
order: 3
libraries: (scheme base) (scheme file) (scm io) (scm fs) (scm glob) (scm fs-find) (scm archive) (scm string)
summary: Reading and writing text and binary files, line by line or at once, appending and encodings, paths, directories, temporary files, globbing, finding files, compressing.
---
# Files and directories

The examples in this chapter work in a temporary directory, which they
delete at the end, so you can run them anywhere.

```scheme
(import (scheme base) (scheme file) (scheme read) (scheme write) (scheme char)
        (srfi 1) (srfi 13) (srfi 132)
        (scm io) (scm fs) (scm glob) (scm fs-find) (scm archive)
        (only (scm string) string-split-char))

(define dir (mktempdir '(prefix . "tutorial")))
(define (here name) (join-path dir name))
```

`mktempdir` creates a new, empty directory in the system's temporary
folder; `join-path` builds a path with the right separator for the platform.

## Writing a text file

```scheme
(call-with-output-file (here "notes.txt")
  (lambda (out)
    (display "first line" out)
    (newline out)
    (write '(a list "with a string") out)
    (newline out)))

(file-exists? (here "notes.txt"))           ;; => #t
(file-size (here "notes.txt"))              ;; => 36
```

`call-with-output-file` opens the file, gives the port to your procedure
and closes it afterwards, also when an error occurs.

## Reading a text file

The whole file at once, as one string or as a list of lines:

```scheme
(file->string (here "notes.txt"))
;; => "first line\n(a list \"with a string\")\n"
(file->lines (here "notes.txt"))
;; => ("first line" "(a list \"with a string\")")
```

Line by line, for files too large to hold in memory:

```scheme
(define (count-lines path)
  (call-with-input-file path
    (lambda (in)
      (let loop ((n 0))
        (if (eof-object? (read-line in)) n (loop (+ n 1)))))))

(count-lines (here "notes.txt"))            ;; => 2
```

Scheme data written with `write` can be read back with `read`, which makes
files a simple way to store structured data:

```scheme
(call-with-input-file (here "notes.txt")
  (lambda (in)
    (read-line in)
    (read in)))                             ;; => (a list "with a string")
```

## Appending and encodings

`open-output-file` and `call-with-output-file` accept options after the file
name. With `call-with-output-file`, pass a list:

```scheme
(call-with-output-file (list (here "log.txt") 'append)
  (lambda (out) (display "started\n" out)))
(call-with-output-file (list (here "log.txt") 'append)
  (lambda (out) (display "stopped\n" out)))
(file->lines (here "log.txt"))              ;; => ("started" "stopped")

(call-with-output-file (list (here "latin.txt") 'latin-1)
  (lambda (out) (display "Zürich" out)))
(file-size (here "latin.txt"))              ;; => 6
(call-with-input-file (list (here "latin.txt") 'latin-1) read-line)
;; => "Zürich"
```

In UTF-8 (the default) "Zürich" takes 7 bytes, in Latin-1 6. Other
encodings: `'utf-8-bom`, `'utf-16`, `'utf-16-le`.

## Binary files

Binary ports read and write bytes:

```scheme
(let ((out (open-binary-output-file (here "data.bin"))))
  (write-bytevector (bytevector 0 1 2 255) out)
  (close-output-port out))

(define (read-all-bytes path)
  (let ((in (open-binary-input-file path)))
    (let ((bv (read-bytevector (file-size path) in)))
      (close-input-port in)
      bv)))

(read-all-bytes (here "data.bin"))          ;; => #u8(0 1 2 255)
```

## Example: a CSV summary

Read a small CSV file, total a column per group, and write a report:

```scheme
(call-with-output-file (here "sales.csv")
  (lambda (out)
    (display "region,product,amount\n" out)
    (display "north,apples,120\nsouth,apples,80\nnorth,pears,45\nsouth,pears,60\nnorth,apples,30\n" out)))

(define (read-csv path)
  (map (lambda (line) (string-split-char line #\,))
       (cdr (file->lines path))))           ; without the header

(define (total-by key-index value-index rows)
  (fold (lambda (row acc)
          (let* ((key (list-ref row key-index))
                 (value (string->number (list-ref row value-index)))
                 (entry (assoc key acc)))
            (if entry
                (begin (set-cdr! entry (+ (cdr entry) value)) acc)
                (cons (cons key value) acc))))
        '()
        rows))

(define rows (read-csv (here "sales.csv")))
(length rows)                               ;; => 5
(reverse (total-by 0 2 rows))               ;; => (("north" . 195) ("south" . 140))
(reverse (total-by 1 2 rows))               ;; => (("apples" . 230) ("pears" . 105))
```

`string-split-char` (from `(scm string)`) splits at every comma and keeps
empty fields. For real CSV with quoted fields, use `(scm data io)`'s `read-csv`; see the
[structured data](techniques-08-structured-data.md) tutorial.

## Paths

Path functions are pure string operations; they do not touch the disk:

```scheme
(join-path "reports" "2025" "summary.txt")  ;; => "reports/2025/summary.txt"
(base-name "/var/log/app.log")              ;; => "app.log"
(directory-name "/var/log/app.log")         ;; => "/var/log"
(normalized-path "a/b/../c/./d")            ;; => "a/c/d"
```

On Windows, `join-path` uses backslashes.

## Directories

```scheme
(make-directory (here "sub"))
(call-with-output-file (join-path (here "sub") "inner.txt")
  (lambda (out) (display "x" out)))

(list-sort string<? (directory-files dir))
;; => ("data.bin" "latin.txt" "log.txt" "notes.txt" "sales.csv")
(directory-directories dir)                 ;; => ("sub")
(directory-exists? (here "sub"))            ;; => #t
```

`directory-files` lists the files in a directory and
`directory-directories` the subdirectories, by name. The order is not
defined, so the example sorts the names with `list-sort` (SRFI 132).

## Copying, moving, deleting

```scheme
(copy-file (here "notes.txt") (here "notes.bak"))
(move-file (here "notes.bak") (here "sub/notes.old"))
(file-exists? (here "notes.bak"))           ;; => #f
(file-exists? (here "sub/notes.old"))       ;; => #t
(delete-file (here "sub/notes.old"))
(file-exists? (here "sub/notes.old"))       ;; => #f
```

`rm` with `'recursive` deletes a directory tree, like the shell command.

## Globbing and finding files

```scheme
(glob-match? "*.txt" "notes.txt")           ;; => #t
(glob-match? "*.txt" "sales.csv")           ;; => #f
(map base-name (glob (join-path dir "*.txt")))
;; => ("latin.txt" "log.txt" "notes.txt")

(list-sort string<?
           (map base-name (find-file dir '(name . "*.txt") '(type . file))))
;; => ("inner.txt" "latin.txt" "log.txt" "notes.txt")
```

`glob` expands a pattern in one directory, `find-file` searches a whole tree
with criteria: name patterns, file type, or any predicate.

## Compressing

```scheme
(gzip (here "sales.csv"))
(file-exists? (here "sales.csv.gz"))        ;; => #t
(< (file-size (here "sales.csv.gz")) 200)   ;; => #t
```

`(scm archive)` also creates and extracts tar and zip archives; see its
tutorial.

## Cleaning up

```scheme
(rm dir 'recursive)
(directory-exists? dir)                     ;; => #f
```

## Where next

- [Hash tables and dictionaries](techniques-04-hash-tables.md).
- Reference: `(scheme file)`, `(scm fs)`, `(scm io)`, `(scm glob)`,
  `(scm fs-find)`, `(scm archive)`.
