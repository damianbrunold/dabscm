---
title: (scm archive), (scm zip), (scm compression): archives
part: libraries
order: 1011
libraries: (scm archive) (scm zip) (scm compression)
summary: Compressing bytevectors with deflate, zlib and gzip; gzip, bzip2 and xz files; writing and reading ZIP archives in memory and on disk; tar archives; packing a directory.
---
# (scm archive), (scm zip), (scm compression): archives

- `(scm compression)` compresses bytevectors in memory;
- `(scm zip)` writes and reads ZIP archives;
- `(scm archive)` adds files: gzip, bzip2, xz and tar, and re-exports the
  other two.

```scheme
(import (scheme base) (scheme file) (scheme write) (srfi 1) (srfi 132)
        (scm archive) (scm zip) (scm fs))

(define dir (mktempdir '(prefix . "arch")))
(define (at name) (join-path dir name))
```

## Compressing bytevectors

```scheme
(define text (string->utf8 (apply string-append (make-list 50 "all work and no play "))))
(bytevector-length text)                          ;; => 1050
(define packed (gzip-compress text))
(< (bytevector-length packed) 100)                ;; => #t
(equal? (gzip-decompress packed) text)            ;; => #t
(equal? (zlib-decompress (zlib-compress text)) text) ;; => #t
(equal? (deflate-decompress (deflate-compress text)) text) ;; => #t
```

The three formats wrap the same DEFLATE compression: raw `deflate`,
`zlib` (as in PNG files and HTTP) and `gzip` (as in `.gz` files).

## Compressing files

```scheme
(call-with-output-file (at "log.txt")
  (lambda (out) (for-each (lambda (i) (write-string "GET /index.html 200\n" out)) (iota 200))))
(file-size (at "log.txt"))                        ;; => 4000
(gzip (at "log.txt"))
(file-exists? (at "log.txt.gz"))                  ;; => #t
(file-exists? (at "log.txt"))                     ;; => #f
(< (file-size (at "log.txt.gz")) 200)             ;; => #t
(gunzip (at "log.txt.gz"))
(file-size (at "log.txt"))                        ;; => 4000
```

Like the shell commands, `gzip` replaces the file with the `.gz` file and
`gunzip` does the reverse. `bzip2`/`bunzip2` and `xz`/`unxz` work the same
way.

## Writing a ZIP archive

```scheme
(define z (open-output-zip-file (at "report.zip")))
(display "Monthly report\n" (zip-add-text-entry z "README.txt"))
(write-bytevector (bytevector 1 2 3 4) (zip-add-binary-entry z "data/values.bin"))
(zip-add-stored-entry z "images/logo.png" (bytevector 137 80 78 71))
(close-output-zip z)
(file-exists? (at "report.zip"))                  ;; => #t
```

`zip-add-text-entry` and `zip-add-binary-entry` start an entry and return a
port to write its contents to; the entry ends when the next one starts or
the archive is closed. `zip-add-stored-entry` takes the data directly and
stores it uncompressed, which is right for
data that is compressed already (images, other archives). In memory,
`open-output-zip-bytevector` and `get-output-zip-bytevector` give the
archive as a bytevector, for example to send it over HTTP.

## Reading a ZIP archive

```scheme
(define in (open-input-zip-file (at "report.zip")))
(list-sort string<? (zip-entry-names in))
;; => ("README.txt" "data/values.bin" "images/logo.png")
(utf8->string (zip-read-entry-bytevector in "README.txt")) ;; => "Monthly report\n"
(zip-read-entry-bytevector in "data/values.bin")  ;; => #u8(1 2 3 4)
(zip-entry-size in "data/values.bin")             ;; => 4
(close-input-zip in)
```

`call-with-input-zip` and `call-with-output-zip` open and close for you.
Office files (XLSX, DOCX, PPTX) and ODF files are ZIP archives, which is
how `(scm ooxml ...)` reads and writes them.

## tar archives

```scheme
(make-directory (at "site"))
(call-with-output-file (at "site/index.html") (lambda (o) (write-string "<h1>hi</h1>" o)))
(call-with-output-file (at "site/style.css") (lambda (o) (write-string "h1{}" o)))

(tar-create (at "site.tar") (list (at "site")))
(file-exists? (at "site.tar"))                    ;; => #t
(pair? (tar-list (at "site.tar")))                ;; => #t
```

## Example: packing a directory into a ZIP file

```scheme
(define (zip-directory src zip-path)
  (let ((z (open-output-zip-file zip-path)))
    (let walk ((d src) (prefix ""))
      (for-each (lambda (f)
                  (write-bytevector (read-bytes (join-path d f))
                                    (zip-add-binary-entry z (string-append prefix f))))
                (directory-files d))
      (for-each (lambda (sub) (walk (join-path d sub) (string-append prefix sub "/")))
                (directory-directories d)))
    (close-output-zip z)))

(define (read-bytes path)
  (let* ((p (open-binary-input-file path))
         (bv (read-bytevector (file-size path) p)))
    (close-input-port p)
    (if (eof-object? bv) (bytevector) bv)))

(zip-directory (at "site") (at "site.zip"))
(let ((in (open-input-zip-file (at "site.zip"))))
  (let ((names (list-sort string<? (zip-entry-names in))))
    (close-input-zip in)
    names))                                       ;; => ("index.html" "style.css")

(rm dir 'recursive)
```

## Where next

- [`(scm fs)`](scm-fs.md), `(scm deb)` for Debian packages.
- Reference: `(scm archive)`, `(scm zip)`, `(scm compression)`.
