;; (scm deb webapp) — a Debian package for a dabscm web application, in pure
;; Scheme (see (scm deb)): `apt install ./<pkg>_<version>_all.deb` installs
;; the app, the runtime it was built with, its systemd units, a config in
;; /etc and a system user. The app follows the usual dabscm webapp layout:
;;
;;   bin/server.scm [config]     starts the app
;;   bin/gen-secret.scm          optional: prints a fresh base64 secret
;;   src/ static/ migrations/    code and assets (the spec's trees)
;;   config.example.scm          (define name value) settings
;;   deploy/systemd/*.service|*.timer   units for the installed layout
;;   deploy/debian/README.Debian        admin notes
;;   deploy/{nginx,apache}.conf.example optional proxy examples
;;   LICENSE                            becomes the copyright file
;;
;; Installed layout for package P:
;;   /opt/P/app/...          bin/, the trees, a config.scm stub loading
;;                           /etc/P/config.scm
;;   /opt/P/bin/scm          java $JAVA_OPTS -jar /opt/P/lib/scm.jar
;;   /opt/P/bin/healthcheck  GET /healthz on the configured host/port, two
;;                           strikes, then restarts the unit given as argument
;;   /opt/P/lib/scm.jar, /opt/P/VERSION
;;   /usr/bin/P-admin        runs app/bin/<script>.scm
;;   /usr/lib/systemd/system the units
;;   /usr/share/P/config.default.scm   copied to /etc/P/config.scm on the
;;                           first install (gen-secret.scm output replaces
;;                           REPLACE_WITH_BASE64_SECRET)
;;   /usr/share/doc/P/       README.Debian, copyright, proxy examples
;;   /var/lib/P              data, owned by the system user P
;; The services start once no setting in /etc/P/config.scm still holds
;; "change-me" or a REPLACE_WITH_... placeholder.

(define-library (scm deb webapp)
  (export package-webapp-deb
          webapp-deb-main
          webapp-deb-version
          webapp-default-config)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (scheme process-context)
          (scheme time)
          (scheme write)
          (srfi 1)
          (srfi 13)
          (srfi 95)
          (scm crypto)
          (scm datetime)
          (scm deb)
          (scm fs)
          (scm system)
          (scm string))
  (begin

    ;; --- spec ---------------------------------------------------------------

    (define (spec-opt spec key default)
      (let ((e (assq key spec))) (if e (cdr e) default)))

    (define (spec-ref spec key)
      (let ((e (assq key spec)))
        (unless e (error "webapp deb spec: missing key" key))
        (cdr e)))

    ;; --- small helpers ------------------------------------------------------

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

    ;; Shell scripts and units must be LF-only even from a CRLF checkout.
    (define (lf-only s)
      (list->string (remove (lambda (c) (char=? c #\return)) (string->list s))))

    (define (substitute text pairs)
      (fold (lambda (kv acc) (string-replace-all acc (car kv) (cdr kv))) text pairs))

    (define (skip-name? name)
      (or (string-suffix? "~" name)
          (string-prefix? ".#" name)
          (string=? name "__pycache__")
          (string-suffix? ".swp" name)))

    ;; Files under dir as sorted "/"-joined relative paths.
    (define (tree-files dir)
      (sort-strings
        (let walk ((rel ""))
          (let ((os (if (string=? rel "") dir (join-path dir rel)))
                (join (lambda (n) (if (string=? rel "") n (string-append rel "/" n)))))
            (append
              (filter-map (lambda (f) (and (not (skip-name? f)) (join f)))
                          (directory-files os))
              (append-map (lambda (d) (if (skip-name? d) '() (walk (join d))))
                          (directory-directories os)))))))

    (define (sort-strings l) (sort l string<?))

    (define (git dir . args)
      (let ((r (run-program/capture (cons "git" args) `((work-dir ,dir)))))
        (unless (and (pair? r) (eqv? (car r) 0))
          (error "git failed" args))
        (string-trim-both (cadr r))))

    ;; --- version ------------------------------------------------------------

    (define (webapp-deb-version epoch hash dirty?)
      "Syntax: (webapp-deb-version epoch hash dirty?)
Library: (scm deb webapp)
Description: The package version for a build of commit hash made at epoch
  (seconds, UTC): YYYY.MM.DD.HHMMSS+g<hash>, with a \".dirty\" suffix for
  uncommitted changes. Versions of later commits sort higher.
Example:
  (webapp-deb-version 1792241802 \"1056360d\" #f) => \"2026.10.17.125642+g1056360d\""
      (let* ((iso (format-iso8601 epoch))          ; YYYY-MM-DDTHH:MM:SSZ
             (stamp (string-append (substring iso 0 4) "." (substring iso 5 7) "."
                                   (substring iso 8 10) "."
                                   (substring iso 11 13) (substring iso 14 16)
                                   (substring iso 17 19))))
        (string-append stamp "+g" hash (if dirty? ".dirty" ""))))

    ;; --- config -------------------------------------------------------------

    ;; The line holding the single-line form (define name ...), or #f.
    (define (define-line? line name)
      (let ((t (string-trim line)))
        (and (string-prefix? (string-append "(define " name) t)
             (let ((rest (substring t (+ 8 (string-length name)) (string-length t))))
               (and (> (string-length rest) 0)
                    (char-whitespace? (string-ref rest 0)))))))

    (define (balanced? s)
      (let loop ((cs (string->list s)) (depth 0) (in-string? #f))
        (cond ((null? cs) (= depth 0))
              (in-string?
               (cond ((char=? (car cs) #\\) (loop (if (pair? (cdr cs)) (cddr cs) '()) depth #t))
                     ((char=? (car cs) #\") (loop (cdr cs) depth #f))
                     (else (loop (cdr cs) depth #t))))
              ((char=? (car cs) #\;) (= depth 0))
              ((char=? (car cs) #\") (loop (cdr cs) depth #t))
              ((char=? (car cs) #\() (loop (cdr cs) (+ depth 1) #f))
              ((char=? (car cs) #\)) (loop (cdr cs) (- depth 1) #f))
              (else (loop (cdr cs) depth #f)))))

    (define (webapp-default-config example pkg settings)
      "Syntax: (webapp-default-config example-text pkg settings)
Library: (scm deb webapp)
Description: The config a package installs as /etc/<pkg>/config.scm:
  example-text (the app's config.example.scm) with a header comment and
  every (define name value) listed in settings, an alist of
  (name . value-source), replaced by (define name value-source). Each
  name must have a single-line define in the example; an error otherwise,
  so a renamed setting cannot silently keep its development value.
Example:
  (webapp-default-config text \"myapp\"
    '((\"files-dir\" . \"\\\"/var/lib/myapp/files\\\"\")
      (\"secure-cookies?\" . \"#t\")))"
      (let* ((lines (string-split example "\n"))
             (out
               (fold
                 (lambda (setting lines)
                   (let ((name (car setting)) (value (cdr setting)) (found #f))
                     (let ((new (map (lambda (l)
                                       (cond ((and (not found) (define-line? l name))
                                              (unless (balanced? l)
                                                (error "config.example.scm: define spans several lines" name))
                                              (set! found #t)
                                              (string-append "(define " name " " value ")"))
                                             (else l)))
                                     lines)))
                       (unless found
                         (error "config.example.scm: no (define ...) for setting" name))
                       new)))
                 lines settings)))
        (string-append
          ";; Installed by the " pkg " package as /etc/" pkg "/config.scm on the first\n"
          ";; install; never overwritten afterwards. Relative paths resolve against\n"
          ";; /opt/" pkg "/app. The services start once no setting holds \"change-me\"\n"
          ";; or a REPLACE_WITH_... placeholder any more.\n\n"
          (string-join out "\n"))))

    ;; --- templates ------------------------------------------------------------

    (define control-template
      "Package: @PKG@
Version: @VERSION@
Architecture: all
Maintainer: @MAINTAINER@
Installed-Size: @INSTALLED_SIZE@
Depends: default-jre-headless | java11-runtime-headless, curl, adduser@DEPENDS@
@RECOMMENDS@Suggests: nginx | apache2
Section: web
Priority: optional
Description: @SUMMARY@
@DESCRIPTION@
")

    (define postinst-template
      "#!/bin/sh
# postinst for @PKG@ (generated by dabscm (scm deb webapp)).
set -e

PKG=@PKG@
APP=/opt/@PKG@
CONF=/etc/@PKG@/config.scm
DATA=/var/lib/@PKG@
DATA_SUBDIRS=\"@DATA_SUBDIRS@\"
SERVICES=\"@SERVICES@\"
TIMERS=\"@TIMERS@\"

have_systemd() { [ -d /run/systemd/system ]; }

# Placeholders from the example config left in a setting (comments do not
# count): the admin has not filled it in yet, so the services stay stopped.
configured() {
  [ -e \"$CONF\" ] &&
    ! grep -v '^[[:space:]]*;' \"$CONF\" | grep -q -e '\"change-me\"' -e 'REPLACE_WITH_'
}

case \"$1\" in
  configure)
    if ! getent passwd \"$PKG\" >/dev/null; then
      adduser --system --group --home \"$DATA\" --no-create-home \\
              --gecos \"$PKG service\" --quiet \"$PKG\"
    fi

    mkdir -p \"$DATA\"
    chown \"$PKG:$PKG\" \"$DATA\"
    chmod 0750 \"$DATA\"
    for d in $DATA_SUBDIRS; do
      mkdir -p \"$DATA/$d\"
      chown \"$PKG:$PKG\" \"$DATA/$d\"
    done

    mkdir -p \"/etc/$PKG\"
    if [ ! -e \"$CONF\" ]; then
      if [ -e \"$APP/app/bin/gen-secret.scm\" ]; then
        secret=$(\"$APP/bin/scm\" \"$APP/app/bin/gen-secret.scm\")
        sed \"s|REPLACE_WITH_BASE64_SECRET|$secret|\" \\
            \"/usr/share/$PKG/config.default.scm\" > \"$CONF.new\"
        note=\" (with a fresh secret)\"
      else
        cp \"/usr/share/$PKG/config.default.scm\" \"$CONF.new\"
        note=\"\"
      fi
      chown \"root:$PKG\" \"$CONF.new\"
      chmod 0640 \"$CONF.new\"
      mv \"$CONF.new\" \"$CONF\"
      echo \"$PKG: created $CONF$note.\"
    fi

    if have_systemd; then
      systemctl daemon-reload
      systemctl enable $SERVICES $TIMERS >/dev/null 2>&1 || true
      if configured; then
        for s in $SERVICES; do
          systemctl restart \"$s\" || echo \"$PKG: could not start $s (see journalctl -u $s)\"
        done
        for t in $TIMERS; do systemctl start \"$t\" || true; done
      else
        echo \"$PKG: fill in every \\\"change-me\\\" and REPLACE_WITH_... setting in $CONF,\"
@SETUP_HINTS@        echo \"$PKG: then: systemctl start $SERVICES $TIMERS\"
      fi
    fi
    ;;
esac

exit 0
")

    (define prerm-template
      "#!/bin/sh
# prerm for @PKG@ (generated by dabscm (scm deb webapp)). Stops the
# services before their files are replaced or removed.
set -e

SERVICES=\"@SERVICES_REVERSED@\"
TIMERS=\"@TIMERS@\"

if [ -d /run/systemd/system ]; then
  case \"$1\" in
    remove|deconfigure)
      systemctl stop $TIMERS $SERVICES >/dev/null 2>&1 || true
      systemctl disable $TIMERS $SERVICES >/dev/null 2>&1 || true
      ;;
    upgrade|failed-upgrade)
      systemctl stop $TIMERS $SERVICES >/dev/null 2>&1 || true
      ;;
  esac
fi

exit 0
")

    (define postrm-template
      "#!/bin/sh
# postrm for @PKG@ (generated by dabscm (scm deb webapp)). Purge removes the
# config; the data in /var/lib/@PKG@ and the system user are kept.
set -e

case \"$1\" in
  remove|purge)
    if [ -d /run/systemd/system ]; then
      systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    ;;
esac

if [ \"$1\" = purge ]; then
  rm -rf /etc/@PKG@
  if [ -d /var/lib/@PKG@ ]; then
    echo \"@PKG@: kept /var/lib/@PKG@; delete it by hand if no longer needed.\"
  fi
fi

exit 0
")

    (define scm-template
      "#!/bin/sh
# Scheme runtime for @PKG@: the dabscm build this package was made with.
# Extra JVM options (e.g. -Xmx1g) via JAVA_OPTS, see /etc/default/@PKG@.
exec java $JAVA_OPTS -jar /opt/@PKG@/lib/scm.jar \"$@\"
")

    (define admin-template
      "#!/bin/sh
# @PKG@-admin <script> [args...]: run one of the app's bin/<script>.scm
# tools with the installed runtime, from /opt/@PKG@/app.
set -e
APP=/opt/@PKG@/app
if [ $# -eq 0 ]; then
  echo \"usage: @PKG@-admin <script> [args...]\"
  echo \"scripts:\"
  for f in \"$APP\"/bin/*.scm; do echo \"  $(basename \"$f\" .scm)\"; done
  exit 2
fi
script=$1
shift
[ -f /etc/default/@PKG@ ] && . /etc/default/@PKG@ && export JAVA_OPTS
cd \"$APP\"
exec /opt/@PKG@/bin/scm \"bin/$script.scm\" \"$@\"
")

    (define healthcheck-template
      "#!/bin/sh
# Health probe for @PKG@ (run by the health unit): GET /healthz on the
# port/host from /etc/@PKG@/config.scm. Two strikes: on failure wait 5s and
# probe again; only then restart the unit, so one slow request can't
# bounce the daemon.
conf=/etc/@PKG@/config.scm
unit=$1

value() {
  sed -n \"s/^[[:space:]]*(define[[:space:]][[:space:]]*$1[[:space:]][[:space:]]*\\\"\\{0,1\\}\\([^\\\" )]*\\).*/\\1/p\" \"$conf\" | head -n 1
}

port=$(value http-port)
host=$(value http-host)
case \"$host\" in ''|0.0.0.0|::) host=127.0.0.1 ;; esac
url=\"http://$host:${port:-@DEFAULT_PORT@}/healthz\"

probe() { curl -fsS --max-time 5 \"$url\" >/dev/null; }

if ! probe; then
  sleep 5
  if ! probe; then
    echo \"$unit: $url failed twice; restarting\"
    systemctl restart \"$unit\"
  fi
fi
")

    ;; --- building -------------------------------------------------------------

    (define (shell-quote s)
      (string-append "'" (string-replace-all s "'" "'\\''") "'"))

    (define (package-webapp-deb spec . opts)
      "Syntax: (package-webapp-deb spec [option ...])
Library: (scm deb webapp)
Description: Builds <out>/<pkg>_<version>_all.deb for the web application
  described by spec and returns its path. spec is an alist:
    (pkg . \"myapp\")              package, system user and unit prefix
    (summary . \"...\")            one-line description
    (description \"line\" ...)     long description
    (services \"myapp.service\")   started after install when configured
    (timers \"myapp-health.timer\" ...)
  optional:
    (app-dir . \".\")              the app (a git checkout)
    (trees \"src\" \"static\")       directories copied to /opt/<pkg>/app
    (bin-exclude \"dev-server.scm\") bin/ scripts left out
    (data-subdirs \"files\")       created under /var/lib/<pkg>
    (config-settings (\"name\" . \"value\") ...)  see webapp-default-config
    (setup-hints \"line\" ...)     printed while the config is unfinished
    (depends \"postgresql-client\")  extra Depends
    (recommends \"postgresql\")    Recommends
    (default-port . 8080)        health probe port if the config has none
    (maintainer . \"Name <mail>\")
  Options, each a pair: (out . dir) (default \"dist\" in app-dir),
  (jar . path) (default ../dabscm/scm-java/scm.jar next to app-dir),
  (allow-dirty . #t) to package uncommitted changes. The version comes from
  the last commit (webapp-deb-version), so the same commit gives the same
  bytes.
Example:
  (package-webapp-deb
    '((pkg . \"myapp\") (summary . \"My app\") (description \"My app.\")
      (services \"myapp.service\") (timers \"myapp-health.timer\"))
    '(out . \"dist\"))"
      (let* ((opt (lambda (k d) (let ((e (assq k opts))) (if e (cdr e) d))))
             (pkg (spec-ref spec 'pkg))
             (dir (normalized-path (absolute-path (spec-opt spec 'app-dir "."))))
             (out-dir (opt 'out (join-path dir "dist")))
             (jar (opt 'jar (join-path (directory-name dir) "dabscm" "scm-java" "scm.jar")))
             (dirty? (not (string=? (git dir "status" "--porcelain") ""))))
        (when (and dirty? (not (opt 'allow-dirty #f)))
          (error "package-webapp-deb: uncommitted changes; commit them or allow-dirty" dir))
        (unless (file-exists? jar)
          (error "package-webapp-deb: scm.jar not found (build dabscm first)" jar))
        (let* ((hash (git dir "rev-parse" "--short=8" "HEAD"))
               (epoch (if dirty?
                          (exact (floor (current-second)))
                          (string->number (git dir "log" "-1" "--format=%ct"))))
               (version (webapp-deb-version epoch hash dirty?))
               (services (spec-ref spec 'services))
               (timers (spec-ref spec 'timers))
               (dabscm-version
                 (let ((f (join-path (directory-name (directory-name jar)) "VERSION")))
                   (if (file-exists? f) (string-trim-both (read-text f)) "unknown")))
               (subst
                 `(("@PKG@" . ,pkg)
                   ("@VERSION@" . ,version)
                   ("@MAINTAINER@" . ,(spec-opt spec 'maintainer "unknown <root@localhost>"))
                   ("@SERVICES@" . ,(string-join services " "))
                   ("@SERVICES_REVERSED@" . ,(string-join (reverse services) " "))
                   ("@TIMERS@" . ,(string-join timers " "))
                   ("@DATA_SUBDIRS@" . ,(string-join (spec-opt spec 'data-subdirs '()) " "))
                   ("@DEFAULT_PORT@" . ,(number->string (spec-opt spec 'default-port 8080)))
                   ("@SETUP_HINTS@"
                    . ,(apply string-append
                         (map (lambda (l) (string-append "        echo " (shell-quote (string-append pkg ": " l)) "\n"))
                              (spec-opt spec 'setup-hints '()))))))
               (fill (lambda (t) (lf-only (substitute t subst))))
               (opt-dir (string-append "opt/" pkg "/"))
               (app (string-append opt-dir "app/"))
               (text (lambda (name mode s) (list name mode (string->utf8 s))))
               (from (lambda (name mode path) (list name mode (read-bytes path))))
               (bin-exclude (spec-opt spec 'bin-exclude '("dev-server.scm")))
               (app-files
                 (append
                   (filter-map
                     (lambda (f)
                       (and (string-suffix? ".scm" f) (not (member f bin-exclude))
                            (from (string-append app "bin/" f) #o644 (join-path dir "bin" f))))
                     (sort-strings (directory-files (join-path dir "bin"))))
                   (append-map
                     (lambda (tree)
                       (map (lambda (f) (from (string-append app tree "/" f) #o644
                                              (join-path dir tree f)))
                            (tree-files (join-path dir tree))))
                     (spec-opt spec 'trees '("src" "static")))
                   (list (text (string-append app "config.scm") #o644
                               (string-append ";; Tools under bin/ load this; the real config is\n"
                                              "(load \"/etc/" pkg "/config.scm\")\n")))))
               (units-dir (join-path dir "deploy" "systemd"))
               (unit-files
                 (map (lambda (u)
                        (text (string-append "usr/lib/systemd/system/" u) #o644
                              (lf-only (read-text (join-path units-dir u)))))
                      (filter (lambda (f) (or (string-suffix? ".service" f)
                                              (string-suffix? ".timer" f)))
                              (sort-strings (directory-files units-dir)))))
               (doc (string-append "usr/share/doc/" pkg "/"))
               (doc-files
                 (append
                   (list (from (string-append doc "README.Debian") #o644
                               (join-path dir "deploy" "debian" "README.Debian"))
                         (from (string-append doc "copyright") #o644 (join-path dir "LICENSE")))
                   (filter-map
                     (lambda (f)
                       (let ((p (join-path dir "deploy" f)))
                         (and (file-exists? p) (from (string-append doc f) #o644 p))))
                     '("nginx.conf.example" "apache.conf.example"))))
               (runtime-files
                 (list (from (string-append opt-dir "lib/scm.jar") #o644 jar)
                       (text (string-append opt-dir "bin/scm") #o755 (fill scm-template))
                       (text (string-append opt-dir "bin/healthcheck") #o755 (fill healthcheck-template))
                       (text (string-append "usr/bin/" pkg "-admin") #o755 (fill admin-template))
                       (text (string-append opt-dir "VERSION") #o644
                             (string-append pkg " " version "\ncommit " hash
                                            "\ndabscm " dabscm-version "\n"))
                       (text (string-append "usr/share/" pkg "/config.default.scm") #o644
                             (webapp-default-config
                               (read-text (join-path dir "config.example.scm")) pkg
                               (spec-opt spec 'config-settings '())))))
               (data (append app-files unit-files doc-files runtime-files))
               (installed-kib
                 (+ (fold (lambda (e acc)
                            (+ acc (quotient (+ (bytevector-length (entry-content e)) 1023) 1024)))
                          0 data)
                    (- (length (add-parent-dirs data)) (length data))))
               (control
                 (fill
                   (substitute control-template
                     `(("@INSTALLED_SIZE@" . ,(number->string installed-kib))
                       ("@SUMMARY@" . ,(spec-ref spec 'summary))
                       ("@DESCRIPTION@"
                        . ,(string-join (map (lambda (l) (string-append " " l))
                                             (spec-ref spec 'description))
                                        "\n"))
                       ("@DEPENDS@"
                        . ,(apply string-append
                             (map (lambda (d) (string-append ", " d))
                                  (spec-opt spec 'depends '()))))
                       ("@RECOMMENDS@"
                        . ,(if (pair? (spec-opt spec 'recommends '()))
                               (string-append "Recommends: "
                                              (string-join (spec-opt spec 'recommends '()) ", ")
                                              "\n")
                               ""))))))
               (md5sums
                 (apply string-append
                   (map (lambda (e)
                          (string-append (md5-hash (entry-content e)) "  " (entry-name e) "\n"))
                        data)))
               (control-entries
                 (list (text "control" #o644 control)
                       (text "md5sums" #o644 md5sums)
                       (text "postinst" #o755 (fill postinst-template))
                       (text "prerm" #o755 (fill prerm-template))
                       (text "postrm" #o755 (fill postrm-template))))
               (deb (join-path out-dir (string-append pkg "_" version "_all.deb"))))
          (unless (directory-exists? out-dir) (make-directory out-dir))
          (call-with-port (open-binary-output-file deb)
            (lambda (port) (write-bytevector (deb-bytevector control-entries data epoch) port)))
          deb)))

    (define (webapp-deb-main spec args)
      "Syntax: (webapp-deb-main spec args)
Library: (scm deb webapp)
Description: Command-line front end for package-webapp-deb, for an app's
  package-deb.scm: args (usually (cdr (command-line))) may hold
  --out <dir>, --jar <scm.jar>, --dabscm <checkout> (uses its
  scm-java/scm.jar) and --allow-dirty. Prints the package path and returns
  it; prints the error and exits with status 1 on failure.
Example:
  ;; package-deb.scm
  (import (scheme base) (scheme process-context) (scm deb webapp))
  (webapp-deb-main '((pkg . \"myapp\") ...) (cdr (command-line)))"
      (let loop ((as args) (opts '()))
        (cond
          ((null? as)
           (guard (e (#t (display "package-deb: ")
                         (display (if (error-object? e) (error-object-message e) e))
                         (when (and (error-object? e) (pair? (error-object-irritants e)))
                           (display " ")
                           (write (car (error-object-irritants e))))
                         (newline)
                         (exit 1)))
             (let ((deb (apply package-webapp-deb spec opts)))
               (display deb) (newline)
               deb)))
          ((string=? (car as) "--allow-dirty")
           (loop (cdr as) (cons '(allow-dirty . #t) opts)))
          ((and (member (car as) '("--out" "--jar" "--dabscm")) (pair? (cdr as)))
           (let ((v (cadr as)))
             (loop (cddr as)
                   (cons (cond ((string=? (car as) "--out") (cons 'out v))
                               ((string=? (car as) "--jar") (cons 'jar v))
                               (else (cons 'jar (join-path v "scm-java" "scm.jar"))))
                         opts))))
          (else
           (display "usage: scm package-deb.scm [--out DIR] [--jar SCM.JAR | --dabscm DIR] [--allow-dirty]")
           (newline)
           (exit 2)))))))
