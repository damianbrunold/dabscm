---
title: (scm system) and (scm sysadmin): processes and the system
part: libraries
order: 1010
libraries: (scm system) (scm sysadmin)
summary: Running programs with or without a shell, capturing output, background processes, environment, platform information, parallel maps, process lists, UUIDs; (scm sysadmin) as a one-import toolbox for scripts.
---
# (scm system) and (scm sysadmin): processes and the system

The [system](techniques-12-system.md) chapter shows running programs; this
one goes through the library. Tested examples avoid external programs, so
they run on every platform.

```scheme
(import (scheme base) (scm system))
```

## Running programs

| procedure | returns |
|---|---|
| `(run-program '("cmd" "arg"))` | the exit code; the program uses the terminal |
| `(run-program/capture '("cmd" "arg"))` | `(exit-code stdout stderr)`, or `#f` if it cannot start |
| `(sh "cmd" "arg")` | standard output; error if the program fails |
| `(sh-lines "cmd" "arg")` | standard output as a list of lines |
| `(run "cmd" "arg")` / `(run? ...)` | runs, returning success as a boolean (`run?`) |
| `(start-program '("cmd"))` | a process object for a program in the background |

```scheme no-test
(sh-lines "git" "branch" "--list")                ; => ("* main" "  feature")
(run-program/capture '("tr" "a-z" "A-Z") '((stdin . "hello")))
; => (0 "HELLO" "")

(define p (start-program '("sleep" "30")))
(process-alive? p)                                ; => #t
(process-kill p)
(process-wait p)                                  ; => the exit status
```

Commands are lists, so no shell interprets them and file names with spaces
need no quoting. When a shell really is needed (pipes, globbing), call it
explicitly and quote arguments with `shell-quote`:

```scheme
(shell-quote "it's here")                         ;; => "'it'\\''s here'"
```

```scheme no-test
(sh "sh" "-c" (string-append "ls " (shell-quote dir) " | wc -l"))
```

## Environment and platform

```scheme
(string? (get-environment-variable "PATH"))       ;; => #t
(pair? (env-list))                                ;; => #t
(and (memq (sys-platform) '(linux windows macos)) #t) ;; => #t
(> (sys-num-cpu-cores) 0)                         ;; => #t
(string? (sys-user-name))                         ;; => #t
(string? (sys-machine-name))                      ;; => #t
(string? (sys-scm-version))                       ;; => #t
(integer? (current-pid))                          ;; => #t
```

`sys-scm-technology` says which implementation runs the program (`java`,
`csharp` or `native`), handy in diagnostics; `sys-platform` is `linux`,
`windows` or `unknown`.

## Parallel work

`run-parallel` maps a procedure over a list with one thread per element and
keeps the order:

```scheme
(run-parallel (lambda (n) (* n n)) '(1 2 3 4))    ;; => (1 4 9 16)
```

## Odds and ends

```scheme
(string-length (uuidgen))                         ;; => 36
(sleep 0.01)
```

`ps`, `pgrep` and `pkill` list and signal processes; `watch` runs a thunk
repeatedly with a delay; `set-interrupt-handler!` reacts to Ctrl+C.

## (scm sysadmin): one import for scripts

`(scm sysadmin)` re-exports the procedures system scripts typically need:
files and paths (`(scm fs)`), finding (`(scm fs-find)`), text tools
(`(scm text)`), archives, remote copies (`curl`, `rsync`, `scp`, `ssh`,
`wget`), processes, dates, logging, hashing and JSON reading. One import,
and a script reads like a shell script:

```scheme no-test
(import (scheme base) (scm sysadmin))

(for-each (lambda (f)
            (log-info "cleanup" f)
            (gzip f))
          (find-file "/var/log/myapp" '(name . "*.log")
                     `(predicate . ,(lambda (p) (> (file-size p) 10000000)))))
```

`scm --sysadmin` starts a REPL with it already imported.

## Where next

- [The system](techniques-12-system.md), [concurrency](techniques-11-concurrency.md).
- Reference: `(scm system)`, `(scm sysadmin)`.
