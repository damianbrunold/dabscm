(define-library (scm fs)
  (import (scm core))
  (export absolute-path
          base-name
          copy-directory
          copy-file
          current-directory
          delete-directory
          delete-file
          directory-directories
          directory-exists?
          directory-files
          directory-name
          file-exists?
          file-modification-date
          file-modification-timestamp
          file-size
          join-path
          make-directory
          move-directory
          move-file
          normalized-path
          path-sep
          special-folder-application-data
          special-folder-documents
          special-folder-temp
          which)
  (begin
    (define path-sep (%primitive "path-sep"))
    (define string-join (%primitive "string-join"))

    (define absolute-path (%primitive "absolute-path"))
    (define base-name (%primitive "base-name"))
    (define copy-directory (%primitive "copy-directory"))
    (define copy-file (%primitive "copy-file"))
    (define current-directory (%primitive "current-directory"))
    (define delete-directory (%primitive "delete-directory"))
    (define delete-file (%primitive "delete-file"))
    (define directory-directories (%primitive "directory-directories"))
    (define directory-exists? (%primitive "directory-exists?"))
    (define directory-files (%primitive "directory-files"))
    (define directory-name (%primitive "directory-name"))
    (define file-exists? (%primitive "file-exists?"))
    (define file-modification-date (%primitive "file-modification-date"))
    (define file-modification-timestamp (%primitive "file-modification-timestamp"))
    (define file-size (%primitive "file-size"))
    (define make-directory (%primitive "make-directory"))
    (define move-directory (%primitive "move-directory"))
    (define move-file (%primitive "move-file"))
    (define normalized-path (%primitive "normalized-path"))
    (define special-folder-application-data (%primitive "special-folder-application-data"))
    (define special-folder-documents (%primitive "special-folder-documents"))
    (define special-folder-temp (%primitive "special-folder-temp"))
    (define which (%primitive "which"))

    (define (join-path . parts)
      "Syntax: (join-path part ...)
Library: (scm fs)
Description: Joins one or more path component strings into a single path
  string using the platform's path separator character.
Example:
  (join-path \"/usr\" \"local\" \"bin\") => \"/usr/local/bin\"  ; on Unix"
      (string-join parts path-sep))))
