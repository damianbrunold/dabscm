---
title: "(scm deb) and (scm deb webapp): Debian packages"
part: libraries
order: 1044
libraries: (scm deb) (scm deb webapp)
summary: What a .deb file is, building one in pure Scheme from control and data entries with file modes, maintainer scripts, looking inside the result, reproducible builds; packaging a dabscm web application with its config, system user, services and timers; version numbers from commits.
---
# (scm deb) and (scm deb webapp): Debian packages

A `.deb` file is how software is installed on Debian and Ubuntu:
`apt install ./tool.deb` copies its files, runs its setup scripts and
can remove it all again. `(scm deb)` builds such files in pure Scheme,
with no `dpkg-deb` needed, so packages can be built on any machine,
Windows included. `(scm deb webapp)` packages a whole dabscm web
application.

```scheme
(import (scheme base) (scheme char) (scheme file) (scheme write)
        (scm fs) (scm archive) (scm deb) (scm deb webapp))
```

## What is in a .deb

A `.deb` is an `ar` archive with three members:

- `debian-binary`, the format version `2.0`;
- `control.tar.gz`, the package description and scripts;
- `data.tar.gz`, the files to install, with their paths from `/`.

The entries of both tar archives are lists `(path mode content)`.

## A small package

A command-line tool, `teashop-report`, installed to `/usr/bin`, with its
documentation:

```scheme
(define control-text "Package: teashop-report
Version: 1.2.0
Architecture: all
Maintainer: Teashop IT <it@tea.example>
Depends: dabscm
Description: Monthly sales report for the tea shops
 Reads the sales export and writes the monthly PDF report.
")

(define script "#!/usr/bin/env scm\n(import (scheme base) (scheme write))\n(display \"report written\\n\")\n")

(define postinst "#!/bin/sh\nset -e\nmkdir -p /var/lib/teashop-report\n")

(define deb
  (deb-bytevector
   (list (list "control" #o644 (string->utf8 control-text))
         (list "postinst" #o755 (string->utf8 postinst)))
   (list (list "usr/bin/teashop-report" #o755 (string->utf8 script))
         (list "usr/share/doc/teashop-report/README" #o644 (string->utf8 "Run monthly.\n")))
   1735689600))

(utf8->string (bytevector-copy deb 0 8))    ;; => "!<arch>\n"
```

- `control` is the package description. The long description lines
  start with a space; `Depends` names packages that must be installed
  first.
- `postinst` runs after installation (here creating a data directory);
  `prerm` and `postrm` run on removal.
- The modes are octal: `#o755` for programs and scripts, `#o644` for
  data.
- The last argument is the modification time of every entry, in
  seconds since 1970. With a fixed time, the same input gives the same
  bytes, so builds are reproducible and their checksums can be
  compared.

## Looking inside

An `ar` archive is simple enough to read by hand: an 8-byte signature,
then for each member a 60-byte header with the name and the size in
decimal:

```scheme
(define (ar-members bv)
  (let loop ((pos 8) (acc '()))
    (if (>= pos (bytevector-length bv))
        (reverse acc)
        (let* ((field (lambda (from to) (string-trim-blank (utf8->string (bytevector-copy bv (+ pos from) (+ pos to))))))
               (name (let ((n (field 0 16)))          ; GNU ar ends names with /
                       (if (string=? (substring n (- (string-length n) 1) (string-length n)) "/")
                           (substring n 0 (- (string-length n) 1))
                           n)))
               (size (string->number (field 48 58)))
               (data (bytevector-copy bv (+ pos 60) (+ pos 60 size))))
          (loop (+ pos 60 size (modulo size 2)) (cons (cons name data) acc))))))

(define (string-trim-blank s)
  (let loop ((e (string-length s)))
    (if (and (> e 0) (char-whitespace? (string-ref s (- e 1)))) (loop (- e 1)) (substring s 0 e))))

(map car (ar-members deb))                  ;; => ("debian-binary" "control.tar.gz" "data.tar.gz")
(utf8->string (cdr (assoc "debian-binary" (ar-members deb)))) ;; => "2.0\n"
```

The data archive lists the files, with the parent directories added:

```scheme
(define dir (mktempdir '(prefix . "deb")))
(define data-tar (join-path dir "data.tar"))
(call-with-port (open-binary-output-file data-tar)
  (lambda (p) (write-bytevector (gzip-decompress (cdr (assoc "data.tar.gz" (ar-members deb)))) p)))
(tar-list data-tar)
;; => ("./" "./usr/" "./usr/bin/" "./usr/bin/teashop-report" "./usr/share/" "./usr/share/doc/" "./usr/share/doc/teashop-report/" "./usr/share/doc/teashop-report/README")
(rm dir 'recursive)
```

Written to a file named `<package>_<version>_<architecture>.deb`, the
package installs as usual:

```sh
sudo apt install ./teashop-report_1.2.0_all.deb
dpkg -L teashop-report          # the files it installed
sudo apt remove teashop-report
```

`tar-bytevector` and `ar-bytevector` build the two archive formats on
their own, and `add-parent-dirs` and `sort-entries` prepare entry lists.

## Packaging a web application

`(scm deb webapp)` packages a web application made from the starters
(see [scaffold](scm-scaffold.md)) the way they are deployed:

- the code goes to `/opt/<pkg>/app`;
- the configuration to `/etc/<pkg>/config.scm`, kept on upgrades;
- the data goes to `/var/lib/<pkg>`;
- a system user is created;
- the systemd services and timers are installed and started.

The application's `package-deb.scm` describes it:

```scheme no-test
(import (scheme base) (scheme process-context) (scm deb webapp))

(webapp-deb-main
 '((pkg . "tea-shop")
   (summary . "Tea shop web application")
   (description "Orders, stock and the monthly reports of the tea shops.")
   (services "tea-shop.service")
   (timers "tea-shop-health.timer" "tea-shop-restart.timer")
   (trees "src" "static")
   (data-subdirs "uploads")
   (config-settings ("data-dir" . "\"/var/lib/tea-shop\"")
                    ("secure-cookies?" . "#t"))
   (depends "postgresql-client")
   (maintainer . "Teashop IT <it@tea.example>"))
 (cdr (command-line)))
```

```sh
scm package-deb.scm                       # dist/tea-shop_2025.03.07.101500+g1a2b3c4_all.deb
scm package-deb.scm --native              # compiled with dabscm native instead of the JVM
```

The version comes from the last commit, so every build sorts after the
one before:

```scheme
(webapp-deb-version 1741342500 "1a2b3c4" #f) ;; => "2025.03.07.101500+g1a2b3c4"
(webapp-deb-version 1741342500 "1a2b3c4" #t) ;; => "2025.03.07.101500+g1a2b3c4.dirty"
```

The installed configuration is the application's `config.example.scm`
with the production values put in; a setting that the example does not
define is an error, so a renamed setting cannot slip through with its
development value:

```scheme
(define (string-search-forward pattern s)     ; position of pattern in s, or #f
  (let loop ((i 0))
    (cond ((> (+ i (string-length pattern)) (string-length s)) #f)
          ((string=? (substring s i (+ i (string-length pattern))) pattern) i)
          (else (loop (+ i 1))))))

(define example ";; tea-shop configuration\n(define http-port 8070)\n(define secure-cookies? #f)\n")
(define installed (webapp-default-config example "tea-shop" '(("secure-cookies?" . "#t"))))
(and (string-search-forward "(define secure-cookies? #t)" installed) #t) ;; => #t
(webapp-default-config example "tea-shop" '(("no-such-setting" . "1"))) ;; => error
```

## Where next

- [Scaffold](scm-scaffold.md) for the applications to package,
  [archives](scm-archive.md) for tar, gzip and ZIP,
  [remote commands](scm-net-remote.md) for copying packages to servers.
- Reference: `(scm deb)`, `(scm deb webapp)`.
