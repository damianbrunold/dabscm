# `(scm scaffold)`

New applications from the starters: scm new-app

## Overview

`(scm scaffold)` starts a new application from one of the starters in
`examples/` (`starter-public`, `starter-login`, `starter-admin`,
`starter-api`): it copies the starter into a new directory and renames it,
replacing every spelling of the starter's name in paths and file contents
(`starter-admin`, `starter_admin`, `Starter Admin`, `STARTER_ADMIN`) with the
same spelling of the new name. Local configs the starter's `.gitignore`
names are left out; shell scripts are made executable.

The command line runs it as `scm new-app`:

```sh
scm new-app starter-admin ~/projects/ledger          # name: ledger
scm new-app starter-api ./svc city-stats             # name: city-stats
scm new-app                                          # usage and starters
```

The starters' files are built into dabscm (`(scm scaffold starters)`,
generated from `examples/` by `update-scheme-files.scm`), so `new-app` needs
no checkout of the dabscm repository.

## Common uses

```scheme
(import (scm scaffold))

(starter-names)                       ; => ("starter-public" ... "starter-api")
(new-app "starter-login" "/home/me/projects/notes")
(new-app "starter-admin" "/srv/src/ledger" "ledger-app")
```


## Exports

### `app-name-variants`

```
Syntax: (app-name-variants name)
Library: (scm scaffold)
Description: The spellings of a kebab-case app name that new-app
  replaces, in this order: kebab, snake, title and upper case.
Example:
  (app-name-variants "my-app") => ("my-app" "my_app" "My App" "MY_APP")
```

### `new-app`

```
Syntax: (new-app starter dir [name])
Library: (scm scaffold)
Description: Copies the starter (one of (starter-names)) into the new or
  empty directory dir and renames it to name, a kebab-case name (default:
  the last component of dir). Shell scripts are made executable. Returns
  the list of files written, relative to dir. Signals an error for an
  unknown starter, an invalid name or a directory that is not empty.
Example:
  (new-app "starter-admin" "/home/me/projects/ledger")
  => (".gitignore" "README.md" "bin/server.scm" ...)
```

### `new-app-command`

```
Syntax: (new-app-command args)
Library: (scm scaffold)
Description: The `scm new-app` command: args are the command-line
  arguments after "new-app". Prints what it did, or the usage, and
  returns the exit code.
```

### `starter-names`

```
Syntax: (starter-names)
Library: (scm scaffold)
Description: The names of the starters new-app can copy, simplest first.
Example:
  (starter-names) => ("starter-public" "starter-login" "starter-admin" "starter-api")
```

