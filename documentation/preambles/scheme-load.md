## Overview

`(scheme load)` provides `load`, which reads and evaluates the expressions in a
Scheme source file as if they were typed at the REPL.

## Common uses

```scheme
(import (scheme load))

(load "helpers.scm")   ;; evaluate every form in the file
```

`load` is convenient for scripts and interactive work. For structured code reuse,
prefer libraries and `import`.
