# `(scm args)`

## Exports

### `arg-parser?`

*(no documentation)*

### `arg-result?`

*(no documentation)*

### `arg-spec?`

*(no documentation)*

### `arg-type?`

*(no documentation)*

### `arg:boolean`

*(no documentation)*

### `arg:integer`

*(no documentation)*

### `arg:list`

```
Syntax: (arg:list elem-type [separator])
Library: (scm args)
Description: A type that splits the argument on separator (a char, default
  #\,) and converts each piece with elem-type, returning a list. elem-type
  may be any type or bare converter procedure. Empty pieces are kept.
Example:
  (option nums (long "nums") (type (arg:list arg:integer)))
  ;; --nums 1,2,3  =>  (1 2 3)
```

### `arg:number`

*(no documentation)*

### `arg:one-of`

```
Syntax: (arg:one-of sym ...)
Library: (scm args)
Description: A type accepting only one of the given symbols (an enumeration).
  The argument string is read as a symbol and must be a member of syms;
  otherwise a usage error listing the choices is reported. In --help the
  placeholder renders as {sym|sym|...}. Note the symbols are evaluated, so
  quote them: (arg:one-of 'fast 'slow).
Example:
  (option mode (long "mode") (type (arg:one-of 'fast 'slow)) (default 'fast))
```

### `arg:string`

*(no documentation)*

### `arg:symbol`

*(no documentation)*

### `args->alist`

```
Syntax: (args->alist result)
Library: (scm args)
Description: Returns the full association list of (name . value) pairs from a
  parse-args result. Handy for debugging or bulk processing.
Example:
  (args->alist r) => ((verbose . #t) (count . 3) (input . "in.txt"))
```

### `args-ref`

```
Syntax: (args-ref result name [fallback])
Library: (scm args)
Description: Returns the value parsed for name (a symbol) from a parse-args
  result. If name was not supplied and has no default, returns fallback (or
  #f when no fallback is given). Flags return #t/#f; repeatable options
  return a list.
Example:
  (args-ref r 'count) => 3
  (args-ref r 'output "-") => "-"   ; not supplied, fallback used
```

### `args-rest`

```
Syntax: (args-rest result)
Library: (scm args)
Description: Returns the list of leftover positional tokens. When the parser
  declares no positional specs, every positional argument lands here; when
  it does declare positionals, this is the empty list (use a repeat
  positional to capture a variable tail by name instead).
Example:
  (args-rest r) => ("a.txt" "b.txt")
```

### `coerce-type`

```
Syntax: (coerce-type t)
Library: (scm args)
Description: Normalizes a type designator to an arg-type: an arg-type is
  returned unchanged; a bare procedure is wrapped as a string->value
  converter with the placeholder "VALUE". Used internally and when writing
  custom type combinators.
Example:
  (coerce-type string->number) => #<arg-type VALUE>
```

### `define-cli`

*(no documentation)*

### `flag`

```
Syntax: (flag name key value ...)
Library: (scm args)
Description: Builds a boolean flag spec (data form). Presence sets it to #t;
  --no-<long> sets it to #f. Keys: short, long, default, help. Use inside
  make-arg-parser's 'options list.
Example:
  (flag 'verbose 'short #\v 'long "verbose" 'help "Verbose output")
```

### `format-help`

```
Syntax: (format-help parser)
Library: (scm args)
Description: Renders the --help text for parser as a string: a usage line,
  the description, an Arguments section for positionals, and an Options
  section (including the auto-generated --help and --version entries).
  parse-args prints this and exits 0 on --help/-h.
Example:
  (display (format-help cli))
```

### `make-arg-parser`

```
Syntax: (make-arg-parser key value ...)
Library: (scm args)
Description: Builds an argument parser (data form). Keys: program (string),
  description, version, epilog, options (list of opt/flag specs),
  positionals (list of pos specs). The declarative define-cli macro is a
  more readable front end producing the same object.
Example:
  (make-arg-parser 'program "tool"
    'options (list (flag 'verbose 'short #\v))
    'positionals (list (pos 'file 'required #t)))
```

### `make-arg-type`

```
Syntax: (make-arg-type name convert)
Library: (scm args)
Description: Builds a custom argument type. name is a short string shown in
  --help as the value placeholder (e.g. "PORT"); convert is a procedure
  taking the raw argument string and returning the converted value, raising
  via error on invalid input (the message is surfaced to the user). Any
  bare string->value procedure also works as a type — parse-args coerces it
  with the placeholder "VALUE".
Example:
  (define arg:port
    (make-arg-type "PORT"
      (lambda (s)
        (let ((n (string->number s)))
          (if (and n (integer? n) (<= 1 n 65535)) n
              (error (string-append "bad port: " s)))))))
```

### `opt`

```
Syntax: (opt name key value ...)
Library: (scm args)
Description: Builds a key-value option spec (data form). Keys: short (a
  char), long (a string), type (an arg-type, default arg:string), default,
  required (boolean), repeat (boolean — collect repeats into a list), help,
  metavar. Use inside make-arg-parser's 'options list.
Example:
  (opt 'count 'short #\n 'long "count" 'type arg:integer 'default 1)
```

### `parse-args`

```
Syntax: (parse-args parser [args] ['on-error mode])
Library: (scm args)
Description: Parses argument list args (default: (cdr (command-line)), i.e.
  the script's arguments with the program path removed) against parser,
  returning a result usable with args-ref / args->alist / args-rest. Values
  are converted to their declared types. mode is 'exit (default) — on a
  usage error print a diagnostic to (current-error-port) and exit 2 — or
  'raise to signal a catchable error instead. --help and --version always
  print to stdout and exit 0.
Example:
  (define r (parse-args cli '("-v" "--count" "3" "in.txt")))
  (args-ref r 'count) => 3
```

### `pos`

```
Syntax: (pos name key value ...)
Library: (scm args)
Description: Builds a positional argument spec (data form). Keys: type,
  required, default, repeat (variadic — collects all remaining positionals
  into a list; must be the last positional), help. Use inside
  make-arg-parser's 'positionals list.
Example:
  (pos 'input 'type arg:string 'required #t 'help "Input file")
```

