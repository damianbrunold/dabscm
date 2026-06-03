## Overview

`(scm net-remote)` wraps the standard remote-access command-line tools — `curl`,
`wget`, `ssh`, `scp`, and `rsync` — so they can be driven from Scheme. Each
procedure shells out to the corresponding native program, which must be installed.

## Common uses

```scheme
(import (scm net-remote))

(ssh "deploy@web1" "systemctl status nginx" '(port . 2222))
(scp "build.tar.gz" "deploy@web1:/srv/releases/" '(port . 2222))
(rsync "build/" "deploy@web1:/srv/app/" 'archive 'delete 'verbose)
```

`curl` and `wget` fetch URLs. Options are passed as trailing arguments —
symbols for flags (e.g. `'archive`) and `(key . value)` pairs for valued options
(e.g. `'(port . 2222)`).
