(define-library (scm net-remote)
  (import (scm core)
          (scheme base)
          (scheme file)
          (scheme write)
          (scm fs)
          (scm system)
          (scm net http client)
          (scm net http request)
          (scm net http response)
          (srfi 1))
  (export curl
          rsync
          scp
          ssh
          wget)
  (begin

    (define (%has-flag? opts sym)
      (let loop ((o opts))
        (cond ((null? o) #f)
              ((eq? (car o) sym) #t)
              (else (loop (cdr o))))))

    (define (%opt-value opts sym default)
      (let loop ((o opts))
        (cond ((null? o) default)
              ((and (pair? (car o)) (eq? (car (car o)) sym)) (cdr (car o)))
              (else (loop (cdr o))))))

    (define (%require-native name)
      (let ((p (which name)))
        (or p (error (string-append name ": native command not found on PATH")))))

    (define (%strip-newline s)
      (let ((n (string-length s)))
        (if (and (> n 0) (char=? (string-ref s (- n 1)) #\newline))
            (substring s 0 (- n 1))
            s)))

    (define (ssh host command . opts)
      "Syntax: (ssh host command [option ...])
Library: (scm net-remote)
Description: Runs command (a string) on the remote host via the native
  ssh command and returns (exit-code stdout stderr). host can be
  \"hostname\" or \"user@hostname\". Options:
    '(user . str)   — overrides user (alternative to user@host form)
    '(port . int)   — SSH port (default 22)
    '(key . path)   — identity file (-i)
    '(stdin . str)  — fed to remote command's stdin
    '(extra-args . list) — additional raw flags appended before host
Example:
  (ssh \"deploy@web1\" \"systemctl status nginx\" '(port . 2222))"
      (let* ((native (%require-native "ssh"))
             (user (%opt-value opts 'user #f))
             (port (%opt-value opts 'port #f))
             (key  (%opt-value opts 'key  #f))
             (stdin (%opt-value opts 'stdin #f))
             (extra (%opt-value opts 'extra-args '()))
             (target (if user (string-append user "@" host) host))
             (args (append
                     (list native)
                     (if port (list "-p" (number->string port)) '())
                     (if key (list "-i" key) '())
                     extra
                     (list target command)))
             (run-opts (if stdin (list (list 'stdin stdin)) '())))
        (run-program/capture args run-opts)))

    (define (scp src dst . opts)
      "Syntax: (scp src dst [option ...])
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
  (scp \"build.tar.gz\" \"deploy@web1:/srv/releases/\" '(port . 2222))"
      (let* ((native (%require-native "scp"))
             (port (%opt-value opts 'port #f))
             (key  (%opt-value opts 'key  #f))
             (args (append
                     (list native)
                     (if (%has-flag? opts 'recursive) (list "-r") '())
                     (if (%has-flag? opts 'preserve)  (list "-p") '())
                     (if (%has-flag? opts 'quiet)     (list "-q") '())
                     (if port (list "-P" (number->string port)) '())
                     (if key  (list "-i" key) '())
                     (list src dst))))
        (zero? (run-program args))))

    (define (rsync src dst . opts)
      "Syntax: (rsync src dst [option ...])
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
    '(rsh . cmd)     — remote-shell command, e.g. \"ssh -p 2222\"
Example:
  (rsync \"build/\" \"deploy@web1:/srv/app/\" 'archive 'delete 'verbose)"
      (let* ((native (%require-native "rsync"))
             (excludes (%opt-value opts 'exclude '()))
             (rsh      (%opt-value opts 'rsh #f))
             (args (append
                     (list native)
                     (if (%has-flag? opts 'archive)    (list "-a") '())
                     (if (%has-flag? opts 'recursive) (list "-r") '())
                     (if (%has-flag? opts 'verbose)   (list "-v") '())
                     (if (%has-flag? opts 'dry-run)   (list "-n") '())
                     (if (%has-flag? opts 'compress)  (list "-z") '())
                     (if (%has-flag? opts 'delete)    (list "--delete") '())
                     (if rsh (list "-e" rsh) '())
                     (append-map (lambda (p) (list "--exclude" p)) excludes)
                     (list src dst))))
        (zero? (run-program args))))

    (define (curl url . opts)
      "Syntax: (curl url [option ...])
Library: (scm net-remote)
Description: Performs an HTTP(S) request via the native curl command.
  By default returns the response body as a string. Options:
    '(method . str)        — HTTP method (default GET)
    '(headers . list)      — list of header strings \"Name: value\"
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
  (curl \"https://example.com/api\"
        '(method . \"POST\")
        '(headers . (\"Content-Type: application/json\"))
        '(data . \"{\\\"x\\\":1}\")
        'silent)"
      (let* ((pure? (%has-flag? opts 'pure))
             (native (and (not pure?) (which "curl"))))
        (if native
            (curl/native native url opts)
            (curl/scheme url opts))))

    (define (curl/native native url opts)
      (let* ((method  (%opt-value opts 'method  #f))
             (headers (%opt-value opts 'headers '()))
             (data    (%opt-value opts 'data    #f))
             (output  (%opt-value opts 'output  #f))
             (timeout (%opt-value opts 'timeout #f))
             (include-status? (%has-flag? opts 'include-status))
             (args (append
                     (list native)
                     (if (%has-flag? opts 'silent)            (list "-s") '())
                     (if (%has-flag? opts 'follow-redirects)  (list "-L") '())
                     (if (%has-flag? opts 'fail-on-error)     (list "-f") '())
                     (if timeout (list "--max-time" (number->string timeout)) '())
                     (if method  (list "-X" method) '())
                     (append-map (lambda (h) (list "-H" h)) headers)
                     (if data    (list "--data-binary" data) '())
                     (if include-status?
                         (list "-w" "\n__CURL_STATUS__:%{http_code}")
                         '())
                     (if output (list "-o" output) '())
                     (list url)))
             (r (run-program/capture args)))
        (cond
          ((not (pair? r)) (if output #f ""))
          (output (zero? (car r)))
          (include-status?
           (let* ((out (cadr r))
                  (marker "\n__CURL_STATUS__:")
                  (mlen (string-length marker))
                  (n (string-length out))
                  (idx (let loop ((i 0))
                         (cond
                           ((> (+ i mlen) n) #f)
                           ((string=? (substring out i (+ i mlen)) marker) i)
                           (else (loop (+ i 1)))))))
             (if idx
                 (let* ((body (substring out 0 idx))
                        (code-str (%strip-newline
                                    (substring out (+ idx mlen) n)))
                        (code (or (string->number code-str) 0)))
                   (cons code body))
                 (cons 0 out))))
          (else (cadr r)))))

    (define (%parse-header-string s)
      ;; \"Name: value\" -> (\"Name\" . \"value\")
      (let* ((n (string-length s))
             (idx (let loop ((i 0))
                    (cond
                      ((>= i n) #f)
                      ((char=? (string-ref s i) #\:) i)
                      (else (loop (+ i 1)))))))
        (if idx
            (let* ((name (substring s 0 idx))
                   (rest (substring s (+ idx 1) n))
                   ;; trim leading spaces of value
                   (rn (string-length rest))
                   (v-start (let loop ((i 0))
                              (cond
                                ((>= i rn) rn)
                                ((char=? (string-ref rest i) #\space)
                                 (loop (+ i 1)))
                                (else i)))))
              (cons name (substring rest v-start rn)))
            (cons s ""))))

    (define (curl/scheme url opts)
      (let* ((method  (%opt-value opts 'method  (if (%opt-value opts 'data #f) "POST" "GET")))
             (headers (map %parse-header-string (%opt-value opts 'headers '())))
             (data    (%opt-value opts 'data    #f))
             (output  (%opt-value opts 'output  #f))
             (include-status? (%has-flag? opts 'include-status))
             (req (make-http-request method url headers (or data "")))
             (resp (http-send req))
             (status (http-response-status resp))
             (body (http-response-body resp))
             (body-str (cond ((string? body) body)
                             ((bytevector? body) (utf8->string body))
                             (else ""))))
        (cond
          (output
           (call-with-port (open-output-file output)
             (lambda (p) (write-string body-str p)))
           (and (>= status 200) (< status 400)))
          (include-status? (cons status body-str))
          (else body-str))))

    (define (wget url . opts)
      "Syntax: (wget url [option ...])
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
  (wget \"https://example.com/file.tar.gz\" '(output . \"/tmp/x.tgz\"))"
      (let* ((pure? (%has-flag? opts 'pure))
             (native (and (not pure?) (which "wget")))
             (output (%opt-value opts 'output #f))
             (timeout (%opt-value opts 'timeout #f)))
        (if (not native)
            (and (curl/scheme url (if output (list (cons 'output output)) '())) #t)
            (wget/native native url opts output timeout))))

    (define (wget/native native url opts output timeout)
      (let* ((dummy #f)
             (args (append
                     (list native)
                     (if (%has-flag? opts 'quiet)         (list "-q") '())
                     (if (%has-flag? opts 'continue)      (list "-c") '())
                     (if (%has-flag? opts 'no-check-cert) (list "--no-check-certificate") '())
                     (if timeout (list "--timeout" (number->string timeout)) '())
                     (if output  (list "-O" output) '())
                     (list url))))
        (zero? (run-program args))))))
