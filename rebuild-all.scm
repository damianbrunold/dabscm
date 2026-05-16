(import (scheme base)
        (build tools))

;; The scm-bootstrap.jar needs only be good enough to
;; successfully run these scripts. Thus, it may well
;; be not up to date. But this is a good way to bootstrap
;; and to build on windows, where files in use cannot be
;; replaced.

(run-builder "update-scheme-files.scm")
(run-builder "build-and-test-scm-csharp.scm")
(run-builder "build-and-test-scm-java.scm")
(run-builder "update-documentation.scm")
