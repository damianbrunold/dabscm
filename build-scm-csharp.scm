(import (scheme base)
        (build tools))

(define run-config '("-c" "Release"))

(run-tool-in-csharp 'build `(,dotnet-cmd "build" ,@run-config))
