(import (scheme base)
        (build tools))

(run-tool-in-java 'build `(,java-cmd "-jar" "../scm-bootstrap.jar" "build.scm"))
