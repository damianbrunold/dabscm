## Overview

`(scm args)` is declarative command-line argument parsing. You describe a grammar
once — options, flags, key/value options, and positionals, each optionally typed —
and hand it to `parse-args`, which validates the input, converts values to their
declared types, and gives you a result to query. It also renders `--help` and
handles `--version` for you.

## Common uses

Build a parser and parse an argument list:

```scheme
(import (scm args))

(define cli
  (make-arg-parser
    'options (list (flag 'verbose 'short #\v 'long "verbose")
                   (opt  'count   'short #\c 'long "count" 'type arg:integer))
    'positionals (list (pos 'file 'type arg:string))))

(define r (parse-args cli '("-v" "--count" "3" "in.txt")))

(args-ref r 'verbose)   ;; => #t
(args-ref r 'count)     ;; => 3   (converted to an integer)
(args-ref r 'file)      ;; => "in.txt"
```

With no argument list, `parse-args` reads the script's own arguments. Built-in
types include `arg:string`, `arg:integer`, `arg:number`, `arg:boolean`,
`arg:symbol`, `arg:one-of`, and `arg:list`; define your own with `make-arg-type`.
`format-help` renders usage text, and the `define-cli` macro offers a compact
declarative form.
