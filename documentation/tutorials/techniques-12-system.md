---
title: The system: programs, environment, platform
part: techniques
order: 12
libraries: (scm system) (scheme process-context) (scm fs)
summary: Running external programs and capturing their output, passing input and environment, exit codes, the platform, special folders, finding executables.
---
# The system: programs, environment, platform

```scheme
(import (scheme base) (scheme process-context) (scm system) (scm fs))
```

## Running a program

`(scm system)` runs external programs. The command is a list: the program
followed by its arguments, so there is no shell quoting to get wrong:

```scheme no-test
(run-program '("git" "status" "--short"))           ; => exit code, output to the terminal
(run-program/capture '("git" "rev-parse" "HEAD"))
; => (0 "f6c17e5...\n" "")                           exit code, stdout, stderr
(sh "date" "+%Y")                                    ; => "2025\n", error on failure
```

- `run-program` lets the program use the terminal and returns its exit
  code;
- `run-program/capture` returns `(exit-code stdout stderr)`;
- `sh` returns standard output and raises an error if the program fails.

Options go in an alist: a working directory, text for standard input,
extra environment variables:

```scheme no-test
(run-program/capture '("sort")
                     '((stdin . "pear\napple\nfig\n")))
; => (0 "apple\nfig\npear\n" "")

(run-program '("make" "test")
             '((work-dir . "/home/me/project")
               (env . (("CI" "1")))))
```

### Example: the current git commit, safely

```scheme no-test
(define (git-commit dir)
  (let ((r (run-program/capture '("git" "rev-parse" "--short" "HEAD")
                                `((work-dir . ,dir)))))
    (and r
         (= (car r) 0)
         (string-trim-right-newline (cadr r)))))

(define (string-trim-right-newline s)
  (if (and (> (string-length s) 0)
           (char=? (string-ref s (- (string-length s) 1)) #\newline))
      (substring s 0 (- (string-length s) 1))
      s))
```

`run-program/capture` returns `#f` when the program cannot be started at
all (for example because it is not installed), and a non-zero exit code when
it ran and failed. Checking both makes tools robust.

## Finding programs

```scheme no-test
(which "git")          ; => "/usr/bin/git", or #f
```

Check with `which` before relying on a tool, and give a clear message when
it is missing.

## The environment

```scheme
(string? (get-environment-variable "PATH")) ;; => #t
(list? (get-environment-variables))         ;; => #t
(pair? (assoc "PATH" (get-environment-variables))) ;; => #t
```

Programs started with `run-program` inherit the environment, plus what the
`env` option adds.

## The platform

```scheme
(symbol? (sys-platform))                    ;; => #t
(> (sys-num-cpu-cores) 0)                   ;; => #t
(string? (special-folder-user-home))        ;; => #t
(string? (special-folder-temp))             ;; => #t
```

`sys-platform` is `linux`, `windows` or `macos`; use it (or
`cond-expand` with the features from `(features)`) where a program must
behave differently. `special-folder-user-home`, `special-folder-temp` and
`special-folder-application-data` give the right places for user files,
temporary files and settings on every platform.

The number of cores is a good default for the size of a thread pool (see
[concurrency](techniques-11-concurrency.md)).

## Exit codes

`exit` ends the program; a number is the exit status, `#t` means success
and `#f` failure:

```scheme no-test
(exit 0)      ; success
(exit 2)      ; e.g. "usage error"
(exit #f)     ; failure
```

`emergency-exit` ends immediately without running `dynamic-wind` after
thunks, for the rare cases where cleanup itself might hang.

## Where next

- That ends the techniques. Continue with the library tutorials in the
  [index](README.md).
- `(scm system)`, `(scheme process-context)`, `(scm fs)`.
