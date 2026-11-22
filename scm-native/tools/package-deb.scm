;; A Debian package of a program compiled by dabscm native:
;; <out>/<name>_<version>_<arch>.deb with the executable as /usr/bin/<name>.
;;
;;   scm scm-native/tools/package-deb.scm --exe build/app --name app --version 1.0
;;       [--description "one line" [--long "more text"]] [--maintainer "Name <mail>"]
;;       [--depends "pkg, pkg"] [--section utils] [--homepage url]
;;       [--file src dest [mode]] ... [--out dir]
;;
;; The executable is static (no Depends needed); --file adds other files
;; (dest an absolute path such as /usr/share/doc/app/README, mode octal,
;; default 644). The architecture comes from the executable's ELF header
;; (x86-64: amd64, aarch64: arm64), so cross-compiled programs are packaged
;; for their target. Pure Scheme ((scm deb)); runs on any dabscm.
;; Install with `sudo apt install ./<name>_<version>_<arch>.deb`.

(import (scheme base)
        (scheme char)
        (scheme file)
        (scheme process-context)
        (scheme write)
        (srfi 1)
        (scm crypto)
        (scm datetime)
        (scm deb)
        (scm fs))

(define (say . xs) (for-each display xs) (newline))

(define (fail . xs)
  (apply say "package-deb: " xs)
  (exit 1))

(define (usage)
  (say "usage: package-deb.scm --exe file --name name --version version"
       " [--description text] [--long text] [--maintainer text] [--depends text]"
       " [--section name] [--homepage url] [--file src dest [mode]] ... [--out dir]")
  (exit 2))

(define (read-bytes path)
  (call-with-port (open-binary-input-file path)
    (lambda (in)
      (let ((out (open-output-bytevector)))
        (let loop ()
          (let ((chunk (read-bytevector 65536 in)))
            (unless (eof-object? chunk)
              (write-bytevector chunk out)
              (loop))))
        (get-output-bytevector out)))))

;; --- arguments ---------------------------------------------------------------

(define opts '())
(define files '()) ; (src dest mode)

(define (opt key . default)
  (cond ((assq key opts) => cdr)
        ((pair? default) (car default))
        (else #f)))

(let loop ((args (cdr (command-line))))
  (cond ((null? args))
        ((and (string=? (car args) "--file") (>= (length args) 3))
         (let* ((src (cadr args))
                (dest (caddr args))
                (rest (cdddr args))
                (mode (and (pair? rest) (string->number (car rest) 8))))
           (set! files (cons (list src dest (or mode #o644)) files))
           (loop (if mode (cdr rest) rest))))
        ((and (>= (string-length (car args)) 3)
              (string=? (substring (car args) 0 2) "--")
              (pair? (cdr args)))
         (set! opts (cons (cons (string->symbol (substring (car args) 2 (string-length (car args))))
                                (cadr args))
                          opts))
         (loop (cddr args)))
        (else (usage))))

(define exe (or (opt 'exe) (usage)))
(define name (or (opt 'name) (usage)))
(define version (or (opt 'version) (usage)))

(unless (file-exists? exe) (fail exe " not found"))

;; Debian package names: lower case letters, digits, + - . (at least two)
(unless (and (>= (string-length name) 2)
             (every (lambda (c) (or (char-lower-case? c) (char-numeric? c) (memv c '(#\+ #\- #\.))))
                    (string->list name)))
  (fail "invalid package name " name " (lower case letters, digits, + - .)"))

;; --- the architecture from the ELF header ------------------------------------

(define exe-bytes (read-bytes exe))

(define arch
  (or (opt 'arch)
      (begin
        (unless (and (> (bytevector-length exe-bytes) 20)
                     (= (bytevector-u8-ref exe-bytes 0) #x7f)
                     (= (bytevector-u8-ref exe-bytes 1) (char->integer #\E))
                     (= (bytevector-u8-ref exe-bytes 2) (char->integer #\L))
                     (= (bytevector-u8-ref exe-bytes 3) (char->integer #\F)))
          (fail exe " is not a Linux executable (ELF)"))
        (let ((machine (+ (bytevector-u8-ref exe-bytes 18) (* 256 (bytevector-u8-ref exe-bytes 19)))))
          (case machine
            ((#x3e) "amd64")
            ((#xb7) "arm64")
            ((#x03) "i386")
            ((#x28) "armhf")
            ((#xf3) "riscv64")
            (else (fail "unknown ELF machine " machine " (pass --arch)")))))))

;; --- contents ------------------------------------------------------------------

(define (strip-slash p)
  (if (and (> (string-length p) 0) (char=? (string-ref p 0) #\/))
      (substring p 1 (string-length p))
      p))

(define data
  (cons (list (string-append "usr/bin/" name) #o755 exe-bytes)
        (map (lambda (f)
               (unless (file-exists? (car f)) (fail (car f) " not found"))
               (list (strip-slash (cadr f)) (caddr f) (read-bytes (car f))))
             (reverse files))))

(define installed-kib
  (+ (fold (lambda (e acc) (+ acc (quotient (+ (bytevector-length (entry-content e)) 1023) 1024)))
           0 data)
     (- (length (add-parent-dirs data)) (length data))))

;; a long description: each line indented by one space, empty lines as " ."
(define (long-text s)
  (apply string-append
         (map (lambda (line)
                (string-append " " (if (string=? (string-trim-right line) "") "." line) "\n"))
              (split-lines s))))

(define (split-lines s)
  (let loop ((i 0) (start 0) (acc '()))
    (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
          ((char=? (string-ref s i) #\newline) (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else (loop (+ i 1) start acc)))))

(define (string-trim-right s)
  (let loop ((n (string-length s)))
    (if (and (> n 0) (char-whitespace? (string-ref s (- n 1)))) (loop (- n 1)) (substring s 0 n))))

(define control
  (string-append
   "Package: " name "\n"
   "Version: " version "\n"
   "Architecture: " arch "\n"
   "Maintainer: " (opt 'maintainer (string-append (or (get-environment-variable "USER") "unknown") " <unknown>")) "\n"
   "Installed-Size: " (number->string installed-kib) "\n"
   (if (opt 'depends) (string-append "Depends: " (opt 'depends) "\n") "")
   "Section: " (opt 'section "misc") "\n"
   "Priority: optional\n"
   (if (opt 'homepage) (string-append "Homepage: " (opt 'homepage) "\n") "")
   "Description: " (opt 'description (string-append name ", compiled with dabscm native")) "\n"
   (if (opt 'long) (long-text (opt 'long)) "")))

(define md5sums
  (apply string-append
         (map (lambda (e) (string-append (md5-hash (entry-content e)) "  " (entry-name e) "\n"))
              data)))

(define control-entries
  (list (list "control" #o644 (string->utf8 control))
        (list "md5sums" #o644 (string->utf8 md5sums))))

;; --- write -------------------------------------------------------------------

(define out-dir (opt 'out "."))
(unless (directory-exists? out-dir) (make-directory out-dir))

(let ((deb (join-path out-dir (string-append name "_" version "_" arch ".deb"))))
  (call-with-port (open-binary-output-file deb)
    (lambda (out)
      (write-bytevector (deb-bytevector control-entries data (quotient (timestamp) 1000)) out)))
  (say deb " (" (length data) " files, " installed-kib " KiB installed)"))
