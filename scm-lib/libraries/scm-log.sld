(define-library (scm log)
  (import (scm core) (scheme base) (scheme write) (srfi 19))
  (export log-info
          log-warn
          log-error
          log-access
          log-port)
  (begin

    ;; ============================================================
    ;; Structured single-line logging.
    ;;
    ;; Format:
    ;;   YYYY-MM-DD HH:MM:SS LEVEL [module] message
    ;;
    ;; Output goes to the port returned by (log-port), which is a
    ;; SRFI-39-style parameter defaulting to (current-error-port).
    ;; This makes the log lib trivial to redirect in tests or
    ;; reconfigure for stdout/file sinks without changing call sites.
    ;; ============================================================

    (define log-port
      (make-parameter (current-error-port)))

    (define (pad2 n)
      (let ((s (number->string n)))
        (cond ((< n 10) (string-append "0" s)) (else s))))

    (define (timestamp)
      (let ((d (current-date)))
        (string-append
          (number->string (date-year d)) "-"
          (pad2 (date-month d)) "-"
          (pad2 (date-day d)) " "
          (pad2 (date-hour d)) ":"
          (pad2 (date-minute d)) ":"
          (pad2 (date-second d)))))

    (define (emit level module msg)
      (let ((out (log-port)))
        (write-string (timestamp) out)
        (write-string " " out)
        (write-string level out)
        (write-string " [" out)
        (write-string module out)
        (write-string "] " out)
        (write-string msg out)
        (newline out)))

    (define (log-info module msg)
      "Syntax: (log-info module msg)
Library: (scm log)
Description: Writes a single INFO-level log line tagged with module to
  (log-port). module and msg are strings.
Example:
  (log-info \"auth\" \"login ok for user 42\")"
      (emit "INFO " module msg))

    (define (log-warn module msg)
      "Syntax: (log-warn module msg)
Library: (scm log)
Description: Writes a single WARN-level log line tagged with module.
Example:
  (log-warn \"feeds\" \"fetch timed out, will retry\")"
      (emit "WARN " module msg))

    (define (log-error module msg)
      "Syntax: (log-error module msg)
Library: (scm log)
Description: Writes a single ERROR-level log line tagged with module.
Example:
  (log-error \"db\" \"connection refused\")"
      (emit "ERROR" module msg))

    (define (log-access method url status duration-ms)
      "Syntax: (log-access method url status duration-ms)
Library: (scm log)
Description: Writes a single access log line: an INFO line in the http
  module of the form 'METHOD URL -> STATUS (Nms)'. status and duration-ms
  are integers.
Example:
  (log-access \"GET\" \"/notes/42\" 200 14)"
      (emit "INFO " "http"
            (string-append method " " url
                           " -> " (number->string status)
                           " (" (number->string duration-ms) "ms)")))
))
