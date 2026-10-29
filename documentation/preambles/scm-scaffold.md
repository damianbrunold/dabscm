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
