;;; Tests for (scm net email) and (scm net smtp).
;;;
;;; Pure (no-network) units cover message serialization, dot-stuffing, response
;;; parsing and AUTH credential encoding. A loopback group stands up an in-process
;;; fake SMTP server with tcp-listen/tcp-accept and drives the real client against
;;; it over a plaintext connection.
;;;
;;; The TLS paths (tls-connect / socket-starttls! / real AUTH) require a real
;;; server with a certificate and are exercised manually, not in CI.

(import (scheme base)
        (scheme write)
        (scm test)
        (srfi 13)
        (srfi 18)
        (scm net sockets)
        (scm net email)
        (scm net smtp))

(test-runner-factory scm-test-runner)

(test-begin "smtp")

(define (has? haystack needle)
  (and (string-contains haystack needle) #t))

;;; ---- Message construction (no I/O) ----
(test-group "email-serialization"
  (let ((s (email->string
            (make-email "me@example.com" "you@example.com" "Hello" "This is the body."))))
    (test-equal #t (has? s "From: me@example.com\r\n"))
    (test-equal #t (has? s "To: you@example.com\r\n"))
    (test-equal #t (has? s "Subject: Hello\r\n"))
    (test-equal #t (has? s "MIME-Version: 1.0\r\n"))
    (test-equal #t (has? s "Content-Type: text/plain; charset=utf-8\r\n"))
    (test-equal #t (has? s "Content-Transfer-Encoding: 7bit\r\n"))
    (test-equal #t (has? s "Date: "))
    (test-equal #t (has? s "Message-ID: <"))
    ;; blank line separates headers from body, body present
    (test-equal #t (has? s "\r\n\r\nThis is the body.")))
  ;; multiple recipients are comma-joined; Bcc never appears in the headers
  (let ((s (email->string
            (make-email "me@x.com"
                        (list "a@y.com" "b@y.com")
                        "Subj" "Body"
                        '()              ; cc
                        (list "secret@z.com")))))  ; bcc
    (test-equal #t (has? s "To: a@y.com, b@y.com\r\n"))
    (test-equal #f (has? s "secret@z.com"))
    (test-equal #f (has? s "Bcc")))
  ;; Cc header rendered only when present
  (let ((s (email->string
            (make-email "me@x.com" "a@y.com" "S" "B" (list "c@y.com")))))
    (test-equal #t (has? s "Cc: c@y.com\r\n")))
  ;; envelope recipients = To + Cc + Bcc
  (test-equal '("a@y.com" "c@y.com" "s@z.com")
    (email-recipients
     (make-email "me@x.com" "a@y.com" "S" "B" (list "c@y.com") (list "s@z.com"))))
  ;; non-ASCII body switches to base64 transfer encoding
  (let ((s (email->string (make-email "me@x.com" "a@y.com" "S" "grüezi"))))
    (test-equal #t (has? s "Content-Transfer-Encoding: base64\r\n"))))

;;; ---- Header helpers (no I/O) ----
(test-group "email-helpers"
  (test-equal #t (email-ascii? "hello"))
  (test-equal #f (email-ascii? "grüezi"))
  (test-equal "Hello" (rfc2047-encode-header "Hello"))
  (test-equal "=?utf-8?B?Z3LDvGV6aQ==?=" (rfc2047-encode-header "grüezi"))
  ;; RFC 5322 date ends with a numeric UTC offset, not "Z"
  (test-equal #t (has? (rfc5322-date) " +0000")))

;;; ---- Dot-stuffing (no I/O) ----
(test-group "dot-stuffing"
  (test-equal ".." (smtp-stuff-dots "."))
  (test-equal "..hidden" (smtp-stuff-dots ".hidden"))
  (test-equal "hello" (smtp-stuff-dots "hello"))
  (test-equal "" (smtp-stuff-dots "")))

;;; ---- Response parsing (no I/O) ----
(define (lines->thunk lines)
  (lambda ()
    (if (null? lines)
        (eof-object)
        (let ((x (car lines))) (set! lines (cdr lines)) x))))

(test-group "response-parsing"
  (call-with-values
    (lambda ()
      (smtp-read-response-from (lines->thunk (list "250-foo" "250-bar" "250 baz"))))
    (lambda (code lines)
      (test-equal 250 code)
      (test-equal '("foo" "bar" "baz") lines)))
  (call-with-values
    (lambda ()
      (smtp-read-response-from (lines->thunk (list "220 ready"))))
    (lambda (code lines)
      (test-equal 220 code)
      (test-equal '("ready") lines))))

;;; ---- AUTH credential encoding (no I/O) ----
(test-group "auth-encoding"
  ;; base64 of "\0user\0pass"
  (test-equal "AHVzZXIAcGFzcw==" (smtp-encode-plain "user" "pass")))

;;; ---- Loopback integration (plaintext) ----
;;
;; A fake SMTP server runs on a worker thread; the real client drives it. The
;; server records the command lines and the DATA payload it received so the test
;; can assert the client speaks correct SMTP.

(define *srv-commands* '())
(define *srv-body* "")

(define (start-fake-smtp listener)
  ;; listener is an already-bound tcp listener; accept one client and play a
  ;; scripted ESMTP dialogue, capturing what the client sends.
  (make-thread
   (lambda ()
     (guard (e (#t #f))
       (let* ((sock (tcp-accept listener))
              (out  (socket-output-port sock)))
         (define (reply line)
           (write-string line out) (write-string "\r\n" out) (flush-output-port out))
         (reply "220 fake ESMTP ready")
         (let loop ()
           (let ((line (socket-read-line sock)))
             (if (eof-object? line)
                 (socket-close sock)
                 (begin
                   (set! *srv-commands* (cons line *srv-commands*))
                   (let ((up (string-upcase line)))
                     (cond
                       ((string-prefix? "EHLO" up)
                        (reply "250-fake greets you")
                        (reply "250-STARTTLS")
                        (reply "250 AUTH PLAIN LOGIN")
                        (loop))
                       ((string-prefix? "MAIL FROM" up) (reply "250 OK") (loop))
                       ((string-prefix? "RCPT TO" up) (reply "250 OK") (loop))
                       ((string-prefix? "DATA" up)
                        (reply "354 End data with <CR><LF>.<CR><LF>")
                        (let bloop ((acc '()))
                          (let ((bl (socket-read-line sock)))
                            (cond
                              ((eof-object? bl) (socket-close sock))
                              ((string=? bl ".")
                               (set! *srv-body*
                                     (string-join (reverse acc) "\n"))
                               (reply "250 OK queued as 12345")
                               (loop))
                              (else (bloop (cons bl acc)))))))
                       ((string-prefix? "QUIT" up)
                        (reply "221 Bye")
                        (socket-close sock))
                       (else (reply "250 OK") (loop)))))))))))))

(test-group "loopback-plaintext"
  (test-equal #t
    (guard (exn (#t #f))
      (let* ((listener (tcp-listen 18095))
             (server   (start-fake-smtp listener)))
        (set! *srv-commands* '())
        (set! *srv-body* "")
        (thread-start! server)
        (send-email "localhost" 18095 'plaintext
                    "me@example.com" "you@example.com"
                    "Hello" "This is a test.")
        (thread-join! server)
        (socket-close listener)
        #t)))
  ;; The client issued the expected commands ...
  (test-equal #t (and (member "EHLO localhost" *srv-commands*) #t))
  (test-equal #t (and (member "MAIL FROM:<me@example.com>" *srv-commands*) #t))
  (test-equal #t (and (member "RCPT TO:<you@example.com>" *srv-commands*) #t))
  (test-equal #t (and (member "QUIT" *srv-commands*) #t))
  ;; ... and the DATA payload carried the headers and body.
  (test-equal #t (has? *srv-body* "From: me@example.com"))
  (test-equal #t (has? *srv-body* "To: you@example.com"))
  (test-equal #t (has? *srv-body* "Subject: Hello"))
  (test-equal #t (has? *srv-body* "This is a test.")))

;;; ---- Loopback: capability detection over plaintext ----
(test-group "loopback-capabilities"
  (test-equal #t
    (guard (exn (#t #f))
      (let* ((listener (tcp-listen 18094))
             (server   (start-fake-smtp listener)))
        (set! *srv-commands* '())
        (thread-start! server)
        (let* ((s (smtp-open "localhost" 18094 'plaintext))
               (has-tls (smtp-has-capability? s "STARTTLS"))
               (has-auth (smtp-has-capability? s "AUTH")))
          (smtp-quit s)
          (thread-join! server)
          (socket-close listener)
          (and has-tls has-auth))))))

(test-end "smtp")
