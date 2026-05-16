(import (scheme base)
        (build tools))

(check-dotnet-version)

(run-builder "build-scm-csharp.scm")
(run-builder "test-scm-csharp.scm")
