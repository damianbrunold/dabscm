(define-library (scm archive)
  (import (scm core)
          (scheme base)
          (scheme file)
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
  '(work-dir . dir) (run as if cwd = dir), 'pure (force the built-in
  implementation even when native tar is present).
  Uses the native tar command when available. If no native tar is found,
  a built-in pure-Scheme USTAR implementation handles plain .tar and
  .tar.gz archives (regular files and directories only); .tar.bz2/.tar.xz
  still require native tools.
Example:
  (tar-create \"backup.tar.gz\" '(\"src\" \"docs\"))"
      (let* ((ext-gz?  (or (%has-flag? opts 'gzip)
                           (tar-suffix? archive '(".tar.gz" ".tgz"))))
             (ext-bz?  (or (%has-flag? opts 'bzip2)
                           (tar-suffix? archive '(".tar.bz2" ".tbz"))))
             (work-dir (%opt-value opts 'work-dir #f))
             (verbose? (%has-flag? opts 'verbose))
             (native   (and (not (%has-flag? opts 'pure)) (which "tar"))))
        (if native
            (let* ((flags    (string-append
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
              (and (pair? r) (zero? (car r))))
            (if (%needs-native-compression? archive opts)
                (error "tar: native tar required for bzip2/xz archives; only plain tar and tar.gz are supported without it")
                (%tar-create-fallback archive paths ext-gz? work-dir)))))

    (define (tar-extract archive . opts)
      "Syntax: (tar-extract archive [option ...])
Library: (scm archive)
Description: Extracts archive into the current directory (or 'work-dir).
  Compression is auto-detected from extension or forced via 'gzip / 'bzip2.
  Options: '(work-dir . dir), 'verbose, 'pure (force the built-in
  implementation even when native tar is present).
  Uses the native tar command when available; otherwise a built-in
  pure-Scheme implementation extracts plain .tar and .tar.gz archives
  (.tar.bz2/.tar.xz still require native tools).
Example:
  (tar-extract \"backup.tar.gz\" '(work-dir . \"/tmp/restore\"))"
      (let* ((ext-gz?  (or (%has-flag? opts 'gzip)
                           (tar-suffix? archive '(".tar.gz" ".tgz"))))
             (ext-bz?  (or (%has-flag? opts 'bzip2)
                           (tar-suffix? archive '(".tar.bz2" ".tbz"))))
             (work-dir (%opt-value opts 'work-dir #f))
             (verbose? (%has-flag? opts 'verbose))
             (native   (and (not (%has-flag? opts 'pure)) (which "tar"))))
        (if native
            (let* ((flags    (string-append
                               "x"
                               (if verbose? "v" "")
                               (cond (ext-gz? "z") (ext-bz? "j") (else ""))
                               "f"))
                   (cmd-list (list native flags archive))
                   (r (if work-dir
                          (run-program/capture cmd-list (list (list 'work-dir work-dir)))
                          (run-program/capture cmd-list))))
              (and (pair? r) (zero? (car r))))
            (if (%needs-native-compression? archive opts)
                (error "tar: native tar required for bzip2/xz archives; only plain tar and tar.gz are supported without it")
                (%tar-extract-fallback archive ext-gz? work-dir)))))

    (define (tar-list archive . opts)
      "Syntax: (tar-list archive [option ...])
Library: (scm archive)
Description: Returns a list of entry names contained in archive.
  Compression is auto-detected; force with 'gzip or 'bzip2.
  Options: 'gzip, 'bzip2, 'pure (force the built-in implementation even
  when native tar is present).
  Uses the native tar command when available; otherwise a built-in
  pure-Scheme implementation lists plain .tar and .tar.gz archives
  (.tar.bz2/.tar.xz still require native tools).
Example:
  (tar-list \"backup.tar.gz\")"
      (let* ((ext-gz?  (or (%has-flag? opts 'gzip)
                           (tar-suffix? archive '(".tar.gz" ".tgz"))))
             (ext-bz?  (or (%has-flag? opts 'bzip2)
                           (tar-suffix? archive '(".tar.bz2" ".tbz"))))
             (native   (and (not (%has-flag? opts 'pure)) (which "tar"))))
        (if native
            (let* ((flags    (string-append
                               "t"
                               (cond (ext-gz? "z") (ext-bz? "j") (else ""))
                               "f"))
                   (r (run-program/capture (list native flags archive))))
              (if (and (pair? r) (zero? (car r)))
                  (split-lines (cadr r))
                  '()))
            (if (%needs-native-compression? archive opts)
                (error "tar: native tar required for bzip2/xz archives; only plain tar and tar.gz are supported without it")
                (%tar-list-fallback archive ext-gz?)))))

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

    ;; --- pure-Scheme tar (USTAR) fallback ---
    ;;
    ;; Used when no native tar is on PATH (e.g. default Windows), or when the
    ;; caller passes the 'pure option. Handles regular files and directories
    ;; for plain .tar and (via gzip-compress/gzip-decompress) .tar.gz. Tar
    ;; entry names always use "/" separators; .NET and Java accept "/" for
    ;; filesystem access on Windows too, so the same separator is used for
    ;; reading/creating files.

    (define (%needs-native-compression? archive opts)
      (or (%has-flag? opts 'bzip2)
          (tar-suffix? archive '(".tar.bz2" ".tbz" ".tar.xz" ".txz"))))

    (define (%join a b)
      (cond ((or (not a) (string=? a "")) b)
            ((char=? (string-ref a (- (string-length a) 1)) #\/)
             (string-append a b))
            (else (string-append a "/" b))))

    (define (%ensure-slash s)
      (if (and (> (string-length s) 0)
               (char=? (string-ref s (- (string-length s) 1)) #\/))
          s
          (string-append s "/")))

    (define (%strip-slash s)
      (let ((n (string-length s)))
        (if (and (> n 0) (char=? (string-ref s (- n 1)) #\/))
            (substring s 0 (- n 1))
            s)))

    (define (%backslashes->slashes s)
      (let* ((n (string-length s))
             (out (make-string n)))
        (let loop ((i 0))
          (if (>= i n)
              out
              (begin
                (string-set! out i
                  (let ((c (string-ref s i)))
                    (if (char=? c #\\) #\/ c)))
                (loop (+ i 1)))))))

    (define (%strip-leading-slashes s)
      (let ((n (string-length s)))
        (let loop ((i 0))
          (cond ((>= i n) "")
                ((char=? (string-ref s i) #\/) (loop (+ i 1)))
                (else (substring s i n))))))

    (define (%tar-entry-name path)
      ;; Normalize an OS path into a relative USTAR entry name: forward
      ;; slashes, no Windows drive letter, no leading slash. This mirrors what
      ;; native tar does ("Removing leading / from member names") and keeps
      ;; archives portable and extractable into an arbitrary work-dir.
      (let* ((s (%backslashes->slashes path))
             (s (if (and (>= (string-length s) 2)
                         (char=? (string-ref s 1) #\:)
                         (let ((c (string-ref s 0)))
                           (or (and (char>=? c #\A) (char<=? c #\Z))
                               (and (char>=? c #\a) (char<=? c #\z)))))
                    (substring s 2 (string-length s))
                    s)))
        (%strip-leading-slashes s)))

    (define (%parent-dir path)
      (let loop ((i (- (string-length path) 1)))
        (cond ((< i 0) #f)
              ((char=? (string-ref path i) #\/)
               (if (= i 0) "/" (substring path 0 i)))
              (else (loop (- i 1))))))

    (define (%pad-left s n)
      (let ((len (string-length s)))
        (if (>= len n)
            s
            (string-append (make-string (- n len) #\0) s))))

    (define (%safe-mtime path)
      (guard (e (#t 0))
        (let ((ts (file-modification-timestamp path)))
          (if (and (integer? ts) (> ts 0))
              (quotient ts 1000)
              0))))

    (define (%bv-poke-string! bv off s)
      (let* ((bytes (string->utf8 s))
             (n (bytevector-length bytes)))
        (let loop ((i 0))
          (when (< i n)
            (bytevector-u8-set! bv (+ off i) (bytevector-u8-ref bytes i))
            (loop (+ i 1))))))

    (define (%octal-field! bv off width n)
      ;; width-1 octal digits, zero padded; trailing byte stays NUL (bv is
      ;; pre-zeroed).
      (%bv-poke-string! bv off (%pad-left (number->string n 8) (- width 1))))

    (define (%ustar-split name)
      ;; Split name into (prefix . suffix) at a "/" so the suffix fits in 100
      ;; and the prefix in 155 bytes. Returns #f if no such split exists.
      (let ((len (string-length name)))
        (let loop ((i (- len 1)))
          (cond
            ((< i 0) #f)
            ((char=? (string-ref name i) #\/)
             (let ((prefix (substring name 0 i))
                   (suffix (substring name (+ i 1) len)))
               (if (and (<= (bytevector-length (string->utf8 suffix)) 100)
                        (<= (bytevector-length (string->utf8 prefix)) 155))
                   (cons prefix suffix)
                   (loop (- i 1)))))
            (else (loop (- i 1)))))))

    (define (%checksum! bv)
      ;; chksum field (148,8) is spaces while summing, then 6 octal digits +
      ;; NUL + space.
      (let loop ((i 148))
        (when (< i 156)
          (bytevector-u8-set! bv i 32)
          (loop (+ i 1))))
      (let sumloop ((i 0) (sum 0))
        (if (< i 512)
            (sumloop (+ i 1) (+ sum (bytevector-u8-ref bv i)))
            (begin
              (%bv-poke-string! bv 148 (%pad-left (number->string sum 8) 6))
              (bytevector-u8-set! bv 154 0)
              (bytevector-u8-set! bv 155 32)))))

    (define (%tar-header name size mtime typeflag)
      (let ((bv (make-bytevector 512 0)))
        (let ((nb (string->utf8 name)))
          (if (<= (bytevector-length nb) 100)
              (%bv-poke-string! bv 0 name)
              (let ((split (%ustar-split name)))
                (if split
                    (begin
                      (%bv-poke-string! bv 345 (car split))
                      (%bv-poke-string! bv 0 (cdr split)))
                    (error (string-append
                             "tar: path too long for USTAR fallback: " name))))))
        (%octal-field! bv 100 8 (if (char=? typeflag #\5) 493 420)) ; mode 0755/0644
        (%octal-field! bv 108 8 0)            ; uid
        (%octal-field! bv 116 8 0)            ; gid
        (%octal-field! bv 124 12 size)        ; size
        (%octal-field! bv 136 12 mtime)       ; mtime
        (bytevector-u8-set! bv 156 (char->integer typeflag))
        (%bv-poke-string! bv 257 "ustar")     ; magic + NUL (262 stays 0)
        (bytevector-u8-set! bv 263 48)        ; version "0"
        (bytevector-u8-set! bv 264 48)        ; version "0"
        (%checksum! bv)
        bv))

    (define (%dir-children os-path)
      (append (directory-directories os-path)
              (directory-files os-path)))

    (define (%collect-entries entry os-path)
      ;; Returns an ordered list of (entry-name os-path dir?) records.
      (if (directory-exists? os-path)
          (cons (list (%ensure-slash entry) os-path #t)
                (append-map
                  (lambda (child)
                    (%collect-entries (%join entry child) (%join os-path child)))
                  (%dir-children os-path)))
          (list (list entry os-path #f))))

    (define (%pad-block port size)
      (let ((rem (modulo size 512)))
        (when (> rem 0)
          (write-bytevector (make-bytevector (- 512 rem) 0) port))))

    (define (%tar-create-fallback archive paths ext-gz? work-dir)
      (let ((port (open-output-bytevector)))
        (for-each
          (lambda (top)
            (let ((os-top (if work-dir (%join work-dir top) top)))
              (for-each
                (lambda (rec)
                  (apply
                    (lambda (name os dir?)
                      (let ((mtime (%safe-mtime os)))
                        (if dir?
                            (write-bytevector (%tar-header name 0 mtime #\5) port)
                            (let* ((bytes (slurp-bytes os))
                                   (size (bytevector-length bytes)))
                              (write-bytevector (%tar-header name size mtime #\0) port)
                              (write-bytevector bytes port)
                              (%pad-block port size)))))
                    rec))
                (%collect-entries (%tar-entry-name top) os-top))))
          paths)
        (write-bytevector (make-bytevector 1024 0) port) ; two zero blocks
        (let ((bv (get-output-bytevector port)))
          (dump-bytes archive (if ext-gz? (gzip-compress bv) bv))
          #t)))

    (define (%tar-decompress archive ext-gz?)
      (let ((raw (slurp-bytes archive)))
        (if ext-gz? (gzip-decompress raw) raw)))

    (define (%zero-block? bv off)
      (let loop ((i 0))
        (cond ((>= i 512) #t)
              ((zero? (bytevector-u8-ref bv (+ off i))) (loop (+ i 1)))
              (else #f))))

    (define (%read-cstr bv off maxlen)
      (let loop ((i 0))
        (if (or (>= i maxlen) (zero? (bytevector-u8-ref bv (+ off i))))
            (utf8->string (bytevector-copy bv off (+ off i)))
            (loop (+ i 1)))))

    (define (%read-name bv off)
      (let ((name (%read-cstr bv off 100))
            (prefix (%read-cstr bv (+ off 345) 155)))
        (if (> (string-length prefix) 0)
            (string-append prefix "/" name)
            name)))

    (define (%parse-octal bv off len)
      (let loop ((i 0) (acc 0) (started #f))
        (if (>= i len)
            acc
            (let ((b (bytevector-u8-ref bv (+ off i))))
              (cond
                ((or (= b 0) (= b 32))            ; NUL or space
                 (if started acc (loop (+ i 1) acc #f)))
                ((and (>= b 48) (<= b 55))        ; octal digit 0-7
                 (loop (+ i 1) (+ (* acc 8) (- b 48)) #t))
                (else (loop (+ i 1) acc started)))))))

    (define (%tar-parse bv)
      ;; Returns list of (name size typeflag-int data-offset) records.
      (let ((len (bytevector-length bv)))
        (let loop ((off 0) (acc '()))
          (if (or (> (+ off 512) len) (%zero-block? bv off))
              (reverse acc)
              (let* ((name (%read-name bv off))
                     (size (%parse-octal bv (+ off 124) 12))
                     (tf (bytevector-u8-ref bv (+ off 156)))
                     (data-off (+ off 512))
                     (next (+ data-off (* 512 (quotient (+ size 511) 512)))))
                (loop next (cons (list name size tf data-off) acc)))))))

    (define (%tar-list-fallback archive ext-gz?)
      (map car (%tar-parse (%tar-decompress archive ext-gz?))))

    (define (%tar-extract-fallback archive ext-gz? work-dir)
      (let* ((bv (%tar-decompress archive ext-gz?))
             (records (%tar-parse bv)))
        (for-each
          (lambda (rec)
            (apply
              (lambda (name size tf data-off)
                (let ((target (if work-dir (%join work-dir name) name)))
                  (if (or (= tf 53)             ; '5' directory
                          (and (> (string-length name) 0)
                               (char=? (string-ref name (- (string-length name) 1)) #\/)))
                      (make-directory (%strip-slash target))
                      (begin
                        (let ((parent (%parent-dir target)))
                          (when parent (make-directory parent)))
                        (dump-bytes target
                                    (bytevector-copy bv data-off (+ data-off size)))))))
              rec))
          records)
        #t))

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

    (define %slurp-chunk-size 1048576) ; 1 MiB

    (define (slurp-bytes path)
      ;; Read the whole file in bulk chunks and concatenate once. The
      ;; previous implementation read one byte at a time with read-u8 into
      ;; a list, then reversed it and copied element-by-element into a
      ;; bytevector — O(n) boxed allocations and VM dispatches per byte,
      ;; which dominated tar/gzip runtime on large files even though the
      ;; underlying binary port is already buffered. read-bytevector does a
      ;; single bulk read per chunk, and bytevector-copy! a single bulk copy.
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let loop ((chunks '()) (total 0))
            (let ((chunk (read-bytevector %slurp-chunk-size p)))
              (if (eof-object? chunk)
                  (let ((out (make-bytevector total 0)))
                    (let fill ((cs (reverse chunks)) (off 0))
                      (if (null? cs)
                          out
                          (let* ((c (car cs))
                                 (n (bytevector-length c)))
                            (bytevector-copy! out off c 0 n)
                            (fill (cdr cs) (+ off n))))))
                  (loop (cons chunk chunks)
                        (+ total (bytevector-length chunk)))))))))

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
