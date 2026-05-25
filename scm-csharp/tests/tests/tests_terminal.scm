(import (scheme base)
        (scheme write)
        (scm test)
        (scm io)
        (scm core) ;; TODO required?!
        (scm terminal))

(test-runner-factory scm-test-runner)

;; Helper to capture output from procedures that use (display ...)
;; by temporarily redirecting *output-port*
(define (capture-output thunk)
  (let ((p (open-output-string))
        (old (current-output-port)))
    (dynamic-wind
      (lambda () (set-current-output-port p))
      (lambda () (thunk) (get-output-string p))
      (lambda () (set-current-output-port old)))))

(test-begin "terminal")

;; === terminal? ===

(test-group "terminal?"
  ;; When running under test harness (piped), terminal? should return #f
  (test-equal #t (boolean? (terminal?))))

;; === terminal-size ===

(test-group "terminal-size"
  ;; When piped, terminal-size returns #f; when interactive, returns a pair
  (define sz (terminal-size))
  (define sz-valid (if (eq? sz #f) #t (pair? sz)))
  (test-equal #t sz-valid))

;; === SGR attribute strings ===

(test-group "SGR attributes"
  (test-equal "\x1b;[0m" (sgr-reset))
  (test-equal "\x1b;[1m" (sgr-bold))
  (test-equal "\x1b;[2m" (sgr-dim))
  (test-equal "\x1b;[3m" (sgr-italic))
  (test-equal "\x1b;[4m" (sgr-underline))
  (test-equal "\x1b;[5m" (sgr-blink))
  (test-equal "\x1b;[7m" (sgr-reverse))
  (test-equal "\x1b;[8m" (sgr-hidden))
  (test-equal "\x1b;[9m" (sgr-strikethrough)))

;; === SGR foreground colors ===

(test-group "SGR foreground colors"
  ;; Named colors
  (test-equal "\x1b;[30m" (sgr-fg 'black))
  (test-equal "\x1b;[31m" (sgr-fg 'red))
  (test-equal "\x1b;[32m" (sgr-fg 'green))
  (test-equal "\x1b;[33m" (sgr-fg 'yellow))
  (test-equal "\x1b;[34m" (sgr-fg 'blue))
  (test-equal "\x1b;[35m" (sgr-fg 'magenta))
  (test-equal "\x1b;[36m" (sgr-fg 'cyan))
  (test-equal "\x1b;[37m" (sgr-fg 'white))
  (test-equal "\x1b;[39m" (sgr-fg 'default))
  ;; Bright colors
  (test-equal "\x1b;[91m" (sgr-fg 'bright-red))
  (test-equal "\x1b;[97m" (sgr-fg 'bright-white))
  ;; 256-color
  (test-equal "\x1b;[38;5;196m" (sgr-fg 196))
  ;; 24-bit RGB
  (test-equal "\x1b;[38;2;255;128;0m" (sgr-fg 255 128 0)))

;; === SGR background colors ===

(test-group "SGR background colors"
  (test-equal "\x1b;[41m" (sgr-bg 'red))
  (test-equal "\x1b;[44m" (sgr-bg 'blue))
  (test-equal "\x1b;[48;5;21m" (sgr-bg 21))
  (test-equal "\x1b;[48;2;0;0;128m" (sgr-bg 0 0 128)))

;; === Cursor control output ===

(test-group "cursor control"
  (test-equal "\x1b;[3A" (capture-output (lambda () (cursor-up 3))))
  (test-equal "\x1b;[2B" (capture-output (lambda () (cursor-down 2))))
  (test-equal "\x1b;[5C" (capture-output (lambda () (cursor-forward 5))))
  (test-equal "\x1b;[1D" (capture-output (lambda () (cursor-back 1))))
  (test-equal "\x1b;[10;20H" (capture-output (lambda () (cursor-position 10 20))))
  (test-equal "\x1b;7" (capture-output (lambda () (cursor-save))))
  (test-equal "\x1b;8" (capture-output (lambda () (cursor-restore))))
  (test-equal "\x1b;[?25l" (capture-output (lambda () (cursor-hide))))
  (test-equal "\x1b;[?25h" (capture-output (lambda () (cursor-show))))
  (test-equal "\x1b;[H" (capture-output (lambda () (cursor-home)))))

;; === Screen control output ===

(test-group "screen control"
  (test-equal "\x1b;[2J\x1b;[H"
      (capture-output (lambda () (clear-screen))))
  (test-equal "\x1b;[2K"
      (capture-output (lambda () (clear-line))))
  (test-equal "\x1b;[0K"
      (capture-output (lambda () (clear-to-end-of-line))))
  (test-equal "\x1b;[0J"
      (capture-output (lambda () (clear-to-end-of-screen))))
  (test-equal "\x1b;[?1049h"
      (capture-output (lambda () (alternate-screen-enable))))
  (test-equal "\x1b;[?1049l"
      (capture-output (lambda () (alternate-screen-disable)))))

;; === terminal-enable-ansi! ===

(test-group "terminal-enable-ansi!"
  ;; Should always succeed (no-op on Linux)
  (test-equal #t (terminal-enable-ansi!)))

;; === console-echo! ===

(test-group "console-echo!"
  ;; When piped (no terminal), console-echo! should return #f
  ;; rather than throw.
  (test-equal #t (boolean? (console-echo! #f)))
  (test-equal #t (boolean? (console-echo! #t))))

(test-end "terminal")
