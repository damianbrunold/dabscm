# `(scm net smtp)`

## Exports

### `send-email`

```
Syntax: (send-email host port security from recipients subject body)
Syntax: (send-email host port security from recipients subject body user pass)
Library: (scm net smtp)
Description: High-level convenience that builds a plain-text message and sends it
  in one call. security is 'plaintext, 'starttls or 'tls (see smtp-open). from is
  the sender address; recipients is an address string or list of address strings
  (used for both the To header and the envelope). When user and pass are given,
  authenticates with smtp-auth after connecting (use 'starttls or 'tls so the
  credentials are encrypted). The socket is always closed, even on error. Returns
  #t on success.
Example:
  (send-email "smtp.example.com" 587 'starttls
              "me@example.com" "you@example.com"
              "Hello" "This is the body."
              "me@example.com" "app-password")
```

### `smtp-auth`

```
Syntax: (smtp-auth session user pass)
Library: (scm net smtp)
Description: Authenticates to the server using the advertised AUTH mechanism,
  preferring AUTH PLAIN and falling back to AUTH LOGIN; both transmit the
  credentials Base64-encoded, so this should only be used over a TLS-secured
  session (smtp-open with 'tls or 'starttls). Signals an error if the server
  advertises neither mechanism or authentication is rejected. Returns the session.
Example:
  (smtp-auth s "me@example.com" "app-password")
```

### `smtp-close`

```
Syntax: (smtp-close session)
Library: (scm net smtp)
Description: Closes the session's socket without sending QUIT, ignoring any
  error (e.g. an already-closed socket). Use on an error path; use smtp-quit for
  a graceful shutdown. Returns #t.
Example:
  (smtp-close s)
```

### `smtp-command`

```
Syntax: (smtp-command session line)
Library: (scm net smtp)
Description: Sends one command line to the server (a CRLF is appended and the
  output flushed), then reads and returns the reply as two values (status code
  and list of text fragments), exactly like smtp-read-response.
Example:
  (smtp-command s "NOOP") ; => 250 and ("OK")
```

### `smtp-data`

```
Syntax: (smtp-data session data)
Library: (scm net smtp)
Description: Sends the message DATA: issues DATA (expecting 354), writes the
  message string data with dot-stuffing and canonical CRLF line endings,
  terminates with the '.' line, and checks for a 250 reply. data is typically the
  result of email->string. Returns the session.
Example:
  (smtp-data s (email->string msg))
```

### `smtp-ehlo`

```
Syntax: (smtp-ehlo session)
Library: (scm net smtp)
Description: Sends EHLO and parses the reply, storing the advertised capability
  lines (all reply lines after the greeting) in the session. Returns the list of
  capability strings. Called automatically by smtp-open and again after a
  STARTTLS upgrade.
Example:
  (smtp-ehlo s) ; => ("STARTTLS" "AUTH LOGIN PLAIN" "SIZE 35882577")
```

### `smtp-encode-plain`

```
Syntax: (smtp-encode-plain user pass)
Library: (scm net smtp)
Description: Returns the Base64 SASL PLAIN credential string for the given
  username and password, i.e. base64 of "\x0;user\x0;pass" with an empty
  authorization identity. This is the argument sent with AUTH PLAIN.
Example:
  (smtp-encode-plain "user" "pass") => "AHVzZXIAcGFzcw=="
```

### `smtp-has-capability?`

```
Syntax: (smtp-has-capability? session name)
Library: (scm net smtp)
Description: Returns #t if the server advertised the named ESMTP capability in
  its EHLO reply (matched case-insensitively against the first token of each
  capability line), otherwise #f. Examples of names: "STARTTLS", "AUTH",
  "SIZE".
Example:
  (smtp-has-capability? s "STARTTLS") => #t
```

### `smtp-mail-from`

```
Syntax: (smtp-mail-from session addr)
Library: (scm net smtp)
Description: Sends MAIL FROM for the envelope sender addr (bare addresses are
  wrapped in angle brackets automatically). Signals an error unless the server
  replies 250. Returns the session.
Example:
  (smtp-mail-from s "me@example.com")
```

### `smtp-open`

```
Syntax: (smtp-open host port security)
Syntax: (smtp-open host port security verify?)
Library: (scm net smtp)
Description: Opens an SMTP session to host:port. security is one of the symbols
  'plaintext (no encryption), 'starttls (connect in clear then upgrade with
  STARTTLS), or 'tls (implicit TLS / SMTPS, typically port 465). Reads the
  greeting, sends EHLO, and for 'starttls performs the upgrade. verify? (default
  #t) controls TLS certificate validation. Returns an smtp-session.
Example:
  (define s (smtp-open "smtp.example.com" 587 'starttls))
```

### `smtp-quit`

```
Syntax: (smtp-quit session)
Library: (scm net smtp)
Description: Sends QUIT for a graceful shutdown and then closes the socket.
  Errors from the QUIT exchange are ignored (the connection is being torn down
  regardless). Returns #t.
Example:
  (smtp-quit s)
```

### `smtp-rcpt-to`

```
Syntax: (smtp-rcpt-to session addr)
Library: (scm net smtp)
Description: Sends RCPT TO for one recipient address addr (bare addresses are
  wrapped in angle brackets automatically). Accepts a 250 or 251 reply; signals
  an error otherwise. Call once per recipient. Returns the session.
Example:
  (smtp-rcpt-to s "you@example.com")
```

### `smtp-read-response`

```
Syntax: (smtp-read-response session)
Library: (scm net smtp)
Description: Reads one complete reply from the server, returning two values: the
  integer status code and the list of text fragments. Reads each line with
  socket-read-line so no bytes are buffered past the reply (important across a
  STARTTLS upgrade).
Example:
  (call-with-values (lambda () (smtp-read-response s)) list) ; => (250 ("OK"))
```

### `smtp-read-response-from`

```
Syntax: (smtp-read-response-from next-line)
Library: (scm net smtp)
Description: Parses one (possibly multi-line) SMTP reply. next-line is a thunk
  that returns the next response line as a string (without its CRLF) or an
  end-of-file object. Reply lines have the form NNN<sep>text, where NNN is a
  three-digit status code and sep is '-' for a continuation line or a space on
  the final line. Returns two values: the integer status code and the list of
  text fragments. This is the network-independent core of smtp-read-response,
  exposed so it can be driven from a string port in tests.
Example:
  (let ((ls (list "250-ehlo" "250 OK")))
    (smtp-read-response-from (lambda () (if (null? ls) (eof-object)
                                            (let ((x (car ls))) (set! ls (cdr ls)) x)))))
  ; => 250 and ("ehlo" "OK")
```

### `smtp-session-capabilities`

*(no documentation)*

### `smtp-session-host`

*(no documentation)*

### `smtp-session-port`

*(no documentation)*

### `smtp-session-security`

*(no documentation)*

### `smtp-session-socket`

*(no documentation)*

### `smtp-session?`

*(no documentation)*

### `smtp-starttls!`

```
Syntax: (smtp-starttls! session)
Syntax: (smtp-starttls! session verify?)
Library: (scm net smtp)
Description: Upgrades the session to TLS using STARTTLS (RFC 3207): verifies the
  server advertises STARTTLS, issues the command, performs the TLS handshake in
  place, and re-sends EHLO over the encrypted channel (refreshing capabilities).
  verify? defaults to #t (validate the server certificate); pass #f to disable
  validation (insecure). Returns the session.
Example:
  (smtp-starttls! s)
```

### `smtp-stuff-dots`

```
Syntax: (smtp-stuff-dots line)
Library: (scm net smtp)
Description: Applies SMTP dot-stuffing (RFC 5321) to a single body line: if the
  line begins with a period, an extra period is prepended so the terminating
  '.' line is never mistaken for content. Lines not starting with '.' are
  returned unchanged.
Example:
  (smtp-stuff-dots ".hidden") => "..hidden"
  (smtp-stuff-dots "hello") => "hello"
```

