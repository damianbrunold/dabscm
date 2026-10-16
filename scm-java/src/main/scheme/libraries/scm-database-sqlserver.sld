(define-library (scm database sqlserver)
  (import (scm core) (scheme base) (scheme char) (scheme inexact) (srfi 151) (scm net sockets))
  (export ss-connect
          ss-instance-port
          ss-close
          ss-query
          ss-exec
          ss-format-sql
          ss-sql-literal
          ss-result-columns
          ss-result-rows
          ss-result->alist-list
          ss-cursor-open
          ss-cursor-fetch
          ss-cursor-columns
          ss-cursor-close
          ss-cursor-for-each
          with-ss-connection
          with-ss-query)
  (begin

    ;; --- Wire helpers (little-endian) ---

    (define (tds-write-u8! val out)
      "Syntax: (tds-write-u8! val out)
Library: (scm database sqlserver)
Description: Writes a single byte to a binary output port.
Example:
  (tds-write-u8! 42 out)"
      (write-u8 val out))

    (define (tds-read-u8! in)
      "Syntax: (tds-read-u8! in)
Library: (scm database sqlserver)
Description: Reads a single byte from a binary input port.
Example:
  (tds-read-u8! in) => 42"
      (read-u8 in))

    (define (tds-write-u16-le! val out)
      "Syntax: (tds-write-u16-le! val out)
Library: (scm database sqlserver)
Description: Writes a 16-bit unsigned integer in little-endian byte order.
Example:
  (tds-write-u16-le! 1433 out)"
      (write-u8 (modulo val 256) out)
      (write-u8 (modulo (quotient val 256) 256) out))

    (define (tds-read-u16-le! in)
      "Syntax: (tds-read-u16-le! in)
Library: (scm database sqlserver)
Description: Reads a 16-bit unsigned integer in little-endian byte order.
Example:
  (tds-read-u16-le! in) => 1433"
      (let ((b0 (read-u8 in))
            (b1 (read-u8 in)))
        (+ b0 (* b1 256))))

    (define (tds-write-u32-le! val out)
      "Syntax: (tds-write-u32-le! val out)
Library: (scm database sqlserver)
Description: Writes a 32-bit unsigned integer in little-endian byte order.
Example:
  (tds-write-u32-le! #x74000004 out)"
      (write-u8 (modulo val 256) out)
      (write-u8 (modulo (quotient val #x100) 256) out)
      (write-u8 (modulo (quotient val #x10000) 256) out)
      (write-u8 (modulo (quotient val #x1000000) 256) out))

    (define (tds-read-u32-le! in)
      "Syntax: (tds-read-u32-le! in)
Library: (scm database sqlserver)
Description: Reads a 32-bit unsigned integer in little-endian byte order.
Example:
  (tds-read-u32-le! in) => 4096"
      (let ((b0 (read-u8 in))
            (b1 (read-u8 in))
            (b2 (read-u8 in))
            (b3 (read-u8 in)))
        (+ b0 (* b1 #x100) (* b2 #x10000) (* b3 #x1000000))))

    (define (tds-read-i32-le! in)
      "Syntax: (tds-read-i32-le! in)
Library: (scm database sqlserver)
Description: Reads a 32-bit signed integer in little-endian byte order.
Example:
  (tds-read-i32-le! in) => -1"
      (let ((u (tds-read-u32-le! in)))
        (if (>= u #x80000000)
            (- u #x100000000)
            u)))

    (define (tds-write-u64-le! val out)
      "Syntax: (tds-write-u64-le! val out)
Library: (scm database sqlserver)
Description: Writes a 64-bit unsigned integer in little-endian byte order.
Example:
  (tds-write-u64-le! 0 out)"
      (tds-write-u32-le! (modulo val #x100000000) out)
      (tds-write-u32-le! (quotient val #x100000000) out))

    (define (tds-read-u64-le! in)
      "Syntax: (tds-read-u64-le! in)
Library: (scm database sqlserver)
Description: Reads a 64-bit unsigned integer in little-endian byte order.
Example:
  (tds-read-u64-le! in) => 0"
      (let ((lo (tds-read-u32-le! in))
            (hi (tds-read-u32-le! in)))
        (+ lo (* hi #x100000000))))

    ;; Read a little-endian unsigned integer from a bytevector
    (define (tds-bv-u16-le bv off)
      "Syntax: (tds-bv-u16-le bv off)
Library: (scm database sqlserver)
Description: Reads a 16-bit unsigned integer in little-endian order from bytevector bv at offset off.
Example:
  (tds-bv-u16-le bv 0) => 3"
      (+ (bytevector-u8-ref bv off)
         (* (bytevector-u8-ref bv (+ off 1)) 256)))

    (define (tds-bv-u32-le bv off)
      "Syntax: (tds-bv-u32-le bv off)
Library: (scm database sqlserver)
Description: Reads a 32-bit unsigned integer in little-endian order from bytevector bv at offset off.
Example:
  (tds-bv-u32-le bv 0) => 4096"
      (+ (bytevector-u8-ref bv off)
         (* (bytevector-u8-ref bv (+ off 1)) #x100)
         (* (bytevector-u8-ref bv (+ off 2)) #x10000)
         (* (bytevector-u8-ref bv (+ off 3)) #x1000000)))

    ;; Read n bytes as little-endian unsigned integer from a bytevector
    (define (tds-bv-uint-le bv offset len)
      "Syntax: (tds-bv-uint-le bv offset len)
Library: (scm database sqlserver)
Description: Reads len bytes as a little-endian unsigned integer from bytevector bv at offset.
Example:
  (tds-bv-uint-le bv 0 3) => 65536"
      (let loop ((i 0) (val 0))
        (if (= i len) val
            (loop (+ i 1)
                  (+ val (* (bytevector-u8-ref bv (+ offset i))
                            (expt 256 i)))))))

    ;; Read n bytes from in as little-endian unsigned integer
    (define (tds-read-uint-le! in len)
      "Syntax: (tds-read-uint-le! in len)
Library: (scm database sqlserver)
Description: Reads len bytes from binary input port in as a little-endian unsigned integer.
Example:
  (tds-read-uint-le! in 4) => 4096"
      (let ((bv (read-bytevector len in)))
        (tds-bv-uint-le bv 0 len)))

    ;; Read n bytes from in as little-endian signed integer
    (define (tds-read-int-le! in len)
      "Syntax: (tds-read-int-le! in len)
Library: (scm database sqlserver)
Description: Reads len bytes from binary input port in as a little-endian signed integer.
Example:
  (tds-read-int-le! in 4) => -1"
      (let ((u (tds-read-uint-le! in len)))
        (let ((max (expt 256 len)))
          (if (>= u (quotient max 2))
              (- u max)
              u))))

    ;; --- UTF-16 LE encoding/decoding (surrogate pairs for non-BMP) ---

    (define (string->utf16le s)
      "Syntax: (string->utf16le s)
Library: (scm database sqlserver)
Description: Converts a string to a UTF-16 LE bytevector. Characters outside the BMP are
  encoded as surrogate pairs.
Example:
  (string->utf16le \"hello\") => #u8(104 0 101 0 108 0 108 0 111 0)"
      (let ((out (open-output-bytevector)))
        (define (put16 u)
          (write-u8 (modulo u 256) out)
          (write-u8 (quotient u 256) out))
        (string-for-each
         (lambda (ch)
           (let ((cp (char->integer ch)))
             (if (< cp #x10000)
                 (put16 cp)
                 (let ((v (- cp #x10000)))
                   (put16 (+ #xD800 (quotient v #x400)))
                   (put16 (+ #xDC00 (modulo v #x400)))))))
         s)
        (get-output-bytevector out)))

    (define (utf16le->string bv offset len-bytes)
      "Syntax: (utf16le->string bv offset len-bytes)
Library: (scm database sqlserver)
Description: Converts a UTF-16 LE bytevector slice to a string. len-bytes is the number of
  bytes (not characters). Code units are kept as they are (scm strings are UTF-16, so a
  surrogate pair stays a pair, as in string literals).
Example:
  (utf16le->string #u8(104 0 101 0) 0 4) => \"he\""
      (let* ((nchars (quotient len-bytes 2))
             (result (make-string nchars)))
        (let loop ((i 0))
          (if (= i nchars) result
              (let* ((b0 (bytevector-u8-ref bv (+ offset (* 2 i))))
                     (b1 (bytevector-u8-ref bv (+ offset (* 2 i) 1))))
                (string-set! result i (integer->char (+ b0 (* b1 256))))
                (loop (+ i 1)))))))

    ;; --- Single-byte code pages (varchar/char/text with non-UTF8 collations) ---

    ;; Windows-1252 code points for bytes #x80-#x9F (#f = undefined); other bytes map 1:1.
    (define %cp1252-high
      (vector #x20AC #f #x201A #x0192 #x201E #x2026 #x2020 #x2021
              #x02C6 #x2030 #x0160 #x2039 #x0152 #f #x017D #f
              #f #x2018 #x2019 #x201C #x201D #x2022 #x2013 #x2014
              #x02DC #x2122 #x0161 #x203A #x0153 #f #x017E #x0178))

    (define (cp1252->string bv)
      "Syntax: (cp1252->string bv)
Library: (scm database sqlserver)
Description: Decodes a Windows-1252 bytevector to a string (the code page of the Latin1_General
  and SQL_Latin1_General collations). Undefined bytes map to U+FFFD.
Example:
  (cp1252->string #u8(#x5A #xFC #x72 #x69 #x63 #x68)) => \"Zürich\""
      (let ((n (bytevector-length bv))
            (out (open-output-string)))
        (let loop ((i 0))
          (if (= i n)
              (get-output-string out)
              (let ((b (bytevector-u8-ref bv i)))
                (write-char
                 (integer->char
                  (if (and (>= b #x80) (< b #xA0))
                      (or (vector-ref %cp1252-high (- b #x80)) #xFFFD)
                      b))
                 out)
                (loop (+ i 1)))))))

    ;; Collation: 4 bytes LE (LCID:20, flags:8 incl. fUTF8 at bit 26, version:4) + SortId(1).
    ;; Returns 'utf8 for UTF-8 collations, otherwise 'cp1252 (Western collations; other code
    ;; pages are decoded as cp1252 as well).
    (define (tds-collation-codec coll-bv)
      (let ((info (tds-bv-u32-le coll-bv 0)))
        (if (odd? (quotient info #x4000000)) 'utf8 'cp1252)))

    (define (tds-decode-bytes bv codec)
      (if (eq? codec 'utf8) (utf8->string bv) (cp1252->string bv)))

    ;; --- TDS packet framing ---
    ;; TDS header: type(1) status(1) length(2,BE) SPID(2) packetId(1) window(1) = 8 bytes

    (define (tds-send-packet! out type-byte payload-bv)
      "Syntax: (tds-send-packet! out type-byte payload-bv)
Library: (scm database sqlserver)
Description: Sends a TDS message of the given type containing payload-bv. Splits it into
  packets (max 4088 bytes payload each), setting EOM on the last. Each packet is written
  and flushed on its own: over TLS, SQL Server expects every TDS packet in its own TLS
  record(s) and drops the connection when a record holds parts of two packets.
Example:
  (tds-send-packet! out #x01 sql-bytes)"
      (let* ((max-payload 4088)
             (total-len   (bytevector-length payload-bv)))
        (let loop ((offset 0) (pkt-id 1))
          (when (< offset total-len)
            (let* ((remaining  (- total-len offset))
                   (chunk-len  (min remaining max-payload))
                   (is-last    (= (+ offset chunk-len) total-len))
                   (pkt-total  (+ 8 chunk-len))
                   (pkt        (make-bytevector pkt-total 0)))
              (bytevector-u8-set! pkt 0 type-byte)
              (bytevector-u8-set! pkt 1 (if is-last #x01 #x00))
              (bytevector-u8-set! pkt 2 (quotient pkt-total 256))
              (bytevector-u8-set! pkt 3 (modulo pkt-total 256))
              (bytevector-u8-set! pkt 6 (modulo pkt-id 256))
              (bytevector-copy! pkt 8 payload-bv offset (+ offset chunk-len))
              (write-bytevector pkt out)
              (flush-output-port out)
              (loop (+ offset chunk-len) (+ pkt-id 1)))))))

    (define (tds-read-packet-header! in)
      "Syntax: (tds-read-packet-header! in)
Library: (scm database sqlserver)
Description: Reads one TDS packet header (8 bytes) and returns a list (type status length).
  length includes the 8-byte header.
Example:
  (tds-read-packet-header! in) => (4 1 26)"
      (let* ((type   (read-u8 in))
             (status (read-u8 in))
             (len-hi (read-u8 in))
             (len-lo (read-u8 in))
             (_      (read-u8 in)) (_      (read-u8 in))  ; SPID
             (_      (read-u8 in)) (_      (read-u8 in))) ; packetId, window
        (list type status (+ (* len-hi 256) len-lo))))

    (define (tds-read-all-packets! in)
      "Syntax: (tds-read-all-packets! in)
Library: (scm database sqlserver)
Description: Reads all TDS response packets (until EOM status bit is set) and reassembles
  their bodies into a single bytevector.
Example:
  (tds-read-all-packets! in) => #u8(...)"
      (let loop ((chunks '()))
        (let* ((hdr    (tds-read-packet-header! in))
               (status (cadr hdr))
               (length (caddr hdr))
               (body   (read-bytevector (- length 8) in))
               (chunks (cons body chunks)))
          (if (= (bitwise-and status #x01) #x01)
              ;; Last packet: assemble in order
              (let* ((rev     (reverse chunks))
                     (total   (apply + (map bytevector-length rev)))
                     (result  (make-bytevector total)))
                (let fill ((off 0) (cs rev))
                  (if (null? cs)
                      result
                      (let ((c (car cs)))
                        (bytevector-copy! result off c 0 (bytevector-length c))
                        (fill (+ off (bytevector-length c)) (cdr cs))))))
              (loop chunks)))))

    ;; --- Password obfuscation (Login7) ---

    (define (tds-obfuscate-byte b)
      "Syntax: (tds-obfuscate-byte b)
Library: (scm database sqlserver)
Description: Applies the TDS Login7 password obfuscation to a single byte: nibble-swap then XOR 0xA5.
Example:
  (tds-obfuscate-byte #x41) => #xf4"
      (bitwise-xor
       (bitwise-ior (arithmetic-shift (bitwise-and b #x0f) 4)
                    (arithmetic-shift b -4))
       #xa5))

    (define (tds-obfuscate-password-bv bv)
      "Syntax: (tds-obfuscate-password-bv bv)
Library: (scm database sqlserver)
Description: Applies TDS password obfuscation to every byte of a bytevector. Returns a new
  bytevector suitable for use in the Login7 password field.
Example:
  (tds-obfuscate-password-bv (string->utf16le \"pass\"))"
      (let* ((len (bytevector-length bv))
             (result (make-bytevector len)))
        (let loop ((i 0))
          (if (= i len) result
              (begin
                (bytevector-u8-set! result i (tds-obfuscate-byte (bytevector-u8-ref bv i)))
                (loop (+ i 1)))))))

    ;; --- Login7 ---

    (define (tds-send-login7! out user password database . opt)
      "Syntax: (tds-send-login7! out user password database [host-name server-name app-name])
Library: (scm database sqlserver)
Description: Builds and sends a TDS Login7 packet (type 0x10) with SQL Server authentication.
  The password is obfuscated per the TDS specification. All strings are UTF-16 LE.
Example:
  (tds-send-login7! out \"sa\" \"Password123!\" \"master\")"
      (let* ((opt-ref    (lambda (i dflt) (if (> (length opt) i) (list-ref opt i) dflt)))
             (host-name  (opt-ref 0 ""))
             (server     (opt-ref 1 ""))
             (app-name   (opt-ref 2 "scm"))
             (enc        (lambda (str) (string->utf16le str)))
             (host-bv    (enc host-name))
             (user-bv    (enc user))
             (pass-bv    (tds-obfuscate-password-bv (enc password)))
             (app-bv     (enc app-name))
             (server-bv  (enc server))
             (lib-bv     (enc "scm"))
             (db-bv      (enc database))
             (nchars     (lambda (bv) (quotient (bytevector-length bv) 2)))
             ;; Variable data starts at offset 94 (fixed part incl. the Length field)
             (base       94)
             (host-off   base)
             (user-off   (+ host-off (bytevector-length host-bv)))
             (pass-off   (+ user-off (bytevector-length user-bv)))
             (app-off    (+ pass-off (bytevector-length pass-bv)))
             (server-off (+ app-off (bytevector-length app-bv)))
             (lib-off    (+ server-off (bytevector-length server-bv)))
             (db-off     (+ lib-off (bytevector-length lib-bv)))
             (total-len  (+ db-off (bytevector-length db-bv)))
             (buf        (open-output-bytevector)))
        ;; Fixed header (36 bytes)
        (tds-write-u32-le! total-len buf)      ; Length (total Login7 size)
        (tds-write-u32-le! #x74000004 buf)     ; TDSVersion 7.4
        (tds-write-u32-le! 4096 buf)           ; PacketSize
        (tds-write-u32-le! 0 buf)              ; ClientProgVer
        (tds-write-u32-le! 0 buf)              ; ClientPID
        (tds-write-u32-le! 0 buf)              ; ConnectionID
        ;; Flags (4 bytes)
        (write-u8 #xE0 buf)                    ; OptionFlags1: USE_DB_ON, INIT_DB_FATAL, SET_LANG_ON
        (write-u8 #x03 buf)                    ; OptionFlags2: INIT_LANG_FATAL, ODBC_ON (bit7=0 = SQL auth)
        (write-u8 #x00 buf)                    ; TypeFlags
        (write-u8 #x00 buf)                    ; OptionFlags3
        ;; Locale (8 bytes)
        (tds-write-u32-le! 0 buf)              ; ClientTimezone
        (tds-write-u32-le! #x0409 buf)         ; ClientLCID (en-US)
        ;; OffLen table (58 bytes)
        (tds-write-u16-le! host-off buf)   (tds-write-u16-le! (nchars host-bv) buf)
        (tds-write-u16-le! user-off buf)   (tds-write-u16-le! (nchars user-bv) buf)
        (tds-write-u16-le! pass-off buf)   (tds-write-u16-le! (nchars pass-bv) buf)
        (tds-write-u16-le! app-off buf)    (tds-write-u16-le! (nchars app-bv) buf)
        (tds-write-u16-le! server-off buf) (tds-write-u16-le! (nchars server-bv) buf)
        (tds-write-u32-le! 0 buf)              ; Unused/Extension
        (tds-write-u16-le! lib-off buf)    (tds-write-u16-le! (nchars lib-bv) buf)
        (tds-write-u16-le! db-off buf)     (tds-write-u16-le! 0 buf) ; Language (empty)
        (tds-write-u16-le! db-off buf)     (tds-write-u16-le! (nchars db-bv) buf)
        ;; ClientID: 6-byte MAC address (zeros)
        (write-bytevector (make-bytevector 6 0) buf)
        (tds-write-u16-le! total-len buf) (tds-write-u16-le! 0 buf)  ; SSPI
        (tds-write-u16-le! total-len buf) (tds-write-u16-le! 0 buf)  ; AtchDBFile
        (tds-write-u16-le! total-len buf) (tds-write-u16-le! 0 buf)  ; ChangePassword
        (tds-write-u32-le! 0 buf)              ; SSPILong
        ;; Variable-length data
        (for-each (lambda (bv) (write-bytevector bv buf))
                  (list host-bv user-bv pass-bv app-bv server-bv lib-bv db-bv))
        ;; Send as TDS type 0x10 (Login7)
        (tds-send-packet! out #x10 (get-output-bytevector buf))))

    ;; --- Date/time helpers ---

    ;; Convert Julian Day Number to (year month day) using proleptic Gregorian calendar
    (define (tds-jdn->ymd jdn)
      "Syntax: (tds-jdn->ymd jdn)
Library: (scm database sqlserver)
Description: Converts a Julian Day Number to a list (year month day) using the proleptic Gregorian calendar.
Example:
  (tds-jdn->ymd 2415021) => (1900 1 1)"
      (let* ((a (+ jdn 32044))
             (b (quotient (+ (* 4 a) 3) 146097))
             (c (- a (quotient (* 146097 b) 4)))
             (d (quotient (+ (* 4 c) 3) 1461))
             (e (- c (quotient (* 1461 d) 4)))
             (m (quotient (+ (* 5 e) 2) 153)))
        (list (+ (* 100 b) d -4800 (quotient m 10))
              (+ m 3 (* -12 (quotient m 10)))
              (+ (- e (quotient (+ (* 153 m) 2) 5)) 1))))

    ;; Format integer with leading zeros to at least width digits
    (define (tds-pad n width)
      "Syntax: (tds-pad n width)
Library: (scm database sqlserver)
Description: Formats a non-negative integer as a decimal string, zero-padded to at least width characters.
Example:
  (tds-pad 5 2) => \"05\""
      (let ((s (number->string n)))
        (let ((pad (- width (string-length s))))
          (if (<= pad 0) s
              (string-append (make-string pad #\0) s)))))

    ;; Format Y/M/D as ISO date string
    (define (tds-ymd->string y m d)
      (string-append (tds-pad y 4) "-" (tds-pad m 2) "-" (tds-pad d 2)))

    ;; Convert DATETIME: days since 1900-01-01 + 1/300-second units
    (define (tds-datetime->string days t300)
      "Syntax: (tds-datetime->string days t300)
Library: (scm database sqlserver)
Description: Converts a TDS DATETIME value (days since 1900-01-01 and 1/300-second units) to an ISO string.
Example:
  (tds-datetime->string 0 0) => \"1900-01-01 00:00:00\""
      (let* ((ymd      (tds-jdn->ymd (+ days 2415021)))
             (tot-sec  (quotient t300 300))
             (h        (quotient tot-sec 3600))
             (m        (quotient (modulo tot-sec 3600) 60))
             (s        (modulo tot-sec 60)))
        (string-append (tds-ymd->string (car ymd) (cadr ymd) (caddr ymd))
                       " "
                       (tds-pad h 2) ":" (tds-pad m 2) ":" (tds-pad s 2))))

    ;; Convert SMALLDATETIME: minutes since 1900-01-01, minutes since midnight
    (define (tds-smalldatetime->string days-in-mins mins-since-midnight)
      "Syntax: (tds-smalldatetime->string days-in-mins mins-since-midnight)
Library: (scm database sqlserver)
Description: Converts a TDS SMALLDATETIME value to an ISO string.
Example:
  (tds-smalldatetime->string 0 0) => \"1900-01-01 00:00:00\""
      (let* ((ymd (tds-jdn->ymd (+ days-in-mins 2415021)))
             (h   (quotient mins-since-midnight 60))
             (m   (modulo mins-since-midnight 60)))
        (string-append (tds-ymd->string (car ymd) (cadr ymd) (caddr ymd))
                       " "
                       (tds-pad h 2) ":" (tds-pad m 2) ":00")))

    ;; Convert DATE (0x28): days since 0001-01-01 in proleptic Gregorian
    (define (tds-date-days->string days)
      "Syntax: (tds-date-days->string days)
Library: (scm database sqlserver)
Description: Converts a TDS DATE value (days since 0001-01-01) to an ISO date string.
Example:
  (tds-date-days->string 693594) => \"1900-01-01\""
      (let ((ymd (tds-jdn->ymd (+ days 1721426))))
        (tds-ymd->string (car ymd) (cadr ymd) (caddr ymd))))

    ;; Number of bytes used to encode TIME for a given scale
    (define (tds-time-bytes-for-scale scale)
      "Syntax: (tds-time-bytes-for-scale scale)
Library: (scm database sqlserver)
Description: Returns the number of bytes used to store a TDS TIME value at the given scale.
Example:
  (tds-time-bytes-for-scale 7) => 5"
      (cond ((< scale 3) 3)
            ((< scale 5) 4)
            (else 5)))

    ;; Convert TIME bytevector to string "HH:MM:SS[.nnn...]"
    (define (tds-time-bv->string bv scale)
      "Syntax: (tds-time-bv->string bv scale)
Library: (scm database sqlserver)
Description: Converts a TDS TIME bytevector (little-endian integer) to a time string.
  scale determines the sub-second precision (0=seconds, 7=100ns).
Example:
  (tds-time-bv->string bv 7) => \"13:45:00.0000000\""
      (let* ((n       (tds-bv-uint-le bv 0 (bytevector-length bv)))
             (divisor (expt 10 scale))
             (tot-sec (quotient n divisor))
             (frac    (modulo n divisor))
             (h       (quotient tot-sec 3600))
             (m       (quotient (modulo tot-sec 3600) 60))
             (s       (modulo tot-sec 60))
             (base    (string-append (tds-pad h 2) ":" (tds-pad m 2) ":" (tds-pad s 2))))
        (if (= scale 0) base
            (string-append base "." (tds-pad frac scale)))))

    ;; Convert bytevector to hex string
    (define (tds-bv->hex bv)
      "Syntax: (tds-bv->hex bv)
Library: (scm database sqlserver)
Description: Converts a bytevector to an uppercase hexadecimal string (two hex digits per byte).
Example:
  (tds-bv->hex #u8(0 1 255)) => \"0001FF\""
      (let loop ((i 0) (acc '()))
        (if (= i (bytevector-length bv))
            (apply string-append (reverse acc))
            (let* ((b   (bytevector-u8-ref bv i))
                   (hi  (quotient b 16))
                   (lo  (modulo b 16))
                   (hex (string (string-ref "0123456789ABCDEF" hi)
                                (string-ref "0123456789ABCDEF" lo))))
              (loop (+ i 1) (cons hex acc))))))

    ;; Decode a little-endian IEEE 754 binary32/binary64 bytevector to a number string
    (define (tds-ieee->string bv)
      "Syntax: (tds-ieee->string bv)
Library: (scm database sqlserver)
Description: Decodes a 4- or 8-byte little-endian IEEE 754 value (REAL / FLOAT) and returns
  it as a decimal number string.
Example:
  (tds-ieee->string #u8(0 0 0 0 0 0 240 63)) => \"1.0\""
      (let* ((n        (bytevector-length bv))
             (bits     (tds-bv-uint-le bv 0 n))
             (ebits    (if (= n 4) 8 11))
             (mbits    (if (= n 4) 23 52))
             (bias     (- (expt 2 (- ebits 1)) 1))
             (sign     (if (>= bits (expt 2 (- (* 8 n) 1))) -1 1))
             (e        (modulo (quotient bits (expt 2 mbits)) (expt 2 ebits)))
             (m        (modulo bits (expt 2 mbits))))
        (cond
          ((= e (- (expt 2 ebits) 1))
           (if (= m 0) (if (< sign 0) "-inf" "inf") "nan"))
          (else
           (let ((v (if (= e 0)
                        (* m (expt 2 (- 1 bias mbits)))
                        (* (+ m (expt 2 mbits)) (expt 2 (- e bias mbits))))))
             (number->string (inexact (* sign v))))))))

    ;; Format a UNIQUEIDENTIFIER (16-byte GUID) with SQL Server's mixed-endian layout
    (define (tds-guid->string bv)
      "Syntax: (tds-guid->string bv)
Library: (scm database sqlserver)
Description: Formats a 16-byte GUID bytevector as a standard UUID string.
  The first three groups are little-endian per the SQL Server wire format.
Example:
  (tds-guid->string bv) => \"6BA7B810-9DAD-11D1-80B4-00C04FD430C8\""
      (define (h2 b)
        (let ((s (number->string b 16)))
          (if (< b 16) (string-append "0" s) s)))
      (string-append
       (h2 (bytevector-u8-ref bv 3)) (h2 (bytevector-u8-ref bv 2))
       (h2 (bytevector-u8-ref bv 1)) (h2 (bytevector-u8-ref bv 0)) "-"
       (h2 (bytevector-u8-ref bv 5)) (h2 (bytevector-u8-ref bv 4)) "-"
       (h2 (bytevector-u8-ref bv 7)) (h2 (bytevector-u8-ref bv 6)) "-"
       (h2 (bytevector-u8-ref bv 8)) (h2 (bytevector-u8-ref bv 9)) "-"
       (h2 (bytevector-u8-ref bv 10)) (h2 (bytevector-u8-ref bv 11))
       (h2 (bytevector-u8-ref bv 12)) (h2 (bytevector-u8-ref bv 13))
       (h2 (bytevector-u8-ref bv 14)) (h2 (bytevector-u8-ref bv 15))))

    ;; --- COLMETADATA parsing ---

    ;; Read COLMETADATA typeinfo bytes for a given type; returns extra params list
    (define (tds-read-col-typeinfo! bv-in type-byte)
      "Syntax: (tds-read-col-typeinfo! bv-in type-byte)
Library: (scm database sqlserver)
Description: Reads type-specific metadata bytes from the COLMETADATA stream and returns
  a list of parameters needed to read ROW values for this column type.
Example:
  (tds-read-col-typeinfo! bv-in #x26) => (4)"
      (cond
        ;; Fixed-length types: no extra typeinfo bytes in column metadata
        ((or (= type-byte #x1F) (= type-byte #x34) (= type-byte #x38) (= type-byte #x7F)
             (= type-byte #x3C) (= type-byte #x3E) (= type-byte #x3D) (= type-byte #x61)
             (= type-byte #x65) (= type-byte #x7A))
         '())
        ;; UNIQUEIDENTIFIER: 1-byte max-size (always 16)
        ((= type-byte #x24)
         (list (read-u8 bv-in)))
        ;; Variable nullable types: 1-byte max-size
        ((or (= type-byte #x26) (= type-byte #x68) (= type-byte #x6D)
             (= type-byte #x6F) (= type-byte #x6E))
         (list (read-u8 bv-in)))
        ;; DECIMALN / NUMERICN: max-size(1) + precision(1) + scale(1)
        ((or (= type-byte #x6A) (= type-byte #x6C))
         (let* ((max-size  (read-u8 bv-in))
                (precision (read-u8 bv-in))
                (scale     (read-u8 bv-in)))
           (list max-size precision scale)))
        ;; VARCHAR / CHAR: max-len(2,LE) + collation(5) -> (max-len codec)
        ((or (= type-byte #xA7) (= type-byte #xAF))
         (let* ((max-len (tds-read-u16-le! bv-in))
                (coll    (read-bytevector 5 bv-in)))
           (list max-len (tds-collation-codec coll))))
        ;; TEXT / NTEXT: max-len(4) + collation(5) + table name; IMAGE: no collation
        ((or (= type-byte #x23) (= type-byte #x63) (= type-byte #x22))
         (tds-read-u32-le! bv-in)
         (let ((codec (if (= type-byte #x22)
                          'binary
                          (tds-collation-codec (read-bytevector 5 bv-in)))))
           (let ((parts (read-u8 bv-in)))
             (do ((i 0 (+ i 1))) ((= i parts))
               (read-bytevector (* 2 (tds-read-u16-le! bv-in)) bv-in)))
           (list codec)))
        ;; SQL_VARIANT: max-len(4)
        ((= type-byte #x62)
         (list (tds-read-u32-le! bv-in)))
        ;; VARBINARY / BINARY: max-len(2,LE), no collation
        ((or (= type-byte #xA5) (= type-byte #xA8))
         (let ((max-len (tds-read-u16-le! bv-in)))
           (list max-len)))
        ;; NVARCHAR / NCHAR: max-len(2,LE) + collation(5)
        ((or (= type-byte #xE7) (= type-byte #xEF))
         (let ((max-len (tds-read-u16-le! bv-in)))
           (read-bytevector 5 bv-in)  ; skip collation
           (list max-len)))
        ;; DATE: no extra bytes
        ((= type-byte #x28) '())
        ;; TIME / DATETIME2N / DATETIMEOFFSETN: scale(1)
        ((or (= type-byte #x29) (= type-byte #x2A) (= type-byte #x2B))
         (list (read-u8 bv-in)))
        ;; XML: optional schema info
        ((= type-byte #xF1)
         (let ((has-schema (read-u8 bv-in)))
           (when (= has-schema 1)
             ;; Skip: db-name, owner, collection (each as length-prefixed UTF-16LE)
             (let ((dbl (read-u8 bv-in)))
               (read-bytevector (* 2 dbl) bv-in))
             (let ((owl (read-u8 bv-in)))
               (read-bytevector (* 2 owl) bv-in))
             (let ((cll (tds-read-u16-le! bv-in)))
               (read-bytevector (* 2 cll) bv-in)))
           '()))
        ;; Unknown: no params (row value reading will use generic length prefix)
        (else '())))

    ;; Parse COLMETADATA token body; returns vector of #(name type-byte params)
    (define (tds-parse-colmetadata! bv-in)
      "Syntax: (tds-parse-colmetadata! bv-in)
Library: (scm database sqlserver)
Description: Parses a COLMETADATA token from a binary input port. Returns a vector of
  column descriptors, each a vector #(name type-byte params hidden?).
Example:
  (tds-parse-colmetadata! bv-in) => #(#(\"id\" #x26 (4)) #(\"name\" #xE7 (50)))"
      (let ((count (tds-read-u16-le! bv-in)))
        (if (= count #xFFFF)
            #f    ; No metadata - caller should use previous
            (let loop ((i 0) (cols '()))
              (if (= i count)
                  (list->vector (reverse cols))
                  (let* ((_         (read-bytevector 4 bv-in))   ; UserType (4 bytes, TDS 7.2+)
                         (flags     (tds-read-u16-le! bv-in))    ; Flags (bit 13 = fHidden)
                         (type-byte (read-u8 bv-in))
                         (params    (tds-read-col-typeinfo! bv-in type-byte))
                         ;; ColName: BLength(1) chars, each 2 bytes UTF-16LE
                         (name-len  (read-u8 bv-in))
                         (name-bv   (read-bytevector (* 2 name-len) bv-in))
                         (name      (utf16le->string name-bv 0 (* 2 name-len))))
                    (loop (+ i 1)
                          (cons (vector name type-byte params
                                        (odd? (quotient flags #x2000)))
                                cols))))))))

    ;; --- ROW value reading ---

    ;; Read a PLP (Partially Length-Prefixed) value for MAX types
    (define (tds-read-plp! bv-in is-unicode)
      "Syntax: (tds-read-plp! bv-in is-unicode)
Library: (scm database sqlserver)
Description: Reads a PLP-encoded value (used for varchar(max), nvarchar(max), varbinary(max), xml).
  is-unicode is #t for UTF-16 data, 'binary for raw bytes (returns a bytevector), or a codec
  ('utf8 / 'cp1252) for byte strings. Returns the value or #f for NULL.
Example:
  (tds-read-plp! bv-in #t) => \"hello world\""
      (let* ((lo (tds-read-u32-le! bv-in))
             (hi (tds-read-u32-le! bv-in)))
        (if (and (= lo #xFFFFFFFF) (= hi #xFFFFFFFF))
            #f  ; NULL
            (let loop ((chunks '()))
              (let ((chunk-len (tds-read-u32-le! bv-in)))
                (if (= chunk-len 0)
                    ;; End of PLP: assemble and decode
                    (let* ((all-bv (apply bytevector-append (reverse chunks))))
                      (cond ((eq? is-unicode #t)
                             (utf16le->string all-bv 0 (bytevector-length all-bv)))
                            ((eq? is-unicode 'binary) all-bv)
                            ((eq? is-unicode 'utf8) (utf8->string all-bv))
                            (else (tds-decode-bytes all-bv is-unicode))))
                    (loop (cons (read-bytevector chunk-len bv-in) chunks))))))))

    ;; Read one column value from a ROW token stream, based on column descriptor
    (define (tds-read-col-value! bv-in type-byte type-params)
      "Syntax: (tds-read-col-value! bv-in type-byte type-params)
Library: (scm database sqlserver)
Description: Reads one column value from a ROW data stream. Returns a string, or #f for NULL.
  type-byte and type-params come from the corresponding COLMETADATA descriptor.
Example:
  (tds-read-col-value! bv-in #x26 '(4)) => \"42\""
      (cond
        ;; Fixed TINYINT (1 byte, no length prefix)
        ((= type-byte #x1F)
         (number->string (read-u8 bv-in)))
        ;; Fixed SMALLINT (2 bytes, no length prefix)
        ((= type-byte #x34)
         (let* ((b0 (read-u8 bv-in)) (b1 (read-u8 bv-in))
                (u  (+ b0 (* b1 256))))
           (number->string (if (>= u #x8000) (- u #x10000) u))))
        ;; Fixed INT (4 bytes, no length prefix)
        ((= type-byte #x38)
         (number->string (tds-read-i32-le! bv-in)))
        ;; Fixed BIGINT (8 bytes, no length prefix)
        ((= type-byte #x7F)
         (let* ((lo        (tds-read-u32-le! bv-in))
                (hi        (tds-read-u32-le! bv-in))
                (hi-signed (if (>= hi #x80000000) (- hi #x100000000) hi)))
           (number->string (+ lo (* hi-signed #x100000000)))))
        ;; Fixed REAL (4 bytes, IEEE 754)
        ((= type-byte #x3C)
         (tds-ieee->string (read-bytevector 4 bv-in)))
        ;; Fixed FLOAT (8 bytes, IEEE 754)
        ((= type-byte #x3E)
         (tds-ieee->string (read-bytevector 8 bv-in)))
        ;; Fixed DATETIME (8 bytes: int32 days LE + uint32 1/300-sec LE)
        ((= type-byte #x3D)
         (let* ((days (tds-read-i32-le! bv-in))
                (t300 (tds-read-u32-le! bv-in)))
           (tds-datetime->string days t300)))
        ;; Fixed SMALLDATETIME (4 bytes: uint16 days LE + uint16 mins LE)
        ((= type-byte #x61)
         (let* ((days (tds-read-u16-le! bv-in))
                (mins (tds-read-u16-le! bv-in)))
           (tds-smalldatetime->string days mins)))
        ;; Fixed MONEY (8 bytes: high int32 LE, low uint32 LE → value/10000)
        ((= type-byte #x65)
         (let* ((hi (tds-read-i32-le! bv-in))
                (lo (tds-read-u32-le! bv-in))
                (v  (+ (* hi #x100000000) lo))
                (d  (quotient v 10000))
                (c  (abs (modulo v 10000))))
           (string-append (number->string d) "." (tds-pad c 4))))
        ;; Fixed SMALLMONEY (4 bytes: int32 LE → value/10000)
        ((= type-byte #x7A)
         (let* ((v (tds-read-i32-le! bv-in))
                (d (quotient v 10000))
                (c (abs (modulo v 10000))))
           (string-append (number->string d) "." (tds-pad c 4))))
        ;; INTN: 1-byte actual size, then that many bytes LE signed
        ((= type-byte #x26)
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (number->string (tds-read-int-le! bv-in actual)))))
        ;; BITN: 1-byte actual size, then 1 byte (0 or 1)
        ((= type-byte #x68)
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (if (= (read-u8 bv-in) 0) "0" "1"))))
        ;; FLOATN: 1-byte actual size, then IEEE bytes
        ((= type-byte #x6D)
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (tds-ieee->string (read-bytevector actual bv-in)))))
        ;; MONEYN: 1-byte actual size
        ((= type-byte #x6E)
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (let* ((bv (read-bytevector actual bv-in))
                      (v  (if (= actual 4)
                              (tds-bv-uint-le bv 0 4)   ; SMALLMONEY
                              ;; MONEY: high int32 * 2^32 + low uint32
                              (let ((hi (tds-bv-uint-le bv 4 4))
                                    (lo (tds-bv-uint-le bv 0 4)))
                                (+ lo (* hi #x100000000)))))
                      (signed (let ((max (expt 256 actual)))
                                (if (>= v (quotient max 2)) (- v max) v)))
                      (d (quotient signed 10000))
                      (c (abs (modulo signed 10000))))
                 (string-append (number->string d) "." (tds-pad c 4))))))
        ;; DECIMALN / NUMERICN: 1-byte actual size, then sign(1) + integer bytes LE
        ((or (= type-byte #x6A) (= type-byte #x6C))
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (let* ((scale     (caddr type-params))
                      (sign-byte (read-u8 bv-in))
                      (nbytes    (- actual 1))
                      (int-val   (tds-bv-uint-le (read-bytevector nbytes bv-in) 0 nbytes))
                      (negative  (= sign-byte 0))
                      (str-int   (number->string int-val))
                      (padded    (if (< (string-length str-int) (+ scale 1))
                                     (string-append
                                      (make-string (- (+ scale 1) (string-length str-int)) #\0)
                                      str-int)
                                     str-int))
                      (result    (if (= scale 0) padded
                                     (string-append
                                      (substring padded 0 (- (string-length padded) scale))
                                      "."
                                      (substring padded (- (string-length padded) scale)
                                                 (string-length padded))))))
                 (if negative (string-append "-" result) result)))))
        ;; DATETIMN: 1-byte actual size
        ((= type-byte #x6F)
         (let ((actual (read-u8 bv-in)))
           (cond
             ((= actual 0) #f)
             ((= actual 4)
              (let* ((days (tds-read-u16-le! bv-in))
                     (mins (tds-read-u16-le! bv-in)))
                (tds-smalldatetime->string days mins)))
             ((= actual 8)
              (let* ((days (tds-read-i32-le! bv-in))
                     (t300 (tds-read-u32-le! bv-in)))
                (tds-datetime->string days t300)))
             (else (tds-bv->hex (read-bytevector actual bv-in))))))
        ;; UNIQUEIDENTIFIER: 1-byte actual size, then 16 bytes
        ((= type-byte #x24)
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (tds-guid->string (read-bytevector 16 bv-in)))))
        ;; VARCHAR / CHAR (byte strings, not unicode): 2-byte LE length
        ((or (= type-byte #xA7) (= type-byte #xAF))
         (let ((max-len (if (null? type-params) 0 (car type-params))))
           (if (= max-len #xFFFF)
               (tds-read-plp! bv-in (cadr type-params))
               (let ((len (tds-read-u16-le! bv-in)))
                 (cond ((= len #xFFFF) #f)
                       ((= len 0) "")
                       (else (tds-decode-bytes (read-bytevector len bv-in)
                                               (cadr type-params))))))))
        ;; NVARCHAR / NCHAR (UTF-16 LE): 2-byte LE length
        ((or (= type-byte #xE7) (= type-byte #xEF))
         (let ((max-len (if (null? type-params) 0 (car type-params))))
           (if (= max-len #xFFFF)
               (tds-read-plp! bv-in #t)
               (let ((len (tds-read-u16-le! bv-in)))
                 (cond ((= len #xFFFF) #f)
                       ((= len 0) "")
                       (else (utf16le->string (read-bytevector len bv-in) 0 len)))))))
        ;; VARBINARY / BINARY: 2-byte LE length, hex output
        ((or (= type-byte #xA5) (= type-byte #xA8))
         (let ((max-len (if (null? type-params) 0 (car type-params))))
           (if (= max-len #xFFFF)
               (let ((plp (tds-read-plp! bv-in 'binary)))
                 (if plp (tds-bv->hex plp) #f))
               (let ((len (tds-read-u16-le! bv-in)))
                 (cond ((= len #xFFFF) #f)
                       ((= len 0) "")
                       (else (tds-bv->hex (read-bytevector len bv-in))))))))
        ;; DATE (0x28): 1-byte actual size, then 3 bytes LE days since 0001-01-01
        ((= type-byte #x28)
         (let ((actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (let* ((b0 (read-u8 bv-in))
                      (b1 (read-u8 bv-in))
                      (b2 (read-u8 bv-in))
                      (days (+ b0 (* b1 256) (* b2 65536))))
                 (tds-date-days->string days)))))
        ;; TIME (0x29): 1-byte actual size, then time bytes
        ((= type-byte #x29)
         (let* ((scale  (if (null? type-params) 7 (car type-params)))
                (actual (read-u8 bv-in)))
           (if (= actual 0) #f
               (let ((bv (read-bytevector actual bv-in)))
                 (tds-time-bv->string bv scale)))))
        ;; DATETIME2N (0x2A): 1-byte actual size, then time-bytes + 3 date bytes
        ((= type-byte #x2A)
         (let* ((scale     (if (null? type-params) 7 (car type-params)))
                (actual    (read-u8 bv-in)))
           (if (= actual 0) #f
               (let* ((time-size (tds-time-bytes-for-scale scale))
                      (time-bv   (read-bytevector time-size bv-in))
                      (b0 (read-u8 bv-in)) (b1 (read-u8 bv-in)) (b2 (read-u8 bv-in))
                      (days      (+ b0 (* b1 256) (* b2 65536)))
                      (time-str  (tds-time-bv->string time-bv scale))
                      (date-str  (tds-date-days->string days)))
                 (string-append date-str " " time-str)))))
        ;; DATETIMEOFFSETN (0x2B): 1-byte actual size, then time-bytes + 3 date bytes + 2 offset bytes
        ((= type-byte #x2B)
         (let* ((scale     (if (null? type-params) 7 (car type-params)))
                (actual    (read-u8 bv-in)))
           (if (= actual 0) #f
               (let* ((time-size (tds-time-bytes-for-scale scale))
                      (time-bv   (read-bytevector time-size bv-in))
                      (b0 (read-u8 bv-in)) (b1 (read-u8 bv-in)) (b2 (read-u8 bv-in))
                      (days      (+ b0 (* b1 256) (* b2 65536)))
                      (off-min   (let* ((ol (read-u8 bv-in)) (oh (read-u8 bv-in))
                                        (u  (+ ol (* oh 256))))
                                   (if (>= u #x8000) (- u #x10000) u)))
                      (time-str  (tds-time-bv->string time-bv scale))
                      (date-str  (tds-date-days->string days))
                      (tz-h      (quotient (abs off-min) 60))
                      (tz-m      (modulo (abs off-min) 60))
                      (tz-sign   (if (< off-min 0) "-" "+")))
                 (string-append date-str " " time-str " "
                                tz-sign (tds-pad tz-h 2) ":" (tds-pad tz-m 2))))))
        ;; XML: read as PLP string
        ((= type-byte #xF1)
         (tds-read-plp! bv-in #t))
        ;; TEXT / NTEXT / IMAGE: textptr-len(1) [textptr + timestamp(8) + len(4) + data]
        ((or (= type-byte #x23) (= type-byte #x63) (= type-byte #x22))
         (let ((ptr-len (read-u8 bv-in)))
           (if (= ptr-len 0) #f
               (begin
                 (read-bytevector ptr-len bv-in)
                 (read-bytevector 8 bv-in)
                 (let* ((len (tds-read-u32-le! bv-in))
                        (bv  (if (= len 0) (bytevector) (read-bytevector len bv-in))))
                   (cond ((= type-byte #x63) (utf16le->string bv 0 len))
                         ((= type-byte #x22) (tds-bv->hex bv))
                         (else (tds-decode-bytes bv (car type-params)))))))))
        ;; SQL_VARIANT: 4-byte length, then raw value (returned as hex)
        ((= type-byte #x62)
         (let ((len (tds-read-u32-le! bv-in)))
           (if (= len 0) #f (tds-bv->hex (read-bytevector len bv-in)))))
        ;; Fallback for unknown types: try 1-byte length prefix
        (else
         (let ((len (read-u8 bv-in)))
           (if (= len 0) #f
               (tds-bv->hex (read-bytevector len bv-in)))))))

    ;; --- Token stream parsing ---

    ;; Parse an ERROR token body; raise a Scheme error with the message
    (define (tds-parse-error-token! body)
      "Syntax: (tds-parse-error-token! body)
Library: (scm database sqlserver)
Description: Parses an ERROR token body bytevector and raises a Scheme error whose message
  is the server text; the irritants are the error number, state and severity.
Example:
  (tds-parse-error-token! body)"
      (let* ((bv-err  (open-input-bytevector body))
             (number  (tds-read-u32-le! bv-err))
             (state   (read-u8 bv-err))
             (class   (read-u8 bv-err))
             (msg-len (tds-read-u16-le! bv-err))
             (msg-bv  (read-bytevector (* 2 msg-len) bv-err))
             (msg     (utf16le->string msg-bv 0 (* 2 msg-len))))
        (error (string-append "ss: SQL Server error " (number->string number) ": " msg)
               number state class)))

    ;; Tokens with a 2-byte length prefix that carry nothing we need:
    ;; INFO, ENVCHANGE, LOGINACK, ORDER, COLINFO, TABNAME
    (define (tds-skippable-u16-token? token)
      (memv token '(#xAB #xE3 #xAD #xA9 #xA5 #xA4)))

    ;; Skip a token's body if it is a known no-data token; returns #t if skipped
    (define (tds-skip-token! token bv-in)
      (cond
        ((tds-skippable-u16-token? token)
         (read-bytevector (tds-read-u16-le! bv-in) bv-in)
         #t)
        ;; SESSIONSTATE (0xE4) / FEATUREEXTACK-free DATACLASSIFICATION use 4-byte lengths
        ((= token #xE4)
         (read-bytevector (tds-read-u32-le! bv-in) bv-in)
         #t)
        ;; RETURNSTATUS (0x79): 4-byte return code
        ((= token #x79)
         (read-bytevector 4 bv-in)
         #t)
        ;; FEATUREEXTACK (0xAE): (featureId(1) [len(4) data])* terminated by 0xFF
        ((= token #xAE)
         (let loop ()
           (let ((fid (read-u8 bv-in)))
             (unless (or (eof-object? fid) (= fid #xFF))
               (read-bytevector (tds-read-u32-le! bv-in) bv-in)
               (loop))))
         #t)
        (else #f)))

    ;; DONE / DONEPROC / DONEINPROC body: status(2) curCmd(2) rowCount(8); returns status
    (define (tds-read-done! bv-in)
      (let* ((status (tds-read-u16-le! bv-in)))
        (tds-read-u16-le! bv-in)
        (read-bytevector 8 bv-in)
        status))

    ;; Read token stream until login completion; raises on ERROR tokens
    (define (tds-read-login-response! bv-in)
      "Syntax: (tds-read-login-response! bv-in)
Library: (scm database sqlserver)
Description: Reads the login response token stream until DONE. Raises an error on ERROR
  tokens, or when no LOGINACK was received.
Example:
  (tds-read-login-response! bv-in)"
      (let loop ((acked #f))
        (let ((token (read-u8 bv-in)))
          (cond
            ((eof-object? token)
             (unless acked (error "ss: login failed (no LOGINACK from server)"))
             #t)
            ((= token #xAD)
             (read-bytevector (tds-read-u16-le! bv-in) bv-in)
             (loop #t))
            ((= token #xAA)
             (let* ((len  (tds-read-u16-le! bv-in))
                    (body (read-bytevector len bv-in)))
               (tds-parse-error-token! body)))
            ((or (= token #xFD) (= token #xFE) (= token #xFF))
             (tds-read-done! bv-in)
             (loop acked))
            ((tds-skip-token! token bv-in) (loop acked))
            (else
             (error "ss: unexpected token during login" token))))))

    ;; Read one ROW (0xD1) or NBCROW (0xD2) into a vector
    (define (tds-read-row! bv-in cols nbc?)
      (let* ((ncols  (vector-length cols))
             (bitmap (and nbc? (read-bytevector (quotient (+ ncols 7) 8) bv-in)))
             (row    (make-vector ncols #f)))
        (define (null-bit? i)
          (odd? (quotient (bytevector-u8-ref bitmap (quotient i 8))
                          (expt 2 (modulo i 8)))))
        (do ((i 0 (+ i 1))) ((= i ncols) row)
          (unless (and bitmap (null-bit? i))
            (let ((col (vector-ref cols i)))
              (vector-set! row i (tds-read-col-value! bv-in
                                                      (vector-ref col 1)
                                                      (vector-ref col 2))))))))

    ;; Read full result from token stream; returns #(cols rows)
    ;; ENVCHANGE body: type(1) + new/old values. Types 8 (begin transaction) carries the
    ;; new transaction descriptor; 9/10/17/18 (commit/rollback/defect/ended) reset it.
    (define (tds-apply-envchange! body conn)
      (when (and conn (> (bytevector-length body) 0))
        (let ((type (bytevector-u8-ref body 0)))
          (cond
            ((and (= type 8) (>= (bytevector-length body) 10))
             (vector-set! conn 3 (bytevector-copy body 2 10)))
            ((memv type '(9 10 17 18))
             (vector-set! conn 3 (make-bytevector 8 0)))))))

    (define (tds-read-result! bv-in . opt-conn)
      "Syntax: (tds-read-result! bv-in)
Library: (scm database sqlserver)
Description: Reads the complete token stream of one response. Collects COLMETADATA and
  ROW / NBCROW tokens into a result vector #(cols rows) where cols is a column name
  vector and rows is a list of row vectors (#f for NULL). Rows of several result sets
  are concatenated; cols are those of the last result set. Raises on ERROR tokens.
Example:
  (tds-read-result! bv-in) => #(#(\"id\" \"name\") (#(\"1\" \"alice\")))"
      (let loop ((cols #f) (rows '()) (err #f))
        (let ((token (read-u8 bv-in)))
          (define (finish)
            (if err
                (tds-parse-error-token! err)
                (let* ((cols    (or cols (vector)))
                       (visible (let vis ((i (- (vector-length cols) 1)) (acc '()))
                                  (if (< i 0) acc
                                      (vis (- i 1)
                                           (if (vector-ref (vector-ref cols i) 3)
                                               acc
                                               (cons i acc))))))
                       (strip   (if (= (length visible) (vector-length cols))
                                    (lambda (row) row)
                                    (lambda (row)
                                      (list->vector (map (lambda (i) (vector-ref row i))
                                                         visible))))))
                  (vector (list->vector (map (lambda (i) (vector-ref (vector-ref cols i) 0))
                                             visible))
                          (map strip (reverse rows))))))
          (cond
            ((eof-object? token) (finish))
            ((= token #x81)
             (let ((new-cols (tds-parse-colmetadata! bv-in)))
               (loop (or new-cols cols) rows err)))
            ((or (= token #xD1) (= token #xD2))
             (if (not cols)
                 (error "ss: ROW token before COLMETADATA")
                 (loop cols (cons (tds-read-row! bv-in cols (= token #xD2)) rows) err)))
            ((or (= token #xFD) (= token #xFE) (= token #xFF))
             ;; the response is fully buffered (up to EOM), so read on until EOF
             (tds-read-done! bv-in)
             (loop cols rows err))
            ;; ERROR: remember the first one, keep reading so the stream stays in sync
            ((= token #xAA)
             (let* ((len  (tds-read-u16-le! bv-in))
                    (body (read-bytevector len bv-in)))
               (loop cols rows (or err body))))
            ((= token #xE3)
             (tds-apply-envchange! (read-bytevector (tds-read-u16-le! bv-in) bv-in)
                                   (and (pair? opt-conn) (car opt-conn)))
             (loop cols rows err))
            ((tds-skip-token! token bv-in) (loop cols rows err))
            (else
             (error "ss: unexpected token in result stream" token))))))

    ;; --- Connection lifecycle ---

    (define (ss-option opts key dflt)
      (let ((p (assq key opts))) (if p (cdr p) dflt)))

    (define (ss-connect host port user password database . rest)
      "Syntax: (ss-connect host port user password database [options])
Library: (scm database sqlserver)
Description: Opens a TDS connection to SQL Server, performs TLS negotiation (via tds-connect),
  and completes Login7 SQL Server authentication. Returns a connection vector
  #(in out sock transaction-descriptor).
  port is a TCP port number, or the name of a named instance (a string such as
  \"SQLEXPRESS\"), whose port is then looked up through the SQL Server Browser
  service on UDP 1434 (see ss-instance-port).
  options is an alist:
    (encrypt . #t)                   ; #t = TLS for the whole session (default),
                                     ; #f = no TLS (only if the server allows it)
    (trust-server-certificate . #t)  ; #t = accept any server certificate (default),
                                     ; #f = validate the chain and host name
    (host-in-certificate . \"name\")   ; expected certificate host name (default: host)
    (app-name . \"scm\")               ; application name shown in sys.dm_exec_sessions
Example:
  (define conn (ss-connect \"localhost\" 1433 \"sa\" \"Password123!\" \"master\"
                           '((trust-server-certificate . #f))))
  (define conn2 (ss-connect \"dbhost\" \"SQLEXPRESS\" \"app\" \"secret\" \"appdb\"))"
      (let* ((opts    (if (null? rest) '() (car rest)))
             (encrypt (ss-option opts 'encrypt #t))
             (trust   (ss-option opts 'trust-server-certificate #t))
             (cn      (ss-option opts 'host-in-certificate host))
             (sock    ((%primitive "tds-connect") host port encrypt (not trust) cn))
             (in      (socket-binary-input-port sock))
             (out     (socket-binary-output-port sock)))
        (guard (e (#t (guard (e2 (#t #f)) (socket-close sock)) (raise e)))
          (tds-send-login7! out user password database
                            "scm" host (ss-option opts 'app-name "scm"))
          (let ((body (tds-read-all-packets! in)))
            (tds-read-login-response! (open-input-bytevector body))))
        (vector in out sock (make-bytevector 8 0))))

    (define (ss-instance-port host instance . rest)
      "Syntax: (ss-instance-port host instance [timeout-ms])
Library: (scm database sqlserver)
Description: Returns the TCP port of the named SQL Server instance on host, as reported
  by the SQL Server Browser service (UDP 1434). Raises an error when the browser does
  not answer within timeout-ms (default 5000) or does not know the instance.
Example:
  (ss-instance-port \"dbhost\" \"SQLEXPRESS\") ; => 49170"
      (apply (%primitive "sql-browser-port") host instance rest))

    (define (ss-close conn)
      "Syntax: (ss-close conn)
Library: (scm database sqlserver)
Description: Closes the TCP connection to the SQL Server.
Example:
  (ss-close conn)"
      (socket-close (vector-ref conn 2)))

    ;; --- Parameter formatting ---

    (define (ss-sql-literal v)
      "Syntax: (ss-sql-literal v)
Library: (scm database sqlserver)
Description: Converts a Scheme value to a T-SQL literal: strings -> N'...' (quotes doubled),
  exact integers and finite reals -> numbers, #t/#f -> 1/0, 'null -> NULL, bytevectors ->
  0x..., lists -> (a, b, ...) for IN, with '() -> (NULL).
Example:
  (ss-sql-literal \"O'Brien\") => \"N'O''Brien'\""
      (cond
        ((string? v)
         (let ((out (open-output-string)))
           (write-string "N'" out)
           (string-for-each (lambda (c)
                              (if (char=? c #\') (write-string "''" out) (write-char c out)))
                            v)
           (write-string "'" out)
           (get-output-string out)))
        ((and (integer? v) (exact? v)) (number->string v))
        ((and (real? v) (not (nan? v)) (not (infinite? v)))
         (number->string (if (exact? v) (inexact v) v)))
        ((eq? v #t) "1")
        ((eq? v #f) "0")
        ((eq? v 'null) "NULL")
        ((bytevector? v) (string-append "0x" (tds-bv->hex v)))
        ((null? v) "(NULL)")
        ((pair? v)
         (let loop ((xs v) (acc '()))
           (if (null? xs)
               (string-append "(" (apply string-append (reverse acc)) ")")
               (loop (cdr xs)
                     (cons (string-append (if (null? acc) "" ", ") (ss-sql-literal (car xs)))
                           acc)))))
        (else (error "ss-sql-literal: unsupported parameter value" v))))

    (define (ss-format-sql sql params)
      "Syntax: (ss-format-sql sql params)
Library: (scm database sqlserver)
Description: Returns sql with $1, $2, ... replaced by the T-SQL literals of the
  corresponding (1-indexed) params. Placeholders inside string literals, quoted
  identifiers (\"...\" and [...]) and comments are left alone. Raises on $0 or $N
  out of range.
Example:
  (ss-format-sql \"WHERE f.jahr = $1 AND f.burnr IN $2\" '(2024 (\"1\" \"2\")))
  => \"WHERE f.jahr = 2024 AND f.burnr IN (N'1', N'2')\""
      (let* ((n   (string-length sql))
             (pv  (list->vector params))
             (out (open-output-string)))
        (define (at i) (string-ref sql i))
        (define (digit? i) (and (< i n) (char-numeric? (at i))))
        (define (copy-until! i close)
          ;; copy from i (opening char already written) through the closing char
          (let loop ((i i))
            (cond ((>= i n) i)
                  ((char=? (at i) close)
                   (write-char close out)
                   (if (and (< (+ i 1) n) (char=? (at (+ i 1)) close) (not (char=? close #\])))
                       (begin (write-char close out) (loop (+ i 2)))
                       (+ i 1)))
                  (else (write-char (at i) out) (loop (+ i 1))))))
        (let loop ((i 0))
          (if (>= i n)
              (get-output-string out)
              (let ((c (at i)))
                (cond
                  ((char=? c #\') (write-char c out) (loop (copy-until! (+ i 1) #\')))
                  ((char=? c #\") (write-char c out) (loop (copy-until! (+ i 1) #\")))
                  ((char=? c #\[) (write-char c out) (loop (copy-until! (+ i 1) #\])))
                  ((and (char=? c #\-) (< (+ i 1) n) (char=? (at (+ i 1)) #\-))
                   (let cl ((i i))
                     (cond ((>= i n) (loop i))
                           ((char=? (at i) #\newline) (loop i))
                           (else (write-char (at i) out) (cl (+ i 1))))))
                  ((and (char=? c #\/) (< (+ i 1) n) (char=? (at (+ i 1)) #\*))
                   (let cl ((i i))
                     (cond ((>= i n) (loop i))
                           ((and (char=? (at i) #\*) (< (+ i 1) n) (char=? (at (+ i 1)) #\/))
                            (write-string "*/" out) (loop (+ i 2)))
                           (else (write-char (at i) out) (cl (+ i 1))))))
                  ((and (char=? c #\$) (digit? (+ i 1)))
                   (let num ((j (+ i 1)) (k 0))
                     (if (digit? j)
                         (num (+ j 1) (+ (* k 10) (- (char->integer (at j)) 48)))
                         (begin
                           (when (or (< k 1) (> k (vector-length pv)))
                             (error (string-append "ss-format-sql: $" (number->string k)
                                                   " but only "
                                                   (number->string (vector-length pv))
                                                   " param(s) supplied")))
                           (write-string (ss-sql-literal (vector-ref pv (- k 1))) out)
                           (loop j)))))
                  (else (write-char c out) (loop (+ i 1)))))))))

    ;; --- Query execution ---

    ;; ALL_HEADERS with a Transaction Descriptor header (required for TDS 7.2+ SQLBatch).
    ;; The descriptor is the one of the open transaction (from ENVCHANGE), zeros otherwise.
    (define (tds-all-headers txn)
      (let ((buf (open-output-bytevector)))
        (tds-write-u32-le! 22 buf)            ; TotalLength
        (tds-write-u32-le! 18 buf)            ; HeaderLength
        (tds-write-u16-le! 2 buf)             ; HeaderType: transaction descriptor
        (write-bytevector txn buf)            ; TransactionDescriptor (8 bytes)
        (tds-write-u32-le! 1 buf)             ; OutstandingRequestCount
        (get-output-bytevector buf)))

    (define (ss-query conn sql . params)
      "Syntax: (ss-query conn sql [param ...])
Library: (scm database sqlserver)
Description: Executes a SQL batch and returns a result object #(cols rows). $1, $2, ...
  in sql are replaced by the T-SQL literals of the params (see ss-format-sql). Use
  ss-result-columns and ss-result-rows to access the result.
Example:
  (define result (ss-query conn \"SELECT id, name FROM users WHERE id = $1\" 42))"
      (let* ((in   (vector-ref conn 0))
             (out  (vector-ref conn 1))
             (text (if (null? params) sql (ss-format-sql sql params)))
             (bv   (bytevector-append (tds-all-headers (vector-ref conn 3))
                                      (string->utf16le text))))
        ;; SQL Batch: type 0x01, ALL_HEADERS + UTF-16 LE SQL text
        (tds-send-packet! out #x01 bv)
        (let ((body (tds-read-all-packets! in)))
          (tds-read-result! (open-input-bytevector body) conn))))

    (define (ss-exec conn sql . params)
      "Syntax: (ss-exec conn sql [param ...])
Library: (scm database sqlserver)
Description: Executes a SQL statement and discards the result. Suitable for DDL and DML.
Example:
  (ss-exec conn \"CREATE TABLE #t (id INT, name NVARCHAR(50))\")"
      (apply ss-query conn sql params)
      #t)

    ;; --- Public result accessors ---

    (define (ss-result-columns result)
      "Syntax: (ss-result-columns result)
Library: (scm database sqlserver)
Description: Returns the column name vector from a query result.
Example:
  (ss-result-columns result) => #(\"id\" \"name\")"
      (vector-ref result 0))

    (define (ss-result-rows result)
      "Syntax: (ss-result-rows result)
Library: (scm database sqlserver)
Description: Returns the list of row vectors from a query result. Each row is a vector of
  string values, or #f for NULL values.
Example:
  (ss-result-rows result) => (#(\"1\" \"alice\") #(\"2\" \"bob\"))"
      (vector-ref result 1))

    (define (ss-result->alist-list result)
      "Syntax: (ss-result->alist-list result)
Library: (scm database sqlserver)
Description: Converts a query result to a list of association lists, one per row.
  Each alist maps column name strings to value strings (or #f for NULL).
Example:
  (ss-result->alist-list result) => ((\"id\" . \"1\") (\"name\" . \"alice\")) ...)"
      (let ((cols (ss-result-columns result))
            (rows (ss-result-rows result)))
        (map (lambda (row)
               (let loop ((i 0) (acc '()))
                 (if (= i (vector-length cols))
                     (reverse acc)
                     (loop (+ i 1)
                           (cons (cons (vector-ref cols i) (vector-ref row i))
                                 acc)))))
             rows)))

    ;; --- Cursor API ---

    (define *ss-cursor-counter* 0)

    (define (ss-cursor-next-name!)
      "Syntax: (ss-cursor-next-name!)
Library: (scm database sqlserver)
Description: Generates a unique server-side cursor name by incrementing a global counter.
  Returns a string of the form \"ss_cursor_N\".
Example:
  (ss-cursor-next-name!) => \"ss_cursor_1\""
      (set! *ss-cursor-counter* (+ *ss-cursor-counter* 1))
      (string-append "ss_cursor_" (number->string *ss-cursor-counter*)))

    (define (ss-cursor-open conn sql)
      "Syntax: (ss-cursor-open conn sql)
Library: (scm database sqlserver)
Description: Opens a server-side cursor for the given SQL query using DECLARE CURSOR
  inside a transaction. Returns a cursor object. Call ss-cursor-close when done.
Example:
  (define cur (ss-cursor-open conn \"SELECT id, name FROM users ORDER BY id\"))"
      (let ((name (ss-cursor-next-name!)))
        (ss-exec conn "BEGIN TRANSACTION")
        (guard (exn (#t
                     (guard (e (#t #f)) (ss-exec conn "ROLLBACK TRANSACTION"))
                     (raise exn)))
          (ss-exec conn (string-append
                         "DECLARE " name " CURSOR FORWARD_ONLY READ_ONLY FOR " sql))
          (ss-exec conn (string-append "OPEN " name)))
        (vector conn name #f #f)))

    (define (ss-cursor-fetch cursor . rest)
      "Syntax: (ss-cursor-fetch cursor [n])
Library: (scm database sqlserver)
Description: Fetches up to n rows from the cursor (default 1). Returns a list of row vectors.
  Returns an empty list when the cursor is exhausted.
Example:
  (ss-cursor-fetch cur 100)"
      (if (vector-ref cursor 3)
          '()
          (let* ((n    (if (null? rest) 1 (car rest)))
                 (conn (vector-ref cursor 0))
                 (name (vector-ref cursor 1)))
            (guard (exn (#t
                         (vector-set! cursor 3 #t)
                         (guard (e (#t #f)) (ss-exec conn "ROLLBACK TRANSACTION"))
                         (raise exn)))
              ;; T-SQL FETCH returns one row per statement: send n of them in one batch
              (let* ((stmt   (string-append "FETCH NEXT FROM " name ";"))
                     (result (ss-query conn (apply string-append
                                                   (vector->list (make-vector n stmt)))))
                     (cols0  (ss-result-columns result))
                     ;; T-SQL FETCH appends a ROWSTAT status column: drop it
                     (strip? (and (> (vector-length cols0) 0)
                                  (equal? (vector-ref cols0 (- (vector-length cols0) 1))
                                          "ROWSTAT")))
                     (cut    (lambda (v) (if strip? (vector-copy v 0 (- (vector-length v) 1)) v)))
                     (cols   (cut cols0))
                     (rows   (map cut (ss-result-rows result))))
                (if (not (vector-ref cursor 2))
                    (vector-set! cursor 2 cols))
                (if (< (length rows) n) (vector-set! cursor 3 'eof))
                rows)))))

    (define (ss-cursor-columns cursor)
      "Syntax: (ss-cursor-columns cursor)
Library: (scm database sqlserver)
Description: Returns the column name vector for the cursor, or #f before the first fetch.
Example:
  (ss-cursor-columns cur) => #(\"id\" \"name\")"
      (vector-ref cursor 2))

    (define (ss-cursor-close cursor)
      "Syntax: (ss-cursor-close cursor)
Library: (scm database sqlserver)
Description: Closes the cursor, deallocates it, and commits the transaction. Returns #t.
  Safe to call multiple times; subsequent calls are no-ops.
Example:
  (ss-cursor-close cur)"
      (if (eq? (vector-ref cursor 3) #t)
          #t
          (let ((conn (vector-ref cursor 0))
                (name (vector-ref cursor 1)))
            (guard (exn (#t
                         (vector-set! cursor 3 #t)
                         (guard (e (#t #f)) (ss-exec conn "ROLLBACK TRANSACTION"))
                         (raise exn)))
              (ss-exec conn (string-append "CLOSE " name))
              (ss-exec conn (string-append "DEALLOCATE " name))
              (ss-exec conn "COMMIT TRANSACTION")
              (vector-set! cursor 3 #t)
              #t))))

    (define (ss-cursor-for-each cursor proc . rest)
      "Syntax: (ss-cursor-for-each cursor proc [batch-size])
Library: (scm database sqlserver)
Description: Calls proc on each row vector from the cursor in batches (default 100).
  Automatically closes the cursor when all rows are consumed.
Example:
  (ss-cursor-for-each cur (lambda (row) (display (vector-ref row 0))) 50)"
      (let ((batch (if (null? rest) 100 (car rest))))
        (let loop ()
          (let ((rows (ss-cursor-fetch cursor batch)))
            (if (null? rows)
                (ss-cursor-close cursor)
                (begin
                  (for-each proc rows)
                  (loop)))))))

    ;; --- Resource-safe wrappers ---

    (define (with-ss-connection host port user password database proc)
      "Syntax: (with-ss-connection host port user password database proc)
Library: (scm database sqlserver)
Description: Opens a SQL Server connection, calls (proc conn), and closes the connection
  on exit even if an exception is raised.
Example:
  (with-ss-connection \"localhost\" 1433 \"sa\" \"pass\" \"master\"
    (lambda (conn) (ss-result->alist-list (ss-query conn \"SELECT 1 AS n\"))))"
      (let ((conn (ss-connect host port user password database)))
        (guard (exn (#t (ss-close conn) (raise exn)))
          (let ((result (proc conn)))
            (ss-close conn)
            result))))

    (define (with-ss-query host port user password database sql proc)
      "Syntax: (with-ss-query host port user password database sql proc)
Library: (scm database sqlserver)
Description: Opens a connection and cursor, calls (proc conn cursor), and closes both
  on exit even if an exception is raised.
Example:
  (with-ss-query \"localhost\" 1433 \"sa\" \"pass\" \"master\" \"SELECT * FROM t\"
    (lambda (conn cursor) (ss-cursor-for-each cursor display)))"
      (with-ss-connection host port user password database
        (lambda (conn)
          (let ((cursor (ss-cursor-open conn sql)))
            (guard (exn (#t (ss-cursor-close cursor) (raise exn)))
              (let ((result (proc conn cursor)))
                (ss-cursor-close cursor)
                result))))))

))
