---
title: Getting started
part: basics
order: 1
libraries: (scheme base) (scheme write) (scheme process-context)
summary: Running scripts, the REPL, one-liners, formatting and linting, native executables.
---
# Getting started

dabscm is an R7RS Scheme with three implementations that run the same code:

| implementation | command | good for |
|---|---|---|
| JVM | `scm` (`scmj`), `java -jar scm.jar` | servers, long-running jobs (JIT), the widest platform support |
| .NET | `scmcs` | Windows integration, .NET hosts |
| native | `scm-native`, `scmc` | small static executables, fast start-up, command-line tools |

Everything in these tutorials runs on all three: every tested example in them
is executed by the test suites of each implementation.

## Your first script

Save this as `hello.scm`:

```scheme
(import (scheme base) (scheme write))

(define (greet name)
  (string-append "Hello, " name "!"))

(display (greet "world"))
(newline)
```

and run it:

```sh
$ scm hello.scm
Hello, world!
```

A script is an R7RS *program*: it starts with an `import` of the libraries it
uses, and nothing else is visible. `(scheme base)` has the core of the
language; `(scheme write)` adds `display`, `write` and `newline`. The
[libraries and programs](basics-10-libraries.md) chapter explains imports in
detail.

The procedure from the script, tried directly:

```scheme
(greet "Scheme") ;; => "Hello, Scheme!"
```

## The REPL

`scm` without arguments starts an interactive read-eval-print loop. The REPL
imports the usual libraries for you, so you can start typing right away:

```text
$ scm
> (+ 1 2 3)
6
> (define xs '(3 1 2))
xs
> (map (lambda (x) (* x x)) xs)
(9 1 4)
```

Use the REPL to try things; put everything you want to keep into a file.

## One-liners

`-e` evaluates an expression and prints its value, handy in shell scripts:

```sh
$ scm -e '(* 6 7)'
42
$ scm -e '(import (scheme char)) (string-upcase "shout")'
"SHOUT"
```

`-f` gives the expression the REPL's imports, `-b` none at all.

## Command-line arguments

`(command-line)` from `(scheme process-context)` returns the program name
followed by its arguments, as strings:

```scheme no-test
(import (scheme base) (scheme write) (scheme process-context))

(define args (cdr (command-line)))
(display (length args))
(display " arguments: ")
(write args)
(newline)
(exit (if (null? args) 1 0))
```

```sh
$ scm count.scm a b "c d"
3 arguments: ("a" "b" "c d")
```

`exit` ends the program with an exit status (`#t` or `0` for success).
For real command-line tools with options and help texts, see the
[command-line programs](techniques-09-command-line.md) tutorial.

## Which implementation am I on?

`(features)` lists what the running implementation supports; programs can
test it with `cond-expand`:

```scheme
(import (scheme process-context))

(and (memq 'r7rs (features)) #t) ;; => #t

(define implementation
  (cond-expand
    (dabscm-native "native")
    (else "JVM or .NET")))

(string? implementation) ;; => #t
```

## Formatting and checking your code

Two tools ship with every `scm`:

```sh
$ scm fmt src/            # format all .scm and .sld files in place
$ scm fmt --check src/    # list files that would change
$ scm lint src/           # unbound names, unused imports, arity errors, ...
```

`scm lint` finds many mistakes before you run the code, for example a
misspelled procedure name or a forgotten import. Run it often.

## Native executables

`scmc` compiles a program, with every library it imports, into one
executable that needs nothing installed:

```sh
$ scmc hello.scm -o hello
$ ./hello
Hello, world!
```

The executable starts in milliseconds, which makes it the right choice for
small tools. The program is compiled as a whole, so `eval` of arbitrary new
code is still possible, but tools that inspect bytecode are not.

## Where next

- [Expressions and values](basics-02-values.md): numbers, booleans, symbols, strings.
- Reference: `(scheme base)`, `(scheme write)`, `(scheme process-context)`.
