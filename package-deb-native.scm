;; Debian package of the native implementation: dist/dabscm-native_<version>_amd64.deb
;;
;;   ./builder.sh package-deb-native.scm [--out <dir>] [--zig <dir>] [--no-build]
;;                                       [--allow-dirty]
;;
;; Builds scmc, the native scm and scmc-deb stripped (scm-native/build/package,
;; with the compiler on the JVM; --no-build packages those already there) and
;; bundles the pinned Zig (--zig, default ~/zig-x86_64-linux-0.17.1), which
;; scmc runs to compile. Pure Scheme (see (scm deb)). Install with
;; `sudo apt install ./dabscm-native_<version>_amd64.deb`; it can be
;; installed next to the Java package (dabscm, /usr/bin/scm).
;;
;; Installed layout:
;;   /usr/bin/scmc                         the compiler
;;   /usr/bin/scm-native                   the native scm (REPL, scripts, fmt, lint)
;;   /usr/bin/scmc-deb                     packages compiled programs as .deb
;;   /usr/lib/dabscm-native/scm-native/    bin/ and the runtime, lib, compiler and
;;                                         vendor sources (compiled into every program)
;;   /usr/lib/dabscm-native/scm-lib/       the Scheme libraries
;;   /usr/lib/dabscm-native/zig/           Zig 0.17.1
;;   /usr/share/doc/dabscm-native/         copyright, README.md (scm-native's)
;; scmc keeps its objects in ~/.cache/dabscm-native (SCM_NATIVE_BUILD).

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
        (scm system))

(define maintainer "Damian Brunold <damian.brunold@bluewin.ch>")
(define zig-version "0.17.1")

(define (say . xs) (for-each display xs) (newline))

(define (fail . xs)
  (apply say "package-deb-native: " xs)
  (exit 1))

(define base-dir (directory-name (absolute-path (car (command-line)))))
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

(define (run . args)
  (let ((r (run-program/capture args `((work-dir ,base-dir)))))
    (unless (and (pair? r) (eqv? (car r) 0))
      (fail "failed: " args "\n" (if (pair? r) (string-append (cadr r) (caddr r)) "")))
    (string-trim-both (cadr r))))

;; Recursive file list under dir, relative "/"-joined paths.
(define (tree-files dir)
  (let walk ((rel ""))
    (let ((os (if (string=? rel "") dir (join-path dir rel)))
          (join (lambda (n) (if (string=? rel "") n (string-append rel "/" n)))))
      (append (map join (directory-files os))
              (append-map (lambda (d) (walk (join d)))
                          (directory-directories os))))))

;; --- arguments ---------------------------------------------------------------

(define out-dir (repo "dist"))
(define zig-dir (join-path (or (get-environment-variable "HOME") ".") (string-append "zig-x86_64-linux-" zig-version)))
(define build? #t)
(define allow-dirty? #f)

(let loop ((args (cdr (command-line))))
  (cond ((null? args))
        ((and (string=? (car args) "--out") (pair? (cdr args)))
         (set! out-dir (cadr args))
         (loop (cddr args)))
        ((and (string=? (car args) "--zig") (pair? (cdr args)))
         (set! zig-dir (cadr args))
         (loop (cddr args)))
        ((string=? (car args) "--no-build")
         (set! build? #f)
         (loop (cdr args)))
        ((string=? (car args) "--allow-dirty")
         (set! allow-dirty? #t)
         (loop (cdr args)))
        (else (say "usage: package-deb-native.scm [--out <dir>] [--zig <dir>] [--no-build] [--allow-dirty]")
              (exit 2))))

;; --- inputs ------------------------------------------------------------------

(define base-version (string-trim-both (read-text (repo "VERSION"))))
(define dirty? (not (string=? (run "git" "status" "--porcelain") "")))

(when (and dirty? (not allow-dirty?))
  (fail "the working tree has uncommitted changes; commit them or pass --allow-dirty"))

(define version (if dirty? (string-append base-version "+dirty") base-version))
(define epoch (if dirty? (quotient (timestamp) 1000) (string->number (run "git" "log" "-1" "--format=%ct"))))
(define hash (run "git" "rev-parse" "--short=8" "HEAD"))

(let ((zig (join-path zig-dir "zig")))
  (unless (file-exists? zig) (fail zig " not found (pass --zig <dir>)"))
  (let ((v (run zig "version")))
    (unless (string=? v zig-version) (fail zig " is version " v ", not " zig-version))))

(define package-dir (repo "scm-native" "build" "package"))
(define tools '(("scmc" "scm-native/scmc.scm" "-I" "scm-native/compiler")
                ("scm" "scm-native/tools/scm.scm")
                ("package-deb" "scm-native/tools/package-deb.scm")))

(when build?
  (unless (directory-exists? package-dir) (make-directory package-dir))
  (for-each (lambda (t)
              (say "building " (car t) " ...")
              (apply run "scm" "scm-native/scmc.scm" (cadr t)
                     "-o" (join-path package-dir (car t)) "--strip"
                     (cddr t)))
            tools))

(for-each (lambda (t)
            (unless (file-exists? (join-path package-dir (car t)))
              (fail (join-path package-dir (car t)) " not found (build without --no-build)")))
          tools)

;; --- package contents --------------------------------------------------------

(define lib "usr/lib/dabscm-native/")
(define native-dir "/usr/lib/dabscm-native/scm-native")

(define (wrapper command exe)
  (list (string-append "usr/bin/" command) #o755
        (string->utf8
         (string-append "#!/bin/sh\n"
                        "# dabscm native " version "\n"
                        "SCM_NATIVE_DIR=" native-dir "\n"
                        "export SCM_NATIVE_DIR\n"
                        "exec " native-dir "/bin/" exe " \"$@\"\n"))))

;; files under dir (in the repository) as entries under prefix; mode 755 for
;; executables listed in exec
(define (tree-entries dir prefix . exec)
  (map (lambda (f)
         (list (string-append prefix f)
               (if (member f exec) #o755 #o644)
               (read-bytes (join-path dir f))))
       (tree-files dir)))

(define doc "usr/share/doc/dabscm-native/")

(define data
  (append
   (list (wrapper "scmc" "scmc")
         (wrapper "scm-native" "scm")
         (wrapper "scmc-deb" "package-deb")
         (list (string-append doc "copyright") #o644 (read-bytes (repo "LICENSE")))
         (list (string-append doc "README.md") #o644 (read-bytes (repo "scm-native" "README.md"))))
   (map (lambda (t)
          (list (string-append lib "scm-native/bin/" (car t)) #o755
                (read-bytes (join-path package-dir (car t)))))
        tools)
   (append-map (lambda (d)
                 (tree-entries (repo "scm-native" d) (string-append lib "scm-native/" d "/")))
               '("runtime" "lib" "compiler" "vendor" "tools"))
   (list (list (string-append lib "scm-lib/library.scm") #o644 (read-bytes (repo "scm-lib" "library.scm"))))
   (tree-entries (repo "scm-lib" "libraries") (string-append lib "scm-lib/libraries/"))
   (tree-entries zig-dir (string-append lib "zig/") "zig")))

(define installed-kib
  (+ (fold (lambda (e acc) (+ acc (quotient (+ (bytevector-length (entry-content e)) 1023) 1024)))
           0 data)
     (- (length (add-parent-dirs data)) (length data))))

(define control
  (string-append "Package: dabscm-native\n"
                 "Version: " version "\n"
                 "Architecture: amd64\n"
                 "Maintainer: " maintainer "\n"
                 "Installed-Size: " (number->string installed-kib) "\n"
                 "Section: devel\n"
                 "Priority: optional\n"
                 "Description: R7RS Scheme compiler to native executables (dabscm native)\n"
                 " scmc compiles dabscm Scheme programs, with every library they use, to\n"
                 " Zig and links one static executable (Linux x86-64 and arm64, macOS,\n"
                 " Windows). The runtime has a generational collector, threads (SRFI 18),\n"
                 " TLS, HTTP and the scm extension libraries. Bundles Zig " zig-version ".\n"
                 " Installs scmc, scm-native (a REPL and interpreter) and scmc-deb.\n"))

(define md5sums
  (apply string-append
         (map (lambda (e) (string-append (md5-hash (entry-content e)) "  " (entry-name e) "\n"))
              data)))

(define control-entries
  (list (list "control" #o644 (string->utf8 control))
        (list "md5sums" #o644 (string->utf8 md5sums))))

;; --- write -------------------------------------------------------------------

(unless (directory-exists? out-dir) (make-directory out-dir))

(let ((deb (join-path out-dir (string-append "dabscm-native_" version "_amd64.deb"))))
  (say "writing " deb " (" (length data) " files) ...")
  (call-with-port (open-binary-output-file deb)
    (lambda (out)
      (write-bytevector (deb-bytevector control-entries data epoch) out)))
  (say deb " (commit " hash ", " (length data) " files, " installed-kib " KiB installed)"))
