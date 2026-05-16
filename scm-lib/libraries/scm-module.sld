(define-library (scm module)
  (import (scm core))
  (export %load-module
          %module-bind
          %module-bindings
          %module-defined-bindings
          %module-export-bindings
          %module-exports
          %module-import-bindings
          %module-ref
          %reset-modules
          import
          current-module
          module-search-path
          module-search-path!
          modules
          set-current-module)
  (begin
    (define current-module (%primitive "current-module"))
    (define %module-bind (%primitive "%module-bind"))
    (define %module-bindings (%primitive "%module-bindings"))
    (define %module-defined-bindings (%primitive "%module-defined-bindings"))
    (define %module-ref (%primitive "%module-ref"))
    (define %module-exports (%primitive "%module-exports"))
    (define %module-export-bindings (%primitive "%module-export-bindings"))
    (define %module-import-bindings (%primitive "%module-import-bindings"))
    (define set-current-module (%primitive "set-current-module"))
    (define %reset-modules (%primitive "%reset-modules"))
    (define %load-module (%primitive "%load-module"))))
