;; Debian package of the Java implementation: dist/dabscm_<version>_all.deb
;;
;;   ./builder.sh package-deb-java.scm [--out <dir>] [--allow-dirty]
;;
;; Packages the scm-java/scm.jar already built (build-and-test-scm-java.scm
;; first). Pure Scheme (see build-deb.sld), no dpkg-deb/tar/gzip needed.
;; Install with `sudo apt install ./dabscm_<version>_all.deb`.
;;
;; Installed layout:
;;   /usr/bin/scm                   launcher (JVM options via SCM_JAVA_OPTS)
;;   /usr/share/dabscm/scm.jar
;;   /usr/share/doc/dabscm/         copyright, README.md, ACKNOWLEDGMENTS.md,
;;                                  html/ (documentation/site)
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
        (scm fs)
        (scm io)
        (scm system)
        (build tools)
        (build deb))

(define maintainer "Damian Brunold <damian.brunold@bluewin.ch>")

(define (say fmt . args)
  (display (apply format #f fmt args))
  (newline))

(define (fail fmt . args)
  (apply say (string-append "package-deb-java: " fmt) args)
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

(define (read-text path)
  (utf8->string (read-bytes path)))

(define (git . args)
  (let ((r (run-program/capture (cons "git" args) `((work-dir ,base-dir)))))
    (unless (and (pair? r) (eqv? (car r) 0))
      (fail "git failed: ~a" args))
    (string-trim-both (cadr r))))

;; Recursive file list under dir, relative "/"-joined paths.
(define (tree-files dir)
  (let walk ((rel ""))
    (let ((os (if (string=? rel "") dir (join-path dir rel)))
          (join (lambda (n) (if (string=? rel "") n (string-append rel "/" n)))))
      (append (map join (directory-files os))
              (append-map (lambda (d) (walk (join d))) (directory-directories os))))))

;; --- arguments ---------------------------------------------------------------

(define out-dir (repo "dist"))
(define allow-dirty? #f)

(let loop ((args (cdr (command-line))))
  (cond ((null? args))
        ((and (string=? (car args) "--out") (pair? (cdr args)))
         (set! out-dir (cadr args))
         (loop (cddr args)))
        ((string=? (car args) "--allow-dirty")
         (set! allow-dirty? #t)
         (loop (cdr args)))
        (else
         (say "usage: package-deb-java.scm [--out <dir>] [--allow-dirty]")
         (exit 2))))

;; --- inputs ------------------------------------------------------------------

(define jar (repo "scm-java" "scm.jar"))
(define base-version (string-trim-both (read-text (repo "VERSION"))))
(define dirty? (not (string=? (git "status" "--porcelain") "")))

(unless (file-exists? jar)
  (fail "~a not found; run ./builder.sh build-and-test-scm-java.scm first" jar))

;; The jar must be built from this VERSION (its version.txt is copied from it).
(let ((r (run-program/capture `(,java-cmd "-jar" ,jar "--version"))))
  (when (and (pair? r) (eqv? (car r) 0)
             (not (string=? (string-trim-both (cadr r)) base-version)))
    (fail "scm.jar reports version ~a but VERSION is ~a; rebuild it"
          (string-trim-both (cadr r)) base-version)))

(when (and dirty? (not allow-dirty?))
  (fail "the working tree has uncommitted changes; commit them or pass --allow-dirty"))

(define version (if dirty? (string-append base-version "+dirty") base-version))
(define epoch (if dirty?
                  (quotient (timestamp) 1000)
                  (string->number (git "log" "-1" "--format=%ct"))))
(define hash (git "rev-parse" "--short=8" "HEAD"))

;; --- package contents --------------------------------------------------------

(define launcher
  (string-append
    "#!/bin/sh\n"
    "# dabscm " version " (Java). Extra JVM options via SCM_JAVA_OPTS, e.g.\n"
    "#   SCM_JAVA_OPTS='-Xmx4g -Dscm.jit=off' scm script.scm\n"
    "exec java $SCM_JAVA_OPTS -jar /usr/share/dabscm/scm.jar \"$@\"\n"))

(define doc "usr/share/doc/dabscm/")

(define data
  (append
    (list (list "usr/bin/scm" #o755 (string->utf8 launcher))
          (list "usr/share/dabscm/scm.jar" #o644 (read-bytes jar))
          (list (string-append doc "copyright") #o644 (read-bytes (repo "LICENSE")))
          (list (string-append doc "README.md") #o644 (read-bytes (repo "README.md")))
          (list (string-append doc "ACKNOWLEDGMENTS.md") #o644
                (read-bytes (repo "ACKNOWLEDGMENTS.md"))))
    (map (lambda (f)
           (list (string-append doc "html/" f) #o644
                 (read-bytes (repo "documentation" "site" f))))
         (tree-files (repo "documentation" "site")))))

(define installed-kib
  (+ (fold (lambda (e acc)
             (+ acc (quotient (+ (bytevector-length (entry-content e)) 1023) 1024)))
           0 data)
     (- (length (add-parent-dirs data)) (length data))))

;; Debian's own "scm" package (Aubrey Jaffer's SCM) also installs /usr/bin/scm.
(define control
  (string-append
    "Package: dabscm\n"
    "Version: " version "\n"
    "Architecture: all\n"
    "Maintainer: " maintainer "\n"
    "Installed-Size: " (number->string installed-kib) "\n"
    "Depends: default-jre-headless | java11-runtime-headless\n"
    "Conflicts: scm\n"
    "Section: interpreters\n"
    "Priority: optional\n"
    "Description: R7RS Scheme interpreter (Java implementation)\n"
    " dabscm is an R7RS-small Scheme with a bytecode VM, a JIT to JVM\n"
    " bytecode, a sets-of-scopes hygienic macro expander, 22 SRFIs and the\n"
    " scm extension libraries (files, processes, HTTP, databases, archives).\n"
    " Installs the scm command.\n"))

(define md5sums
  (apply string-append
    (map (lambda (e) (string-append (md5-hash (entry-content e)) "  " (entry-name e) "\n"))
         data)))

(define control-entries
  (list (list "control" #o644 (string->utf8 control))
        (list "md5sums" #o644 (string->utf8 md5sums))))

;; --- write -------------------------------------------------------------------

(unless (directory-exists? out-dir) (make-directory out-dir))

(let ((deb (join-path out-dir (string-append "dabscm_" version "_all.deb"))))
  (call-with-port (open-binary-output-file deb)
    (lambda (out) (write-bytevector (deb-bytevector control-entries data epoch) out)))
  (say "~a (commit ~a, ~a files, ~a KiB installed)" deb hash (length data) installed-kib))
