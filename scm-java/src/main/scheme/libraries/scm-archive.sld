(define-library (scm archive)
  (import (scm core)
          (scheme base)
          (scm fs)
          (scm system)
          (scm compression)
          (scm zip)
          (srfi 1))
  (export tar-create
          tar-extract
          tar-list
          bzip2
          bunzip2
          gzip
          gunzip
          xz
          unxz
          ;; re-exports from (scm zip)
          open-output-zip-file
          open-input-zip-file
          close-output-zip
          close-input-zip
          zip-add-binary-entry
          zip-add-stored-entry
          zip-add-text-entry
          zip-entry-names
          zip-read-entry-bytevector
          zip-files-equal?
          ;; re-exports from (scm compression)
          gzip-compress
          gzip-decompress
          zlib-compress
          zlib-decompress
          deflate-compress
          deflate-decompress)
  (begin

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

    (define (%require-native name)
      (let ((p (which name)))
        (or p (error (string-append name ": native command not found on PATH")))))

    (define (tar-create archive paths . opts)
      "Syntax: (tar-create archive paths [option ...])
Library: (scm archive)
Description: Creates a tar archive at path archive containing the listed
  paths. archive's extension determines compression: .tar.gz/.tgz uses
  gzip; .tar.bz2/.tbz uses bzip2; otherwise plain tar.
  Options: 'gzip (force -z), 'bzip2 (force -j), 'verbose (-v),
  '(work-dir . dir) (run as if cwd = dir).
  Shells out to the native tar command.
Example:
  (tar-create \"backup.tar.gz\" '(\"src\" \"docs\"))"
      (let* ((native (%require-native "tar"))
             (ext-gz?  (or (%has-flag? opts 'gzip)
                           (tar-suffix? archive '(".tar.gz" ".tgz"))))
             (ext-bz?  (or (%has-flag? opts 'bzip2)
                           (tar-suffix? archive '(".tar.bz2" ".tbz"))))
             (work-dir (%opt-value opts 'work-dir #f))
             (verbose? (%has-flag? opts 'verbose))
             (flags    (string-append
                         "c"
                         (if verbose? "v" "")
                         (cond (ext-gz? "z") (ext-bz? "j") (else ""))
                         "f"))
             (cmd-list (append
                         (list native flags archive)
                         paths))
             (r (if work-dir
                    (run-program/capture cmd-list (list (list 'work-dir work-dir)))
                    (run-program/capture cmd-list))))
        (and (pair? r) (zero? (car r)))))

    (define (tar-extract archive . opts)
      "Syntax: (tar-extract archive [option ...])
Library: (scm archive)
Description: Extracts archive into the current directory (or 'work-dir).
  Compression is auto-detected from extension or forced via 'gzip / 'bzip2.
  Options: '(work-dir . dir), 'verbose.
Example:
  (tar-extract \"backup.tar.gz\" '(work-dir . \"/tmp/restore\"))"
      (let* ((native (%require-native "tar"))
             (ext-gz?  (or (%has-flag? opts 'gzip)
                           (tar-suffix? archive '(".tar.gz" ".tgz"))))
             (ext-bz?  (or (%has-flag? opts 'bzip2)
                           (tar-suffix? archive '(".tar.bz2" ".tbz"))))
             (work-dir (%opt-value opts 'work-dir #f))
             (verbose? (%has-flag? opts 'verbose))
             (flags    (string-append
                         "x"
                         (if verbose? "v" "")
                         (cond (ext-gz? "z") (ext-bz? "j") (else ""))
                         "f"))
             (cmd-list (list native flags archive))
             (r (if work-dir
                    (run-program/capture cmd-list (list (list 'work-dir work-dir)))
                    (run-program/capture cmd-list))))
        (and (pair? r) (zero? (car r)))))

    (define (tar-list archive . opts)
      "Syntax: (tar-list archive [option ...])
Library: (scm archive)
Description: Returns a list of entry names contained in archive.
  Compression is auto-detected; force with 'gzip or 'bzip2.
Example:
  (tar-list \"backup.tar.gz\")"
      (let* ((native (%require-native "tar"))
             (ext-gz?  (or (%has-flag? opts 'gzip)
                           (tar-suffix? archive '(".tar.gz" ".tgz"))))
             (ext-bz?  (or (%has-flag? opts 'bzip2)
                           (tar-suffix? archive '(".tar.bz2" ".tbz"))))
             (flags    (string-append
                         "t"
                         (cond (ext-gz? "z") (ext-bz? "j") (else ""))
                         "f"))
             (r (run-program/capture (list native flags archive))))
        (if (and (pair? r) (zero? (car r)))
            (split-lines (cadr r))
            '())))

    (define (gzip path . opts)
      "Syntax: (gzip path [option ...])
Library: (scm archive)
Description: Compresses path into path.gz using the native gzip command
  when available; falls back to gzip-compress on the file bytes.
  Option 'keep retains the original file (-k).
Example:
  (gzip \"big.log\")"
      (let ((native (which "gzip"))
            (keep? (%has-flag? opts 'keep)))
        (if native
            (let* ((args (if keep? (list native "-k" path) (list native path)))
                   (r (run-program/capture args)))
              (and (pair? r) (zero? (car r))))
            (gzip-fallback path keep?))))

    (define (gunzip path . opts)
      "Syntax: (gunzip path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .gz) in place.
  Option 'keep retains the .gz original (-k).
Example:
  (gunzip \"big.log.gz\")"
      (let ((native (which "gunzip"))
            (keep? (%has-flag? opts 'keep)))
        (if native
            (let* ((args (if keep? (list native "-k" path) (list native path)))
                   (r (run-program/capture args)))
              (and (pair? r) (zero? (car r))))
            (gunzip-fallback path keep?))))

    (define (bzip2 path . opts)
      "Syntax: (bzip2 path [option ...])
Library: (scm archive)
Description: Compresses path into path.bz2 using the native bzip2 command.
  Option 'keep retains the original file (-k).
Example:
  (bzip2 \"big.log\")"
      (%simple-compress "bzip2" path opts))

    (define (bunzip2 path . opts)
      "Syntax: (bunzip2 path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .bz2) in place via
  the native bunzip2 command. Option 'keep retains the .bz2 original.
Example:
  (bunzip2 \"big.log.bz2\")"
      (%simple-decompress "bunzip2" path opts))

    (define (xz path . opts)
      "Syntax: (xz path [option ...])
Library: (scm archive)
Description: Compresses path into path.xz using the native xz command.
  Option 'keep retains the original file (-k).
Example:
  (xz \"big.log\")"
      (%simple-compress "xz" path opts))

    (define (unxz path . opts)
      "Syntax: (unxz path [option ...])
Library: (scm archive)
Description: Decompresses path (which should end in .xz) in place via
  the native unxz command. Option 'keep retains the .xz original.
Example:
  (unxz \"big.log.xz\")"
      (%simple-decompress "unxz" path opts))

    (define (%simple-compress cmd path opts)
      (let* ((native (%require-native cmd))
             (keep? (%has-flag? opts 'keep))
             (args (if keep? (list native "-k" path) (list native path)))
             (r (run-program/capture args)))
        (and (pair? r) (zero? (car r)))))

    (define (%simple-decompress cmd path opts)
      (let* ((native (%require-native cmd))
             (keep? (%has-flag? opts 'keep))
             (args (if keep? (list native "-k" path) (list native path)))
             (r (run-program/capture args)))
        (and (pair? r) (zero? (car r)))))

    ;; --- internals ---

    (define (tar-suffix? path suffixes)
      (let ((plen (string-length path)))
        (let loop ((s suffixes))
          (cond
            ((null? s) #f)
            ((let* ((suf (car s))
                    (slen (string-length suf)))
               (and (>= plen slen)
                    (string=? (substring path (- plen slen) plen) suf)))
             #t)
            (else (loop (cdr s)))))))

    (define (split-lines s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond
          ((>= i (string-length s))
           (reverse (if (= start i) acc (cons (substring s start i) acc))))
          ((char=? (string-ref s i) #\newline)
           (loop (+ i 1) (+ i 1)
                 (if (= start i) acc (cons (substring s start i) acc))))
          (else (loop (+ i 1) start acc)))))

    (define (slurp-bytes path)
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let loop ((acc '()))
            (let ((b (read-u8 p)))
              (if (eof-object? b)
                  (let* ((n (length acc))
                         (bv (make-bytevector n)))
                    (let fill ((lst (reverse acc)) (i 0))
                      (cond
                        ((null? lst) bv)
                        (else (bytevector-u8-set! bv i (car lst))
                              (fill (cdr lst) (+ i 1))))))
                  (loop (cons b acc))))))))

    (define (dump-bytes path bv)
      (call-with-port (open-binary-output-file path)
        (lambda (p) (write-bytevector bv p))))

    (define (gzip-fallback path keep?)
      (let ((bytes (slurp-bytes path)))
        (dump-bytes (string-append path ".gz") (gzip-compress bytes))
        (when (not keep?) (delete-file path))
        #t))

    (define (gunzip-fallback path keep?)
      (let* ((n (string-length path))
             (out (if (and (> n 3)
                           (string=? (substring path (- n 3) n) ".gz"))
                      (substring path 0 (- n 3))
                      (string-append path ".out")))
             (bytes (slurp-bytes path)))
        (dump-bytes out (gzip-decompress bytes))
        (when (not keep?) (delete-file path))
        #t))))
