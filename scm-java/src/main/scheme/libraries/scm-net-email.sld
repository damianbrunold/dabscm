(define-library (scm net email)
  (import (scm core) (scheme base) (scm crypto) (srfi 19))
  (export make-email
          email?
          email-from
          email-to
          email-cc
          email-bcc
          email-subject
          email-body
          email-headers
          email-recipients
          email->string
          ;; Helpers (also useful standalone and exercised by tests)
          email-ascii?
          rfc5322-date
          rfc2047-encode-header)
  (begin

    (define-record-type email
      (%make-email from to cc bcc subject body headers)
      email?
      (from    email-from)
      (to      email-to)
      (cc      email-cc)
      (bcc     email-bcc)
      (subject email-subject)
      (body    email-body)
      (headers email-headers))

    (define (%as-address-list x)
      ;; Accept either a single address string or a list of address strings.
      (cond ((string? x) (list x))
            ((list? x) x)
            (else (error "email: address must be a string or list of strings" x))))

    (define (make-email from to subject body . opt)
      "Syntax: (make-email from to subject body)
Syntax: (make-email from to subject body cc)
Syntax: (make-email from to subject body cc bcc)
Library: (scm net email)
Description: Builds a plain-text email message object. from is a single address
  string. to, cc and bcc are each either a single address string or a list of
  address strings (cc and bcc default to the empty list). subject and body are
  strings (UTF-8 is supported in both). Use email->string to serialize the
  message to RFC 5322 wire format, or send it with send-email from (scm net smtp).
Example:
  (make-email \"me@example.com\" \"you@example.com\" \"Hi\" \"Hello there\")
  (make-email \"me@x.com\" (list \"a@y.com\" \"b@y.com\") \"Subj\" \"Body\")"
      (let ((cc  (if (pair? opt) (%as-address-list (car opt)) '()))
            (bcc (if (and (pair? opt) (pair? (cdr opt)))
                     (%as-address-list (cadr opt))
                     '())))
        (%make-email from (%as-address-list to) cc bcc subject body '())))

    (define (email-recipients e)
      "Syntax: (email-recipients e)
Library: (scm net email)
Description: Returns the full list of envelope recipient addresses for the email
  e: every To, Cc and Bcc address concatenated. This is the list to pass to RCPT
  TO when sending; the Bcc addresses are deliberately excluded from the rendered
  headers but still receive the message.
Example:
  (email-recipients (make-email \"a@x\" \"b@y\" \"s\" \"body\")) => (\"b@y\")"
      (append (email-to e) (email-cc e) (email-bcc e)))

    (define (email-ascii? s)
      "Syntax: (email-ascii? s)
Library: (scm net email)
Description: Returns #t if every character of string s is a US-ASCII character
  (code point below 128), otherwise #f. Used to decide whether headers or body
  need transfer encoding.
Example:
  (email-ascii? \"hello\") => #t
  (email-ascii? \"grüezi\") => #f"
      (let ((n (string-length s)))
        (let loop ((i 0))
          (cond ((= i n) #t)
                ((>= (char->integer (string-ref s i)) 128) #f)
                (else (loop (+ i 1)))))))

    (define (%strip-cr s)
      ;; Remove all carriage returns so we can re-introduce canonical CRLF.
      (let ((out (open-output-string)))
        (string-for-each
         (lambda (c) (unless (char=? c #\return) (write-char c out)))
         s)
        (get-output-string out)))

    (define (%normalize-crlf s)
      ;; Convert any line ending (LF or CRLF) to canonical CRLF.
      (let ((out (open-output-string)))
        (string-for-each
         (lambda (c)
           (if (char=? c #\newline)
               (begin (write-char #\return out) (write-char #\newline out))
               (write-char c out)))
         (%strip-cr s))
        (get-output-string out)))

    (define (%wrap-base64 s width)
      ;; Insert CRLF every `width` characters (MIME requires lines <= 76).
      (let ((n (string-length s))
            (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((>= i n) (get-output-string out))
            (else
             (let ((end (min n (+ i width))))
               (write-string (substring s i end) out)
               (when (< end n) (write-string "\r\n" out))
               (loop end)))))))

    (define (rfc2047-encode-header s)
      "Syntax: (rfc2047-encode-header s)
Library: (scm net email)
Description: Returns s unchanged if it is pure ASCII, otherwise returns an
  RFC 2047 'encoded-word' carrying the UTF-8 bytes of s in Base64, i.e.
  =?utf-8?B?...?=. Used to make non-ASCII header values (such as a Subject)
  safe for transport.
Example:
  (rfc2047-encode-header \"Hello\") => \"Hello\"
  (rfc2047-encode-header \"grüezi\") => \"=?utf-8?B?Z3LDvGV6aQ==?=\""
      (if (email-ascii? s)
          s
          (string-append "=?utf-8?B?" (base64-encode (string->utf8 s)) "?=")))

    (define (rfc5322-date)
      "Syntax: (rfc5322-date)
Library: (scm net email)
Description: Returns the current date and time as an RFC 5322 date string in
  UTC, e.g. \"Sat, 20 Jun 2026 12:30:45 +0000\", suitable for a Date: header.
Example:
  (rfc5322-date) ; => \"Sat, 20 Jun 2026 12:30:45 +0000\""
      (string-append
       (date->string (current-date 0) "~a, ~d ~b ~Y ~H:~M:~S")
       " +0000"))

    (define (%domain-of addr)
      ;; Extract the domain part of an address (after the last @), stripping any
      ;; surrounding angle brackets; defaults to "localhost".
      (let* ((n (string-length addr)))
        (let loop ((i (- n 1)))
          (cond
            ((< i 0) "localhost")
            ((char=? (string-ref addr i) #\@)
             (let ((dom (substring addr (+ i 1) n)))
               (let ((dom (if (and (> (string-length dom) 0)
                                   (char=? (string-ref dom (- (string-length dom) 1))
                                           #\>))
                              (substring dom 0 (- (string-length dom) 1))
                              dom)))
                 (if (= (string-length dom) 0) "localhost" dom))))
            (else (loop (- i 1)))))))

    (define (%message-id from)
      (string-append "<"
                     (random-string "abcdefghijklmnopqrstuvwxyz0123456789" 24)
                     "@" (%domain-of from) ">"))

    (define (%join-addresses lst)
      (cond
        ((null? lst) "")
        ((null? (cdr lst)) (car lst))
        (else (string-append (car lst) ", " (%join-addresses (cdr lst))))))

    (define (%header out name value)
      (write-string name out)
      (write-string ": " out)
      (write-string value out)
      (write-string "\r\n" out))

    (define (email->string e)
      "Syntax: (email->string e)
Library: (scm net email)
Description: Serializes the email object e to an RFC 5322 message string with
  CRLF line endings: From, To, optional Cc, Subject (RFC 2047 encoded if it
  contains non-ASCII), an auto-generated Date and Message-ID, MIME-Version and
  a text/plain; charset=utf-8 body. An all-ASCII body is sent 7bit (human
  readable on the wire); a body containing non-ASCII is Base64 encoded. Bcc
  addresses are intentionally NOT included in the output (they go only into the
  envelope via email-recipients).
Example:
  (email->string (make-email \"a@x.com\" \"b@y.com\" \"Hi\" \"Hello\"))"
      (let ((out (open-output-string))
            (ascii? (email-ascii? (email-body e))))
        (%header out "From" (email-from e))
        (%header out "To" (%join-addresses (email-to e)))
        (unless (null? (email-cc e))
          (%header out "Cc" (%join-addresses (email-cc e))))
        (%header out "Subject" (rfc2047-encode-header (email-subject e)))
        (%header out "Date" (rfc5322-date))
        (%header out "Message-ID" (%message-id (email-from e)))
        ;; Any user-supplied extra headers (alist of name . value).
        (for-each (lambda (h) (%header out (car h) (cdr h))) (email-headers e))
        (%header out "MIME-Version" "1.0")
        (%header out "Content-Type" "text/plain; charset=utf-8")
        (%header out "Content-Transfer-Encoding" (if ascii? "7bit" "base64"))
        (write-string "\r\n" out)
        (if ascii?
            (write-string (%normalize-crlf (email-body e)) out)
            (write-string (%wrap-base64 (base64-encode (string->utf8 (email-body e))) 76)
                          out))
        (get-output-string out)))
))
