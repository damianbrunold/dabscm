---
title: "(scm net-remote): ssh, scp, rsync, curl and wget from Scheme"
part: libraries
order: 1032
libraries: (scm net-remote)
summary: Running commands on other machines with ssh, copying with scp and rsync, fetching with curl and wget (or without them, in pure Scheme), options as symbols and pairs, results and exit codes, a deployment script.
---
# (scm net-remote): ssh, scp, rsync, curl and wget from Scheme

`(scm net-remote)` runs the usual command-line tools for remote work,
with their options written as Scheme data. The programs must be
installed; `ssh` uses your SSH keys and configuration as it does on the
command line.

```scheme
(import (scheme base) (scheme write) (scm net-remote)
        (scm net http request) (scm net http response) (scm net http route) (scm net http server))
```

## Options

Every procedure takes its options after the required arguments: a symbol
for a flag, a pair for an option with a value.

```scheme no-test
(rsync "build/" "deploy@web1:/srv/app/" 'archive 'delete '(exclude . ("*.log" "tmp/")))
;; runs: rsync -a --delete --exclude *.log --exclude tmp/ build/ deploy@web1:/srv/app/
```

The arguments go to the program directly, not through a shell, so file
names with spaces or quotes need no escaping.

## ssh

`ssh` runs a command on another machine and returns its exit code,
output and error output:

```scheme no-test
(ssh "deploy@web1" "df -h /srv")
;; => (0 "Filesystem  Size  Used Avail Use% Mounted on\n/dev/sda1  ...\n" "")

(ssh "web1" "systemctl is-active tea-shop" '(user . "deploy") '(port . 2222) '(key . "~/.ssh/deploy"))
;; => (0 "active\n" "")
```

A host that cannot be reached is not an error: ssh's exit code 255 comes
back, with its message:

```scheme no-test
(ssh "web9.invalid" "true")
;; => (255 "" "ssh: Could not resolve hostname web9.invalid: Name or service not known\r\n")
```

`'(stdin . text)` feeds text to the remote command, for example a SQL
script to `psql`.

## Copying: scp and rsync

```scheme no-test
(scp "dist/tea-shop.tar.gz" "deploy@web1:/srv/releases/")       ; => #t
(scp "deploy@web1:/var/log/tea-shop/access.log" "logs/" 'quiet)
(rsync "static/" "deploy@web1:/srv/tea-shop/static/" 'archive 'compress 'delete)
(rsync "static/" "deploy@web1:/srv/tea-shop/static/" 'archive 'dry-run 'verbose)  ; only show
```

Both return `#t` when the copy succeeded. `rsync` copies only what
changed, which makes it the tool for directories; `'delete` removes files
at the destination that the source no longer has, so try a `'dry-run`
first.

## Fetching: curl and wget

`curl` returns the body of a response, or with `'include-status` the
status and the body. The option `'pure` uses `(scm net http client)`
instead of the curl program, so it works where curl is not installed:

```scheme
(define r (make-router))
(router-add! r "GET" "/version" (lambda (req p) (text-response "2.31.0")))
(router-add! r "POST" "/echo" (lambda (req p) (text-response (string-append "got " (http-request-body req)))))
(define server (start-app-with-router r 18930 4 "127.0.0.1"))

(curl "http://127.0.0.1:18930/version" 'pure) ;; => "2.31.0"
(curl "http://127.0.0.1:18930/missing" 'pure 'include-status) ;; => (404 . "Not Found")
(curl "http://127.0.0.1:18930/echo" '(data . "order 117") 'pure) ;; => "got order 117"
(server-stop server)
```

Without `'pure` the same calls run curl, and the curl options work:
`'follow-redirects`, `'(timeout . 10)`, `'fail-on-error`,
`'(output . "file")` to save the body. `wget` downloads files, with
`'continue` to resume a broken download:

```scheme no-test
(curl "https://api.example.com/v1/status" 'silent 'follow-redirects '(timeout . 10))
(wget "https://downloads.example.com/data-2025.zip" '(output . "data/2025.zip") 'quiet 'continue)
```

For anything more than fetching a URL, `(scm net http client)` is the
better choice: it returns headers and binary bodies and raises clear
errors ([HTTP client](scm-http-client.md)).

## Example: a deployment script

Copy a release to each server, switch a symlink to it, restart the
service and check that it answers, stopping at the first problem:

```scheme no-test
(define servers '("deploy@web1" "deploy@web2"))
(define release "tea-shop-2.31.0")

(define (run-on host command)
  (let ((r (ssh host command)))
    (unless (zero? (car r))
      (error "remote command failed" host command (caddr r)))
    (cadr r)))

(define (deploy host)
  (display (string-append "deploying to " host "\n"))
  (unless (rsync (string-append "dist/" release "/")
                 (string-append host ":/srv/releases/" release "/") 'archive 'compress)
    (error "copy failed" host))
  (run-on host (string-append "ln -sfn /srv/releases/" release " /srv/tea-shop"))
  (run-on host "sudo systemctl restart tea-shop")
  (run-on host "curl -fsS http://127.0.0.1:8070/healthz"))

(for-each deploy servers)
```

One server at a time keeps the others serving while each restarts.

## Where next

- [Running programs](techniques-12-system.md) for local processes,
  [HTTP client](scm-http-client.md), [scaffold](scm-scaffold.md) for the
  starters' own `deploy/install.sh`.
- Reference: `(scm net-remote)`.
