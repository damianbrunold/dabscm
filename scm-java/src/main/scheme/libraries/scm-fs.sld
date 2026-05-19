(define-library (scm fs)
  (import (scm core) (scheme base))
  (export absolute-path
          base-name
          cd
          chmod
          chown
          copy-directory
          copy-file
          cp
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
          ln
          make-directory
          mktemp
          mktempdir
          move-directory
          move-file
          mv
          normalized-path
          path-sep
          readlink
          rm
          special-folder-application-data
          special-folder-documents
          special-folder-temp
          stat
          touch
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

    (define %run-capture (%primitive "run-program/capture"))
    (define %run-program (%primitive "run-program"))
    (define cd (%primitive "set-current-directory!"))
    (define %sys-platform (%primitive "sys-platform"))
    (define %open-output-file (%primitive "open-output-file"))
    (define %close-output-port (%primitive "close-output-port"))
    (define %jiffy (%primitive "%jiffy"))
    (define %number->string (%primitive "number->string"))
    (define %string-append (%primitive "string-append"))
    (define %string-length (%primitive "string-length"))
    (define %string-ref (%primitive "string-ref"))
    (define %substring (%primitive "substring"))
    (define %string=? (%primitive "string=?"))
    (define %symbol->string (%primitive "symbol->string"))
    (define %counter 0)
    (define (%next-counter)
      (set! %counter (+ %counter 1))
      %counter)

    (define (%has-flag? opts sym)
      (let loop ((o opts))
        (cond ((null? o) #f)
              ((eq? (car o) sym) #t)
              (else (loop (cdr o))))))

    (define (%opt-value opts sym default)
      (let loop ((o opts))
        (cond ((null? o) default)
              ((and (pair? (car o)) (eq? (car (car o)) sym)) (cdr (car o)))
              (else (loop (cdr o))))))

    (define (%windows?)
      (let ((p (%sys-platform)))
        (or (eq? p 'windows)
            (and (symbol? p)
                 (let ((s (%symbol->string p)))
                   (and (>= (%string-length s) 3)
                        (%string=? (%substring s 0 3) "win")))))))

    (define (%strip-newline s)
      (let ((n (%string-length s)))
        (if (and (> n 0) (char=? (%string-ref s (- n 1)) #\newline))
            (%substring s 0 (- n 1))
            s)))

    (define (join-path . parts)
      "Syntax: (join-path part ...)
Library: (scm fs)
Description: Joins one or more path component strings into a single path
  string using the platform's path separator character.
Example:
  (join-path \"/usr\" \"local\" \"bin\") => \"/usr/local/bin\"  ; on Unix"
      (string-join parts path-sep))

    (define (touch path . opts)
      "Syntax: (touch path [option ...])
Library: (scm fs)
Description: Creates path as an empty file if it does not exist. When path
  already exists and a native touch command is available on PATH, its
  modification time is updated. Option 'no-create (-c) skips creation of
  missing files. Returns #t on success, #f otherwise.
Example:
  (touch \"/tmp/foo\")"
      (let ((exists? (file-exists? path)))
        (cond
          ((and (not exists?) (%has-flag? opts 'no-create)) #f)
          ((not exists?)
           (let ((p (%open-output-file path)))
             (%close-output-port p))
           #t)
          (else
           (let ((native (which "touch")))
             (if native
                 (zero? (%run-program (list native path)))
                 #t))))))

    (define (chmod path mode . opts)
      "Syntax: (chmod path mode [option ...])
Library: (scm fs)
Description: Changes file mode bits via the native chmod command. mode is
  either an octal string (e.g. \"755\") or a symbolic spec (\"u+x\").
  Options: 'recursive (-R). On Windows this is a best-effort no-op when
  no native chmod is available.
Example:
  (chmod \"script.sh\" \"755\")
  (chmod \"dir\" \"700\" 'recursive)"
      (let ((native (which "chmod")))
        (if native
            (let* ((mode-str (if (string? mode) mode (%number->string mode 8)))
                   (args (if (%has-flag? opts 'recursive)
                             (list native "-R" mode-str path)
                             (list native mode-str path))))
              (zero? (%run-program args)))
            (if (%windows?) #f
                (error "chmod: native chmod not found")))))

    (define (chown path owner . opts)
      "Syntax: (chown path owner [option ...])
Library: (scm fs)
Description: Changes the owner (and optionally group) of path. owner is a
  string like \"user\" or \"user:group\". Options: 'recursive (-R).
  Returns #t on success, #f otherwise. Best-effort no-op on Windows.
Example:
  (chown \"file\" \"alice:staff\")"
      (let ((native (which "chown")))
        (if native
            (let ((args (if (%has-flag? opts 'recursive)
                            (list native "-R" owner path)
                            (list native owner path))))
              (zero? (%run-program args)))
            (if (%windows?) #f
                (error "chown: native chown not found")))))

    (define (ln target name . opts)
      "Syntax: (ln target name [option ...])
Library: (scm fs)
Description: Creates a link at name pointing to target. Options:
  'symbolic (-s) creates a symbolic link, otherwise a hard link;
  'force (-f) replaces an existing destination.
Example:
  (ln \"/usr/bin/python3\" \"/usr/local/bin/python\" 'symbolic 'force)"
      (let ((native (which "ln")))
        (if native
            (let* ((args (list native))
                   (args (if (%has-flag? opts 'symbolic) (append args '("-s")) args))
                   (args (if (%has-flag? opts 'force)    (append args '("-f")) args))
                   (args (append args (list target name))))
              (zero? (%run-program args)))
            (if (%windows?)
                (let ((sym? (%has-flag? opts 'symbolic)))
                  (zero? (%run-program
                          (if sym?
                              (list "cmd" "/c" "mklink" name target)
                              (list "cmd" "/c" "mklink" "/H" name target)))))
                (error "ln: native ln not found")))))

    (define (readlink path)
      "Syntax: (readlink path)
Library: (scm fs)
Description: Returns the target of the symbolic link at path as a string,
  or #f if path is not a symlink or cannot be read. Uses native readlink.
Example:
  (readlink \"/usr/local/bin/python\") => \"/usr/bin/python3\""
      (let ((native (which "readlink")))
        (if native
            (let ((r (%run-capture (list native "-f" path))))
              (if (and (pair? r) (zero? (car r)))
                  (%strip-newline (cadr r))
                  #f))
            #f)))

    (define (stat path)
      "Syntax: (stat path)
Library: (scm fs)
Description: Returns an alist describing path with keys exists, type
  (one of file/directory/missing), size, mtime, and mode (octal string
  on Unix; #f on Windows or when stat is unavailable).
Example:
  (stat \"/etc/hosts\")"
      (let* ((exists? (or (file-exists? path) (directory-exists? path)))
             (type (cond ((directory-exists? path) 'directory)
                         ((file-exists? path) 'file)
                         (else 'missing)))
             (size (if (eq? type 'file) (file-size path) 0))
             (mtime (if exists? (file-modification-timestamp path) 0))
             (mode (let ((s (which "stat")))
                     (if (and exists? s (not (%windows?)))
                         (let ((r (%run-capture (list s "-c" "%a" path))))
                           (if (and (pair? r) (zero? (car r)))
                               (%strip-newline (cadr r))
                               (let ((r2 (%run-capture
                                          (list s "-f" "%Lp" path))))
                                 (if (and (pair? r2) (zero? (car r2)))
                                     (%strip-newline (cadr r2))
                                     #f))))
                         #f))))
        (list (cons 'exists exists?)
              (cons 'type type)
              (cons 'size size)
              (cons 'mtime mtime)
              (cons 'mode mode))))

    (define (%temp-name prefix)
      (let* ((dir (special-folder-temp))
             (uniq (%string-append prefix "-"
                                  (%number->string (%jiffy) 16) "-"
                                  (%number->string (%next-counter) 16))))
        (%string-append dir path-sep uniq)))

    (define (mktemp . opts)
      "Syntax: (mktemp [option ...])
Library: (scm fs)
Description: Creates a uniquely-named empty file in the temp directory and
  returns its path. Option '(prefix . str) sets the filename prefix
  (default \"tmp\").
Example:
  (mktemp) => \"/tmp/tmp-12345-1aff3...\""
      (let* ((prefix (%opt-value opts 'prefix "tmp"))
             (path (%temp-name prefix)))
        (let ((p (%open-output-file path)))
          (%close-output-port p))
        path))

    (define (mktempdir . opts)
      "Syntax: (mktempdir [option ...])
Library: (scm fs)
Description: Creates a uniquely-named empty directory in the temp directory
  and returns its path. Option '(prefix . str) sets the dir-name prefix.
Example:
  (mktempdir) => \"/tmp/tmp-12345-1aff3...\""
      (let* ((prefix (%opt-value opts 'prefix "tmp"))
             (path (%temp-name prefix)))
        (make-directory path)
        path))

    (define (rm path . opts)
      "Syntax: (rm path [option ...])
Library: (scm fs)
Description: Removes path. Options: 'recursive (-r) to remove a directory
  and its contents; 'force (-f) to suppress errors when path is missing.
Example:
  (rm \"foo.txt\")
  (rm \"build\" 'recursive 'force)"
      (let ((force? (%has-flag? opts 'force))
            (recursive? (%has-flag? opts 'recursive)))
        (cond
          ((directory-exists? path)
           (if recursive?
               (delete-directory path)
               (if force? #f (error "rm: is a directory (use 'recursive)" path))))
          ((file-exists? path)
           (delete-file path))
          (force? #f)
          (else (error "rm: no such file or directory" path)))))

    (define (cp src dst . opts)
      "Syntax: (cp src dst [option ...])
Library: (scm fs)
Description: Copies src to dst. Options: 'recursive (-r) to copy a directory.
  When src is a directory and 'recursive is not given, signals an error.
Example:
  (cp \"a.txt\" \"b.txt\")
  (cp \"src/\" \"dst/\" 'recursive)"
      (let ((recursive? (%has-flag? opts 'recursive)))
        (cond
          ((directory-exists? src)
           (if recursive?
               (copy-directory src dst)
               (error "cp: source is a directory (use 'recursive)" src)))
          ((file-exists? src) (copy-file src dst))
          (else (error "cp: no such file or directory" src)))))

    (define (mv src dst . opts)
      "Syntax: (mv src dst [option ...])
Library: (scm fs)
Description: Moves/renames src to dst. Works on files and directories.
Example:
  (mv \"old.txt\" \"new.txt\")"
      opts
      (cond
        ((directory-exists? src) (move-directory src dst))
        ((file-exists? src) (move-file src dst))
        (else (error "mv: no such file or directory" src))))))
