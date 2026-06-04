(define-library (scm reloader)
  ;; Development process supervisor with file-watch reload and crash
  ;; recovery. Launches a child process (a server, a worker, …) and:
  ;;   - restarts it whenever any watched file changes (debounced so a
  ;;     mid-write save doesn't restart onto a truncated file), and
  ;;   - auto-retries it on an exponential backoff if it exits on its own
  ;;     (e.g. importing mid-`git pull` while the source tree is briefly
  ;;     inconsistent), instead of parking until the next edit.
  ;;
  ;; Extracted from the per-project bin/dev-server.scm supervisors so the
  ;; webapp, jobs worker, and sibling projects share one implementation.
  (import (scheme base)
          (scheme write)
          (scm fs)
          (scm system)
          (srfi 18))
  (export supervise
          files-with-suffix)
  (begin

    (define (files-with-suffix dir suffix)
      "Syntax: (files-with-suffix dir suffix)
Library: (scm reloader)
Description: Returns the immediate (non-recursive) entries of dir whose
  name ends in suffix, each as a \"dir/name\" path string. Handy for
  building a watch set, e.g. (files-with-suffix src-dir \".sld\").
Example:
  (files-with-suffix \"src\" \".sld\") => (\"src/a.sld\" \"src/b.sld\")"
      (let ((slen (string-length suffix)))
        (let loop ((entries (directory-files dir)) (acc '()))
          (cond
            ((null? entries) (reverse acc))
            (else
             (let* ((name (car entries))
                    (n (string-length name)))
               (loop (cdr entries)
                     (if (and (>= n slen)
                              (string=? (substring name (- n slen) n) suffix))
                         (cons (string-append dir "/" name) acc)
                         acc))))))))

    ;; --- options ---------------------------------------------------------

    (define (opt opts key default)
      (let ((cell (assq key opts)))
        (if cell (cdr cell) default)))

    ;; --- file snapshots --------------------------------------------------

    (define (snapshot files)
      (map (lambda (f)
             (cons f (if (file-exists? f)
                         (file-modification-timestamp f)
                         0)))
           files))

    (define (changed? before after)
      (let loop ((a before) (b after))
        (cond
          ((or (null? a) (null? b)) (not (and (null? a) (null? b))))
          ((not (= (cdr (car a)) (cdr (car b)))) #t)
          (else (loop (cdr a) (cdr b))))))

    (define (changed-paths before after)
      (let loop ((a before) (b after) (acc '()))
        (cond
          ((or (null? a) (null? b)) (reverse acc))
          ((= (cdr (car a)) (cdr (car b)))
           (loop (cdr a) (cdr b) acc))
          (else
           (loop (cdr a) (cdr b) (cons (car (car a)) acc))))))

    ;; --- formatting helpers ---------------------------------------------

    (define (join-with sep parts)
      (cond
        ((null? parts) "")
        ((null? (cdr parts)) (car parts))
        (else (string-append (car parts) sep (join-with sep (cdr parts))))))

    (define (relative-to root path)
      (if (not root)
          path
          (let ((prefix (string-append root "/"))
                (n (string-length path)))
            (if (and (>= n (string-length prefix))
                     (string=? (substring path 0 (string-length prefix)) prefix))
                (substring path (string-length prefix) n)
                path))))

    (define (resolve-command command)
      (if (procedure? command) (command) command))

    ;; --- supervise -------------------------------------------------------

    (define (supervise command watch opts)
      "Syntax: (supervise command watch opts)
Library: (scm reloader)
Description: Runs a development supervisor loop forever. `command` is the
  child argv as a list of strings (or a thunk returning one); `watch` is a
  thunk returning the list of file paths to watch (re-evaluated each poll,
  so newly added files are picked up); `opts` is an alist of options:
    (label . str)               log prefix, shown as \"[label]\" (default \"reloader\")
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
  (supervise (list \"scm\" \"bin/server.scm\" cfg)
             (lambda () (cons cfg (files-with-suffix \"src\" \".sld\")))
             `((label . \"dev-server\") (work-dir . ,root) (root . ,root)))"
      (let* ((label (opt opts 'label "reloader"))
             (work-dir (opt opts 'work-dir #f))
             (root (opt opts 'root #f))
             (poll-interval (opt opts 'poll-interval 0.5))
             (debounce-interval (opt opts 'debounce-interval 0.3))
             (base-backoff-ticks (opt opts 'base-backoff-ticks 2))
             (max-backoff-ticks (opt opts 'max-backoff-ticks 20))
             (healthy-ticks (opt opts 'healthy-ticks 10)))

        (define (log msg)
          (display "[") (display label) (display "] ")
          (display msg) (newline))

        (define (start-child)
          (let* ((argv (resolve-command command))
                 (proc (begin
                         (log (string-append "starting: " (join-with " " argv)))
                         (if work-dir
                             (start-program argv `((work-dir ,work-dir)))
                             (start-program argv '())))))
            ;; Ensure the child dies with us: if the supervisor is stopped
            ;; (SIGINT/SIGTERM/SIGHUP/normal exit) it would otherwise orphan
            ;; the child, leaving e.g. a server holding its port and breaking
            ;; the next start with "Address already in use".
            (process-kill-on-exit proc)
            proc))

        (define (stop-child proc)
          (when (process-alive? proc)
            (process-kill proc #t))
          (process-wait proc))

        ;; After a change is first detected, wait until mtimes stop moving
        ;; before restarting. Editors often write files in chunks; restarting
        ;; mid-write makes the child die on a truncated read.
        (define (settle snap)
          (thread-sleep! debounce-interval)
          (let ((next (snapshot (watch))))
            (if (changed? snap next) (settle next) next)))

        (define (backoff-ticks fails)
          (min max-backoff-ticks
               (* base-backoff-ticks (expt 2 (max 0 (- fails 1))))))

        (log (string-append "watching "
                            (number->string (length (watch)))
                            " files; poll every "
                            (number->string poll-interval) "s"))
        ;; Loop state:
        ;;   proc   — current child (may be dead)
        ;;   snap   — last settled snapshot of watched files
        ;;   fails  — consecutive crash count, drives the backoff
        ;;   wait   — 'live while the child is believed running, else the
        ;;            number of polls remaining before the next retry
        ;;   uptime — polls the current child has been observed alive
        (let loop ((proc (start-child))
                   (snap (snapshot (watch)))
                   (fails 0)
                   (wait 'live)
                   (uptime 0))
          (thread-sleep! poll-interval)
          (let* ((new-snap (snapshot (watch)))
                 (alive (process-alive? proc)))
            (cond
              ;; A file changed: always restart immediately, clearing backoff.
              ((changed? snap new-snap)
               (let* ((settled (settle new-snap))
                      (changes (changed-paths snap settled)))
                 (log (string-append "change detected ("
                                     (number->string (length changes))
                                     "): "
                                     (join-with ", "
                                       (map (lambda (p) (relative-to root p))
                                            changes))))
                 (when alive (stop-child proc))
                 (log (if alive "restarting child" "child not running; starting"))
                 (loop (start-child) settled 0 'live 0)))
              ;; Child believed running.
              ((eq? wait 'live)
               (cond
                 (alive
                  ;; Stable for healthy-ticks ⇒ forgive earlier crashes.
                  (let ((up (+ uptime 1)))
                    (loop proc snap (if (>= up healthy-ticks) 0 fails) 'live up)))
                 (else
                  ;; Crashed on its own; reap it and schedule a backoff retry.
                  (process-wait proc)
                  (let* ((nfails (+ fails 1))
                         (ticks (backoff-ticks nfails)))
                    (log (string-append "child exited; retry "
                                        (number->string nfails)
                                        " in "
                                        (number->string (* ticks poll-interval))
                                        "s"))
                    (loop proc new-snap nfails ticks 0)))))
              ;; Child dead, counting down to the next retry.
              ((<= wait 1)
               (log "retrying child")
               (loop (start-child) new-snap fails 'live 0))
              (else
               (loop proc new-snap fails (- wait 1) 0)))))))))
