---
title: (scm net email) and (scm net smtp): sending e-mail
part: libraries
order: 1029
libraries: (scm net email) (scm net smtp)
summary: Building messages with To, Cc and Bcc, what goes over the wire, non-ASCII subjects and bodies, a local mail catcher for development and tests, send-email, one session for many messages, providers, TLS and passwords.
---
# (scm net email) and (scm net smtp): sending e-mail

- `(scm net email)` builds plain-text messages in the format mail
  servers expect.
- `(scm net smtp)` hands them to a mail server with SMTP, the protocol
  every mail provider speaks.

```scheme
(import (scheme base) (scheme char) (scheme write) (srfi 18) (only (srfi 13) string-prefix?)
        (scm string) (scm net sockets) (scm net email) (scm net smtp))
```

## A message

```scheme
(define order-mail
  (make-email "shop@tea.example"
              (list "ada@example.com" "alan@example.com")
              "Your order 117"
              "Dear Ada,\n\nyour tea has shipped.\n"
              "accounts@tea.example"                 ; Cc
              "archive@tea.example"))                ; Bcc

(email-to order-mail)                       ;; => ("ada@example.com" "alan@example.com")
(email-subject order-mail)                  ;; => "Your order 117"
(email-recipients order-mail)
;; => ("ada@example.com" "alan@example.com" "accounts@tea.example" "archive@tea.example")
```

`to`, `cc` and `bcc` take one address or a list. `email-recipients` is
everybody the server must deliver to, the Bcc address included.

## On the wire

`email->string` gives the message as it is sent: header lines, an empty
line, the body, with CRLF line ends:

```scheme
(define (lines text) (string-split text "\r\n"))
(define (filter-lines keep? ls)
  (cond ((null? ls) '())
        ((keep? (car ls)) (cons (car ls) (filter-lines keep? (cdr ls))))
        (else (filter-lines keep? (cdr ls)))))

(define wire (email->string order-mail))
(filter-lines (lambda (l) (not (or (string-prefix? "Date:" l) (string-prefix? "Message-ID:" l))))
              (lines wire))
;; => ("From: shop@tea.example" "To: ada@example.com, alan@example.com" "Cc: accounts@tea.example" "Subject: Your order 117" "MIME-Version: 1.0" "Content-Type: text/plain; charset=utf-8" "Content-Transfer-Encoding: 7bit" "" "Dear Ada," "" "your tea has shipped." "")
```

A date and a unique Message-ID are added, which is why they are left
out above. The Bcc address appears nowhere in the message: that is what
makes it blind.

Mail headers are ASCII. A subject with other characters is encoded, and
so is a body that is not plain ASCII; mail programs decode both:

```scheme
(define greeting (lines (email->string (make-email "shop@tea.example" "heidi@example.ch" "Grüezi" "Merci für Ihre Bestellung.\n"))))
(filter-lines (lambda (l) (or (string-prefix? "Subject" l) (string-prefix? "Content-Transfer" l))) greeting)
;; => ("Subject: =?utf-8?B?R3LDvGV6aQ==?=" "Content-Transfer-Encoding: base64")
(rfc2047-encode-header "Order 117")         ;; => "Order 117"
```

## A mail catcher

Programs that send mail need a server to test against, and it should not
deliver anything. A few dozen lines make one: it accepts connections,
answers the SMTP commands with "OK" and keeps what it received. (Tools
like Mailpit do the same, with a web page to read the mail.)

```scheme
(define caught '())                         ; (sender recipients data), newest first
(define caught-lock (make-mutex))

(define (catch-session sock)
  (let ((out (socket-output-port sock)))
    (define (reply text) (write-string text out) (write-string "\r\n" out) (flush-output-port out))
    (define (address line) (let ((i (string-index* line #\<)) (j (string-index* line #\>)))
                             (if (and i j) (substring line (+ i 1) j) line)))
    (reply "220 catcher ready")
    (let loop ((from #f) (to '()))
      (let* ((line (socket-read-line sock))
             (verb (if (eof-object? line) "" (string-upcase (substring line 0 (min 4 (string-length line)))))))
        (cond ((eof-object? line) (socket-close sock))
              ((string=? verb "EHLO") (reply "250-catcher") (reply "250 SIZE 10000000") (loop from to))
              ((string=? verb "MAIL") (reply "250 OK") (loop (address line) '()))
              ((string=? verb "RCPT") (reply "250 OK") (loop from (append to (list (address line)))))
              ((string=? verb "DATA")
               (reply "354 go ahead")
               (let read-data ((acc '()))
                 (let ((l (socket-read-line sock)))
                   (if (or (eof-object? l) (string=? l "."))
                       (begin
                         (mutex-lock! caught-lock)
                         (set! caught (cons (list from to (reverse acc)) caught))
                         (mutex-unlock! caught-lock)
                         (reply "250 OK queued")
                         (loop #f '()))
                       (read-data (cons l acc))))))
              ((string=? verb "QUIT") (reply "221 bye") (socket-close sock))
              (else (reply "250 OK") (loop from to)))))))

(define (string-index* s ch)
  (let loop ((i 0))
    (cond ((= i (string-length s)) #f) ((char=? (string-ref s i) ch) i) (else (loop (+ i 1))))))

(define (start-catcher port)
  (let* ((listener (tcp-listen port))
         (t (make-thread
             (lambda ()
               (let loop ()
                 (let ((sock (guard (e (#t #f)) (tcp-accept listener))))
                   (when sock
                     (thread-start! (make-thread (lambda () (catch-session sock))))
                     (loop))))))))
    (thread-start! t)
    (lambda () (socket-close listener) (thread-join! t))))   ; stops the catcher

(define stop-catcher (start-catcher 18921))
```

## send-email

`send-email` connects, sends one message and disconnects. Here it goes to
the catcher with no encryption, which is fine on the local machine:

```scheme
(send-email "127.0.0.1" 18921 'plaintext
            "shop@tea.example" "ada@example.com"
            "Your order 117" "Dear Ada,\nyour tea has shipped.\n") ;; => #t

(define received (car caught))
(car received)                              ;; => "shop@tea.example"
(cadr received)                             ;; => ("ada@example.com")
(filter-lines (lambda (l) (string-prefix? "Subject:" l)) (caddr received)) ;; => ("Subject: Your order 117")
```

The server's address and security are the first arguments; with a user
name and password after the body it logs in first.

## Many messages, one connection

A newsletter to many customers should not open a connection for each.
The session procedures take the steps one by one: the envelope sender
(`smtp-mail-from`), each recipient (`smtp-rcpt-to`), the message
(`smtp-data`), as often as needed, then `smtp-quit`:

```scheme
(define customers '(("Ada" . "ada@example.com") ("Alan" . "alan@example.com") ("Grace" . "grace@example.com")))

(define (newsletter customer)
  (let ((m (make-email "news@tea.example" (cdr customer) "Spring teas are here"
                       (string-append "Dear " (car customer) ",\n\nthe first flush Darjeeling has arrived.\n"))))
    (list (email-from m) (email-recipients m) (email->string m))))

(define (send-all host port security messages)
  (let ((s (smtp-open host port security)))
    (guard (e (#t (smtp-close s) (raise e)))
      (for-each (lambda (m)
                  (smtp-mail-from s (car m))
                  (for-each (lambda (r) (smtp-rcpt-to s r)) (cadr m))
                  (smtp-data s (caddr m)))
                messages)
      (smtp-quit s))))

(set! caught '())
(send-all "127.0.0.1" 18921 'plaintext (map newsletter customers))

(map cadr (reverse caught))                 ;; => (("ada@example.com") ("alan@example.com") ("grace@example.com"))
(stop-catcher)
```

Each customer gets a message of their own, so nobody sees the other
addresses. `smtp-data` also takes care of *dot-stuffing*: a body line
that starts with a period is sent with two, because a lone `.` ends the
message:

```scheme
(smtp-stuff-dots ".hidden file")            ;; => "..hidden file"
```

## Real mail servers

Mail providers want an encrypted connection and a login, usually with an
app password rather than the account's password:

| port | security | used by |
|---|---|---|
| 587 | `'starttls` | most providers: connect, then switch to TLS |
| 465 | `'tls` | TLS from the start ("SMTPS") |
| 25 | `'plaintext` | server-to-server only; often blocked |

```scheme no-test
(define (env name) (or (get-environment-variable name) (error "missing setting" name)))

(send-email (env "SMTP_HOST") 587 'starttls
            "shop@tea.example" "ada@example.com"
            "Your order 117" "Dear Ada,\nyour tea has shipped.\n"
            (env "SMTP_USER") (env "SMTP_PASSWORD"))
```

- Keep the password out of the source: environment variables, a
  configuration file outside the repository, or a secrets store.
- The server's certificate is checked; `smtp-open` with a fourth argument
  `#f` turns that off, for test servers only.
- `smtp-has-capability?` tells what the server offers, e.g. `"SIZE"` for
  the largest message it accepts.
- An error is raised when the server refuses a step (an unknown
  recipient, a failed login); a web request should not wait for that, so
  send from a background thread or a job queue.
- The messages are plain text. Attachments and HTML mail need MIME
  multipart messages, which this library does not build.

## Where next

- [Sockets](scm-websocket.md) for the line protocol underneath,
  [threads](srfi-18.md), [templating](scm-templating.md) for message
  texts.
- Reference: `(scm net email)`, `(scm net smtp)`.
