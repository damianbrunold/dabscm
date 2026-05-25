(define-library (scm terminal)
  (import (scheme base) (scheme write) (scheme char) (scheme cxr) (scheme time))
  (export
    ;; Primitives
    terminal?
    terminal-size
    terminal-raw!
    terminal-read-byte
    terminal-byte-ready?
    terminal-enable-ansi!
    console-echo!
    console-read-password

    ;; Raw mode convenience
    with-terminal-raw

    ;; Echo / password convenience
    with-console-echo-off
    read-password

    ;; Key reading
    terminal-read-key

    ;; Cursor control
    cursor-up
    cursor-down
    cursor-forward
    cursor-back
    cursor-position
    cursor-save
    cursor-restore
    cursor-hide
    cursor-show
    cursor-home

    ;; Screen control
    clear-screen
    clear-line
    clear-to-end-of-line
    clear-to-end-of-screen
    alternate-screen-enable
    alternate-screen-disable
    with-alternate-screen

    ;; Text attributes
    sgr-reset
    sgr-bold
    sgr-dim
    sgr-italic
    sgr-underline
    sgr-blink
    sgr-reverse
    sgr-hidden
    sgr-strikethrough
    sgr-fg
    sgr-bg)
  (begin
    ;; === Primitive bindings ===

    (define terminal?            (%primitive "terminal?"))
    (define terminal-size        (%primitive "terminal-size"))
    (define terminal-raw!        (%primitive "terminal-raw!"))
    (define terminal-read-byte   (%primitive "terminal-read-byte"))
    (define terminal-byte-ready? (%primitive "terminal-byte-ready?"))
    (define terminal-enable-ansi! (%primitive "terminal-enable-ansi!"))
    (define console-echo!         (%primitive "console-echo!"))
    (define console-read-password (%primitive "console-read-password"))

    ;; === Constants ===

    (define %esc (string (integer->char 27)))
    (define %csi (string-append %esc "["))

    ;; === Raw mode convenience ===

    (define (with-terminal-raw thunk)
      "Syntax: (with-terminal-raw thunk)
Library: (scm terminal)
Description: Calls thunk with raw terminal mode enabled. The original
terminal settings are restored when thunk returns or when an exception
is raised. Returns the value returned by thunk.
Example:
  (with-terminal-raw
    (lambda ()
      (let ((key (terminal-read-key)))
        (display key))))"
      (dynamic-wind
        (lambda () (terminal-raw! #t))
        thunk
        (lambda () (terminal-raw! #f))))

    ;; === Echo / password convenience ===

    (define (with-console-echo-off thunk)
      "Syntax: (with-console-echo-off thunk)
Library: (scm terminal)
Description: Calls thunk with terminal echo disabled. Echo is
re-enabled when thunk returns or when an exception is raised.
Returns the value returned by thunk. If echo cannot be disabled
(e.g. stdin is not a terminal, or running under Java on Windows),
thunk is still invoked but typed characters may be visible.
Example:
  (with-console-echo-off
    (lambda ()
      (display \"Password: \")
      (let ((pw (read-line)))
        (newline)
        pw)))"
      (dynamic-wind
        (lambda () (console-echo! #f))
        thunk
        (lambda () (console-echo! #t))))

    (define (read-password . args)
      "Syntax: (read-password)
Syntax: (read-password prompt)
Library: (scm terminal)
Description: Reads a password from the terminal without echoing
typed characters. If prompt is given as a string, it is displayed
before reading. Returns the entered string (without trailing
newline), or the eof-object if input is closed. Works on Linux,
macOS, and Windows for both the C# and Java implementations.
Example:
  (read-password \"Password: \")"
      (cond
        ((null? args)        (console-read-password))
        ((null? (cdr args))  (console-read-password (car args)))
        (else (error "read-password: expected 0 or 1 arguments"))))

    ;; === Cursor control ===

    (define (cursor-up n)
      "Syntax: (cursor-up n)
Library: (scm terminal)
Description: Moves the cursor up by n rows.
Example:
  (cursor-up 3)"
      (display (string-append %csi (number->string n) "A")))

    (define (cursor-down n)
      "Syntax: (cursor-down n)
Library: (scm terminal)
Description: Moves the cursor down by n rows.
Example:
  (cursor-down 3)"
      (display (string-append %csi (number->string n) "B")))

    (define (cursor-forward n)
      "Syntax: (cursor-forward n)
Library: (scm terminal)
Description: Moves the cursor forward (right) by n columns.
Example:
  (cursor-forward 5)"
      (display (string-append %csi (number->string n) "C")))

    (define (cursor-back n)
      "Syntax: (cursor-back n)
Library: (scm terminal)
Description: Moves the cursor back (left) by n columns.
Example:
  (cursor-back 5)"
      (display (string-append %csi (number->string n) "D")))

    (define (cursor-position row col)
      "Syntax: (cursor-position row col)
Library: (scm terminal)
Description: Moves the cursor to the specified row and column (1-based).
Example:
  (cursor-position 1 1)  ; move to top-left corner"
      (display (string-append %csi
                              (number->string row)
                              ";"
                              (number->string col)
                              "H")))

    (define (cursor-save)
      "Syntax: (cursor-save)
Library: (scm terminal)
Description: Saves the current cursor position. Use cursor-restore to
return to the saved position.
Example:
  (cursor-save)"
      (display (string-append %esc "7")))

    (define (cursor-restore)
      "Syntax: (cursor-restore)
Library: (scm terminal)
Description: Restores the cursor to the position saved by cursor-save.
Example:
  (cursor-restore)"
      (display (string-append %esc "8")))

    (define (cursor-hide)
      "Syntax: (cursor-hide)
Library: (scm terminal)
Description: Hides the cursor.
Example:
  (cursor-hide)"
      (display (string-append %csi "?25l")))

    (define (cursor-show)
      "Syntax: (cursor-show)
Library: (scm terminal)
Description: Shows the cursor.
Example:
  (cursor-show)"
      (display (string-append %csi "?25h")))

    (define (cursor-home)
      "Syntax: (cursor-home)
Library: (scm terminal)
Description: Moves the cursor to the top-left corner (row 1, column 1).
Example:
  (cursor-home)"
      (display (string-append %csi "H")))

    ;; === Screen control ===

    (define (clear-screen)
      "Syntax: (clear-screen)
Library: (scm terminal)
Description: Clears the entire screen and moves the cursor to the
top-left corner.
Example:
  (clear-screen)"
      (display (string-append %csi "2J"))
      (cursor-home))

    (define (clear-line)
      "Syntax: (clear-line)
Library: (scm terminal)
Description: Clears the entire current line.
Example:
  (clear-line)"
      (display (string-append %csi "2K")))

    (define (clear-to-end-of-line)
      "Syntax: (clear-to-end-of-line)
Library: (scm terminal)
Description: Clears from the cursor position to the end of the line.
Example:
  (clear-to-end-of-line)"
      (display (string-append %csi "0K")))

    (define (clear-to-end-of-screen)
      "Syntax: (clear-to-end-of-screen)
Library: (scm terminal)
Description: Clears from the cursor position to the end of the screen.
Example:
  (clear-to-end-of-screen)"
      (display (string-append %csi "0J")))

    (define (alternate-screen-enable)
      "Syntax: (alternate-screen-enable)
Library: (scm terminal)
Description: Switches to the alternate screen buffer. The original
screen content is preserved and restored when alternate-screen-disable
is called.
Example:
  (alternate-screen-enable)"
      (display (string-append %csi "?1049h")))

    (define (alternate-screen-disable)
      "Syntax: (alternate-screen-disable)
Library: (scm terminal)
Description: Switches back from the alternate screen buffer to the
normal screen, restoring the original screen content.
Example:
  (alternate-screen-disable)"
      (display (string-append %csi "?1049l")))

    (define (with-alternate-screen thunk)
      "Syntax: (with-alternate-screen thunk)
Library: (scm terminal)
Description: Calls thunk with the alternate screen buffer enabled.
The original screen is restored when thunk returns or when an exception
is raised.
Example:
  (with-alternate-screen
    (lambda ()
      (clear-screen)
      (cursor-position 1 1)
      (display \"Hello from alternate screen!\")))"
      (dynamic-wind
        (lambda () (alternate-screen-enable))
        thunk
        (lambda () (alternate-screen-disable))))

    ;; === Text attributes (SGR — Select Graphic Rendition) ===
    ;; These return strings so they can be composed and stored.

    (define (sgr-reset)
      "Syntax: (sgr-reset)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string that resets all
text attributes to their defaults.
Example:
  (display (sgr-reset))"
      (string-append %csi "0m"))

    (define (sgr-bold)
      "Syntax: (sgr-bold)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for bold text.
Example:
  (display (string-append (sgr-bold) \"hello\" (sgr-reset)))"
      (string-append %csi "1m"))

    (define (sgr-dim)
      "Syntax: (sgr-dim)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for dim text.
Example:
  (display (string-append (sgr-dim) \"hello\" (sgr-reset)))"
      (string-append %csi "2m"))

    (define (sgr-italic)
      "Syntax: (sgr-italic)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for italic text.
Example:
  (display (string-append (sgr-italic) \"hello\" (sgr-reset)))"
      (string-append %csi "3m"))

    (define (sgr-underline)
      "Syntax: (sgr-underline)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for underlined text.
Example:
  (display (string-append (sgr-underline) \"hello\" (sgr-reset)))"
      (string-append %csi "4m"))

    (define (sgr-blink)
      "Syntax: (sgr-blink)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for blinking text.
Example:
  (display (string-append (sgr-blink) \"hello\" (sgr-reset)))"
      (string-append %csi "5m"))

    (define (sgr-reverse)
      "Syntax: (sgr-reverse)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for reverse video.
Example:
  (display (string-append (sgr-reverse) \"hello\" (sgr-reset)))"
      (string-append %csi "7m"))

    (define (sgr-hidden)
      "Syntax: (sgr-hidden)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for hidden text.
Example:
  (display (string-append (sgr-hidden) \"secret\" (sgr-reset)))"
      (string-append %csi "8m"))

    (define (sgr-strikethrough)
      "Syntax: (sgr-strikethrough)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for strikethrough text.
Example:
  (display (string-append (sgr-strikethrough) \"hello\" (sgr-reset)))"
      (string-append %csi "9m"))

    (define (%color-name->code name offset)
      (case name
        ((black)   (+ offset 0))
        ((red)     (+ offset 1))
        ((green)   (+ offset 2))
        ((yellow)  (+ offset 3))
        ((blue)    (+ offset 4))
        ((magenta) (+ offset 5))
        ((cyan)    (+ offset 6))
        ((white)   (+ offset 7))
        ((default) (+ offset 9))
        ((bright-black)   (+ offset 60))
        ((bright-red)     (+ offset 61))
        ((bright-green)   (+ offset 62))
        ((bright-yellow)  (+ offset 63))
        ((bright-blue)    (+ offset 64))
        ((bright-magenta) (+ offset 65))
        ((bright-cyan)    (+ offset 66))
        ((bright-white)   (+ offset 67))
        (else #f)))

    (define (sgr-fg . args)
      "Syntax: (sgr-fg color-name)
Syntax: (sgr-fg color-index)
Syntax: (sgr-fg r g b)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for setting the
foreground color. Accepts a named color symbol (black, red, green,
yellow, blue, magenta, cyan, white, default, bright-black, bright-red,
bright-green, bright-yellow, bright-blue, bright-magenta, bright-cyan,
bright-white), a 256-color index (0-255), or three integers for 24-bit
RGB color.
Example:
  (display (string-append (sgr-fg 'red) \"error\" (sgr-reset)))
  (display (string-append (sgr-fg 196) \"red\" (sgr-reset)))
  (display (string-append (sgr-fg 255 128 0) \"orange\" (sgr-reset)))"
      (cond
        ((= (length args) 1)
         (let ((arg (car args)))
           (cond
             ((symbol? arg)
              (let ((code (%color-name->code arg 30)))
                (if code
                    (string-append %csi (number->string code) "m")
                    (error "sgr-fg: unknown color name" arg))))
             ((integer? arg)
              (string-append %csi "38;5;" (number->string arg) "m"))
             (else (error "sgr-fg: expected symbol or integer" arg)))))
        ((= (length args) 3)
         (string-append %csi "38;2;"
                        (number->string (car args)) ";"
                        (number->string (cadr args)) ";"
                        (number->string (caddr args)) "m"))
        (else (error "sgr-fg: expected 1 or 3 arguments"))))

    (define (sgr-bg . args)
      "Syntax: (sgr-bg color-name)
Syntax: (sgr-bg color-index)
Syntax: (sgr-bg r g b)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for setting the
background color. Accepts the same arguments as sgr-fg: a named color
symbol, a 256-color index (0-255), or three integers for 24-bit RGB.
Example:
  (display (string-append (sgr-bg 'blue) \"info\" (sgr-reset)))
  (display (string-append (sgr-bg 21) \"blue\" (sgr-reset)))
  (display (string-append (sgr-bg 0 0 128) \"navy\" (sgr-reset)))"
      (cond
        ((= (length args) 1)
         (let ((arg (car args)))
           (cond
             ((symbol? arg)
              (let ((code (%color-name->code arg 40)))
                (if code
                    (string-append %csi (number->string code) "m")
                    (error "sgr-bg: unknown color name" arg))))
             ((integer? arg)
              (string-append %csi "48;5;" (number->string arg) "m"))
             (else (error "sgr-bg: expected symbol or integer" arg)))))
        ((= (length args) 3)
         (string-append %csi "48;2;"
                        (number->string (car args)) ";"
                        (number->string (cadr args)) ";"
                        (number->string (caddr args)) "m"))
        (else (error "sgr-bg: expected 1 or 3 arguments"))))

    ;; === Key reading ===

    (define (%wait-for-byte timeout-us)
      ;; Wait up to timeout-us microseconds for a byte to become available.
      ;; Returns #t if a byte is ready, #f if timeout expired.
      (let ((deadline (+ (current-jiffy) timeout-us)))
        (let loop ()
          (cond
            ((terminal-byte-ready?) #t)
            ((>= (current-jiffy) deadline) #f)
            (else (loop))))))

    (define (%read-csi-sequence)
      ;; Read a CSI sequence after ESC [ has been consumed.
      ;; Returns the parameter bytes and the final byte.
      (let loop ((params '()))
        (if (not (%wait-for-byte 100000))
            ;; Timeout — return what we have
            (list (list->string (reverse params)) #f)
            (let ((b (terminal-read-byte)))
              (if (eof-object? b)
                  (list (list->string (reverse params)) #f)
                  (let ((ch (integer->char b)))
                    (if (and (>= b 64) (<= b 126))
                        ;; Final byte
                        (list (list->string (reverse params)) ch)
                        ;; Parameter or intermediate byte
                        (loop (cons ch params)))))))))

    (define (%decode-modifier mod-num)
      ;; Decode xterm modifier number: subtract 1, then
      ;; bit 0 = shift, bit 1 = alt, bit 2 = ctrl
      (let ((m (- mod-num 1)))
        (let ((shift (> (bitwise-and m 1) 0))
              (alt   (> (bitwise-and m 2) 0))
              (ctrl  (> (bitwise-and m 4) 0)))
          (list shift alt ctrl))))

    (define (%modifier-prefix shift alt ctrl)
      ;; Build a modifier prefix string like "ctrl-alt-shift-"
      (string-append
        (if ctrl  "ctrl-"  "")
        (if alt   "alt-"   "")
        (if shift "shift-" "")))

    (define (%make-modified-key base-name mod-num)
      ;; Create a modified key symbol from base name and modifier number.
      (if (or (not mod-num) (= mod-num 1))
          (string->symbol base-name)
          (let ((mods (%decode-modifier mod-num)))
            (string->symbol
              (string-append
                (%modifier-prefix (car mods) (cadr mods) (caddr mods))
                base-name)))))

    (define (%parse-csi-params param-str)
      ;; Parse CSI parameters like "1;5" into a list of integers.
      ;; Empty string gives empty list.
      (if (or (not param-str) (string=? param-str ""))
          '()
          (let loop ((s param-str) (current '()) (result '()))
            (if (string=? s "")
                (reverse (cons (if (null? current)
                                   0
                                   (string->number (list->string (reverse current))))
                               result))
                (let ((ch (string-ref s 0))
                      (rest (substring s 1 (string-length s))))
                  (if (char=? ch #\;)
                      (loop rest
                            '()
                            (cons (if (null? current)
                                      0
                                      (string->number (list->string (reverse current))))
                                  result))
                      (loop rest (cons ch current) result)))))))

    (define (%decode-csi-key param-str final-byte)
      ;; Decode a CSI sequence into a key symbol.
      (if (not final-byte)
          'escape  ;; Incomplete sequence
          (let ((params (%parse-csi-params param-str)))
            (case final-byte
              ;; Arrow keys
              ((#\A) (%make-modified-key "up"    (and (>= (length params) 2) (cadr params))))
              ((#\B) (%make-modified-key "down"  (and (>= (length params) 2) (cadr params))))
              ((#\C) (%make-modified-key "right" (and (>= (length params) 2) (cadr params))))
              ((#\D) (%make-modified-key "left"  (and (>= (length params) 2) (cadr params))))
              ((#\H) (%make-modified-key "home"  (and (>= (length params) 2) (cadr params))))
              ((#\F) (%make-modified-key "end"   (and (>= (length params) 2) (cadr params))))
              ;; Tilde sequences
              ((#\~)
               (let ((code (if (null? params) 0 (car params)))
                     (mod  (if (>= (length params) 2) (cadr params) #f)))
                 (case code
                   ((1)  (%make-modified-key "home"      mod))
                   ((2)  (%make-modified-key "insert"    mod))
                   ((3)  (%make-modified-key "delete"    mod))
                   ((4)  (%make-modified-key "end"       mod))
                   ((5)  (%make-modified-key "page-up"   mod))
                   ((6)  (%make-modified-key "page-down" mod))
                   ((11) (%make-modified-key "f1"        mod))
                   ((12) (%make-modified-key "f2"        mod))
                   ((13) (%make-modified-key "f3"        mod))
                   ((14) (%make-modified-key "f4"        mod))
                   ((15) (%make-modified-key "f5"        mod))
                   ((17) (%make-modified-key "f6"        mod))
                   ((18) (%make-modified-key "f7"        mod))
                   ((19) (%make-modified-key "f8"        mod))
                   ((20) (%make-modified-key "f9"        mod))
                   ((21) (%make-modified-key "f10"       mod))
                   ((23) (%make-modified-key "f11"       mod))
                   ((24) (%make-modified-key "f12"       mod))
                   (else 'unknown))))
              ;; Bracketed paste
              ((#\Z) 'shift-tab)
              (else 'unknown)))))

    (define (%decode-ss3-key byte)
      ;; Decode an SS3 sequence (ESC O ...) into a key symbol.
      (case (integer->char byte)
        ((#\P) 'f1)
        ((#\Q) 'f2)
        ((#\R) 'f3)
        ((#\S) 'f4)
        ((#\H) 'home)
        ((#\F) 'end)
        (else  'unknown)))

    (define (%read-utf8-char first-byte)
      ;; Decode a UTF-8 character from the first byte and continuation bytes.
      (define (read-continuation)
        (if (%wait-for-byte 10000)
            (let ((b (terminal-read-byte)))
              (if (eof-object? b) 0
                  (bitwise-and b #x3F)))
            0))
      (cond
        ((< first-byte #xC0) (integer->char first-byte))  ;; Should not happen
        ((< first-byte #xE0)
         ;; 2-byte sequence
         (let ((b1 (bitwise-and first-byte #x1F))
               (b2 (read-continuation)))
           (integer->char (+ (* b1 64) b2))))
        ((< first-byte #xF0)
         ;; 3-byte sequence
         (let ((b1 (bitwise-and first-byte #x0F))
               (b2 (read-continuation))
               (b3 (read-continuation)))
           (integer->char (+ (* b1 4096) (* b2 64) b3))))
        (else
         ;; 4-byte sequence
         (let ((b1 (bitwise-and first-byte #x07))
               (b2 (read-continuation))
               (b3 (read-continuation))
               (b4 (read-continuation)))
           (integer->char (+ (* b1 262144) (* b2 4096) (* b3 64) b4))))))

    (define (terminal-read-key)
      "Syntax: (terminal-read-key)
Library: (scm terminal)
Description: Reads a single keypress from the terminal in raw mode.
Returns a character for printable keys, or a symbol for special keys.

Special key symbols: up, down, left, right, home, end, page-up,
page-down, insert, delete, f1 through f12, escape, enter, tab,
backspace, shift-tab.

Modifier prefixes: ctrl-, alt-, shift- (e.g. ctrl-a, alt-x, shift-up,
ctrl-alt-delete).

Must be called while raw mode is active (see terminal-raw! or
with-terminal-raw).
Example:
  (with-terminal-raw
    (lambda ()
      (let loop ()
        (let ((key (terminal-read-key)))
          (cond
            ((eq? key 'ctrl-q) (display \"Bye!\"))
            ((char? key) (display key) (loop))
            (else (display key) (display \" \") (loop)))))))"
      (let ((b (terminal-read-byte)))
        (cond
          ((eof-object? b) b)

          ;; ESC
          ((= b 27)
           (if (not (%wait-for-byte 50000))
               'escape
               (let ((b2 (terminal-read-byte)))
                 (cond
                   ((eof-object? b2) 'escape)
                   ;; CSI sequence: ESC [
                   ((= b2 91)  ;; [
                    (let ((seq (%read-csi-sequence)))
                      (%decode-csi-key (car seq) (cadr seq))))
                   ;; SS3 sequence: ESC O
                   ((= b2 79)  ;; O
                    (if (%wait-for-byte 50000)
                        (let ((b3 (terminal-read-byte)))
                          (if (eof-object? b3) 'escape
                              (%decode-ss3-key b3)))
                        'escape))
                   ;; Alt+key
                   ((and (>= b2 32) (<= b2 126))
                    (string->symbol
                      (string-append "alt-" (string (integer->char b2)))))
                   ;; Alt+ctrl-key
                   ((and (>= b2 1) (<= b2 26))
                    (string->symbol
                      (string-append "alt-ctrl-"
                                     (string (integer->char (+ b2 96))))))
                   (else 'escape)))))

          ;; Ctrl+letter (1-26, except 9=tab, 10=newline, 13=return)
          ((= b 9) 'tab)
          ((= b 10) 'enter)
          ((= b 13) 'enter)
          ((and (>= b 1) (<= b 26))
           (string->symbol
             (string-append "ctrl-" (string (integer->char (+ b 96))))))

          ;; Backspace
          ((= b 127) 'backspace)

          ;; Printable ASCII
          ((and (>= b 32) (<= b 126))
           (integer->char b))

          ;; UTF-8 multi-byte
          ((>= b 128)
           (%read-utf8-char b))

          ;; Other control characters
          (else b))))))
