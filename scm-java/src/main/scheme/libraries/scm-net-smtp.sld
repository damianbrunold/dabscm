(define-library (scm net smtp)
  (import (scm core) (scheme base) (scheme char)
          (scm net sockets) (scm crypto) (scm net email))
  (export smtp-open
          smtp-session?
          smtp-session-socket
          smtp-session-host
          smtp-session-port
          smtp-session-security
          smtp-session-capabilities
          smtp-read-response
          smtp-read-response-from
          smtp-command
          smtp-ehlo
          smtp-has-capability?
          smtp-starttls!
          smtp-auth
          smtp-encode-plain
          smtp-mail-from
          smtp-rcpt-to
          smtp-stuff-dots
          smtp-data
          smtp-quit
          smtp-close
          send-email)
  (begin

    (define-record-type smtp-session
      (%make-smtp-session socket host port security capabilities)
      smtp-session?
      (socket       smtp-session-socket)
      (host         smtp-session-host)
      (port         smtp-session-port)
      (security     smtp-session-security)
      (capabilities smtp-session-capabilities smtp-session-capabilities-set!))

    (define %nul (string (integer->char 0)))

    ;; ---- low-level response parsing -------------------------------------

    (define (smtp-read-response-from next-line)
      "Syntax: (smtp-read-response-from next-line)
Library: (scm net smtp)
Description: Parses one (possibly multi-line) SMTP reply. next-line is a thunk
  that returns the next response line as a string (without its CRLF) or an
  end-of-file object. Reply lines have the form NNN<sep>text, where NNN is a
  three-digit status code and sep is '-' for a continuation line or a space on
  the final line. Returns two values: the integer status code and the list of
  text fragments. This is the network-independent core of smtp-read-response,
  exposed so it can be driven from a string port in tests.
Example:
  (let ((ls (list \"250-ehlo\" \"250 OK\")))
    (smtp-read-response-from (lambda () (if (null? ls) (eof-object)
                                            (let ((x (car ls))) (set! ls (cdr ls)) x)))))
  ; => 250 and (\"ehlo\" \"OK\")"
      (let loop ((acc '()))
        (let ((line (next-line)))
          (when (eof-object? line)
            (error "smtp: connection closed while reading response"))
          (let ((len (string-length line)))
            (when (< len 3)
              (error "smtp: malformed response line" line))
            (let ((code (string->number (substring line 0 3)))
                  (text (if (> len 4) (substring line 4 len) ""))
                  (more (and (> len 3) (char=? (string-ref line 3) #\-))))
              (when (not code)
                (error "smtp: malformed response code" line))
              (if more
                  (loop (cons text acc))
                  (values code (reverse (cons text acc)))))))))

    (define (smtp-read-response session)
      "Syntax: (smtp-read-response session)
Library: (scm net smtp)
Description: Reads one complete reply from the server, returning two values: the
  integer status code and the list of text fragments. Reads each line with
  socket-read-line so no bytes are buffered past the reply (important across a
  STARTTLS upgrade).
Example:
  (call-with-values (lambda () (smtp-read-response s)) list) ; => (250 (\"OK\"))"
      (let ((sock (smtp-session-socket session)))
        (smtp-read-response-from (lambda () (socket-read-line sock)))))

    (define (%join-lines lines)
      (cond ((null? lines) "")
            ((null? (cdr lines)) (car lines))
            (else (string-append (car lines) " / " (%join-lines (cdr lines))))))

    (define (%expect code ok-codes lines context)
      (unless (memv code ok-codes)
        (error (string-append "smtp: " context " failed")
               code (%join-lines lines)))
      code)

    (define (smtp-command session line)
      "Syntax: (smtp-command session line)
Library: (scm net smtp)
Description: Sends one command line to the server (a CRLF is appended and the
  output flushed), then reads and returns the reply as two values (status code
  and list of text fragments), exactly like smtp-read-response.
Example:
  (smtp-command s \"NOOP\") ; => 250 and (\"OK\")"
      (let ((out (socket-output-port (smtp-session-socket session))))
        (write-string line out)
        (write-string "\r\n" out)
        (flush-output-port out)
        (smtp-read-response session)))

    ;; ---- capabilities ---------------------------------------------------

    (define (%first-token s)
      (let ((n (string-length s)))
        (let loop ((i 0))
          (cond ((= i n) s)
                ((char=? (string-ref s i) #\space) (substring s 0 i))
                (else (loop (+ i 1)))))))

    (define (%tokens s)
      (let ((n (string-length s)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((= i n) (reverse (if (> i start) (cons (substring s start i) acc) acc)))
            ((char=? (string-ref s i) #\space)
             (loop (+ i 1) (+ i 1)
                   (if (> i start) (cons (substring s start i) acc) acc)))
            (else (loop (+ i 1) start acc))))))

    (define (smtp-has-capability? session name)
      "Syntax: (smtp-has-capability? session name)
Library: (scm net smtp)
Description: Returns #t if the server advertised the named ESMTP capability in
  its EHLO reply (matched case-insensitively against the first token of each
  capability line), otherwise #f. Examples of names: \"STARTTLS\", \"AUTH\",
  \"SIZE\".
Example:
  (smtp-has-capability? s \"STARTTLS\") => #t"
      (let ((up (string-upcase name)))
        (let loop ((caps (smtp-session-capabilities session)))
          (cond ((null? caps) #f)
                ((string=? (string-upcase (%first-token (car caps))) up) #t)
                (else (loop (cdr caps)))))))

    (define (%auth-line session)
      (let loop ((caps (smtp-session-capabilities session)))
        (cond ((null? caps) #f)
              ((string=? (string-upcase (%first-token (car caps))) "AUTH") (car caps))
              (else (loop (cdr caps))))))

    (define (%mechanism? auth-line mech)
      (and (member mech (map string-upcase (%tokens auth-line))) #t))

    (define %ehlo-name "localhost")

    (define (smtp-ehlo session)
      "Syntax: (smtp-ehlo session)
Library: (scm net smtp)
Description: Sends EHLO and parses the reply, storing the advertised capability
  lines (all reply lines after the greeting) in the session. Returns the list of
  capability strings. Called automatically by smtp-open and again after a
  STARTTLS upgrade.
Example:
  (smtp-ehlo s) ; => (\"STARTTLS\" \"AUTH LOGIN PLAIN\" \"SIZE 35882577\")"
      (let-values (((code lines)
                    (smtp-command session (string-append "EHLO " %ehlo-name))))
        (%expect code '(250) lines "EHLO")
        (let ((caps (if (pair? lines) (cdr lines) '())))
          (smtp-session-capabilities-set! session caps)
          caps)))

    ;; ---- STARTTLS -------------------------------------------------------

    (define (smtp-starttls! session . opt)
      "Syntax: (smtp-starttls! session)
Syntax: (smtp-starttls! session verify?)
Library: (scm net smtp)
Description: Upgrades the session to TLS using STARTTLS (RFC 3207): verifies the
  server advertises STARTTLS, issues the command, performs the TLS handshake in
  place, and re-sends EHLO over the encrypted channel (refreshing capabilities).
  verify? defaults to #t (validate the server certificate); pass #f to disable
  validation (insecure). Returns the session.
Example:
  (smtp-starttls! s)"
      (let ((verify (if (pair? opt) (car opt) #t)))
        (unless (smtp-has-capability? session "STARTTLS")
          (error "smtp: server does not advertise STARTTLS"))
        (let-values (((code lines) (smtp-command session "STARTTLS")))
          (%expect code '(220) lines "STARTTLS"))
        (socket-starttls! (smtp-session-socket session)
                          (smtp-session-host session)
                          verify)
        (smtp-ehlo session)
        session))

    ;; ---- AUTH -----------------------------------------------------------

    (define (smtp-encode-plain user pass)
      "Syntax: (smtp-encode-plain user pass)
Library: (scm net smtp)
Description: Returns the Base64 SASL PLAIN credential string for the given
  username and password, i.e. base64 of \"\\x0;user\\x0;pass\" with an empty
  authorization identity. This is the argument sent with AUTH PLAIN.
Example:
  (smtp-encode-plain \"user\" \"pass\") => \"AHVzZXIAcGFzcw==\""
      (base64-encode (string->utf8 (string-append %nul user %nul pass))))

    (define (%auth-plain session user pass)
      (let-values (((code lines)
                    (smtp-command session
                                  (string-append "AUTH PLAIN "
                                                 (smtp-encode-plain user pass)))))
        (%expect code '(235) lines "AUTH PLAIN")))

    (define (%auth-login session user pass)
      (let-values (((code lines) (smtp-command session "AUTH LOGIN")))
        (%expect code '(334) lines "AUTH LOGIN"))
      (let-values (((code lines)
                    (smtp-command session (base64-encode (string->utf8 user)))))
        (%expect code '(334) lines "AUTH LOGIN (username)"))
      (let-values (((code lines)
                    (smtp-command session (base64-encode (string->utf8 pass)))))
        (%expect code '(235) lines "AUTH LOGIN (password)")))

    (define (smtp-auth session user pass)
      "Syntax: (smtp-auth session user pass)
Library: (scm net smtp)
Description: Authenticates to the server using the advertised AUTH mechanism,
  preferring AUTH PLAIN and falling back to AUTH LOGIN; both transmit the
  credentials Base64-encoded, so this should only be used over a TLS-secured
  session (smtp-open with 'tls or 'starttls). Signals an error if the server
  advertises neither mechanism or authentication is rejected. Returns the session.
Example:
  (smtp-auth s \"me@example.com\" \"app-password\")"
      (let ((auth (%auth-line session)))
        (unless auth
          (error "smtp: server does not advertise AUTH"))
        (cond
          ((%mechanism? auth "PLAIN") (%auth-plain session user pass))
          ((%mechanism? auth "LOGIN") (%auth-login session user pass))
          (else (error "smtp: no supported AUTH mechanism (need PLAIN or LOGIN)" auth))))
      session)

    ;; ---- envelope + data ------------------------------------------------

    (define (%angle addr)
      (if (and (> (string-length addr) 0) (char=? (string-ref addr 0) #\<))
          addr
          (string-append "<" addr ">")))

    (define (smtp-mail-from session addr)
      "Syntax: (smtp-mail-from session addr)
Library: (scm net smtp)
Description: Sends MAIL FROM for the envelope sender addr (bare addresses are
  wrapped in angle brackets automatically). Signals an error unless the server
  replies 250. Returns the session.
Example:
  (smtp-mail-from s \"me@example.com\")"
      (let-values (((code lines)
                    (smtp-command session (string-append "MAIL FROM:" (%angle addr)))))
        (%expect code '(250) lines "MAIL FROM"))
      session)

    (define (smtp-rcpt-to session addr)
      "Syntax: (smtp-rcpt-to session addr)
Library: (scm net smtp)
Description: Sends RCPT TO for one recipient address addr (bare addresses are
  wrapped in angle brackets automatically). Accepts a 250 or 251 reply; signals
  an error otherwise. Call once per recipient. Returns the session.
Example:
  (smtp-rcpt-to s \"you@example.com\")"
      (let-values (((code lines)
                    (smtp-command session (string-append "RCPT TO:" (%angle addr)))))
        (%expect code '(250 251) lines "RCPT TO"))
      session)

    (define (smtp-stuff-dots line)
      "Syntax: (smtp-stuff-dots line)
Library: (scm net smtp)
Description: Applies SMTP dot-stuffing (RFC 5321) to a single body line: if the
  line begins with a period, an extra period is prepended so the terminating
  '.' line is never mistaken for content. Lines not starting with '.' are
  returned unchanged.
Example:
  (smtp-stuff-dots \".hidden\") => \"..hidden\"
  (smtp-stuff-dots \"hello\") => \"hello\""
      (if (and (> (string-length line) 0) (char=? (string-ref line 0) #\.))
          (string-append "." line)
          line))

    (define (%write-data out data)
      ;; Emit data as dot-stuffed lines with canonical CRLF endings, accepting
      ;; either LF or CRLF line endings in the input.
      (let ((n (string-length data)))
        (let loop ((i 0) (start 0))
          (cond
            ((>= i n)
             (when (> i start)
               (write-string (smtp-stuff-dots (substring data start i)) out)
               (write-string "\r\n" out)))
            ((char=? (string-ref data i) #\newline)
             (let ((end (if (and (> i start)
                                 (char=? (string-ref data (- i 1)) #\return))
                            (- i 1) i)))
               (write-string (smtp-stuff-dots (substring data start end)) out)
               (write-string "\r\n" out))
             (loop (+ i 1) (+ i 1)))
            (else (loop (+ i 1) start))))))

    (define (smtp-data session data)
      "Syntax: (smtp-data session data)
Library: (scm net smtp)
Description: Sends the message DATA: issues DATA (expecting 354), writes the
  message string data with dot-stuffing and canonical CRLF line endings,
  terminates with the '.' line, and checks for a 250 reply. data is typically the
  result of email->string. Returns the session.
Example:
  (smtp-data s (email->string msg))"
      (let-values (((code lines) (smtp-command session "DATA")))
        (%expect code '(354) lines "DATA"))
      (let ((out (socket-output-port (smtp-session-socket session))))
        (%write-data out data)
        (write-string ".\r\n" out)
        (flush-output-port out))
      (let-values (((code lines) (smtp-read-response session)))
        (%expect code '(250) lines "end of DATA"))
      session)

    (define (smtp-close session)
      "Syntax: (smtp-close session)
Library: (scm net smtp)
Description: Closes the session's socket without sending QUIT, ignoring any
  error (e.g. an already-closed socket). Use on an error path; use smtp-quit for
  a graceful shutdown. Returns #t.
Example:
  (smtp-close s)"
      (guard (e (#t #f))
        (socket-close (smtp-session-socket session)))
      #t)

    (define (smtp-quit session)
      "Syntax: (smtp-quit session)
Library: (scm net smtp)
Description: Sends QUIT for a graceful shutdown and then closes the socket.
  Errors from the QUIT exchange are ignored (the connection is being torn down
  regardless). Returns #t.
Example:
  (smtp-quit s)"
      (guard (e (#t #f))
        (let-values (((code lines) (smtp-command session "QUIT")))
          code))
      (smtp-close session))

    ;; ---- session open + high-level send ---------------------------------

    (define (smtp-open host port security . opt)
      "Syntax: (smtp-open host port security)
Syntax: (smtp-open host port security verify?)
Library: (scm net smtp)
Description: Opens an SMTP session to host:port. security is one of the symbols
  'plaintext (no encryption), 'starttls (connect in clear then upgrade with
  STARTTLS), or 'tls (implicit TLS / SMTPS, typically port 465). Reads the
  greeting, sends EHLO, and for 'starttls performs the upgrade. verify? (default
  #t) controls TLS certificate validation. Returns an smtp-session.
Example:
  (define s (smtp-open \"smtp.example.com\" 587 'starttls))"
      (let* ((verify (if (pair? opt) (car opt) #t))
             (sock (if (eq? security 'tls)
                       (tls-connect host port verify)
                       (tcp-connect host port)))
             (session (%make-smtp-session sock host port security '())))
        (let-values (((code lines) (smtp-read-response session)))
          (%expect code '(220) lines "greeting"))
        (smtp-ehlo session)
        (when (eq? security 'starttls)
          (smtp-starttls! session verify))
        session))

    (define (send-email host port security from recipients subject body . opt)
      "Syntax: (send-email host port security from recipients subject body)
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
  (send-email \"smtp.example.com\" 587 'starttls
              \"me@example.com\" \"you@example.com\"
              \"Hello\" \"This is the body.\"
              \"me@example.com\" \"app-password\")"
      (let* ((user (if (pair? opt) (car opt) #f))
             (pass (if (and (pair? opt) (pair? (cdr opt))) (cadr opt) #f))
             (msg (make-email from recipients subject body))
             (data (email->string msg))
             (session (smtp-open host port security)))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (when (and user pass) (smtp-auth session user pass))
            (smtp-mail-from session from)
            (for-each (lambda (r) (smtp-rcpt-to session r)) (email-recipients msg))
            (smtp-data session data)
            (smtp-quit session)
            #t)
          (lambda () (smtp-close session)))))
))
