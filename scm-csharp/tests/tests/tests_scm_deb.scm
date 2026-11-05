(import (scheme base)
        (scheme file)
        (scheme write)
        (srfi 1)
        (srfi 13)
        (scm archive)
        (scm deb)
        (scm deb webapp)
        (scm fs)
        (scm system)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-deb")

(define (bytes-contain? bv s)
  (string-contains (utf8->string (bytevector-map-latin bv)) s))

;; bytes -> string without UTF-8 decoding errors: every byte as one char
(define (bytevector-map-latin bv)
  (let ((out (make-bytevector (bytevector-length bv))))
    (let loop ((i 0))
      (when (< i (bytevector-length bv))
        (let ((b (bytevector-u8-ref bv i)))
          (bytevector-u8-set! out i (if (< b 128) b 63)))
        (loop (+ i 1))))
    out))

(define (read-file-bytes path)
  (call-with-port (open-binary-input-file path)
    (lambda (in) (read-bytevector (file-size path) in))))

(define (write-file path s)
  (call-with-output-file path (lambda (p) (write-string s p))))

;; ar members of a .deb: ((name . bytes) ...)
(define (ar-members bv)
  (let loop ((off 8) (acc '()))
    (if (>= off (bytevector-length bv))
        (reverse acc)
        (let* ((head (utf8->string (bytevector-copy bv off (+ off 60))))
               (name (string-trim-right
                      (substring head 0 16)
                      (lambda (c) (or (char=? c #\space) (char=? c #\/)))))
               (size (string->number (string-trim-both
                                      (substring head 48 58))))
               (data (bytevector-copy bv (+ off 60) (+ off 60 size))))
          (loop (+ off 60 size (if (odd? size) 1 0))
                (cons (cons name data) acc))))))

(test-group "tar, ar, entries"
  (test-equal "one small file: root dir, header, data block, end" 2560
              (bytevector-length (tar-bytevector
                                  (list
                                   (list "a.txt" #o644 (string->utf8 "hi")))
                                  0)))
  (test-equal "parent directories added"
              '("a/" "a/b/" "a/b/c")
              (map entry-name
                   (add-parent-dirs (list
                                     (list "a/b/c" #o644 (bytevector))))))
  (test-equal "sorted by name"
              '("a" "b")
              (map entry-name
                   (sort-entries (list (list "b" #o644 #f)
                                       (list "a" #o644 #f)))))
  (test-equal "entry accessors"
              '("x" 420 #f)
              (let ((e (list "x" #o644 #f)))
                (list (entry-name e) (entry-mode e) (entry-content e))))
  (test-error "long path rejected" #t
              (tar-bytevector (list (list (make-string 300 #\a)
                                          #o644
                                          (bytevector)))
                              0))
  (let
      ((ar (ar-bytevector (list (list "debian-binary" (string->utf8 "2.0\n")))
                          7)))
    (test-equal "ar magic" "!<arch>\n"
                (utf8->string (bytevector-copy ar 0 8)))
    (test-equal "ar member"
                '(("debian-binary" . "2.0\n"))
                (map (lambda (m) (cons (car m) (utf8->string (cdr m))))
                     (ar-members ar))))
  (let
      ((deb (deb-bytevector (list (list "control" #o644
                                        (string->utf8 "Package: x\n")))
                            (list (list "usr/bin/x" #o755
                                        (string->utf8 "#!/bin/sh\n")))
                            1700000000)))
    (test-equal "deb members"
                '("debian-binary" "control.tar.gz" "data.tar.gz")
                (map car (ar-members deb)))
    (test-assert "data holds the file and its parents"
                 (let
                     ((data (gzip-decompress
                             (cdr (assoc "data.tar.gz" (ar-members deb))))))
                   (and (bytes-contain? data "./usr/bin/x")
                        (bytes-contain? data "./usr/")))))
  (test-equal "same input, same bytes" #t
              (equal? (deb-bytevector '()
                                      (list (list "a" #o644 (bytevector 1)))
                                      5)
                      (deb-bytevector '()
                                      (list (list "a" #o644 (bytevector 1)))
                                      5))))

(test-group "webapp version and config"
  (test-equal "version" "2026.10.17.125642+g1056360d"
              (webapp-deb-version 1792241802 "1056360d" #f))
  (test-equal "dirty version" "2026.10.17.125642+g1056360d.dirty"
              (webapp-deb-version 1792241802 "1056360d" #t))
  (let
      ((cfg (webapp-default-config
             "(define a 1)\n  (define files-dir \"data/files\")  ; comment\n(define secure-cookies? #f)\n"
             "myapp"
             '(("files-dir" . "\"/var/lib/myapp/files\"")
               ("secure-cookies?" . "#t")))))
    (test-assert "header"
                 (string-prefix? ";; Installed by the myapp package" cfg))
    (test-assert "setting replaced"
                 (string-contains cfg
                                  "(define files-dir \"/var/lib/myapp/files\")"))
    (test-assert "boolean replaced"
                 (string-contains cfg "(define secure-cookies? #t)"))
    (test-assert "others kept" (string-contains cfg "(define a 1)")))
  (test-error "unknown setting is an error" #t
              (webapp-default-config "(define a 1)\n" "p"
                                     '(("files-dir" . "\"x\""))))
  (test-error "multi-line define is an error" #t
              (webapp-default-config "(define h\n  \"x\")\n" "p"
                                     '(("h" . "\"y\""))))
  (test-equal "prefix of another name does not match" #t
              (guard (e (#t #t))
                (webapp-default-config "(define files-dir-old 1)\n" "p"
                                       '(("files-dir" . "2")))
                #f)))

;; A whole package from a throwaway git checkout (needs git).
(define git-ok?
  (guard (e (#t #f))
    (let ((r (run-program/capture '("git" "--version"))))
      (and (pair? r) (eqv? (car r) 0)))))

(when git-ok?
  (test-group "package-webapp-deb"
    (let* ((tmp (normalized-path (join-path (special-folder-temp)
                                            "scm-deb-webapp-test")))
           (app (join-path tmp "myapp"))
           (git (lambda args
                  (run-program/capture (cons "git" args)
                                       `((work-dir ,app))))))
      (when (directory-exists? tmp) (delete-directory tmp))
      (for-each make-directory
                (list tmp app
                      (join-path app "bin")
                      (join-path app "src")
                      (join-path app "static")
                      (join-path app "deploy")
                      (join-path app "deploy" "systemd")
                      (join-path app "deploy" "debian")))
      (write-file (join-path app "bin" "server.scm") "(display 1)\n")
      (write-file (join-path app "bin" "dev-server.scm") "(display 2)\n")
      (write-file (join-path app "src" "myapp-web.sld")
                  "(define-library (myapp web))\n")
      (write-file (join-path app "static" "app.css") "body {}\n")
      (write-file (join-path app "config.example.scm")
                  "(define http-port 8070)\n(define data-dir \"data\")\n(define db-password \"change-me\")\n")
      (write-file (join-path app "deploy" "systemd" "myapp.service")
                  "[Service]\r\nExecStart=/opt/myapp/bin/scm bin/server.scm\r\n")
      (write-file (join-path app "deploy" "systemd" "myapp-health.timer")
                  "[Timer]\n")
      (write-file (join-path app "deploy" "debian" "README.Debian") "notes\n")
      (write-file (join-path app "LICENSE") "MIT\n")
      (write-file (join-path tmp "scm.jar") "not really a jar")
      (git "init" "-q")
      (git "add" ".")
      (git "-c" "user.name=t" "-c" "user.email=t@t" "commit" "-q" "-m" "x")
      (let* ((spec `((pkg . "myapp")
                     (app-dir . ,app)
                     (summary . "My app")
                     (description "My app," "for tests.")
                     (data-subdirs "data")
                     (config-settings ("data-dir" .
                                       "\"/var/lib/myapp/data\""))
                     (setup-hints "set db-password")
                     (recommends "postgresql")
                     (services "myapp.service")
                     (timers "myapp-health.timer")
                     (default-port . 8070)
                     (copyright-notes "Map data: (c) swisstopo.")))
             (deb (package-webapp-deb spec
                                      (cons 'out (join-path tmp "dist"))
                                      (cons 'jar (join-path tmp "scm.jar"))))
             (members (ar-members (read-file-bytes deb)))
             (data (gzip-decompress (cdr (assoc "data.tar.gz" members))))
             (control (gzip-decompress (cdr
                                        (assoc "control.tar.gz" members)))))
        (test-assert "file name" (string-suffix? "_all.deb" deb))
        (test-assert "named after the package" (string-contains deb "myapp_"))
        (test-assert "app files"
                     (bytes-contain? data "./opt/myapp/app/bin/server.scm"))
        (test-assert "trees"
                     (bytes-contain? data
                                     "./opt/myapp/app/src/myapp-web.sld"))
        (test-assert "dev server left out"
                     (not (bytes-contain? data "dev-server.scm")))
        (test-assert "runtime"
                     (bytes-contain? data "./opt/myapp/lib/scm.jar"))
        (test-assert "launcher"
                     (bytes-contain? data
                                     "exec java $JAVA_OPTS -jar /opt/myapp/lib/scm.jar"))
        (test-assert "admin tool"
                     (bytes-contain? data "./usr/bin/myapp-admin"))
        (test-assert "units, CRs removed"
                     (and (bytes-contain? data
                                          "./usr/lib/systemd/system/myapp.service")
                          (not (bytes-contain? data "server.scm\r"))))
        (test-assert "config default relocated"
                     (bytes-contain? data
                                     "(define data-dir \"/var/lib/myapp/data\")"))
        (test-assert "copyright"
                     (bytes-contain? data "./usr/share/doc/myapp/copyright"))
        (test-assert "copyright: notes and runtime"
                     (and (bytes-contain? data
                                          "Bundled third-party material:\n\nMap data: (c) swisstopo.\n")
                          (bytes-contain? data
                                          "Scheme runtime /opt/myapp/lib/scm.jar: dabscm ")))
        (test-assert "control fields"
                     (and (bytes-contain? control "Package: myapp")
                          (bytes-contain? control "Recommends: postgresql")
                          (bytes-contain? control " for tests.")))
        (test-assert "postinst knows services, data dirs, hints"
                     (and (bytes-contain? control
                                          "SERVICES=\"myapp.service\"")
                          (bytes-contain? control "DATA_SUBDIRS=\"data\"")
                          (bytes-contain? control "myapp: set db-password")))
        (test-assert "healthcheck default port"
                     (bytes-contain? data "${port:-8070}"))
        (test-equal "same commit, same bytes" #t
                    (equal? (read-file-bytes deb)
                            (read-file-bytes
                             (package-webapp-deb
                              spec
                              (cons 'out (join-path tmp "dist2"))
                              (cons 'jar (join-path tmp "scm.jar"))))))
        (write-file (join-path app "static" "app.css")
                    "body { color: red }\n")
        (test-error "uncommitted changes refused" #t
                    (package-webapp-deb
                     spec
                     (cons 'out (join-path tmp "dist3"))
                     (cons 'jar (join-path tmp "scm.jar"))))
        (test-assert "allowed with allow-dirty"
                     (string-contains (package-webapp-deb
                                       spec
                                       (cons 'out (join-path tmp "dist3"))
                                       (cons 'jar (join-path tmp "scm.jar"))
                                       '(allow-dirty . #t))
                                      ".dirty_all.deb")))
      (delete-directory tmp))))

(test-end "scm-deb")
