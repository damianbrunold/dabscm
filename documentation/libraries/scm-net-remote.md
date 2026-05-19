# `(scm net-remote)`

## Exports

### `curl`

```
Syntax: (curl url [option ...])
Library: (scm net-remote)
Description: Performs an HTTP(S) request via the native curl command.
  By default returns the response body as a string. Options:
    '(method . str)        — HTTP method (default GET)
    '(headers . list)      — list of header strings "Name: value"
    '(data . str)          — request body (sets method to POST if unset)
    '(output . path)       — write body to file; returns #t/#f
    '(timeout . seconds)
    'silent                — suppress progress (-s)
    'follow-redirects      — -L
    'fail-on-error         — -f (non-2xx exit non-zero)
    'include-status        — return (status . body) instead of body
    'pure                  — force pure-Scheme path (uses (scm net http client));
                             does not honor follow-redirects, timeout, fail-on-error
Example:
  (curl "https://example.com/api"
        '(method . "POST")
        '(headers . ("Content-Type: application/json"))
        '(data . "{\"x\":1}")
        'silent)
```

### `rsync`

```
Syntax: (rsync src dst [option ...])
Library: (scm net-remote)
Description: Invokes rsync to synchronise src to dst. Either may be a
  local path or a remote spec (user@host:/path or rsync://...). Options:
    'archive         — -a (recursive + preserve everything)
    'recursive       — -r
    'delete          — --delete (remove dst files not in src)
    'verbose         — -v
    'dry-run         — -n
    'compress        — -z
    '(exclude . list) — list of patterns to pass as --exclude
    '(rsh . cmd)     — remote-shell command, e.g. "ssh -p 2222"
Example:
  (rsync "build/" "deploy@web1:/srv/app/" 'archive 'delete 'verbose)
```

### `scp`

```
Syntax: (scp src dst [option ...])
Library: (scm net-remote)
Description: Copies files between hosts via the native scp command.
  src or dst may be local paths or remote specs of the form
  user@host:/path. Options:
    'recursive       — pass -r for directory copy
    '(port . int)    — remote SSH port (-P)
    '(key . path)    — identity file (-i)
    'preserve        — preserve times/modes (-p)
    'quiet           — suppress progress (-q)
Example:
  (scp "build.tar.gz" "deploy@web1:/srv/releases/" '(port . 2222))
```

### `ssh`

```
Syntax: (ssh host command [option ...])
Library: (scm net-remote)
Description: Runs command (a string) on the remote host via the native
  ssh command and returns (exit-code stdout stderr). host can be
  "hostname" or "user@hostname". Options:
    '(user . str)   — overrides user (alternative to user@host form)
    '(port . int)   — SSH port (default 22)
    '(key . path)   — identity file (-i)
    '(stdin . str)  — fed to remote command's stdin
    '(extra-args . list) — additional raw flags appended before host
Example:
  (ssh "deploy@web1" "systemctl status nginx" '(port . 2222))
```

### `wget`

```
Syntax: (wget url [option ...])
Library: (scm net-remote)
Description: Downloads url via the native wget command. Options:
    '(output . path)   — save as this filename (-O)
    'quiet             — -q
    'continue          — -c (resume partial)
    'no-check-cert     — --no-check-certificate
    '(timeout . secs)  — --timeout
    'pure              — force pure-Scheme HTTP (uses (scm net http client));
                         does not honor continue/no-check-cert/timeout
Example:
  (wget "https://example.com/file.tar.gz" '(output . "/tmp/x.tgz"))
```

