(import (scheme base)
        (build tools))

(check-java-version)

(run-builder "build-scm-java.scm")
(run-builder "test-scm-java.scm")
