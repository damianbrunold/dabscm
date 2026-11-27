---
title: Command-line programs
part: techniques
order: 9
libraries: (scheme process-context) (scm args) (scm terminal) (scm log)
summary: A complete command-line tool: options and positional arguments, help text, reading stdin, exit codes, environment variables, colored output, logging.
---
# Command-line programs

This chapter builds `linecount`, a small `wc -l`-like tool, piece by piece.

```scheme
(import (scheme base) (scheme write) (scheme process-context)
        (only (srfi 13) string-contains)
        (scm args) (scm terminal) (scm log))
```

## Declaring the arguments

`(scm args)` parses options and positional arguments from a declaration:

```scheme
(define cli
  (make-arg-parser
   'program "linecount"
   'description "Counts the lines of files."
   'options (list (flag 'verbose 'short #\v 'long "verbose"
                        'help "print a line per file")
                  (opt 'min 'long "min" 'type arg:integer 'default 0
                       'help "only count lines with at least N characters"))
   'positionals (list (pos 'files 'type arg:string 'repeat #t))))

(define r (parse-args cli '("-v" "--min" "3" "a.txt" "b.txt")))
(args-ref r 'verbose)                       ;; => #t
(args-ref r 'min)                           ;; => 3
(args-ref r 'files)                         ;; => ("a.txt" "b.txt")

(define r2 (parse-args cli '("c.txt")))
(args-ref r2 'verbose)                      ;; => #f
(args-ref r2 'min)                          ;; => 0
```

The types convert the text (`"3"` becomes 3) and reject bad input with a
message. Without an argument list, `parse-args` reads the program's own
command line. `--help` prints a usage text built from the declaration and
exits:

```scheme
(string? (format-help cli))                 ;; => #t
```

## The counting part

Keep the logic in procedures that take ports, so that they can be tested
without files:

```scheme
(define (count-lines in min-length)
  (let loop ((n 0))
    (let ((line (read-line in)))
      (cond ((eof-object? line) n)
            ((>= (string-length line) min-length) (loop (+ n 1)))
            (else (loop n))))))

(count-lines (open-input-string "one\n\nthree\n") 0) ;; => 3
(count-lines (open-input-string "one\n\nthree\n") 1) ;; => 2
```

## Putting it together

```scheme no-test
(define (main)
  (let* ((args (parse-args cli))
         (files (args-ref args 'files))
         (min-length (args-ref args 'min)))
    (if (null? files)
        ;; no files: read standard input
        (begin (display (count-lines (current-input-port) min-length))
               (newline))
        (let loop ((files files) (total 0) (failed #f))
          (cond ((null? files)
                 (display total) (newline)
                 (exit (if failed 1 0)))
                ((file-exists? (car files))
                 (let ((n (call-with-input-file (car files)
                            (lambda (in) (count-lines in min-length)))))
                   (when (args-ref args 'verbose)
                     (display n) (display " ") (display (car files)) (newline))
                   (loop (cdr files) (+ total n) failed)))
                (else
                 (write-string (string-append "linecount: no such file: " (car files) "\n")
                               (current-error-port))
                 (loop (cdr files) total #t)))))))

(main)
```

```sh
$ scm linecount.scm -v notes.txt todo.txt
12 notes.txt
3 todo.txt
15
$ cat notes.txt | scm linecount.scm --min 1
11
$ scmc linecount.scm -o linecount     # a native executable
```

Conventions worth keeping:

- errors go to `(current-error-port)`, results to standard output;
- the exit status is 0 on success and non-zero on failure, so that shell
  scripts can test it;
- with no files, read standard input, so the tool works in pipes.

## Environment variables

```scheme
(string? (get-environment-variable "PATH")) ;; => #t
(get-environment-variable "SURELY_NOT_SET_12345") ;; => #f

(define (setting name default)
  (or (get-environment-variable name) default))

(setting "SURELY_NOT_SET_12345" "fallback") ;; => "fallback"
```

## Colored output

`(scm terminal)` produces ANSI escape sequences for colors and styles:

```scheme
(string-append (sgr-fg 'red) "error" (sgr-reset)) ;; => "\x1b;[31merror\x1b;[0m"

(define (status-line ok? message)
  (string-append (if ok? (sgr-fg 'green) (sgr-fg 'red))
                 (if ok? "ok  " "FAIL")
                 (sgr-reset) " " message))

(string-length (status-line #t "compiled")) ;; => 22
```

Only use colors when the output goes to a terminal; when it goes to a file
or a pipe, plain text is friendlier. The library also moves the cursor,
reads keys in raw mode and reads passwords without echo.

## Logging

`(scm log)` writes one structured line per event, with a time stamp, level
and category, to `log-port` (standard error by default):

```scheme no-test
(log-info "import" "read 1200 rows")
(log-warn "import" "3 rows without a date, skipped")
(log-error "db" "connection refused")
```

Point `log-port` somewhere else with `parameterize`, for example into a
string port in tests:

```scheme
(define captured
  (let ((p (open-output-string)))
    (parameterize ((log-port p))
      (log-info "demo" "hello"))
    (get-output-string p)))

(and (string-contains captured "hello") #t)  ;; => #t
```

(`string-contains` is from SRFI 13.)

## Where next

- [Testing your code](techniques-10-testing.md).
- `(scm args)`, `(scm terminal)`, `(scm log)`, `(scheme process-context)`.
