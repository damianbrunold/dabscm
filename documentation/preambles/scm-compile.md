## Overview

`(scm compile)` exposes the interpreter's compiler internals: compile expressions
to bytecode, disassemble lambdas, generate fresh symbols, and test values with
low-level predicates. It's mainly useful for tooling, debugging, and
metaprogramming.

## Common uses

```scheme
(import (scm compile))

(macro? car)        ;; => #f
(primitive? car)    ;; => #t
(gensym)            ;; => a fresh, unique symbol

(disassemble (lambda (x) (+ x 1)))   ;; print the bytecode of a lambda
```

Other tools include `compile` (source → code), `get-code` / `set-code!` and the
`instruction-*` accessors for inspecting bytecode, and predicates like
`constant?`, `lambda?`, and `bound?`.
