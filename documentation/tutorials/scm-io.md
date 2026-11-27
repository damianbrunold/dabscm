---
title: (scm io): ports and formatting
part: libraries
order: 1004
libraries: (scm io)
summary: Capturing output in strings and bytevectors, reading from strings, whole-file reading with encodings, safe reading of untrusted data, format, port positions.
---
# (scm io): ports and formatting

`(scm io)` adds conveniences on top of the R7RS ports.

```scheme
(import (scheme base) (scheme read) (scheme write) (scheme file) (scm io) (scm fs))
```

## Capturing output

```scheme
(call-with-output-string
  (lambda (out) (display "total: " out) (write 42 out)))   ;; => "total: 42"
(call-with-output-bytevector
  (lambda (out) (write-u8 1 out) (write-bytevector #u8(2 3) out))) ;; => #u8(1 2 3)
```

Any procedure that writes to a port can be turned into one that returns a
string this way, which makes it easy to test.

## Reading from strings

```scheme
(call-with-input-string "(1 2 3) next" read)             ;; => (1 2 3)
(with-input-from-string "hello world" read)              ;; => hello
(read-chars 3 (open-input-string "abcdef"))              ;; => "abc"
(port-position (open-input-string "x"))                  ;; => ("{string}" 1 0)
```

`with-input-from-string` makes the string the *current* input port for the
duration of a thunk, so code that reads from `(current-input-port)` can be
fed test input.

## Reading whole files

```scheme
(define dir (mktempdir '(prefix . "io")))
(define path (join-path dir "notes.txt"))
(call-with-output-file path (lambda (out) (display "alpha\nbeta\n" out)))

(read-file-string path)                                  ;; => "alpha\nbeta\n"
(read-file-lines path)                                   ;; => ("alpha" "beta")
(file->lines (join-path dir "missing.txt"))              ;; => #f
(read-file-lines (join-path dir "missing.txt"))          ;; => error
```

Two flavours: `read-file-string` and `read-file-lines` raise an error when
the file cannot be read, `file->string` and `file->lines` return `#f`. Both
take encoding options such as `'latin-1`.

## Reading untrusted data safely

`read` accepts any Scheme syntax, including datum labels that make cyclic
structures. For data from uploads or the network, use `read-data`, which
rejects labels and limits nesting:

```scheme
(read-data (open-input-string "(order 1 (items \"a\" \"b\"))")) ;; => (order 1 (items "a" "b"))
(guard (e ((read-error? e) 'rejected))
  (read-data (open-input-string "#0=(a . #0#)")))        ;; => rejected
(guard (e ((read-error? e) 'too-deep))
  (read-data (open-input-string "((((((x))))))") 3))     ;; => too-deep
```

## format

`format` is the same as in [SRFI 48](srfi-48.md): `#f` returns a string,
`#t` writes to the current output port.

```scheme
(format #f "~a: ~s" 'name "Ada")                         ;; => "name: \"Ada\""
(format #f "~8,2f|" 3.14159)                             ;; => "    3.14|"
```

## Line and field separators

```scheme
(string? line-sep)                                       ;; => #t
(string? field-sep)                                      ;; => #t
```

`line-sep` is the platform's line ending and `field-sep` the separator of
path lists (`:` on Unix, `;` on Windows), for building `PATH`-like values.

```scheme
(rm dir 'recursive)
```

## Where next

- [Files and directories](techniques-03-files.md).
- Reference: `(scm io)`.
