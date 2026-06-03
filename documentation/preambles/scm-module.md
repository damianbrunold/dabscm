## Overview

`(scm module)` is the interface to the module system: import libraries, inspect a
module's bindings and exports, and manage the module search path. Most programs
use `import` directly; the rest of the API is for tooling and introspection.

## Common uses

```scheme
(import (scm module))

(module-search-path)                 ;; => (".")
(module-search-path! '("." "/usr/share/scm"))
(current-module)                     ;; the module in effect
```

The lower-level `%module-*` procedures expose a module's bindings, exports, and
imports for introspection, and `%load-module` / `%reset-modules` manage loading.
