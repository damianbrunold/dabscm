---
title: (scm args): command-line parsing
part: libraries
order: 1007
libraries: (scm args)
summary: Declaring options, flags and positionals with define-cli or as data, types (integers, enumerations, lists, custom), defaults, required and repeated arguments, --help and errors.
---
# (scm args): command-line parsing

`(scm args)` turns a declaration of a program's arguments into a parser
that converts values, reports usage errors and prints `--help`. The
[command-line programs](techniques-09-command-line.md) chapter builds a
complete tool with it.

```scheme
(import (scheme base) (scheme write) (scm args))
```

## Declaring with define-cli

```scheme
(define cli
  (define-cli
    (program "thumbs")
    (description "Makes thumbnails of images.")
    (version "1.2")
    (option size (short #\s) (long "size") (type arg:integer) (default 128)
            (help "edge length in pixels"))
    (option format (long "format") (type (arg:one-of 'png 'jpeg)) (default 'png))
    (option tags (long "tags") (type (arg:list arg:string)) (default '()))
    (flag verbose (short #\v) (long "verbose") (help "report every file"))
    (positional images (repeat) (help "image files"))))
```

## Parsing

```scheme
(define r (parse-args cli '("-v" "--size=64" "--format" "jpeg" "--tags" "a,b" "x.png" "y.png")))
(args-ref r 'verbose)                       ;; => #t
(args-ref r 'size)                          ;; => 64
(args-ref r 'format)                        ;; => jpeg
(args-ref r 'tags)                          ;; => ("a" "b")
(args-ref r 'images)                        ;; => ("x.png" "y.png")

(define d (parse-args cli '("one.png")))
(list (args-ref d 'size) (args-ref d 'format) (args-ref d 'verbose)) ;; => (128 png #f)
```

The usual syntaxes work: `--size 64`, `--size=64`, `-s 64`, clustered flags
like `-vq`, `--no-verbose` to turn a flag off, and `--` to end the options.

## Errors

By default a usage error prints a message to standard error and exits with
status 2, as command-line tools do. `'on-error 'raise` raises an error
instead, which is what tests and interactive use want:

```scheme
(define (try args)
  (guard (e ((error-object? e) 'usage-error))
    (parse-args cli args 'on-error 'raise)
    'ok))

(try '("--size" "big"))                     ;; => usage-error
(try '("--format" "gif"))                   ;; => usage-error
(try '("--unknown"))                        ;; => usage-error
(try '("a.png"))                            ;; => ok
```

## Help

`--help` prints a text built from the declaration and exits; `format-help`
returns the same text:

```scheme no-test
(display (format-help cli))
```

```text
Usage: thumbs [options] [images...]

Makes thumbnails of images.

Arguments:
  images              image files

Options:
  -s, --size INTEGER  edge length in pixels (default: 128)
  ...
```

## Custom types

A type is a converter from the argument string to a value:

```scheme
(define arg:port
  (make-arg-type "PORT"
    (lambda (s)
      (let ((n (string->number s)))
        (if (and n (exact-integer? n) (<= 1 n 65535)) n (error "not a port number" s))))))

(define server-cli
  (define-cli
    (program "serve")
    (option port (long "port") (type arg:port) (default 8080))
    (option host (long "host") (default "localhost"))))

(args-ref (parse-args server-cli '("--port" "443")) 'port) ;; => 443
(args->alist (parse-args server-cli '()))   ;; => ((host . "localhost") (port . 8080))
(guard (e ((error-object? e) 'rejected))
  (parse-args server-cli '("--port" "99999") 'on-error 'raise)) ;; => rejected
```

## The data form

`make-arg-parser` with `opt`, `flag` and `pos` builds the same parser from
data, which suits programs that construct their options at run time:

```scheme
(define p
  (make-arg-parser
   'program "count"
   'options (list (flag 'lines 'short #\l) (opt 'min 'long "min" 'type arg:integer 'default 0))
   'positionals (list (pos 'file 'required #t))))

(define pr (parse-args p '("-l" "notes.txt")))
(list (args-ref pr 'lines) (args-ref pr 'min) (args-ref pr 'file)) ;; => (#t 0 "notes.txt")
```

Without a positional declaration, extra arguments are collected by
`args-rest`.

## Where next

- [Command-line programs](techniques-09-command-line.md).
- Reference: `(scm args)`.
