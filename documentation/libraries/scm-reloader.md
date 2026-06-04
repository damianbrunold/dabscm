# `(scm reloader)`

## Exports

### `files-with-suffix`

```
Syntax: (files-with-suffix dir suffix)
Library: (scm reloader)
Description: Returns the immediate (non-recursive) entries of dir whose
  name ends in suffix, each as a "dir/name" path string. Handy for
  building a watch set, e.g. (files-with-suffix src-dir ".sld").
Example:
  (files-with-suffix "src" ".sld") => ("src/a.sld" "src/b.sld")
```

### `supervise`

```
Syntax: (supervise command watch opts)
Library: (scm reloader)
Description: Runs a development supervisor loop forever. `command` is the
  child argv as a list of strings (or a thunk returning one); `watch` is a
  thunk returning the list of file paths to watch (re-evaluated each poll,
  so newly added files are picked up); `opts` is an alist of options:
    (label . str)               log prefix, shown as "[label]" (default "reloader")
    (work-dir . str)            child working directory (default: inherit)
    (root . str)                strip this prefix from logged paths (default: none)
    (poll-interval . secs)      file poll cadence (default 0.5)
    (debounce-interval . secs)  settle wait after a change (default 0.3)
    (base-backoff-ticks . n)    first crash retry delay, in polls (default 2)
    (max-backoff-ticks . n)     crash retry delay cap, in polls (default 20)
    (healthy-ticks . n)         polls alive before the backoff resets (default 10)
  The child is restarted immediately on any watched-file change, and
  auto-retried on an exponential backoff if it exits on its own. Does not
  return.
Example:
  (supervise (list "scm" "bin/server.scm" cfg)
             (lambda () (cons cfg (files-with-suffix "src" ".sld")))
             `((label . "dev-server") (work-dir . ,root) (root . ,root)))
```

