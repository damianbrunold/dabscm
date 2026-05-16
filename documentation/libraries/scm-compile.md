# `(scm compile)`

Compiler introspection, bytecode access, and type predicates

## Exports

### `atom?`

```
Syntax: (atom? obj)
Library: (scm compile)
Description: Returns #t if obj is an atomic value: a number, boolean, char,
string, or symbol. Returns #f for pairs, vectors, and other compound objects.
Example:
  (atom? 42)   => #t
  (atom? 'x)   => #t
  (atom? '(1)) => #f
```

### `bound?`

```
Syntax: (bound? symbol)
Library: (scm core)
Description: Returns #t if the given symbol is bound to a value in the current module.
Example:
  (bound? 'car) => #t
  (bound? 'undefined-name) => #f
```

### `compile`

```
Syntax: (compile expr)
Library: (scm compile)
Description: Compiles the given Scheme expression to a bytecode instruction vector without evaluating it.
Example:
  (compile '(+ 1 2)) => #(...)
```

### `constant?`

```
Syntax: (constant? obj)
Library: (scm core)
Description: Returns #t if obj is a self-quoting constant: a number, boolean, character, string, or a quoted datum. Used internally by the quasiquote expander.
Example:
  (constant? 42) => #t
  (constant? 'x) => #f
  (constant? '(quote foo)) => #t
```

### `disassemble`

```
Syntax: (disassemble fn) (disassemble fn port)
Library: (scm compile)
Description: Writes a human-readable disassembly of the bytecode of the lambda fn to the current output port (or to port if given).
Example:
  (disassemble (lambda (x) (+ x 1)))
```

### `gensym`

```
Syntax: (gensym)
Library: (scm core)
Description: Returns a fresh, unique, non-interned symbol. Each call returns a symbol distinct from all previously generated symbols.
Example:
  (gensym) => gensym-1
  (eq? (gensym) (gensym)) => #f
```

### `get-code`

```
Syntax: (get-code fn)
Library: (scm compile)
Description: Returns the bytecode instructions of the lambda fn as a list of strings.
Example:
  (get-code (lambda (x) x)) => ("LOAD_ARG 0" ...)
```

### `get-lambda-env`

```
Syntax: (get-lambda-env fn)
Library: (scm compile)
Description: Returns the closed-over environment of the lambda fn.
Example:
  (let ((x 42)) (get-lambda-env (lambda () x)))
```

### `get-token`

```
Syntax: (get-token) (get-token port)
Library: (scm core)
Description: Reads and returns the next token from the given input port (or current input port). Returns #f at end-of-input.
Example:
  (get-token (open-input-string "(+ 1 2)"))
```

### `instruction-arg1`

```
Syntax: (instruction-arg1 inst)
Library: (scm compile)
Description: Returns the first argument of the given bytecode instruction, or unspecified if it has none.
Example:
  (instruction-arg1 (car (get-code (lambda () 42))))
```

### `instruction-arg2`

```
Syntax: (instruction-arg2 inst)
Library: (scm compile)
Description: Returns the second argument of the given bytecode instruction, or unspecified if it has none.
Example:
  (instruction-arg2 (car (get-code (lambda () 42))))
```

### `instruction-opcode`

```
Syntax: (instruction-opcode inst)
Library: (scm compile)
Description: Returns the opcode of the given bytecode instruction as a symbol.
Example:
  (instruction-opcode (car (get-code (lambda () 42)))) => LOAD_CONST
```

### `lambda?`

```
Syntax: (lambda? obj)
Library: (scm core)
Description: Returns #t if obj is a compiled lambda (procedure), otherwise returns #f.
Example:
  (lambda? (lambda (x) x)) => #t
  (lambda? 42) => #f
```

### `macro?`

```
Syntax: (macro? obj)
Library: (scm compile)
Description: Returns #t if obj is a macro (a pair whose car is the symbol
'macro and whose cadr is a procedure), otherwise returns #f.
Example:
  (macro? (list 'macro (lambda (x) x))) => #t
  (macro? car) => #f
```

### `make-instruction`

```
Syntax: (make-instruction opcode) (make-instruction opcode arg1) (make-instruction opcode arg1 arg2)
Library: (scm compile)
Description: Creates a bytecode instruction object with the given opcode symbol and optional arguments.
Example:
  (make-instruction 'LOAD_CONST 42)
```

### `primitive?`

```
Syntax: (primitive? obj)
Library: (scm core)
Description: Returns #t if obj is a built-in primitive procedure, otherwise returns #f.
Example:
  (primitive? car) => #t
  (primitive? (lambda (x) x)) => #f
```

### `set-code!`

```
Syntax: (set-code! fn instructions)
Library: (scm compile)
Description: Replaces the bytecode instructions of the lambda fn with the given instructions list. Used for low-level code patching.
Example:
  (define f (lambda (x) x))
  (set-code! f (get-code f))
```

