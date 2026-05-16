(import (scheme base)
        (build tools))

(define run-config '("-c" "Release"))

(run-tool-in-csharp-tests 'test `(,dotnet-cmd "run" ,@run-config))
