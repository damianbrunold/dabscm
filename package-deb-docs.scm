;; Debian package of the HTML documentation: dist/dabscm-docs_<version>_all.deb
;;
;;   ./builder.sh package-deb-docs.scm [--out <dir>] [--root <dir>] [--allow-dirty]
;;
;; Packages documentation/site as it is committed (run
;; ./builder.sh update-documentation.scm and commit first). Pure Scheme (see
;; (scm deb)), no dpkg-deb/tar/gzip needed. Install with
;; `sudo apt install ./dabscm-docs_<version>_all.deb`; an upgrade replaces the
;; site and removes pages that no longer exist.
;;
;; Installed layout:
;;   /var/www/dabscm/                the site (index.html, tutorials.html, ...;
;;                                   --root sets another directory)
;;   /usr/share/doc/dabscm-docs/     copyright
;;
;; The package only installs the files; the web server is configured
;; separately, e.g. in nginx:
;;
;;   location /dabscm/ { alias /var/www/dabscm/; }
;;
;; Version: the VERSION file; a dirty tree (only with --allow-dirty) gets
;; "+dirty" and the build time instead of the commit time.

(import (scheme base)
        (scheme char)
        (scheme file)
        (scheme process-context)
        (scheme write)
        (srfi 1)
        (srfi 13)
        (scm crypto)
        (scm datetime)
        (scm deb)
        (scm fs)
        (scm io)
        (scm system)
        (build tools))

(define maintainer "Damian Brunold <damian.brunold@bluewin.ch>")

(define (say fmt . args)
  (display (apply format #f fmt args))
  (newline))

(define (fail fmt . args)
  (apply say (string-append "package-deb-docs: " fmt) args)
  (exit 1))

(define (repo . parts) (apply join-path base-dir parts))

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

(define (read-text path) (utf8->string (read-bytes path)))

(define (git . args)
  (let ((r (run-program/capture (cons "git" args) `((work-dir ,base-dir)))))
    (unless (and (pair? r) (eqv? (car r) 0)) (fail "git failed: ~a" args))
    (string-trim-both (cadr r))))

;; Recursive file list under dir, relative "/"-joined paths.
(define (tree-files dir)
  (let walk ((rel ""))
    (let ((os (if (string=? rel "") dir (join-path dir rel)))
          (join (lambda (n)
                  (if (string=? rel "") n (string-append rel "/" n)))))
      (append (map join (directory-files os))
              (append-map (lambda (d) (walk (join d)))
                          (directory-directories os))))))

;; "/var/www/dabscm/" -> "var/www/dabscm/" (archive paths have no leading /)
(define (archive-dir dir)
  (let* ((trimmed (string-trim-right (string-trim dir #\/) #\/)))
    (if (string=? trimmed "")
        (fail "--root must not be /")
        (string-append trimmed "/"))))

;; --- arguments ---------------------------------------------------------------

(define out-dir (repo "dist"))
(define root "/var/www/dabscm")
(define allow-dirty? #f)

(let loop ((args (cdr (command-line))))
  (cond ((null? args))
        ((and (string=? (car args) "--out") (pair? (cdr args)))
         (set! out-dir (cadr args))
         (loop (cddr args)))
        ((and (string=? (car args) "--root") (pair? (cdr args)))
         (set! root (cadr args))
         (loop (cddr args)))
        ((string=? (car args) "--allow-dirty")
         (set! allow-dirty? #t)
         (loop (cdr args)))
        (else (say
               "usage: package-deb-docs.scm [--out <dir>] [--root <dir>] [--allow-dirty]")
              (exit 2))))

;; --- inputs ------------------------------------------------------------------

(define site (repo "documentation" "site"))
(define base-version (string-trim-both (read-text (repo "VERSION"))))
(define dirty? (not (string=? (git "status" "--porcelain") "")))

(unless (file-exists? (join-path site "index.html"))
  (fail "~a/index.html not found; run ./builder.sh update-documentation.scm first"
        site))

(when (and dirty? (not allow-dirty?))
  (fail
   "the working tree has uncommitted changes; commit them or pass --allow-dirty"))

(define version
  (if dirty? (string-append base-version "+dirty") base-version))
(define epoch
  (if dirty?
      (quotient (timestamp) 1000)
      (string->number (git "log" "-1" "--format=%ct"))))
(define hash (git "rev-parse" "--short=8" "HEAD"))

;; --- package contents --------------------------------------------------------

(define www (archive-dir root))
(define doc "usr/share/doc/dabscm-docs/")

(define data
  (cons (list (string-append doc "copyright") #o644 (read-bytes (repo "LICENSE")))
        (map (lambda (f)
               (list (string-append www f) #o644 (read-bytes (join-path site f))))
             (tree-files site))))

(define installed-kib
  (+ (fold (lambda (e acc)
             (+ acc
                (quotient (+ (bytevector-length (entry-content e)) 1023)
                          1024)))
           0
           data)
     (- (length (add-parent-dirs data)) (length data))))

(define control
  (string-append "Package: dabscm-docs\n" "Version: " version "\n"
                 "Architecture: all\n"
                 "Maintainer: "
                 maintainer
                 "\n"
                 "Installed-Size: "
                 (number->string installed-kib)
                 "\n"
                 "Section: doc\n"
                 "Priority: optional\n"
                 "Description: dabscm documentation as a static web site\n"
                 " The HTML documentation of dabscm, an R7RS Scheme: the library\n"
                 " reference, the tutorials and the search index, installed under\n"
                 " /" www " for a web server to publish.\n"))

(define md5sums
  (apply string-append
         (map (lambda (e)
                (string-append (md5-hash (entry-content e))
                               "  "
                               (entry-name e)
                               "\n"))
              data)))

(define control-entries
  (list (list "control" #o644 (string->utf8 control))
        (list "md5sums" #o644 (string->utf8 md5sums))))

;; --- write -------------------------------------------------------------------

(unless (directory-exists? out-dir) (make-directory out-dir))

(let ((deb (join-path out-dir (string-append "dabscm-docs_" version "_all.deb"))))
  (call-with-port (open-binary-output-file deb)
    (lambda (out)
      (write-bytevector (deb-bytevector control-entries data epoch) out)))
  (say "~a (commit ~a, ~a files, ~a KiB installed, in /~a)" deb hash
       (length data)
       installed-kib
       www))
