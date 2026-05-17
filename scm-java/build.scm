(import (scheme base)
        (scheme file)
        (scheme write)
        (srfi 1)
        (srfi 13)
        (scm fs)
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

(define (append-continuation-line lst line)
  (let loop ((line line) (lst lst))
    (if (> (string-length line) 72)
        (loop (format #f "  ~a" (substring line 72))
              (append lst (list (substring line 0 72))))
        (if (not (zero? (string-length line)))
            (append lst (list line))
            lst))))

(define (append-continuation-lines lst lines)
  (let loop ((lines lines) (lst lst))
    (if (null? lines)
        lst
        (loop (cdr lines) (append-continuation-line lst (car lines))))))

(define (create-jar-file jarfile basedir main-class cp)
  (let ((jar (get-java-executable "jar"))
        (manifest (append-continuation-lines
                   '()
                   (list (format #f "Main-Class: ~a" main-class)
                         (format #f "Class-Path: ~a" cp)))))
    (write-file (join-path "build" "_manifest") manifest)
    (let ((exit-code (run-program (list jar
                                        "--create"
                                        "--file" jarfile
                                        "--manifest" (join-path "build" "_manifest")
                                        "-C" (string-append basedir "/")
                                        "."))))
      (delete-file (join-path "build" "_manifest"))
      (if (not (zero? exit-code))
          (error 'err "Jarfile creation failed")))))

(define (run-unittests path resources cp work-dir)
  (let* ((cmd (list (get-java-executable "java")
                    "-cp" (string-join (list path cp resources) field-sep)
                    "scheme.SchemeTests"))
         (options (list (list 'work-dir work-dir)))
         (exit-code (run-program cmd options)))
    (if (not (zero? exit-code))
        (error 'error "unittests failed"))))

(if (directory-exists? "build") (delete-directory "build"))
(make-directory "build")

(make-directory (join-path "build" "build"))
(compile-java-files (join-path "src" "main")
                    (join-path "build" "build")
                    ".")
(copy-file (join-path "src" "main" "library.scm")
           (join-path "build" "build" "library.scm"))
;; Version is read from the repo-root VERSION file — single source of
;; truth shared with the C# build (see ../scm-csharp/Directory.Build.props).
(copy-file (join-path ".." "VERSION")
           (join-path "build" "build" "version.txt"))
(make-directory (join-path "build" "build" "libraries"))
(for-each
  (lambda (f)
    (when (string-suffix? ".sld" f)
      (copy-file (join-path "src" "main" "scheme" "libraries" f)
                 (join-path "build" "build" "libraries" f))))
  (directory-files (join-path "src" "main" "scheme" "libraries")))

(create-jar-file "scm.jar"
                 (join-path "build" "build")
                 "scheme.Scheme"
                 ".")
