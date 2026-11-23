;; eval and environment find libraries in the directories module-search-path!
;; set at run time, as on the JVM (bld.scm sets buildsys/lib this way)
(import (scheme base) (scheme eval) (scheme write) (scm module))
(module-search-path! (cons "rtpath-dir" (module-search-path)))
(write (eval '(greeting) (environment '(scheme base) '(rtpath lib))))
(newline)
