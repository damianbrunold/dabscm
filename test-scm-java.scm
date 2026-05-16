(import (scheme base)
        (build tools))

(run-tool-in-java 'test `(,java-cmd "-jar" "../scm-bootstrap.jar" "test.scm"))
