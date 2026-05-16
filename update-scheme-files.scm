(import (scheme base)
        (scheme write)
        (scheme file)
        (srfi 1)
        (srfi 13)
        (scm fs)
        (scm list))

(define base-dir (directory-name script-name))

(define libs-src-dir (join-path base-dir "scm-lib" "libraries"))
(define csharp-libs-dir (join-path base-dir "scm-csharp" "scheme" "libraries"))
(define java-libs-dir (join-path base-dir "scm-java" "src" "main" "scheme" "libraries"))

(define tests-src-dir (join-path base-dir "scm-tests"))
(define csharp-tests-dir (join-path base-dir "scm-csharp" "tests"))
(define java-tests-dir (join-path base-dir "scm-java" "src" "test"))

;; Test category subdirectories
(define test-categories '("core" "tests" "failures"))

(define (delete-files dir pred)
  (for-each
   (lambda (file) (delete-file (join-path dir file)))
   (filter pred (directory-files dir))))

;; Sync library.scm
(display "library.scm")
(copy-file (join-path base-dir "scm-lib" "library.scm")
           (join-path base-dir "scm-csharp" "scheme" "library.scm"))
(copy-file (join-path base-dir "scm-lib" "library.scm")
           (join-path base-dir "scm-java" "src" "main" "library.scm"))
(newline)

;; Sync .sld library files
(delete-files csharp-libs-dir (lambda (fname) (string-suffix? ".sld" fname)))
(delete-files java-libs-dir (lambda (fname) (string-suffix? ".sld" fname)))
(for-each
  (lambda (sld-file)
    (let ((src (join-path libs-src-dir sld-file)))
      (display (join-path (base-name libs-src-dir) sld-file))
      (copy-file src (join-path csharp-libs-dir sld-file))
      (copy-file src (join-path java-libs-dir sld-file))
      (newline)))
  (filter (lambda (f) (string-suffix? ".sld" f))
          (directory-files libs-src-dir)))

;; Sync test category subdirectories
(for-each
 (lambda (category)
   (let ((src-dir (join-path tests-src-dir category))
         (csharp-dir (join-path csharp-tests-dir category))
         (java-dir (join-path java-tests-dir category)))
     ;; Ensure destination directories exist (delete and recreate for clean sync)
     (when (directory-exists? csharp-dir) (delete-directory csharp-dir))
     (when (directory-exists? java-dir) (delete-directory java-dir))
     (make-directory csharp-dir)
     (make-directory java-dir)
     ;; Copy all files in this category
     (when (directory-exists? src-dir)
       (for-each
        (lambda (file)
          (display (join-path category file))
          (copy-file (join-path src-dir file)
                     (join-path csharp-dir file))
          (copy-file (join-path src-dir file)
                     (join-path java-dir file))
          (newline))
        (directory-files src-dir)))))
 test-categories)

(display "done")
(newline)
