# `(scm net email)`

## Exports

### `email->string`

```
Syntax: (email->string e)
Library: (scm net email)
Description: Serializes the email object e to an RFC 5322 message string with
  CRLF line endings: From, To, optional Cc, Subject (RFC 2047 encoded if it
  contains non-ASCII), an auto-generated Date and Message-ID, MIME-Version and
  a text/plain; charset=utf-8 body. An all-ASCII body is sent 7bit (human
  readable on the wire); a body containing non-ASCII is Base64 encoded. Bcc
  addresses are intentionally NOT included in the output (they go only into the
  envelope via email-recipients).
Example:
  (email->string (make-email "a@x.com" "b@y.com" "Hi" "Hello"))
```

### `email-ascii?`

```
Syntax: (email-ascii? s)
Library: (scm net email)
Description: Returns #t if every character of string s is a US-ASCII character
  (code point below 128), otherwise #f. Used to decide whether headers or body
  need transfer encoding.
Example:
  (email-ascii? "hello") => #t
  (email-ascii? "grüezi") => #f
```

### `email-bcc`

*(no documentation)*

### `email-body`

*(no documentation)*

### `email-cc`

*(no documentation)*

### `email-from`

*(no documentation)*

### `email-headers`

*(no documentation)*

### `email-recipients`

```
Syntax: (email-recipients e)
Library: (scm net email)
Description: Returns the full list of envelope recipient addresses for the email
  e: every To, Cc and Bcc address concatenated. This is the list to pass to RCPT
  TO when sending; the Bcc addresses are deliberately excluded from the rendered
  headers but still receive the message.
Example:
  (email-recipients (make-email "a@x" "b@y" "s" "body")) => ("b@y")
```

### `email-subject`

*(no documentation)*

### `email-to`

*(no documentation)*

### `email?`

*(no documentation)*

### `make-email`

```
Syntax: (make-email from to subject body)
Syntax: (make-email from to subject body cc)
Syntax: (make-email from to subject body cc bcc)
Library: (scm net email)
Description: Builds a plain-text email message object. from is a single address
  string. to, cc and bcc are each either a single address string or a list of
  address strings (cc and bcc default to the empty list). subject and body are
  strings (UTF-8 is supported in both). Use email->string to serialize the
  message to RFC 5322 wire format, or send it with send-email from (scm net smtp).
Example:
  (make-email "me@example.com" "you@example.com" "Hi" "Hello there")
  (make-email "me@x.com" (list "a@y.com" "b@y.com") "Subj" "Body")
```

### `rfc2047-encode-header`

```
Syntax: (rfc2047-encode-header s)
Library: (scm net email)
Description: Returns s unchanged if it is pure ASCII, otherwise returns an
  RFC 2047 'encoded-word' carrying the UTF-8 bytes of s in Base64, i.e.
  =?utf-8?B?...?=. Used to make non-ASCII header values (such as a Subject)
  safe for transport.
Example:
  (rfc2047-encode-header "Hello") => "Hello"
  (rfc2047-encode-header "grüezi") => "=?utf-8?B?Z3LDvGV6aQ==?="
```

### `rfc5322-date`

```
Syntax: (rfc5322-date)
Library: (scm net email)
Description: Returns the current date and time as an RFC 5322 date string in
  UTC, e.g. "Sat, 20 Jun 2026 12:30:45 +0000", suitable for a Date: header.
Example:
  (rfc5322-date) ; => "Sat, 20 Jun 2026 12:30:45 +0000"
```

