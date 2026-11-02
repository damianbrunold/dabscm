# `(scm deb webapp)`

Debian package for a dabscm web application (systemd, /opt + /etc + /var/lib)

## Exports

### `package-webapp-deb`

```
Syntax: (package-webapp-deb spec [option ...])
Library: (scm deb webapp)
Description: Builds <out>/<pkg>_<version>_all.deb for the web application
  described by spec and returns its path. spec is an alist:
    (pkg . "myapp")              package, system user and unit prefix
    (summary . "...")            one-line description
    (description "line" ...)     long description
    (services "myapp.service")   started after install when configured
    (timers "myapp-health.timer" ...)
  optional:
    (app-dir . ".")              the app (a git checkout)
    (trees "src" "static")       directories copied to /opt/<pkg>/app
    (bin-exclude "dev-server.scm") bin/ scripts left out
    (data-subdirs "files")       created under /var/lib/<pkg>
    (config-settings ("name" . "value") ...)  see webapp-default-config
    (setup-hints "line" ...)     printed while the config is unfinished
    (depends "postgresql-client")  extra Depends
    (recommends "postgresql")    Recommends
    (default-port . 8080)        health probe port if the config has none
    (maintainer . "Name <mail>")
  Options, each a pair: (out . dir) (default "dist" in app-dir),
  (jar . path) (default ../dabscm/scm-java/scm.jar next to app-dir),
  (allow-dirty . #t) to package uncommitted changes. The version comes from
  the last commit (webapp-deb-version), so the same commit gives the same
  bytes.
Example:
  (package-webapp-deb
    '((pkg . "myapp") (summary . "My app") (description "My app.")
      (services "myapp.service") (timers "myapp-health.timer"))
    '(out . "dist"))
```

### `webapp-deb-main`

```
Syntax: (webapp-deb-main spec args)
Library: (scm deb webapp)
Description: Command-line front end for package-webapp-deb, for an app's
  package-deb.scm: args (usually (cdr (command-line))) may hold
  --out <dir>, --jar <scm.jar>, --dabscm <checkout> (uses its
  scm-java/scm.jar) and --allow-dirty. Prints the package path and returns
  it; prints the error and exits with status 1 on failure.
Example:
  ;; package-deb.scm
  (import (scheme base) (scheme process-context) (scm deb webapp))
  (webapp-deb-main '((pkg . "myapp") ...) (cdr (command-line)))
```

### `webapp-deb-version`

```
Syntax: (webapp-deb-version epoch hash dirty?)
Library: (scm deb webapp)
Description: The package version for a build of commit hash made at epoch
  (seconds, UTC): YYYY.MM.DD.HHMMSS+g<hash>, with a ".dirty" suffix for
  uncommitted changes. Versions of later commits sort higher.
Example:
  (webapp-deb-version 1792241802 "1056360d" #f) => "2026.10.17.125642+g1056360d"
```

### `webapp-default-config`

```
Syntax: (webapp-default-config example-text pkg settings)
Library: (scm deb webapp)
Description: The config a package installs as /etc/<pkg>/config.scm:
  example-text (the app's config.example.scm) with a header comment and
  every (define name value) listed in settings, an alist of
  (name . value-source), replaced by (define name value-source). Each
  name must have a single-line define in the example; an error otherwise,
  so a renamed setting cannot silently keep its development value.
Example:
  (webapp-default-config text "myapp"
    '(("files-dir" . "\"/var/lib/myapp/files\"")
      ("secure-cookies?" . "#t")))
```

