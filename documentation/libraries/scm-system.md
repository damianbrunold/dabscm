# `(scm system)`

System info, environment variables, process execution

## Overview

`(scm system)` is the interface to the operating system: running external
programs (and capturing their output), environment variables, process inspection
and control, simple option parsing, and parallel execution.

## Common uses

Run external commands:

```scheme
(import (scm system))

(run "ls" "-l")                           ;; run a program
(run-program/capture (list "echo" "hi"))  ;; run, capturing stdout
(sh "date" "+%Y")                         ;; => "2026\n"  (stdout as a string)
```

Environment and processes:

```scheme
(get-environment-variable "HOME")
(env-list)            ;; all environment variables
(ps)                  ;; process list
```

`run-parallel` maps a procedure over inputs using threads:

```scheme
(run-parallel (lambda (x) (* x x)) '(1 2 3 4))   ;; => (1 4 9 16)
```

`getopt` parses command-line option lists; see also the higher-level
`(scm args)`.


## Exports

### `current-pid`

```
Syntax: (current-pid)
Library: (scm system)
Description: Returns the OS process id of the current Scheme process.
Example:
  (current-pid) => 12345
```

### `env-list`

```
Syntax: (env-list)
Library: (scm system)
Description: Returns an alist of all environment variables as (name . value)
  pairs. Equivalent to SRFI-98 get-environment-variables.
Example:
  (env-list) => (("PATH" . "/usr/bin") ...)
```

### `get-bytes`

```
Syntax: (get-bytes obj [encoding])
Library: (scm core)
Description: Returns the byte representation of obj (string, symbol, or bytevector) as a bytevector.
  encoding is an optional string or symbol specifying the character encoding (default: utf-8).
  Supported encodings: utf-8, utf-8-bom, latin-1, utf-16, utf-16-le.
Example:
  (get-bytes "hello")
  (get-bytes "hello" "latin-1")
```

### `get-environment-variable`

```
Syntax: (get-environment-variable name)
Library: (scm system) (scheme process-context) (srfi 98)
Description: Returns the value of the environment variable named name as a string, or #f if it is not set.
Example:
  (get-environment-variable "HOME") => "/home/user"
  (get-environment-variable "UNDEFINED_VAR") => #f
```

### `getopt`

```
Syntax: (getopt argv spec)
Library: (scm system)
Description: Parses command-line arguments. argv is a list of strings;
  spec is a list of option descriptors, each one of:
    (long-name short-char takes-value? [default])
  where long-name is a string (without the --), short-char is a character
  (or #f), takes-value? is a boolean, and default is the value used when
  the option is absent (defaults to #f for non-value flags, #f for
  value-taking options). Returns (alist . positionals) where alist maps
  long-name strings to the supplied values (#t for absent boolean flags
  is replaced by the default). Unknown options raise an error.
Example:
  (getopt '("-v" "--name" "foo" "a" "b")
          '(("verbose" #\v #f)
            ("name"    #\n #t "anon")))
  => ((("verbose" . #t) ("name" . "foo")) . ("a" "b"))
```

### `kill`

```
Syntax: (kill pid [force?])
Library: (scm system)
Description: Sends a termination request to the process with the given
  pid. With force? = #f (default) requests a normal termination
  (SIGTERM on Unix); with force? = #t kills forcefully (SIGKILL on Unix).
  Returns #t if the request was delivered, #f if the process does not
  exist or the caller lacks permission to signal it.
Example:
  (kill 12345)        ; graceful
  (kill 12345 #t)     ; force
```

### `modules`

*(no documentation)*

### `parent-pid`

```
Syntax: (parent-pid)
Library: (scm system)
Description: Returns the OS process id of the parent of the current
  Scheme process, or #f if it cannot be determined.
Example:
  (parent-pid) => 12340
```

### `pgrep`

```
Syntax: (pgrep pattern [full?])
Library: (scm system)
Description: Returns a list of pids whose command matches the substring
  pattern. By default matches against the process name. If full? is #t,
  matches against the full command line (where the platform supplies it).
  Pattern matching is case-sensitive substring.
Example:
  (pgrep "java") => (1234 5678)
```

### `pkill`

```
Syntax: (pkill pattern [force? [full?]])
Library: (scm system)
Description: Sends a termination request to every process whose command
  matches the substring pattern. By default matches against the process
  name; if full? is #t, matches against the full command line. With
  force? = #t kills forcefully (SIGKILL on Unix). Returns the number of
  processes that were successfully signaled. Does NOT match the current
  Scheme process.
Example:
  (pkill "sleep") => 2
```

### `process-alive?`

```
Syntax: (process-alive? handle)
Library: (scm system)
Description: Returns #t if the process started by start-program is still running, #f if it has exited.
Example:
  (process-alive? p) => #t
```

### `process-kill`

```
Syntax: (process-kill handle [force?])
Library: (scm system)
Description: Stops a process started by start-program. With force? = #f (default) requests a normal termination (SIGTERM on Unix, TerminateProcess on Windows via Process.destroy). With force? = #t kills forcefully (SIGKILL on Unix). Returns #t.
Example:
  (process-kill p)        ; graceful where supported
  (process-kill p #t)     ; force
```

### `process-kill-on-exit`

```
Syntax: (process-kill-on-exit handle)
Library: (scm system)
Description: Registers a process started by start-program to be killed forcefully when this (parent) process exits, via a JVM shutdown hook fired on SIGINT, SIGTERM, SIGHUP and normal exit. Prevents orphaned children — e.g. a dev supervisor's server child left holding a port after the supervisor is stopped. Already-exited handles are pruned, so the registry stays bounded across repeated restarts. Returns #t.
Example:
  (define p (start-program '("scm" "server.scm")))
  (process-kill-on-exit p)
```

### `process-pid`

```
Syntax: (process-pid handle)
Library: (scm system)
Description: Returns the OS process id of a process handle returned by start-program.
Example:
  (process-pid p) => 12345
```

### `process-wait`

```
Syntax: (process-wait handle [timeout-ms])
Library: (scm system)
Description: Waits for the process to exit. Without timeout-ms, blocks until exit and returns the exit code as an integer. With timeout-ms, waits at most that long; returns the exit code on exit, or #f if the process is still running when the timeout elapses.
Example:
  (process-wait p)            => 0
  (process-wait p 5000)       => 0 or #f
```

### `ps`

```
Syntax: (ps)
Library: (scm system)
Description: Returns a list of alists describing the processes currently
  visible on the system. Each alist has the keys:
    pid         — process id (integer)
    ppid        — parent pid (integer) or #f
    command     — process command as a string, or #f
    user        — owning user (string) or #f
    start-time  — epoch milliseconds (integer) or #f
    cpu-time    — accumulated cpu time in seconds (inexact) or #f
  Fields the platform cannot supply or that the current user cannot
  access are #f. Order is unspecified.
Example:
  (length (ps)) => 312
```

### `ps-info`

```
Syntax: (ps-info pid)
Library: (scm system)
Description: Returns an alist describing the process with the given pid,
  or #f if no such process exists or it cannot be inspected. See (ps)
  for the field set.
Example:
  (cdr (assq 'command (ps-info (current-pid)))) => "scm"
```

### `run`

```
Syntax: (run prog arg ...)
Library: (scm system)
Description: Varargs wrapper around run-program. Runs the external program
  prog with the given arguments and returns its exit code.
Example:
  (run "echo" "hello") => 0
```

### `run!`

```
Syntax: (run! prog arg ...)
Library: (scm system)
Description: Like run, but raises an error when the program exits non-zero
  or fails to launch. Returns 0 on success.
Example:
  (run! "true") => 0
```

### `run-parallel`

```
Syntax: (run-parallel fn values)
Library: (scm system)
Description: Runs fn in parallel over each element of values using one thread per
  element and returns the results as a list in the same order. Exceptions raised
  in any thread are propagated when joining.
Example:
  (run-parallel (lambda (x) (* x x)) '(1 2 3 4)) => (1 4 9 16)
```

### `run-program`

```
Syntax: (run-program cmd)
Library: (scm system)
Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns its exit code as an exact integer. Returns #f on failure.
Example:
  (run-program '("echo" "hello")) => 0
```

### `run-program/capture`

```
Syntax: (run-program/capture cmd [options])
Library: (scm system)
Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns a list (exit-code stdout stderr) where stdout and stderr are captured as strings. options is an alist with optional keys: 'work-dir <path>, 'stdin <string> (text to write to the child's standard input). Returns #f on failure.
Example:
  (run-program/capture '("echo" "hello")) => (0 "hello\n" "")
```

### `run?`

```
Syntax: (run? prog arg ...)
Library: (scm system)
Description: Returns #t when the program exits with status 0, #f otherwise.
  Useful for predicates like (run? "test" "-f" path).
Example:
  (run? "test" "-f" "/etc/hosts") => #t
```

### `sh`

```
Syntax: (sh prog arg ...)
Library: (scm system)
Description: Runs the program and returns its captured stdout as a string.
  Raises an error on non-zero exit. Trailing newlines are preserved.
Example:
  (sh "date" "+%Y") => "2026\n"
```

### `sh-lines`

```
Syntax: (sh-lines prog arg ...)
Library: (scm system)
Description: Like sh but returns stdout split into a list of lines
  (the trailing empty line from a final newline is dropped).
Example:
  (sh-lines "ls" "/tmp") => ("file1" "file2")
```

### `shell-quote`

```
Syntax: (shell-quote s)
Library: (scm system)
Description: Returns s quoted such that it can be safely passed as a single
  argument to a POSIX shell (e.g. via /bin/sh -c). Wraps the string in
  single quotes and escapes any embedded single quotes.
Example:
  (shell-quote "it's fine") => "'it'\\''s fine'"
```

### `sleep`

```
Syntax: (sleep seconds)
Library: (scm system)
Description: Pauses the current thread for the given number of seconds
  (which may be fractional). Returns an unspecified value. Uses SRFI 18
  thread-sleep! internally.
Example:
  (sleep 1.5)
```

### `start-program`

```
Syntax: (start-program cmd-and-args [options])
Library: (scm system)
Description: Starts an external program without waiting for it to finish and returns a process handle (a native value). cmd-and-args is a list (program arg1 arg2 ...). options is an alist with optional keys: 'work-dir <path>, 'log-file <path> (redirects stdout+stderr to this file). Use process-pid, process-kill, process-wait, process-alive? on the handle.
Example:
  (define p (start-program '("sleep" "30")))
  (process-kill p)
  (process-wait p)
```

### `sys-machine-name`

```
Syntax: (sys-machine-name)
Library: (scm system)
Description: Returns the hostname of the current machine as a string.
Example:
  (sys-machine-name) => "myhost"
```

### `sys-num-cpu-cores`

```
Syntax: (sys-num-cpu-cores)
Library: (scm system)
Description: Returns the number of logical CPU cores available to the current process as an integer.
Example:
  (sys-num-cpu-cores) => 8
```

### `sys-os-version`

```
Syntax: (sys-os-version)
Library: (scm system)
Description: Returns a list describing the operating system: (platform version-string major minor service-pack).
Example:
  (sys-os-version) => (linux "Unix 5.15.0.0" 5 15 "")
```

### `sys-platform`

```
Syntax: (sys-platform)
Library: (scm system)
Description: Returns a symbol identifying the current operating system platform: windows, linux, or unknown.
Example:
  (sys-platform) => linux
```

### `sys-scm-technology`

```
Syntax: (sys-scm-technology)
Library: (scm system)
Description: Returns a symbol identifying the SCM implementation technology: csharp or java.
Example:
  (sys-scm-technology) => java
```

### `sys-scm-version`

```
Syntax: (sys-scm-version)
Library: (scm system)
Description: Returns the SCM interpreter version as a string.
Example:
  (sys-scm-version) => "0.0.1"
```

### `sys-user-name`

```
Syntax: (sys-user-name)
Library: (scm system)
Description: Returns the name of the currently logged-in user as a string.
Example:
  (sys-user-name) => "alice"
```

### `uuidgen`

```
Syntax: (uuidgen)
Library: (scm system)
Description: Returns a random RFC 4122 version 4 UUID as a string in
  canonical 8-4-4-4-12 hyphenated form. Uses cryptographically random
  bytes; version and variant bits are set per the spec.
Example:
  (uuidgen) => "e3b0c442-98fc-4c14-9afb-f4ca495991b9"
```

### `watch`

```
Syntax: (watch thunk [option ...])
Library: (scm system)
Description: Repeatedly invokes the zero-argument thunk, sleeping between
  invocations. Returns when thunk raises or when the iteration limit is
  reached. Options:
    '(interval . seconds) — seconds between calls (default 2)
    '(count . n)          — stop after n iterations (default: forever)
Example:
  (watch (lambda () (display (sh "date")) (newline))
         '(interval . 5) '(count . 3))
```

