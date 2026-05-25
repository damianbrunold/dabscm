# `(scm terminal)`

Terminal control — colors, cursor, raw mode

## Exports

### `alternate-screen-disable`

```
Syntax: (alternate-screen-disable)
Library: (scm terminal)
Description: Switches back from the alternate screen buffer to the
normal screen, restoring the original screen content.
Example:
  (alternate-screen-disable)
```

### `alternate-screen-enable`

```
Syntax: (alternate-screen-enable)
Library: (scm terminal)
Description: Switches to the alternate screen buffer. The original
screen content is preserved and restored when alternate-screen-disable
is called.
Example:
  (alternate-screen-enable)
```

### `clear-line`

```
Syntax: (clear-line)
Library: (scm terminal)
Description: Clears the entire current line.
Example:
  (clear-line)
```

### `clear-screen`

```
Syntax: (clear-screen)
Library: (scm terminal)
Description: Clears the entire screen and moves the cursor to the
top-left corner.
Example:
  (clear-screen)
```

### `clear-to-end-of-line`

```
Syntax: (clear-to-end-of-line)
Library: (scm terminal)
Description: Clears from the cursor position to the end of the line.
Example:
  (clear-to-end-of-line)
```

### `clear-to-end-of-screen`

```
Syntax: (clear-to-end-of-screen)
Library: (scm terminal)
Description: Clears from the cursor position to the end of the screen.
Example:
  (clear-to-end-of-screen)
```

### `console-echo!`

```
Syntax: (console-echo! enable)
Library: (scm terminal)
Description: Enables or disables echoing of typed characters
on the terminal. Unlike terminal-raw!, line buffering and
signal processing are left untouched, so the user can still
edit the line and press enter before it is delivered. The
primary use is reading a password.
Returns #t on success, #f if not supported (e.g. when stdin
is not a terminal). On the Java implementation under
Windows, console-echo! returns #f because stty is not
available there — use console-read-password instead.
A shutdown hook restores echo on exit.
Example:
  (console-echo! #f)  ; disable echo
  (read-line)         ; read password silently
  (console-echo! #t)  ; re-enable echo
```

### `console-read-password`

```
Syntax: (console-read-password)
Syntax: (console-read-password prompt)
Library: (scm terminal)
Description: Reads a line from the terminal without echoing
the typed characters. If prompt is given, it is displayed
before reading. Returns the entered string (without the
trailing newline), or the eof-object if input is closed.
When stdin is redirected, this falls back to read-line
behaviour on the underlying stream.
Example:
  (console-read-password "Password: ")
```

### `cursor-back`

```
Syntax: (cursor-back n)
Library: (scm terminal)
Description: Moves the cursor back (left) by n columns.
Example:
  (cursor-back 5)
```

### `cursor-down`

```
Syntax: (cursor-down n)
Library: (scm terminal)
Description: Moves the cursor down by n rows.
Example:
  (cursor-down 3)
```

### `cursor-forward`

```
Syntax: (cursor-forward n)
Library: (scm terminal)
Description: Moves the cursor forward (right) by n columns.
Example:
  (cursor-forward 5)
```

### `cursor-hide`

```
Syntax: (cursor-hide)
Library: (scm terminal)
Description: Hides the cursor.
Example:
  (cursor-hide)
```

### `cursor-home`

```
Syntax: (cursor-home)
Library: (scm terminal)
Description: Moves the cursor to the top-left corner (row 1, column 1).
Example:
  (cursor-home)
```

### `cursor-position`

```
Syntax: (cursor-position row col)
Library: (scm terminal)
Description: Moves the cursor to the specified row and column (1-based).
Example:
  (cursor-position 1 1)  ; move to top-left corner
```

### `cursor-restore`

```
Syntax: (cursor-restore)
Library: (scm terminal)
Description: Restores the cursor to the position saved by cursor-save.
Example:
  (cursor-restore)
```

### `cursor-save`

```
Syntax: (cursor-save)
Library: (scm terminal)
Description: Saves the current cursor position. Use cursor-restore to
return to the saved position.
Example:
  (cursor-save)
```

### `cursor-show`

```
Syntax: (cursor-show)
Library: (scm terminal)
Description: Shows the cursor.
Example:
  (cursor-show)
```

### `cursor-up`

```
Syntax: (cursor-up n)
Library: (scm terminal)
Description: Moves the cursor up by n rows.
Example:
  (cursor-up 3)
```

### `read-password`

```
Syntax: (read-password)
Syntax: (read-password prompt)
Library: (scm terminal)
Description: Reads a password from the terminal without echoing
typed characters. If prompt is given as a string, it is displayed
before reading. Returns the entered string (without trailing
newline), or the eof-object if input is closed. Works on Linux,
macOS, and Windows for both the C# and Java implementations.
Example:
  (read-password "Password: ")
```

### `sgr-bg`

```
Syntax: (sgr-bg color-name)
Syntax: (sgr-bg color-index)
Syntax: (sgr-bg r g b)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for setting the
background color. Accepts the same arguments as sgr-fg: a named color
symbol, a 256-color index (0-255), or three integers for 24-bit RGB.
Example:
  (display (string-append (sgr-bg 'blue) "info" (sgr-reset)))
  (display (string-append (sgr-bg 21) "blue" (sgr-reset)))
  (display (string-append (sgr-bg 0 0 128) "navy" (sgr-reset)))
```

### `sgr-blink`

```
Syntax: (sgr-blink)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for blinking text.
Example:
  (display (string-append (sgr-blink) "hello" (sgr-reset)))
```

### `sgr-bold`

```
Syntax: (sgr-bold)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for bold text.
Example:
  (display (string-append (sgr-bold) "hello" (sgr-reset)))
```

### `sgr-dim`

```
Syntax: (sgr-dim)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for dim text.
Example:
  (display (string-append (sgr-dim) "hello" (sgr-reset)))
```

### `sgr-fg`

```
Syntax: (sgr-fg color-name)
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
  (display (string-append (sgr-fg 'red) "error" (sgr-reset)))
  (display (string-append (sgr-fg 196) "red" (sgr-reset)))
  (display (string-append (sgr-fg 255 128 0) "orange" (sgr-reset)))
```

### `sgr-hidden`

```
Syntax: (sgr-hidden)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for hidden text.
Example:
  (display (string-append (sgr-hidden) "secret" (sgr-reset)))
```

### `sgr-italic`

```
Syntax: (sgr-italic)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for italic text.
Example:
  (display (string-append (sgr-italic) "hello" (sgr-reset)))
```

### `sgr-reset`

```
Syntax: (sgr-reset)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string that resets all
text attributes to their defaults.
Example:
  (display (sgr-reset))
```

### `sgr-reverse`

```
Syntax: (sgr-reverse)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for reverse video.
Example:
  (display (string-append (sgr-reverse) "hello" (sgr-reset)))
```

### `sgr-strikethrough`

```
Syntax: (sgr-strikethrough)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for strikethrough text.
Example:
  (display (string-append (sgr-strikethrough) "hello" (sgr-reset)))
```

### `sgr-underline`

```
Syntax: (sgr-underline)
Library: (scm terminal)
Description: Returns the ANSI escape sequence string for underlined text.
Example:
  (display (string-append (sgr-underline) "hello" (sgr-reset)))
```

### `terminal-byte-ready?`

```
Syntax: (terminal-byte-ready?)
Library: (scm terminal)
Description: Returns #t if a byte is available for reading from
standard input without blocking, #f otherwise.
Intended for use in raw terminal mode to detect multi-byte
escape sequences.
Example:
  (terminal-byte-ready?) => #f
```

### `terminal-enable-ansi!`

```
Syntax: (terminal-enable-ansi!)
Library: (scm terminal)
Description: Enables ANSI escape sequence processing.
On Windows, this enables virtual terminal processing for the
console output and input handles. On Linux and macOS, this is
a no-op since ANSI is natively supported.
Returns #t on success, #f on failure.
Note: In the Java implementation, this is always a no-op.
Windows ANSI support requires a modern terminal emulator.
Example:
  (terminal-enable-ansi!) => #t
```

### `terminal-raw!`

```
Syntax: (terminal-raw! enable)
Library: (scm terminal)
Description: Enables or disables raw terminal mode.
When enable is #t, disables line buffering, echo, and signal
processing so that individual keypresses can be read.
When enable is #f, restores the original terminal settings.
Returns #t on success, #f if raw mode is not supported.
On Windows with Java, raw mode is not supported and returns #f.
Example:
  (terminal-raw! #t)  ; enable raw mode
  (terminal-raw! #f)  ; restore original mode
```

### `terminal-read-byte`

```
Syntax: (terminal-read-byte)
Library: (scm terminal)
Description: Reads a single raw byte from standard input, bypassing
the port system and any line buffering. Returns an integer 0-255,
or an eof-object if the end of input has been reached.
Intended for use in raw terminal mode.
Example:
  (terminal-read-byte) => 27  ; ESC key
```

### `terminal-read-key`

```
Syntax: (terminal-read-key)
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
            ((eq? key 'ctrl-q) (display "Bye!"))
            ((char? key) (display key) (loop))
            (else (display key) (display " ") (loop)))))))
```

### `terminal-size`

```
Syntax: (terminal-size)
Library: (scm terminal)
Description: Returns the terminal dimensions as a pair (cols . rows),
or #f if the terminal size cannot be determined.
Example:
  (terminal-size) => (80 . 24)
```

### `terminal?`

```
Syntax: (terminal?)
Syntax: (terminal? which)
Library: (scm terminal)
Description: Returns #t if the process is connected to a terminal.
If which is 'input, checks only the input stream.
If which is 'output, checks only the output stream.
With no arguments, returns #t only if both input and output are terminals.
Example:
  (terminal?) => #t
```

### `with-alternate-screen`

```
Syntax: (with-alternate-screen thunk)
Library: (scm terminal)
Description: Calls thunk with the alternate screen buffer enabled.
The original screen is restored when thunk returns or when an exception
is raised.
Example:
  (with-alternate-screen
    (lambda ()
      (clear-screen)
      (cursor-position 1 1)
      (display "Hello from alternate screen!")))
```

### `with-console-echo-off`

```
Syntax: (with-console-echo-off thunk)
Library: (scm terminal)
Description: Calls thunk with terminal echo disabled. Echo is
re-enabled when thunk returns or when an exception is raised.
Returns the value returned by thunk. If echo cannot be disabled
(e.g. stdin is not a terminal, or running under Java on Windows),
thunk is still invoked but typed characters may be visible.
Example:
  (with-console-echo-off
    (lambda ()
      (display "Password: ")
      (let ((pw (read-line)))
        (newline)
        pw)))
```

### `with-terminal-raw`

```
Syntax: (with-terminal-raw thunk)
Library: (scm terminal)
Description: Calls thunk with raw terminal mode enabled. The original
terminal settings are restored when thunk returns or when an exception
is raised. Returns the value returned by thunk.
Example:
  (with-terminal-raw
    (lambda ()
      (let ((key (terminal-read-key)))
        (display key))))
```

