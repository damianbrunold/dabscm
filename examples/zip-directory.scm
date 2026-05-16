;;
;; zip-directory.scm — Create a ZIP archive from a directory tree.
;;
;; Usage: scm zip-directory.scm <output.zip> <directory>
;;
;; Recursively adds all files and subdirectories from <directory>
;; into <output.zip>, preserving the relative path structure.
;;

(import (scheme base)
        (scheme write)
        (scheme file)
        (scheme process-context)
        (scm fs)
        (scm zip))

(define (read-file-bytevector path)
  "Read the entire contents of a file as a bytevector."
  (let* ((size (file-size path))
         (in (open-binary-input-file path)))
    (let ((bv (read-bytevector size in)))
      (close-input-port in)
      bv)))

(define (collect-files base-dir prefix)
  "Recursively collect all files under base-dir.
   Returns a list of (relative-path . full-path) pairs."
  (let ((files (directory-files base-dir))
        (dirs (directory-directories base-dir)))
    (append
     (map (lambda (f)
            (let ((rel (if (string=? prefix "")
                           f
                           (string-append prefix "/" f)))
                  (full (join-path base-dir f)))
              (cons rel full)))
          files)
     (apply append
            (map (lambda (d)
                   (let ((rel (if (string=? prefix "")
                                  d
                                  (string-append prefix "/" d))))
                     (collect-files (join-path base-dir d) rel)))
                 dirs)))))

(define (zip-directory output-zip dir)
  "Create a ZIP file containing all files in dir recursively."
  (let ((entries (collect-files dir "")))
    (call-with-output-zip output-zip
      (lambda (z)
        (for-each
         (lambda (entry)
           (let ((rel-path (car entry))
                 (full-path (cdr entry)))
             (let ((port (zip-add-binary-entry z rel-path)))
               (let ((bv (read-file-bytevector full-path)))
                 (write-bytevector bv port)
                 (flush-output-port port)))))
         entries)))
    (display (string-append "Created " output-zip " with "
                            (number->string (length entries))
                            " entries.\n"))))

(define (main)
  (let ((args (command-line)))
    (when (not (= (length args) 3))
      (display "Usage: scm zip-directory.scm <output.zip> <directory>\n"
               (current-error-port))
      (exit 1))
    (let ((output-zip (list-ref args 1))
          (dir (list-ref args 2)))
      (when (not (directory-exists? dir))
        (display (string-append "Error: directory '" dir "' does not exist.\n")
                 (current-error-port))
        (exit 1))
      (zip-directory output-zip dir))))

(main)
