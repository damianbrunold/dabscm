(import (scheme base)
        (build tools))

(define run-config '("-c" "Release"))

;; a full build: the test files are embedded resources, and the copies
;; update-scheme-files.scm makes keep their sources' times, which an
;; incremental build can take for unchanged
(run-tool-in-csharp-tests 'build `(,dotnet-cmd "build" "--no-incremental" ,@run-config))
(run-tool-in-csharp-tests 'test `(,dotnet-cmd "run" "--no-build" ,@run-config))
