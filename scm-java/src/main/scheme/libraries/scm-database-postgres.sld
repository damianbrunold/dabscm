(define-library (scm database postgres)
  (import (scm core) (scheme base) (scheme inexact) (scm crypto) (scm net sockets) (srfi 18))
  (export pg-connect
          pg-close
          pg-query
          pg-exec
          pg-result-columns
          pg-result-rows
          pg-result->alist-list
          pg-cursor-open
          pg-cursor-fetch
          pg-cursor-columns
          pg-cursor-close
          pg-cursor-for-each
          with-pg-connection
          with-pg-query
          pg-quote-literal
          pg-quote-int
          pg-format-sql
          ;; Connection pool
          make-pg-pool
          pg-pool?
          pg-pool-checkout
          pg-pool-checkin
          pg-pool-close-all!
          with-pg-pool-connection)
  (begin

    ;; --- Wire protocol helpers ---

    ;; Write big-endian 32-bit unsigned integer to binary output port
    (define (pg-write-u32! val port)
      "Syntax: (pg-write-u32! val port)
Library: (scm database postgres)
Description: Writes a 32-bit unsigned integer to a binary output port in big-endian byte order.
Example:
  (pg-write-u32! #x00030000 out)"
      (write-u8 (modulo (quotient val #x1000000) 256) port)
      (write-u8 (modulo (quotient val #x10000) 256) port)
      (write-u8 (modulo (quotient val #x100) 256) port)
      (write-u8 (modulo val 256) port))

    ;; Read big-endian 32-bit unsigned integer from binary input port
    (define (pg-read-u32! port)
      "Syntax: (pg-read-u32! port)
Library: (scm database postgres)
Description: Reads a 32-bit unsigned integer from a binary input port in big-endian byte order.
Example:
  (pg-read-u32! in) => 196608"
      (+ (* (read-u8 port) #x1000000)
         (* (read-u8 port) #x10000)
         (* (read-u8 port) #x100)
         (read-u8 port)))

    ;; Read big-endian 32-bit signed integer from binary input port
    (define (pg-read-i32! port)
      "Syntax: (pg-read-i32! port)
Library: (scm database postgres)
Description: Reads a 32-bit signed integer from a binary input port in big-endian byte order.
  Returns -1 for NULL column lengths in DataRow messages.
Example:
  (pg-read-i32! in) => -1"
      (let ((u (pg-read-u32! port)))
        (if (>= u #x80000000)
            (- u #x100000000)
            u)))

    ;; Read big-endian 16-bit unsigned integer from binary input port
    (define (pg-read-u16! port)
      "Syntax: (pg-read-u16! port)
Library: (scm database postgres)
Description: Reads a 16-bit unsigned integer from a binary input port in big-endian byte order.
Example:
  (pg-read-u16! in) => 3"
      (+ (* (read-u8 port) 256) (read-u8 port)))

    ;; Write null-terminated UTF-8 string to binary output port
    (define (pg-write-string! s port)
      "Syntax: (pg-write-string! s port)
Library: (scm database postgres)
Description: Writes a null-terminated UTF-8 encoded string to a binary output port.
Example:
  (pg-write-string! \"user\" out)"
      (write-bytevector (string->utf8 s) port)
      (write-u8 0 port))

    ;; Read null-terminated string from binary input port
    (define (pg-read-string! port)
      "Syntax: (pg-read-string! port)
Library: (scm database postgres)
Description: Reads a null-terminated UTF-8 string from a binary input port.
  Returns the decoded string without the terminating null byte.
Example:
  (pg-read-string! in) => \"alice\""
      (let loop ((acc '()))
        (let ((b (read-u8 port)))
          (if (or (eof-object? b) (= b 0))
              (utf8->string (apply bytevector (reverse acc)))
              (loop (cons b acc))))))

    ;; Read exactly n bytes from binary input port
    (define (pg-read-bytes! n port)
      "Syntax: (pg-read-bytes! n port)
Library: (scm database postgres)
Description: Reads exactly n bytes from a binary input port and returns them as a bytevector.
Example:
  (pg-read-bytes! 4 in)"
      (read-bytevector n port))

    ;; Read big-endian 32-bit unsigned integer from bytevector at offset
    (define (pg-bv-u32 bv off)
      "Syntax: (pg-bv-u32 bv off)
Library: (scm database postgres)
Description: Reads a 32-bit unsigned integer in big-endian byte order from bytevector bv
  starting at byte offset off.
Example:
  (pg-bv-u32 body 0) => 0"
      (+ (* (bytevector-u8-ref bv off) #x1000000)
         (* (bytevector-u8-ref bv (+ off 1)) #x10000)
         (* (bytevector-u8-ref bv (+ off 2)) #x100)
         (bytevector-u8-ref bv (+ off 3))))

    ;; --- Message framing ---

    ;; Send a typed message: type-byte followed by int32(4+payload-length) and payload
    (define (pg-send-message! out type-byte payload-bv)
      "Syntax: (pg-send-message! out type-byte payload-bv)
Library: (scm database postgres)
Description: Sends a framed PostgreSQL frontend message: a single type byte, a 32-bit
  length (4 + payload length), and the payload bytevector.
Example:
  (pg-send-message! out 81 query-bv)"
      (write-u8 type-byte out)
      (pg-write-u32! (+ 4 (bytevector-length payload-bv)) out)
      (write-bytevector payload-bv out))

    ;; Read next message: returns (type-byte . body-bytevector)
    (define (pg-read-message! in)
      "Syntax: (pg-read-message! in)
Library: (scm database postgres)
Description: Reads one framed PostgreSQL backend message. Returns a pair
  (type-byte . body-bytevector) where body excludes the 4-byte length prefix.
Example:
  (pg-read-message! in) => (90 . #u8())"
      (let* ((type (read-u8 in))
             (len  (pg-read-u32! in))
             (body (pg-read-bytes! (- len 4) in)))
        (cons type body)))

    ;; --- Startup message (no type byte) ---

    (define (pg-send-startup! out user database)
      "Syntax: (pg-send-startup! out user database)
Library: (scm database postgres)
Description: Sends the PostgreSQL startup message (protocol 3.0) with the given user
  and database name. This message has no type byte, only a length-prefixed body.
Example:
  (pg-send-startup! out \"alice\" \"mydb\")"
      (let ((bv (open-output-bytevector)))
        (pg-write-u32! #x00030000 bv)       ; protocol version 3.0
        (pg-write-string! "user" bv)
        (pg-write-string! user bv)
        (pg-write-string! "database" bv)
        (pg-write-string! database bv)
        (write-u8 0 bv)                     ; parameter list terminator
        (let* ((payload (get-output-bytevector bv))
               (len (+ 4 (bytevector-length payload))))
          (pg-write-u32! len out)
          (write-bytevector payload out))))

    ;; --- Error response parsing ---

    ;; Extracts the 'M' (message) field from an ErrorResponse body
    (define (pg-parse-error body)
      "Syntax: (pg-parse-error body)
Library: (scm database postgres)
Description: Parses an ErrorResponse body bytevector and returns the human-readable
  message field ('M'). Returns an empty string if no message field is present.
Example:
  (pg-parse-error body) => \"relation \\\"foo\\\" does not exist\""
      (let ((bv-in (open-input-bytevector body)))
        (let loop ((msg ""))
          (let ((code (read-u8 bv-in)))
            (cond
              ((or (eof-object? code) (= code 0)) msg)
              ((= code 77)                         ; 'M' = human-readable message
               (loop (pg-read-string! bv-in)))
              (else
               (pg-read-string! bv-in)             ; discard field value
               (loop msg)))))))

    ;; --- Wait for ReadyForQuery ---

    ;; Consumes messages until ReadyForQuery ('Z') is received
    (define (pg-wait-ready! in)
      "Syntax: (pg-wait-ready! in)
Library: (scm database postgres)
Description: Reads and discards backend messages until a ReadyForQuery ('Z') message
  is received. Raises an error if an ErrorResponse ('E') is encountered.
Example:
  (pg-wait-ready! in)"
      (let loop ()
        (let* ((msg (pg-read-message! in))
               (type (car msg)))
          (cond
            ((= type 90) #t)                       ; Z = ReadyForQuery
            ((= type 69)                           ; E = ErrorResponse
             (error "pg: backend error" (pg-parse-error (cdr msg))))
            (else (loop))))))

    ;; --- MD5 password authentication ---

    ;; Computes PostgreSQL MD5 password: "md5" + md5hex(md5hex(password+user) + salt)
    (define (pg-md5-password password user salt-bv)
      "Syntax: (pg-md5-password password user salt-bv)
Library: (scm database postgres)
Description: Computes the PostgreSQL MD5 password hash: the string \"md5\" concatenated
  with md5hex(md5hex(password || user) || salt). Returns the result as a string.
Example:
  (pg-md5-password \"secret\" \"alice\" salt) => \"md5abc123...\""
      (let* ((inner (md5-hash (string-append password user)))
             (combined (bytevector-append (string->utf8 inner) salt-bv))
             (outer (md5-hash combined)))
        (string-append "md5" outer)))

    ;; --- SCRAM-SHA-256 authentication ---

    ;; Split a string on comma characters
    (define (pg-scram-split s)
      "Syntax: (pg-scram-split s)
Library: (scm database postgres)
Description: Splits a string on comma characters and returns a list of substrings.
  Used to parse SCRAM server messages.
Example:
  (pg-scram-split \"r=nonce,s=salt,i=4096\") => (\"r=nonce\" \"s=salt\" \"i=4096\")"
      (let loop ((i 0) (start 0) (acc '()))
        (cond
          ((= i (string-length s))
           (reverse (cons (substring s start i) acc)))
          ((char=? (string-ref s i) #\,)
           (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else
           (loop (+ i 1) start acc)))))

    ;; Find "key=value" in a list of strings and return the value
    (define (pg-scram-field parts key)
      "Syntax: (pg-scram-field parts key)
Library: (scm database postgres)
Description: Searches a list of \"key=value\" strings for the given key and returns the
  value portion. Raises an error if the key is not found.
Example:
  (pg-scram-field '(\"r=nonce\" \"s=salt\" \"i=4096\") \"s\") => \"salt\""
      (let ((prefix (string-append key "=")))
        (let loop ((parts parts))
          (cond
            ((null? parts) (error "pg: SCRAM missing field" key))
            ((and (>= (string-length (car parts)) (string-length prefix))
                  (string=? (substring (car parts) 0 (string-length prefix)) prefix))
             (substring (car parts) (string-length prefix) (string-length (car parts))))
            (else (loop (cdr parts)))))))

    ;; Perform SCRAM-SHA-256 exchange (called after AuthenticationSASL is received)
    (define (pg-do-scram! in out user password)
      "Syntax: (pg-do-scram! in out user password)
Library: (scm database postgres)
Description: Performs the full SCRAM-SHA-256 authentication exchange on the given
  input/output ports. Sends SASLInitialResponse and SASLResponse, verifies the
  server signature, and expects AuthenticationOk at the end.
Example:
  (pg-do-scram! in out \"alice\" \"secret\")"
      (let* ((cnonce    (base64-encode (random-bytes 18)))
             (cfm-bare  (string-append "n=" user ",r=" cnonce))
             (cfm       (string-append "n,," cfm-bare))
             (cfm-bv    (string->utf8 cfm))
             (payload   (open-output-bytevector)))
        ;; Send SASLInitialResponse
        (write-bytevector (string->utf8 "SCRAM-SHA-256") payload)
        (write-u8 0 payload)
        (pg-write-u32! (bytevector-length cfm-bv) payload)
        (write-bytevector cfm-bv payload)
        (pg-send-message! out 112 (get-output-bytevector payload))   ; 'p'

        ;; Read AuthenticationSASLContinue (body[0..3]=11, body[4..]=server-first-message)
        (let* ((msg       (pg-read-message! in))
               (body      (cdr msg))
               (_ (if (= (car msg) 69)
                      (error "pg: SCRAM authentication failed" (pg-parse-error body))))
               (sfm       (utf8->string (bytevector-copy body 4 (bytevector-length body))))
               (parts     (pg-scram-split sfm))
               (full-nonce (pg-scram-field parts "r"))
               (b64-salt  (pg-scram-field parts "s"))
               (iterations (string->number (pg-scram-field parts "i")))
               (salt      (base64-decode b64-salt)))

          ;; Derive keys
          (let* ((salted-pw   (pbkdf2-sha256 password salt iterations 32))
                 (client-key  (hmac-sha256 salted-pw (string->utf8 "Client Key")))
                 (stored-key  (sha256-hash client-key))
                 (cfm-no-proof (string-append "c=biws,r=" full-nonce))
                 (auth-msg    (string-append cfm-bare "," sfm "," cfm-no-proof))
                 (client-sig  (hmac-sha256 stored-key (string->utf8 auth-msg)))
                 (client-proof (xor-key client-key client-sig))
                 (cfm-final   (string-append cfm-no-proof ",p=" (base64-encode client-proof)))
                 ;; Server signature for verification
                 (server-key  (hmac-sha256 salted-pw (string->utf8 "Server Key")))
                 (server-sig  (hmac-sha256 server-key (string->utf8 auth-msg)))
                 (b64-server-sig (base64-encode server-sig))
                 (resp        (open-output-bytevector)))

            ;; Send SASLResponse
            (write-bytevector (string->utf8 cfm-final) resp)
            (pg-send-message! out 112 (get-output-bytevector resp))   ; 'p'

            ;; Read AuthenticationSASLFinal (body[0..3]=12, body[4..]=server-final-message)
            (let* ((final-msg  (pg-read-message! in))
                   (final-body (cdr final-msg))
                   (_ (if (= (car final-msg) 69)
                          (error "pg: SCRAM authentication failed" (pg-parse-error final-body))))
                   (final-str  (utf8->string (bytevector-copy final-body 4
                                                              (bytevector-length final-body))))
                   (fparts     (pg-scram-split final-str))
                   (server-v   (pg-scram-field fparts "v")))
              (if (not (string=? server-v b64-server-sig))
                  (error "pg: SCRAM server signature mismatch"))

              ;; Read AuthenticationOk
              (let* ((ok-msg  (pg-read-message! in))
                     (ok-auth (pg-bv-u32 (cdr ok-msg) 0)))
                (if (not (= ok-auth 0))
                    (error "pg: SCRAM expected AuthenticationOk"))
                #t))))))

    ;; --- Authentication dispatch ---

    ;; Handle authentication exchange after startup; reads until AuthenticationOk
    (define (pg-handle-auth! in out user password)
      "Syntax: (pg-handle-auth! in out user password)
Library: (scm database postgres)
Description: Handles the authentication phase after the startup message. Dispatches on
  the authentication type: trust (0), MD5 (5), or SCRAM-SHA-256 (10). Raises an error
  for unsupported authentication types.
Example:
  (pg-handle-auth! in out \"alice\" \"secret\")"
      (let* ((msg  (pg-read-message! in))
             (type (car msg))
             (body (cdr msg)))
        (if (not (= type 82))                         ; R = AuthenticationRequest
            (error "pg: expected authentication message, got" type)
            (let ((auth-type (pg-bv-u32 body 0)))
              (cond
                ((= auth-type 0)                      ; AuthenticationOk (trust)
                 #t)
                ((= auth-type 5)                      ; AuthenticationMD5Password
                 (let* ((salt (bytevector-copy body 4 8))
                        (pw   (pg-md5-password password user salt))
                        (bv   (open-output-bytevector)))
                   (pg-write-string! pw bv)
                   (pg-send-message! out 112 (get-output-bytevector bv)))    ; 'p'
                 ;; Read AuthenticationOk
                 (let* ((msg2  (pg-read-message! in))
                        (auth2 (pg-bv-u32 (cdr msg2) 0)))
                   (if (not (= auth2 0))
                       (error "pg: MD5 authentication failed")))
                 #t)
                ((= auth-type 10)                     ; AuthenticationSASL (SCRAM)
                 (pg-do-scram! in out user password)
                 #t)
                (else
                 (error "pg: unsupported authentication type" auth-type)))))))

    ;; --- Connection lifecycle ---

    ;; Connect to PostgreSQL; returns a connection vector #(in out socket)
    (define (pg-connect host port user password database)
      "Syntax: (pg-connect host port user password database)
Library: (scm database postgres)
Description: Opens a TCP connection to a PostgreSQL server and performs authentication.
  Supports trust, MD5, and SCRAM-SHA-256 authentication. Returns a connection object.
Example:
  (define conn (pg-connect \"localhost\" 5432 \"alice\" \"secret\" \"mydb\"))"
      (let* ((sock (tcp-connect host port))
             (in   (socket-binary-input-port sock))
             (out  (socket-binary-output-port sock)))
        (pg-send-startup! out user database)
        (pg-handle-auth! in out user password)
        (pg-wait-ready! in)
        (vector in out sock)))

    ;; Close a PostgreSQL connection
    (define (pg-close conn)
      "Syntax: (pg-close conn)
Library: (scm database postgres)
Description: Closes the TCP connection to the PostgreSQL server.
Example:
  (pg-close conn)"
      (socket-close (vector-ref conn 2)))

    ;; --- Result set parsing ---

    ;; Parse a RowDescription body; returns a vector of column name strings
    (define (pg-parse-rowdesc body)
      "Syntax: (pg-parse-rowdesc body)
Library: (scm database postgres)
Description: Parses a RowDescription message body and returns a vector of column name strings.
Example:
  (pg-parse-rowdesc body) => #(\"id\" \"name\")"
      (let* ((bv-in (open-input-bytevector body))
             (ncols (pg-read-u16! bv-in)))
        (let loop ((i 0) (names '()))
          (if (= i ncols)
              (list->vector (reverse names))
              (let* ((name (pg-read-string! bv-in))
                     (_    (pg-read-bytes! 18 bv-in)))   ; skip: tableOID(4) colNum(2) typeOID(4) typeSize(2) typeMod(4) format(2)
                (loop (+ i 1) (cons name names)))))))

    ;; Parse a DataRow body; returns a vector of string values (or #f for NULL)
    (define (pg-parse-datarow cols body)
      "Syntax: (pg-parse-datarow cols body)
Library: (scm database postgres)
Description: Parses a DataRow message body given the column name vector cols. Returns a
  vector of string values, one per column, with #f for NULL values and \"\" for zero-length values.
Example:
  (pg-parse-datarow #(\"id\" \"name\") body) => #(\"1\" \"alice\")"
      (let* ((bv-in (open-input-bytevector body))
             (ncols (pg-read-u16! bv-in)))
        (let loop ((i 0) (vals '()))
          (if (= i ncols)
              (list->vector (reverse vals))
              (let* ((len (pg-read-i32! bv-in))
                     (val (cond ((= len -1) #f)
                               ((= len  0) "")
                               (else (utf8->string (pg-read-bytes! len bv-in))))))
                (loop (+ i 1) (cons val vals)))))))

    ;; Read messages until ReadyForQuery; returns a result vector #(cols-vector rows-list)
    (define (pg-read-result! in)
      "Syntax: (pg-read-result! in)
Library: (scm database postgres)
Description: Reads backend messages until ReadyForQuery, collecting RowDescription and
  DataRow messages. Returns a result vector #(cols rows) where cols is a column name
  vector and rows is a list of row vectors.
Example:
  (pg-read-result! in) => #(#(\"id\" \"name\") (#(\"1\" \"alice\")))"
      (let loop ((cols #f) (rows '()))
        (let* ((msg  (pg-read-message! in))
               (type (car msg))
               (body (cdr msg)))
          (cond
            ((= type 84)                             ; T = RowDescription
             (loop (pg-parse-rowdesc body) rows))
            ((= type 68)                             ; D = DataRow
             (loop cols (cons (pg-parse-datarow cols body) rows)))
            ((= type 67)                             ; C = CommandComplete
             (loop cols rows))
            ((= type 73)                             ; I = EmptyQueryResponse
             (loop cols rows))
            ((= type 78)                             ; N = NoticeResponse
             (loop cols rows))
            ((= type 90)                             ; Z = ReadyForQuery
             (vector (or cols (vector)) (reverse rows)))
            ((= type 69)                             ; E = ErrorResponse
             (error "pg: query error" (pg-parse-error body)))
            (else (loop cols rows))))))

    ;; --- Query execution ---

    ;; Execute a query and return a result object
    (define (pg-query conn sql . params)
      "Syntax: (pg-query conn sql [param ...])
Library: (scm database postgres)
Description: Executes a SQL query and returns a result object containing
  column names and rows. Use pg-result-columns and pg-result-rows to
  access the result.

  If params are supplied, the sql string is treated as a template with
  $1, $2, ... placeholders that are substituted with the corresponding
  param values. See pg-format-sql for the conversion rules. With no
  params, sql is sent verbatim.
Example:
  (pg-query conn \"SELECT * FROM users\")
  (pg-query conn \"SELECT * FROM users WHERE id = $1\" 42)
  (pg-query conn \"SELECT * FROM users WHERE name = $1 AND age > $2\"
            \"Ada\" 30)"
      (let* ((sql (cond ((null? params) sql)
                        (else (pg-format-sql sql params))))
             (in  (vector-ref conn 0))
             (out (vector-ref conn 1))
             (bv  (open-output-bytevector)))
        (pg-write-string! sql bv)
        (pg-send-message! out 81 (get-output-bytevector bv))   ; 'Q'
        (pg-read-result! in)))

    ;; Execute a statement and discard the result (for DDL/DML)
    (define (pg-exec conn sql . params)
      "Syntax: (pg-exec conn sql [param ...])
Library: (scm database postgres)
Description: Executes a SQL statement and discards the result. Suitable
  for DDL and DML statements such as CREATE TABLE, INSERT, UPDATE, and
  DELETE.

  If params are supplied, the sql string is a template with $1, $2, ...
  placeholders substituted via pg-format-sql.
Example:
  (pg-exec conn \"INSERT INTO users (name) VALUES ('alice')\")
  (pg-exec conn \"INSERT INTO users (name, age) VALUES ($1, $2)\"
           \"Ada\" 36)"
      (let* ((sql (cond ((null? params) sql)
                        (else (pg-format-sql sql params))))
             (in  (vector-ref conn 0))
             (out (vector-ref conn 1))
             (bv  (open-output-bytevector)))
        (pg-write-string! sql bv)
        (pg-send-message! out 81 (get-output-bytevector bv))   ; 'Q'
        (let loop ()
          (let* ((msg  (pg-read-message! in))
                 (type (car msg)))
            (cond
              ((= type 90) #t)                       ; Z = ReadyForQuery
              ((= type 69)                           ; E = ErrorResponse
               (error "pg: exec error" (pg-parse-error (cdr msg))))
              (else (loop)))))))

    ;; --- Public result accessors ---

    ;; Returns the column name vector from a result
    (define (pg-result-columns result)
      "Syntax: (pg-result-columns result)
Library: (scm database postgres)
Description: Returns the column name vector from a query result.
Example:
  (pg-result-columns result) => #(\"id\" \"name\")"
      (vector-ref result 0))

    ;; Returns the list of row vectors from a result
    (define (pg-result-rows result)
      "Syntax: (pg-result-rows result)
Library: (scm database postgres)
Description: Returns the list of row vectors from a query result. Each row is a vector of
  string values, or #f for NULL values.
Example:
  (pg-result-rows result) => (#(\"1\" \"alice\") #(\"2\" \"bob\"))"
      (vector-ref result 1))

    ;; Converts a result to a list of association lists ((col . val) ...)
    (define (pg-result->alist-list result)
      "Syntax: (pg-result->alist-list result)
Library: (scm database postgres)
Description: Converts a query result to a list of association lists, one per row.
  Each alist maps column name strings to value strings (or #f for NULL).
Example:
  (pg-result->alist-list result) => ((\"id\" . \"1\") (\"name\" . \"alice\")) ...)"
      (let ((cols (pg-result-columns result))
            (rows (pg-result-rows result)))
        (map (lambda (row)
               (let loop ((i 0) (acc '()))
                 (if (= i (vector-length cols))
                     (reverse acc)
                     (loop (+ i 1)
                           (cons (cons (vector-ref cols i) (vector-ref row i))
                                 acc)))))
             rows)))

    ;; --- Cursor API ---

    (define *pg-cursor-counter* 0)

    (define (pg-cursor-next-name!)
      "Syntax: (pg-cursor-next-name!)
Library: (scm database postgres)
Description: Generates a unique server-side cursor name by incrementing a global counter.
  Returns a string of the form \"pg_cursor_N\".
Example:
  (pg-cursor-next-name!) => \"pg_cursor_1\""
      (set! *pg-cursor-counter* (+ *pg-cursor-counter* 1))
      (string-append "pg_cursor_" (number->string *pg-cursor-counter*)))

    (define (pg-cursor-open conn sql)
      "Syntax: (pg-cursor-open conn sql)
Library: (scm database postgres)
Description: Opens a server-side cursor for the given SQL query. Returns a cursor object.
  The query runs inside a transaction; call pg-cursor-close when done.
Example:
  (define cur (pg-cursor-open conn \"SELECT id, name FROM users ORDER BY id\"))"
      (let ((name (pg-cursor-next-name!)))
        (pg-exec conn "BEGIN")
        (guard (exn (#t
                     (guard (e (#t #f)) (pg-exec conn "ROLLBACK"))
                     (raise exn)))
          (pg-exec conn (string-append "DECLARE " name " NO SCROLL CURSOR FOR " sql)))
        (vector conn name #f #f)))

    (define (pg-cursor-fetch cursor . rest)
      "Syntax: (pg-cursor-fetch cursor [n])
Library: (scm database postgres)
Description: Fetches up to n rows from cursor (default 1). Returns a list of row vectors.
  Returns an empty list when the cursor is exhausted.
Example:
  (pg-cursor-fetch cur 100)"
      (if (vector-ref cursor 3)
          '()
          (let* ((n    (if (null? rest) 1 (car rest)))
                 (conn (vector-ref cursor 0))
                 (name (vector-ref cursor 1)))
            (guard (exn (#t
                         (vector-set! cursor 3 #t)
                         (guard (e (#t #f)) (pg-exec conn "ROLLBACK"))
                         (raise exn)))
              (let* ((result (pg-query conn (string-append "FETCH " (number->string n) " FROM " name)))
                     (cols   (pg-result-columns result))
                     (rows   (pg-result-rows result)))
                (if (not (vector-ref cursor 2))
                    (vector-set! cursor 2 cols))
                (if (null? rows)
                    (begin (vector-set! cursor 3 #t) '())
                    rows))))))

    (define (pg-cursor-columns cursor)
      "Syntax: (pg-cursor-columns cursor)
Library: (scm database postgres)
Description: Returns the column name vector for the cursor, or #f before the first fetch.
Example:
  (pg-cursor-columns cur) => #(\"id\" \"name\")"
      (vector-ref cursor 2))

    (define (pg-cursor-close cursor)
      "Syntax: (pg-cursor-close cursor)
Library: (scm database postgres)
Description: Closes the cursor and commits the transaction. Returns #t. Safe to call
  multiple times; subsequent calls are no-ops.
Example:
  (pg-cursor-close cur)"
      (if (vector-ref cursor 3)
          #t
          (let ((conn (vector-ref cursor 0))
                (name (vector-ref cursor 1)))
            (pg-exec conn (string-append "CLOSE " name))
            (pg-exec conn "COMMIT")
            (vector-set! cursor 3 #t)
            #t)))

    (define (pg-cursor-for-each cursor proc . rest)
      "Syntax: (pg-cursor-for-each cursor proc [batch-size])
Library: (scm database postgres)
Description: Calls proc on each row vector from cursor in batches (default 100).
  Automatically closes the cursor when all rows are consumed.
Example:
  (pg-cursor-for-each cur (lambda (row) (display (vector-ref row 0))) 50)"
      (let ((batch (if (null? rest) 100 (car rest))))
        (let loop ()
          (let ((rows (pg-cursor-fetch cursor batch)))
            (if (null? rows)
                (pg-cursor-close cursor)
                (begin
                  (for-each proc rows)
                  (loop)))))))

    ;; --- Resource-safe wrappers ---

    (define (with-pg-connection host port user password database proc)
      "Syntax: (with-pg-connection host port user password database proc)
Library: (scm database postgres)
Description: Opens a connection, calls (proc conn), and closes the connection on exit,
  even if an exception is raised.
Example:
  (with-pg-connection \"localhost\" 5432 \"user\" \"pass\" \"db\"
    (lambda (conn) (display (pg-result->alist-list (pg-query conn \"SELECT 1\")))))"
      (let ((conn (pg-connect host port user password database)))
        (guard (exn (#t (pg-close conn) (raise exn)))
          (let ((result (proc conn)))
            (pg-close conn)
            result))))

    (define (with-pg-query host port user password database sql proc)
      "Syntax: (with-pg-query host port user password database sql proc)
Library: (scm database postgres)
Description: Opens a connection and cursor, calls (proc conn cursor), and closes both
  on exit, even if an exception is raised.
Example:
  (with-pg-query \"localhost\" 5432 \"user\" \"pass\" \"db\" \"SELECT * FROM t\"
    (lambda (conn cursor) (pg-cursor-for-each cursor display)))"
      (with-pg-connection host port user password database
        (lambda (conn)
          (let ((cursor (pg-cursor-open conn sql)))
            (guard (exn (#t (pg-cursor-close cursor) (raise exn)))
              (let ((result (proc conn cursor)))
                (pg-cursor-close cursor)
                result))))))

    ;; --- SQL quoting ---
    ;;
    ;; These are escape-then-concatenate helpers for callers who build SQL
    ;; as strings. Always pass user-controlled values through these — never
    ;; splice raw strings into SQL. When (scm database postgres) gains
    ;; parameter binding (Parse/Bind/Execute via the Extended Query
    ;; protocol), prefer that over quoting; these helpers will remain for
    ;; the cases where building the SQL text dynamically is simpler.

    (define (pg-quote-literal s)
      "Syntax: (pg-quote-literal s)
Library: (scm database postgres)
Description: Returns s wrapped in single quotes with internal single quotes
  doubled — the SQL standard string-literal escape, safe under PostgreSQL's
  default standard_conforming_strings=on (i.e. backslashes are literal).
  Use for any user-controlled string interpolated into SQL.
Example:
  (pg-quote-literal \"O'Brien\") => \"'O''Brien'\"
  (pg-quote-literal \"\\\\n\")    => \"'\\\\n'\""
      (let* ((n (string-length s))
             (out (open-output-string)))
        (write-char #\' out)
        (let loop ((i 0))
          (cond
            ((= i n)
             (write-char #\' out)
             (get-output-string out))
            (else
             (let ((c (string-ref s i)))
               (cond ((char=? c #\') (write-string "''" out))
                     (else           (write-char c out)))
               (loop (+ i 1))))))))

    (define (pg-quote-int n)
      "Syntax: (pg-quote-int n)
Library: (scm database postgres)
Description: Returns the decimal representation of an integer n, validated as
  integer. Accepts an integer or a numeric string. Raises an error for any
  other input, preventing callers from accidentally splicing arbitrary text
  through what was intended to be a numeric parameter.
Example:
  (pg-quote-int 42)   => \"42\"
  (pg-quote-int \"42\") => \"42\"
  (pg-quote-int \"x\") raises an error"
      (cond
        ((integer? n) (number->string n))
        ((string? n)
         (let ((parsed (string->number n)))
           (cond ((and parsed (integer? parsed)) (number->string parsed))
                 (else (error "pg-quote-int: not an integer string" n)))))
        (else (error "pg-quote-int: not an integer" n))))

    ;; ============================================================
    ;; Parameterized SQL — library-side substitution
    ;;
    ;; pg-format-sql replaces $N placeholders in a SQL template with
    ;; properly-escaped literals from the params list. It is the only
    ;; documented way to interpolate user data into SQL; callers that
    ;; use it cannot leak unescaped values through it.
    ;;
    ;; Conversion (Scheme value → SQL literal):
    ;;   #f                 → NULL          (symmetric with reads)
    ;;   #t                 → TRUE
    ;;   integer            → 42
    ;;   real / rational    → 3.14          (converted via inexact)
    ;;   string             → 'doubled'     (pg-quote-literal style)
    ;;   bytevector         → '\\xHEX'::bytea
    ;;   anything else      → error
    ;;
    ;; The parser tracks string literals ('...' with '' escape),
    ;; quoted identifiers ("..." with "" escape), line and block
    ;; comments, and dollar-quoted strings ($tag$...$tag$ and $$...$$);
    ;; $N inside any of those is passed through verbatim, not
    ;; substituted. $0 raises; $N with N > param-count raises.
    ;; ============================================================

    (define (%pg-hex-nibble n)
      (cond ((< n 10) (integer->char (+ (char->integer #\0) n)))
            (else    (integer->char (+ (char->integer #\a) (- n 10))))))

    (define (%pg-bytea-literal bv)
      (let* ((n (bytevector-length bv))
             (out (open-output-string)))
        (write-string "'\\x" out)
        (let loop ((i 0))
          (cond
            ((= i n) (write-string "'::bytea" out) (get-output-string out))
            (else
             (let* ((b  (bytevector-u8-ref bv i))
                    (hi (quotient b 16))
                    (lo (modulo b 16)))
               (write-char (%pg-hex-nibble hi) out)
               (write-char (%pg-hex-nibble lo) out)
               (loop (+ i 1))))))))

    (define (%pg-sql-literal v)
      ;; Returns the SQL literal text for a Scheme value, or raises.
      (cond
        ((not v)            "NULL")            ; #f → NULL
        ((eq? v #t)         "TRUE")
        ((string? v)        (pg-quote-literal v))
        ((integer? v)       (number->string v))
        ((real? v)          (number->string (inexact v)))
        ((bytevector? v)    (%pg-bytea-literal v))
        (else (error "pg-format-sql: cannot encode as SQL literal" v))))

    (define (pg-format-sql sql params)
      "Syntax: (pg-format-sql sql params)
Library: (scm database postgres)
Description: Returns sql with $1, $2, ... placeholders substituted by
  the corresponding (1-indexed) values from the params list, each
  converted to a properly-escaped SQL literal. Substitution is skipped
  inside string literals, quoted identifiers, comments, and dollar-
  quoted strings. Raises on $0, $N out of range, or a param of an
  unsupported type.
Example:
  (pg-format-sql \"WHERE slug = $1 AND age > $2\" '(\"a'b\" 18))
  => \"WHERE slug = 'a''b' AND age > 18\""
      (let* ((n         (string-length sql))
             (params-vec (list->vector params))
             (n-params  (vector-length params-vec))
             (out       (open-output-string)))
        (define (at i) (string-ref sql i))
        (define (eq-at? i ch) (and (< i n) (char=? (at i) ch)))
        (define (digit-at? i)
          (and (< i n)
               (let ((c (at i)))
                 (and (char>=? c #\0) (char<=? c #\9)))))
        (define (ident-start-at? i)
          (and (< i n)
               (let ((c (at i)))
                 (or (and (char>=? c #\a) (char<=? c #\z))
                     (and (char>=? c #\A) (char<=? c #\Z))
                     (char=? c #\_)))))
        (define (ident-char-at? i)
          (and (< i n)
               (let ((c (at i)))
                 (or (and (char>=? c #\a) (char<=? c #\z))
                     (and (char>=? c #\A) (char<=? c #\Z))
                     (and (char>=? c #\0) (char<=? c #\9))
                     (char=? c #\_)))))
        (define (write-param! idx)
          (cond
            ((or (< idx 1) (> idx n-params))
             (error (string-append "pg-format-sql: $"
                                   (number->string idx)
                                   " but only "
                                   (number->string n-params)
                                   " param(s) supplied")))
            (else
             (write-string (%pg-sql-literal (vector-ref params-vec (- idx 1)))
                           out))))
        (define (read-int! i)
          ;; Reads consecutive digits at i. Returns (values num next-i).
          ;; Caller has verified digit-at? i is #t.
          (let loop ((i i) (acc 0))
            (cond
              ((digit-at? i)
               (loop (+ i 1)
                     (+ (* acc 10)
                        (- (char->integer (at i)) (char->integer #\0)))))
              (else (values acc i)))))
        (define (read-dollar-tag! i)
          ;; i is the position of `$`. Try to read `$tag$` or `$$`.
          ;; On success: (values "$tag$" next-i). On failure: (values #f i).
          (cond
            ((eq-at? (+ i 1) #\$)
             (values "$$" (+ i 2)))
            ((ident-start-at? (+ i 1))
             (let loop ((j (+ i 2)))
               (cond
                 ((>= j n) (values #f i))
                 ((char=? (at j) #\$)
                  (values (substring sql i (+ j 1)) (+ j 1)))
                 ((ident-char-at? j) (loop (+ j 1)))
                 (else (values #f i)))))
            (else (values #f i))))
        (let loop ((i 0) (state 'default) (dollar-tag #f))
          (cond
            ((>= i n)
             (cond
               ((or (eq? state 'default)
                    (eq? state 'in-line-comment))
                (get-output-string out))
               (else
                (error (string-append "pg-format-sql: unterminated "
                                      (symbol->string state))))))
            ((eq? state 'default)
             (let ((c (at i)))
               (cond
                 ((char=? c #\')
                  (write-char c out) (loop (+ i 1) 'in-single-quote #f))
                 ((char=? c #\")
                  (write-char c out) (loop (+ i 1) 'in-double-quote #f))
                 ((and (char=? c #\-) (eq-at? (+ i 1) #\-))
                  (write-char #\- out) (write-char #\- out)
                  (loop (+ i 2) 'in-line-comment #f))
                 ((and (char=? c #\/) (eq-at? (+ i 1) #\*))
                  (write-char #\/ out) (write-char #\* out)
                  (loop (+ i 2) 'in-block-comment #f))
                 ((char=? c #\$)
                  (cond
                    ((digit-at? (+ i 1))
                     (call-with-values
                       (lambda () (read-int! (+ i 1)))
                       (lambda (num next-i)
                         (cond
                           ((zero? num)
                            (error "pg-format-sql: $0 is not a valid placeholder"))
                           (else
                            (write-param! num)
                            (loop next-i 'default #f))))))
                    (else
                     (call-with-values
                       (lambda () (read-dollar-tag! i))
                       (lambda (tag next-i)
                         (cond
                           (tag
                            (write-string tag out)
                            (loop next-i 'in-dollar tag))
                           (else
                            (write-char #\$ out)
                            (loop (+ i 1) 'default #f))))))))
                 (else
                  (write-char c out)
                  (loop (+ i 1) 'default #f)))))
            ((eq? state 'in-single-quote)
             (let ((c (at i)))
               (cond
                 ((and (char=? c #\') (eq-at? (+ i 1) #\'))
                  (write-char #\' out) (write-char #\' out)
                  (loop (+ i 2) 'in-single-quote #f))
                 ((char=? c #\')
                  (write-char #\' out) (loop (+ i 1) 'default #f))
                 (else (write-char c out) (loop (+ i 1) 'in-single-quote #f)))))
            ((eq? state 'in-double-quote)
             (let ((c (at i)))
               (cond
                 ((and (char=? c #\") (eq-at? (+ i 1) #\"))
                  (write-char #\" out) (write-char #\" out)
                  (loop (+ i 2) 'in-double-quote #f))
                 ((char=? c #\")
                  (write-char #\" out) (loop (+ i 1) 'default #f))
                 (else (write-char c out) (loop (+ i 1) 'in-double-quote #f)))))
            ((eq? state 'in-line-comment)
             (let ((c (at i)))
               (cond
                 ((char=? c #\newline)
                  (write-char c out) (loop (+ i 1) 'default #f))
                 (else (write-char c out) (loop (+ i 1) 'in-line-comment #f)))))
            ((eq? state 'in-block-comment)
             (let ((c (at i)))
               (cond
                 ((and (char=? c #\*) (eq-at? (+ i 1) #\/))
                  (write-char #\* out) (write-char #\/ out)
                  (loop (+ i 2) 'default #f))
                 (else (write-char c out) (loop (+ i 1) 'in-block-comment #f)))))
            ((eq? state 'in-dollar)
             (let ((tag-len (string-length dollar-tag)))
               (cond
                 ((and (char=? (at i) #\$)
                       (<= (+ i tag-len) n)
                       (string=? (substring sql i (+ i tag-len)) dollar-tag))
                  (write-string dollar-tag out)
                  (loop (+ i tag-len) 'default #f))
                 (else (write-char (at i) out)
                       (loop (+ i 1) 'in-dollar dollar-tag)))))
            (else
             (error "pg-format-sql: internal state error" state))))))

    ;; ============================================================
    ;; Connection pool
    ;;
    ;; A pg-pool is a fixed-capacity pool of idle pg-connect connections.
    ;; Threads check out a connection for the duration of one logical
    ;; unit of work and check it back in when done. Connections are
    ;; serialized — a single connection is only used by one thread at
    ;; a time, because pg-query/pg-exec are not safe to interleave on
    ;; the same socket.
    ;;
    ;; The pool is lazy: connections are created on demand up to the
    ;; capacity. If all connections are in use and capacity is reached,
    ;; checkout waits on a condition variable until one is returned.
    ;;
    ;; The pool does NOT validate idle connections before handing them
    ;; out. If postgres closes a connection from its side (idle
    ;; timeout, restart), the next use will fail; callers can retry by
    ;; closing the bad connection (pool-checkin pool conn #f) and
    ;; checking out a fresh one. For long-lived pools, consider
    ;; configuring postgres's idle_in_transaction_session_timeout and
    ;; the application's own retry policy.
    ;; ============================================================

    (define-record-type pg-pool
      (%make-pool host port user password database
                  capacity idle in-use mutex cv shutdown?)
      pg-pool?
      (host     pool-host)
      (port     pool-port)
      (user     pool-user)
      (password pool-password)
      (database pool-database)
      (capacity pool-capacity)
      (idle     pool-idle     pool-idle-set!)
      (in-use   pool-in-use   pool-in-use-set!)
      (mutex    pool-mutex)
      (cv       pool-cv)
      (shutdown? pool-shutdown? pool-shutdown-set!))

    (define (make-pg-pool host port user password database capacity)
      "Syntax: (make-pg-pool host port user password database capacity)
Library: (scm database postgres)
Description: Creates an empty pg connection pool. Connections are created
  lazily on first checkout, up to capacity. Use with-pg-pool-connection
  to borrow a connection, and pg-pool-close-all! to tear it down.
Example:
  (define pool (make-pg-pool \"localhost\" 5432 \"u\" \"p\" \"db\" 8))"
      (cond
        ((not (and (integer? capacity) (> capacity 0)))
         (error "make-pg-pool: capacity must be a positive integer" capacity))
        (else
         (%make-pool host port user password database
                     capacity '() 0
                     (make-mutex)
                     (make-condition-variable)
                     #f))))

    (define (pg-pool-checkout pool)
      "Syntax: (pg-pool-checkout pool)
Library: (scm database postgres)
Description: Borrows a connection from the pool. If an idle connection
  is available, returns it immediately. Otherwise, opens a new one (up
  to capacity), or waits on the pool's condition variable until a
  checkin frees one up. Prefer with-pg-pool-connection — it handles
  the matching checkin under exceptions."
      (mutex-lock! (pool-mutex pool))
      (let loop ()
        (cond
          ((pool-shutdown? pool)
           (mutex-unlock! (pool-mutex pool))
           (error "pg-pool: closed"))
          ((pair? (pool-idle pool))
           (let ((conn (car (pool-idle pool))))
             (pool-idle-set!   pool (cdr (pool-idle pool)))
             (pool-in-use-set! pool (+ 1 (pool-in-use pool)))
             (mutex-unlock! (pool-mutex pool))
             conn))
          ((< (pool-in-use pool) (pool-capacity pool))
           ;; Reserve a slot, then connect outside the lock — pg-connect
           ;; takes ~100 ms with SCRAM, so we must not hold the mutex
           ;; while doing it.
           (pool-in-use-set! pool (+ 1 (pool-in-use pool)))
           (mutex-unlock! (pool-mutex pool))
           (guard (exn (#t
                        ;; Connect failed — release the slot we reserved.
                        (mutex-lock! (pool-mutex pool))
                        (pool-in-use-set! pool (- (pool-in-use pool) 1))
                        (condition-variable-signal! (pool-cv pool))
                        (mutex-unlock! (pool-mutex pool))
                        (raise exn)))
             (pg-connect (pool-host pool)
                         (pool-port pool)
                         (pool-user pool)
                         (pool-password pool)
                         (pool-database pool))))
          (else
           ;; At capacity and nothing idle — wait. mutex-unlock! with a
           ;; condition variable atomically releases the mutex and
           ;; waits to be signaled.
           (mutex-unlock! (pool-mutex pool) (pool-cv pool))
           (mutex-lock!   (pool-mutex pool))
           (loop)))))

    (define (pg-pool-checkin pool conn ok?)
      "Syntax: (pg-pool-checkin pool conn ok?)
Library: (scm database postgres)
Description: Returns conn to the pool. If ok? is #t, the connection
  goes back on the idle list. If #f, the connection is closed and
  discarded — use this when an exception suggests the connection is
  in an unknown state. Prefer with-pg-pool-connection."
      (mutex-lock! (pool-mutex pool))
      (pool-in-use-set! pool (- (pool-in-use pool) 1))
      (cond
        ((and ok? (not (pool-shutdown? pool)))
         (pool-idle-set! pool (cons conn (pool-idle pool)))
         (condition-variable-signal! (pool-cv pool))
         (mutex-unlock! (pool-mutex pool)))
        (else
         (condition-variable-signal! (pool-cv pool))
         (mutex-unlock! (pool-mutex pool))
         (guard (e (#t #f)) (pg-close conn)))))

    (define (with-pg-pool-connection pool proc)
      "Syntax: (with-pg-pool-connection pool proc)
Library: (scm database postgres)
Description: Checks out a connection, calls (proc conn), and checks
  it back in. On normal return, the connection is returned to the
  idle list. On exception, the connection is closed (not pooled) and
  the exception is re-raised — assumes the connection's state is
  suspect.
Example:
  (with-pg-pool-connection pool
    (lambda (c) (pg-result-rows (pg-query c \"SELECT 1\"))))"
      (let ((conn (pg-pool-checkout pool)))
        (guard (exn (#t (pg-pool-checkin pool conn #f) (raise exn)))
          (let ((result (proc conn)))
            (pg-pool-checkin pool conn #t)
            result))))

    (define (pg-pool-close-all! pool)
      "Syntax: (pg-pool-close-all! pool)
Library: (scm database postgres)
Description: Marks the pool as shut down and closes every idle
  connection. Connections currently checked out will be closed when
  they are checked back in. Subsequent checkouts raise."
      (mutex-lock! (pool-mutex pool))
      (pool-shutdown-set! pool #t)
      (let ((idle (pool-idle pool)))
        (pool-idle-set! pool '())
        (mutex-unlock! (pool-mutex pool))
        (for-each (lambda (c) (guard (e (#t #f)) (pg-close c))) idle)))
))
