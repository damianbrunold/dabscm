---
title: (scm terminal) and (scm log): terminal output and logging
part: libraries
order: 1008
libraries: (scm terminal) (scm log)
summary: Colors and styles, display width of text, cursor movement and screen control, raw keyboard input, passwords without echo; structured log lines with levels and categories.
---
# (scm terminal) and (scm log): terminal output and logging

```scheme
(import (scheme base) (scheme write) (only (srfi 13) string-contains)
        (scm terminal) (scm log))
```

## Colors and styles

The `sgr-` procedures return ANSI escape sequences; put them around text
and reset afterwards:

```scheme
(define (red s) (string-append (sgr-fg 'red) s (sgr-reset)))
(red "error")                               ;; => "\x1b;[31merror\x1b;[0m"
(string-append (sgr-bold) "bold" (sgr-reset)) ;; => "\x1b;[1mbold\x1b;[0m"
(string? (sgr-fg 255 128 0))                ;; => #t
(string? (sgr-bg 'blue))                    ;; => #t
```

Colors are names (`'red`, `'green`, `'yellow`, `'blue`, `'magenta`,
`'cyan`, `'white`, `'black`) or 24-bit RGB values. Styles: bold, dim,
italic, underline, blink, reverse, hidden, strikethrough.

Escape sequences belong in a terminal, not in files or pipes. `terminal?`
tells whether the output is one:

```scheme
(boolean? (terminal?))                      ;; => #t
```

## Display width

Some characters take two columns in a terminal (Chinese, Japanese, many
emoji), others none. Aligning text needs the *display width*, not the
length:

```scheme
(string-width "abc")                        ;; => 3
(string-width "日本")                       ;; => 4
(char-width #\a)                            ;; => 1

(define (pad-to s width)
  (string-append s (make-string (max 0 (- width (string-width s))) #\space)))
(pad-to "日本" 6)                           ;; => "日本  "
```

## Cursor and screen

These write their escape sequence directly to the output:

```scheme no-test
(clear-screen)
(cursor-position 1 1)          ; row, column, 1-based
(cursor-hide)
(display "working...")
(clear-line)
(cursor-show)
(with-alternate-screen (lambda () (run-full-screen-ui)))   ; like less and vim
```

`terminal-size` returns the columns and rows of the window.

## Keys and passwords

```scheme no-test
(with-terminal-raw
  (lambda ()
    (let loop ()
      (let ((k (terminal-read-key)))       ; 'up, 'down, #\q, ...
        (unless (eqv? k #\q) (handle k) (loop))))))

(define pw (read-password "Password: "))  ; no echo
```

Raw mode delivers each key as it is pressed, without waiting for Enter;
`with-terminal-raw` restores the normal mode afterwards, also after an
error.

## Logging

`(scm log)` writes one line per event: time, level, category and message.
It goes to `log-port`, the standard error port by default, so logs do not
mix with a program's output:

```scheme no-test
(log-info "import" "read 1200 rows")
(log-warn "import" "3 rows without a date")
(log-error "db" "connection refused")
(log-access ...)                      ; web-server access lines
```

```text
2025-11-27 14:03:12 INFO  [import] read 1200 rows
```

Redirect it with `parameterize`, for example into a file or, in tests, a
string:

```scheme
(define captured
  (let ((p (open-output-string)))
    (parameterize ((log-port p))
      (log-warn "disk" "almost full"))
    (get-output-string p)))

(and (string-contains captured "almost full") #t) ;; => #t
(and (string-contains captured "disk") #t)        ;; => #t
```

## Where next

- [Command-line programs](techniques-09-command-line.md), [`(scm args)`](scm-args.md).
- Reference: `(scm terminal)`, `(scm log)`.
