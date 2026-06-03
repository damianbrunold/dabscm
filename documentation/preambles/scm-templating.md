## Overview

`(scm templating)` fills `{{placeholder}}` markers in a template string from a
context (an association list of name → value). It can render a template given
inline or from a file, and a reusable engine can be created for repeated use.

## Common uses

```scheme
(import (scm templating))

(template-render "Hello {{name}}!" (list (cons "name" "Ada")))
;; => "Hello Ada!"
```

Render a template stored in a file with `template-render-file`, or build a
reusable engine with `make-template-engine` and render through
`template-engine-render`.
