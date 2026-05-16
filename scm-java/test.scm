(import (scheme base)
        (scheme file)
        (scheme write)
        (srfi 1)
        (srfi 13)
        (scm fs)
        (scm list)
        (scm io)
        (scm system))

(define (collect-files path extension)
  (let loop-files ((files (directory-files path)) (result '()))
    (if (null? files)
        (let loop-dirs ((dirs (directory-directories path)) (result result))
          (if (null? dirs)
              (reverse result)
              (loop-dirs (cdr dirs)
                         (append result
                                 (collect-files
                                  (join-path path (car dirs))
                                  extension)))))
        (if (string-suffix? extension (car files))
            (loop-files (cdr files)
                        (cons (join-path path (car files)) result))
            (loop-files (cdr files)
                        result)))))

(define (write-file path lines)
  (call-with-output-file (list path 'latin-1)
    (lambda (port)
      (for-each (lambda (line)
                  (display line port)
                  (newline port))
                lines))))

(define (get-java-executable cmd)
  (if (eq? (sys-platform) 'linux)
      (which cmd)
      (which (string-append cmd ".exe"))))

(define (compile-java-files path output cp)
  (let ((sources (collect-files path ".java"))
        (options `("-cp" ,cp
                   "-d" ,output
                   "-encoding" "UTF-8"
                   "-source" "11"
                   "-target" "11"
                   "-Xlint:-options")))
    (write-file (join-path "build" "_javac_input")
                (append options sources))
    (let ((exit-code (run-program (list (get-java-executable "javac")
                                        "@build/_javac_input"))))
      (if (not (zero? exit-code))
          (error 'error "compilation failed")))))

(define (run-unittests path resources cp work-dir)
  (let* ((cmd (list (get-java-executable "java")
                    "-cp" (string-join (list path cp resources) field-sep)
                    "scheme.SchemeTests"))
         (options (list (list 'work-dir work-dir)))
         (exit-code (run-program cmd options)))
    (if (not (zero? exit-code))
        (error 'error "unittests failed"))))

(make-directory (join-path "build" "test"))
(compile-java-files (join-path "src" "test")
                    (join-path "build" "test")
                    (join-path "build" "build"))

;; Copy test category subdirectories to build/test/
(define test-categories '("core" "tests" "failures"))
(for-each
 (lambda (category)
   (let ((src-dir (join-path "src" "test" category))
         (dst-dir (join-path "build" "test" category)))
     (when (directory-exists? src-dir)
       (when (directory-exists? dst-dir) (delete-directory dst-dir))
       (make-directory dst-dir)
       (for-each
        (lambda (file)
          (copy-file (join-path src-dir file)
                     (join-path dst-dir file)))
        (directory-files src-dir)))))
 test-categories)

(run-unittests "test" "../src/test" "build" "build")
