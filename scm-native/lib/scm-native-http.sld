(define-library (scm native http)
  (export http-get
          http-get-bytevector
          http-post
          http-send
          make-http-request
          http-request?
          http-request-method
          http-request-url
          http-request-headers
          http-request-body
          http-request-body-bytes
          http-request-body-file
          make-http-response
          make-http-file-response
          make-http-stream-response
          http-websocket-upgrade
          http-response-with-headers
          http-response?
          http-response-status
          http-response-headers
          http-response-body
          tcp-http-serve
          server-stop
          server-wait
          server-install-shutdown-hook
          ws-accept
          ws-connect
          ws-send
          ws-receive
          ws-close
          ws?)
  (import (scheme base)
          (scheme char)
          (except (scheme file) file-exists? delete-file)
          (only (scheme process-context) exit)
          (scheme write)
          (srfi 151)
          (scm bytevector)
          (scm crypto)
          (scm datetime)
          (scm fs)
          (scm net sockets)
          (scm native tasks))
  (begin
    ;; The HTTP client, the HTTP server (tcp-http-serve) and WebSockets of
    ;; dabscm native, as the JVM implementation's primitives (see its
    ;; behavior in scm-java's primitives). Written in Scheme over the
    ;; runtime's sockets.
    ;;
    ;; Native programs have no threads yet: the server is a cooperative
    ;; event loop. Each connection runs as a task (a continuation); a task
    ;; that would block on a socket yields to the scheduler, which polls the
    ;; waiting sockets and the listening servers. The program itself is a
    ;; task too: its network waits (a client reading a response, server-wait)
    ;; let the servers run. Handlers run one at a time.

    (define recv-some (%primitive "%socket-recv-some"))
    (define send-some (%primitive "%socket-send-some"))
    (define net-poll (%primitive "%net-poll"))
    (define shutdown-output (%primitive "%socket-shutdown-output"))
    (define tcp-listen-host (%primitive "%tcp-listen-host"))

    (define (now-ms) (timestamp))

    (define set-record-printer! (%primitive "%set-record-printer!"))

    ;; the servers' listeners are polled by the scheduler, (scm native tasks)
    (define servers '())

    (define (update-pollers!)
      (set-pollers! (map (lambda (s) (cons (server-listener s) (lambda () (accept-connection! s)))) servers))
      ((%primitive "%net-servers-running!") (length servers)))

    (define (remove-eq x l)
      (cond ((null? l) '())
            ((eq? (car l) x) (cdr l))
            (else (cons (car l) (remove-eq x (cdr l))))))

    (define (filter-list keep? l)
      (cond ((null? l) '())
            ((keep? (car l)) (cons (car l) (filter-list keep? (cdr l))))
            (else (filter-list keep? (cdr l)))))

    (define (any-list p l) (and (pair? l) (or (p (car l)) (any-list p (cdr l)))))

    ;; --- reading and writing sockets (yielding) -------------------------------

    ;; A buffered reader over a socket
    (define-record-type reader
      (%make-reader socket buf pos eof)
      reader?
      (socket reader-socket)
      (buf reader-buf set-reader-buf!)
      (pos reader-pos set-reader-pos!)
      (eof reader-eof? set-reader-eof!))

    (define (make-reader socket) (%make-reader socket (bytevector) 0 #f))

    (define (reader-available r) (- (bytevector-length (reader-buf r)) (reader-pos r)))

    ;; More bytes into r's buffer: #t, 'eof, or 'timeout
    (define (reader-fill! r deadline)
      (if (reader-eof? r)
          'eof
          (let loop ()
            (let ((got (guard (e (#t (eof-object))) (recv-some (reader-socket r) 65536))))
              (cond ((eof-object? got) (set-reader-eof! r #t) 'eof)
                    (got
                     (set-reader-buf! r (bytevector-append (bytevector-copy (reader-buf r) (reader-pos r)) got))
                     (set-reader-pos! r 0)
                     #t)
                    ((wait-for! (reader-socket r) 'read deadline) (loop))
                    (else 'timeout))))))

    ;; The bytes up to and including CRLFCRLF: a bytevector, 'eof, 'timeout
    ;; or 'too-long (more than limit bytes)
    (define (read-head r limit deadline)
      (let loop ((from 0))
        (let* ((buf (reader-buf r)) (pos (reader-pos r)) (n (bytevector-length buf)))
          (let scan ((i (+ pos from)))
            (cond ((> (- i pos) limit) 'too-long)
                  ((<= (+ i 4) n)
                   (if (and (= (bytevector-u8-ref buf i) 13) (= (bytevector-u8-ref buf (+ i 1)) 10)
                            (= (bytevector-u8-ref buf (+ i 2)) 13) (= (bytevector-u8-ref buf (+ i 3)) 10))
                       (let ((head (bytevector-copy buf pos (+ i 4))))
                         (set-reader-pos! r (+ i 4))
                         head)
                       (scan (+ i 1))))
                  (else
                   (let ((done (- i pos)))
                     (let ((f (reader-fill! r deadline)))
                       (if (eq? f #t) (loop done) f)))))))))

    ;; Up to n bytes (fewer only at the end of the stream), or 'timeout
    (define (read-n r n deadline)
      (let loop ((parts '()) (left n))
        (if (= left 0)
            (apply bytevector-append (reverse parts))
            (if (> (reader-available r) 0)
                (let* ((k (min left (reader-available r)))
                       (part (bytevector-copy (reader-buf r) (reader-pos r) (+ (reader-pos r) k))))
                  (set-reader-pos! r (+ (reader-pos r) k))
                  (loop (cons part parts) (- left k)))
                (let ((f (reader-fill! r deadline)))
                  (cond ((eq? f #t) (loop parts left))
                        ((eq? f 'eof) (apply bytevector-append (reverse parts)))
                        (else 'timeout)))))))

    ;; Everything up to the end of the stream
    (define (read-all r)
      (let loop ((parts '()))
        (if (> (reader-available r) 0)
            (let ((part (bytevector-copy (reader-buf r) (reader-pos r))))
              (set-reader-pos! r (bytevector-length (reader-buf r)))
              (loop (cons part parts)))
            (if (eq? (reader-fill! r #f) #t)
                (loop parts)
                (apply bytevector-append (reverse parts))))))

    ;; A line (without CR and LF) as bytes; 'eof, 'too-long or 'timeout
    (define (read-line-bytes r limit deadline)
      (let loop ((acc '()) (count 0))
        (if (> count limit)
            'too-long
            (if (> (reader-available r) 0)
                (let ((b (bytevector-u8-ref (reader-buf r) (reader-pos r))))
                  (set-reader-pos! r (+ (reader-pos r) 1))
                  (cond ((= b 10) (apply bytevector (reverse acc)))
                        ((= b 13) (loop acc count))
                        (else (loop (cons b acc) (+ count 1)))))
                (let ((f (reader-fill! r deadline)))
                  (if (eq? f #t) (loop acc count) f))))))

    ;; Write all of bv; #f if the connection failed
    (define (send-all socket bv)
      (let ((n (bytevector-length bv)))
        (let loop ((start 0))
          (or (>= start n)
              (let ((k (guard (e (#t #f)) (send-some socket bv start n))))
                (cond ((not k) #f)
                      ((= k 0) (wait-for! socket 'write #f) (loop start))
                      (else (loop (+ start k)))))))))

    ;; --- strings ---------------------------------------------------------------

    (define (lower s) (string-downcase s))

    (define (string-index-of s ch from)
      (let loop ((i from))
        (cond ((>= i (string-length s)) #f)
              ((char=? (string-ref s i) ch) i)
              (else (loop (+ i 1))))))

    (define (string-search s part)
      (let ((n (string-length s)) (m (string-length part)))
        (let loop ((i 0))
          (cond ((> (+ i m) n) #f)
                ((string=? (substring s i (+ i m)) part) i)
                (else (loop (+ i 1)))))))

    (define (starts-with? s p)
      (and (>= (string-length s) (string-length p)) (string=? (substring s 0 (string-length p)) p)))

    (define (trim s)
      (let* ((n (string-length s))
             (a (let loop ((i 0)) (if (and (< i n) (char<=? (string-ref s i) #\space)) (loop (+ i 1)) i)))
             (b (let loop ((i n)) (if (and (> i a) (char<=? (string-ref s (- i 1)) #\space)) (loop (- i 1)) i))))
        (substring s a b)))

    (define (split s ch)
      (let loop ((start 0) (i 0) (acc '()))
        (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) ch) (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop start (+ i 1) acc)))))

    ;; lines of a head (CRLF separated, the final CRLFCRLF removed)
    (define (head-lines text)
      (let ((body (substring text 0 (max 0 (- (string-length text) 4)))))
        (let loop ((start 0) (i 0) (acc '()))
          (cond ((>= (+ i 1) (string-length body))
                 (reverse (cons (substring body start (string-length body)) acc)))
                ((and (char=? (string-ref body i) #\return) (char=? (string-ref body (+ i 1)) #\newline))
                 (loop (+ i 2) (+ i 2) (cons (substring body start i) acc)))
                (else (loop start (+ i 1) acc))))))

    ;; (name . value) of the header lines (no colon or a leading colon: skipped)
    (define (parse-header-lines lines)
      (let loop ((ls lines) (acc '()))
        (if (null? ls)
            (reverse acc)
            (let* ((l (car ls)) (c (string-index-of l #\: 0)))
              (if (and c (> c 0))
                  (loop (cdr ls) (cons (cons (trim (substring l 0 c)) (trim (substring l (+ c 1) (string-length l)))) acc))
                  (loop (cdr ls) acc))))))

    (define (header-value headers name)
      (let ((n (lower name)))
        (let loop ((hs headers))
          (cond ((null? hs) #f)
                ((string=? (lower (caar hs)) n) (cdar hs))
                (else (loop (cdr hs)))))))

    (define (has-token? value token)
      (and value (any-list (lambda (t) (string=? (lower (trim t)) token)) (split value #\,))))

    (define (check-headers who headers)
      (unless (list? headers) (error (string-append "Failed in " who ": wrong argument type")))
      (for-each (lambda (h)
                  (unless (and (pair? h) (string? (car h)) (string? (cdr h)))
                    (error (string-append "Failed in " who ": wrong argument type"))))
                headers))

    (define (crlf-free s)
      (let ((out (open-output-string)))
        (string-for-each (lambda (c) (unless (memv c '(#\return #\newline #\null)) (write-char c out))) s)
        (get-output-string out)))

    ;; --- request and response objects ----------------------------------------

    (define-record-type http-request
      (%make-request method url headers body bytes file timeout follow)
      http-request?
      (method request-method)
      (url request-url)
      (headers request-headers)
      (body request-body-string set-request-body-string!)
      (bytes request-bytes set-request-bytes!)
      (file request-file)
      (timeout request-timeout)
      (follow request-follow?))
    (set-record-printer! http-request '("#<http-request " 0 " " 1 ">"))

    (define (make-http-request method url headers body . opts)
      (unless (string? method) (error "Failed in make-http-request: wrong argument type"))
      (unless (string? url) (error "Failed in make-http-request: wrong argument type"))
      (check-headers "make-http-request" headers)
      (let ((timeout (if (pair? opts) (car opts) 600))
            (follow (or (< (length opts) 2) (cadr opts))))
        (unless (exact-integer? timeout) (error "Failed in make-http-request: wrong argument type"))
        (cond ((bytevector? body) (%make-request method url headers (utf8->string body) body #f timeout (and follow #t)))
              ((not body) (%make-request method url headers #f #f #f timeout (and follow #t)))
              ((string? body) (%make-request method url headers body #f #f timeout (and follow #t)))
              (else (error "Failed in make-http-request: wrong argument type")))))

    (define (http-request-method r) (string-copy (request-method r)))
    (define (http-request-url r) (string-copy (request-url r)))
    (define (http-request-headers r) (map (lambda (h) (cons (string-copy (car h)) (string-copy (cdr h)))) (request-headers r)))
    (define (http-request-body-bytes r)
      (or (request-bytes r)
          (and (request-file r)
               (let ((bv (file->bytevector (request-file r))))
                 (set-request-bytes! r bv)
                 bv))))
    (define (http-request-body r)
      (or (request-body-string r)
          (let ((bv (http-request-body-bytes r)))
            (and bv
                 (let ((s (utf8->string bv)))
                   (set-request-body-string! r s)
                   s)))))
    (define (http-request-body-file r) (request-file r))

    (define (file->bytevector path)
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let ((bv (read-bytevector (max 1 (file-size path)) p)))
            (if (eof-object? bv) (bytevector) bv)))))

    ;; kind: string bytes file stream websocket
    (define-record-type http-response
      (%make-response status headers kind body offset length)
      http-response?
      (status response-status)
      (headers response-headers)
      (kind response-kind)
      (body response-body-value)
      (offset response-offset)
      (length response-length))
    (set-record-printer! http-response '("#<http-response " 0 ">"))

    (define (status-arg who s)
      (unless (exact-integer? s) (error (string-append "value out of range: " (datum->string s))))
      s)

    (define (datum->string x) (let ((o (open-output-string))) (write x o) (get-output-string o)))

    (define (make-http-response status headers body)
      (status-arg "make-http-response" status)
      (check-headers "make-http-response" headers)
      (cond ((bytevector? body) (%make-response status headers 'bytes body 0 0))
            ((string? body) (%make-response status headers 'string body 0 0))
            (else (error "Failed in make-http-response: wrong argument type"))))

    (define (make-http-file-response status headers path . opts)
      (status-arg "make-http-file-response" status)
      (unless (string? path) (error "Failed in make-http-file-response: wrong argument type"))
      (unless (file-regular? path) (error (string-append "make-http-file-response: not a file: " path)))
      (let* ((size (file-size path))
             (offset (if (pair? opts) (car opts) 0))
             (len (if (and (pair? opts) (pair? (cdr opts))) (cadr opts) (- size offset))))
        (when (or (< offset 0) (< len 0) (> (+ offset len) size))
          (error (string-append "make-http-file-response: part outside the file: " (number->string offset)
                                "+" (number->string len) " of " (number->string size))))
        (check-headers "make-http-file-response" headers)
        (%make-response status headers 'file path offset len)))

    (define (file-regular? path) (and (file-exists? path) (not (directory-exists? path))))

    (define (make-http-stream-response status headers writer)
      (status-arg "make-http-stream-response" status)
      (check-headers "make-http-stream-response" headers)
      (unless (procedure? writer) (error "Failed in make-http-stream-response: wrong argument type"))
      (%make-response status headers 'stream writer 0 0))

    (define (http-websocket-upgrade handler . headers)
      (unless (procedure? handler) (error "Failed in http-websocket-upgrade: wrong argument type"))
      (let ((hs (if (pair? headers) (car headers) '())))
        (check-headers "http-websocket-upgrade" hs)
        (%make-response 101 hs 'websocket handler 0 0)))

    (define (http-response-with-headers r status headers)
      (status-arg "http-response-with-headers" status)
      (check-headers "http-response-with-headers" headers)
      (%make-response status headers (response-kind r) (response-body-value r) (response-offset r) (response-length r)))

    (define (http-response-status r) (response-status r))
    (define (http-response-headers r) (map (lambda (h) (cons (string-copy (car h)) (string-copy (cdr h)))) (response-headers r)))

    (define (http-response-body r)
      (case (response-kind r)
        ((string) (string-copy (response-body-value r)))
        ((bytes) (response-body-value r))
        ((file) (file-part (response-body-value r) (response-offset r) (response-length r)))
        ((stream) (error "http-response-body: a streamed response has no body to read"))
        (else "")))

    (define (file-part path offset len)
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let skip ((left offset))
            (when (> left 0)
              (let ((got (read-bytevector (min left 65536) p)))
                (unless (eof-object? got) (skip (- left (bytevector-length got)))))))
          (let ((bv (read-bytevector (max 1 len) p)))
            (cond ((= len 0) (bytevector))
                  ((eof-object? bv) (bytevector))
                  (else bv))))))

    ;; the body as bytes, for sending (string bodies as UTF-8)
    (define (response-bytes r)
      (case (response-kind r)
        ((string) (string->utf8 (response-body-value r)))
        ((bytes) (response-body-value r))
        (else (bytevector))))

    ;; --- the client ------------------------------------------------------------

    ;; (scheme host port target authority) of an http(s) URL
    (define (parse-url who url)
      (let ((sep (string-search url "://")))
        (unless sep (error (string-append who ": URI with undefined scheme")))
        (let ((scheme (lower (substring url 0 sep))))
          (unless (member scheme '("http" "https"))
            (error (string-append who ": invalid URI scheme " (substring url 0 sep))))
          (let* ((rest (substring url (+ sep 3) (string-length url)))
                 (end (let loop ((i 0))
                        (cond ((= i (string-length rest)) i)
                              ((memv (string-ref rest i) '(#\/ #\? #\#)) i)
                              (else (loop (+ i 1))))))
                 (authority0 (substring rest 0 end))
                 (authority (let ((at (let loop ((i (- (string-length authority0) 1)))
                                        (cond ((< i 0) #f) ((char=? (string-ref authority0 i) #\@) i) (else (loop (- i 1)))))))
                              (if at (substring authority0 (+ at 1) (string-length authority0)) authority0)))
                 (target0 (substring rest end (string-length rest)))
                 (target1 (let ((h (string-index-of target0 #\# 0))) (if h (substring target0 0 h) target0)))
                 (target (cond ((string=? target1 "") "/")
                               ((char=? (string-ref target1 0) #\?) (string-append "/" target1))
                               (else target1))))
            (when (or (string=? authority "") (string-index-of authority #\space 0))
              (error (string-append who ": Illegal character in authority at index " (number->string (+ sep 3)) ": " url)))
            (let-values (((host port)
                          (if (char=? (string-ref authority 0) #\[)
                              (let ((close (string-index-of authority #\] 0)))
                                (values (substring authority 1 (or close (string-length authority)))
                                        (and close (< (+ close 1) (string-length authority))
                                             (string->number (substring authority (+ close 2) (string-length authority))))))
                              (let ((c (string-index-of authority #\: 0)))
                                (if c
                                    (values (substring authority 0 c) (string->number (substring authority (+ c 1) (string-length authority))))
                                    (values authority #f))))))
              (list scheme host (or port (if (string=? scheme "https") 443 80)) target authority))))))

    ;; Location resolved against url
    (define (resolve-url url location)
      (cond ((string-search location "://") location)
            ((starts-with? location "//")
             (string-append (substring url 0 (string-search url "://")) ":" location))
            (else
             (let* ((u (parse-url "http-get" url))
                    (base (string-append (car u) "://" (list-ref u 4))))
               (if (starts-with? location "/")
                   (string-append base location)
                   (let* ((target (list-ref u 3))
                          (q (string-index-of target #\? 0))
                          (path (if q (substring target 0 q) target))
                          (slash (let loop ((i (- (string-length path) 1)))
                                   (cond ((< i 0) 0) ((char=? (string-ref path i) #\/) (+ i 1)) (else (loop (- i 1)))))))
                     (string-append base (substring path 0 slash) location)))))))

    (define restricted-headers '("connection" "content-length" "expect" "host" "upgrade"))

    (define (insecure?)
      (let ((v (get-env "SCM_TLS_INSECURE")))
        (and v (member (lower (trim v)) '("1" "true" "yes")) #t)))

    (define get-env (%primitive "get-environment-variable"))

    ;; One exchange: (status headers body-bytes), or an error
    (define (exchange who method url headers body send-length? timeout)
      (let* ((u (parse-url who url))
             (https? (string=? (car u) "https"))
             (deadline (and (> timeout 0) (+ (now-ms) (* 1000 timeout))))
             (socket (guard (e (#t (error (string-append who ": ConnectException"))))
                       (tcp-connect (cadr u) (caddr u)))))
        (with-cleanup
         (lambda ()
           (when https?
             (guard (e (#t (let ((m (if (error-object? e) (error-object-message e) "TLS failure")))
                             (error (string-append who ": "
                                                   (if (starts-with? m "socket-starttls!: ")
                                                       (substring m 18 (string-length m))
                                                       m))))))
               (socket-starttls! socket (cadr u) (not (insecure?)))))
           (let ((out (open-output-string)))
             (write-string (string-append method " " (list-ref u 3) " HTTP/1.1\r\n") out)
             (write-string (string-append "Host: " (list-ref u 4) "\r\n") out)
             (unless (header-value headers "User-Agent")
               (write-string "User-Agent: dabscm\r\n" out))
             (for-each (lambda (h)
                         (write-string (string-append (car h) ": " (cdr h) "\r\n") out))
                       headers)
             (when (or body send-length?)
               (write-string (string-append "Content-Length: " (number->string (if body (bytevector-length body) 0)) "\r\n") out))
             (write-string "Connection: close\r\n\r\n" out)
             (unless (and (send-all socket (string->utf8 (get-output-string out)))
                          (or (not body) (send-all socket body)))
               (error (string-append who ": Broken pipe"))))
           (let ((r (make-reader socket)))
             (let read-response ()
               (let ((head (read-head r 1048576 deadline)))
                 (cond ((eq? head 'timeout) (error (string-append who ": request timed out")))
                       ((not (bytevector? head)) (error (string-append who ": received no response")))
                       (else
                        (let* ((lines (head-lines (utf8->string head)))
                               (parts (split (car lines) #\space))
                               (status (and (>= (length parts) 2) (string->number (cadr parts)))))
                          (unless status (error (string-append who ": bad response status line")))
                          (if (and (>= status 100) (< status 200) (not (= status 101)))
                              (read-response)
                              (let* ((hs (parse-header-lines (cdr lines)))
                                     (te (header-value hs "Transfer-Encoding"))
                                     (cl (header-value hs "Content-Length"))
                                     (body
                                      (cond ((or (string-ci=? method "HEAD") (= status 204) (= status 304)) (bytevector))
                                            ((and te (has-token? te "chunked")) (read-chunked-client r who))
                                            (cl (let ((n (read-n r (or (string->number (trim cl)) 0) #f)))
                                                  (if (bytevector? n) n (bytevector))))
                                            (else (read-all r)))))
                                (list status hs body))))))))))
         (lambda () (socket-close socket)))))

    ;; (thunk), then (cleanup), also when thunk raises. Not dynamic-wind:
    ;; a task that waits leaves its extent (its continuation is resumed
    ;; later), which must not run the cleanup.
    (define (with-cleanup thunk cleanup)
      (let ((result (guard (e (#t (cleanup) (raise e))) (thunk))))
        (cleanup)
        result))

    (define (read-chunked-client r who)
      (let loop ((parts '()))
        (let ((line (read-line-bytes r 4096 #f)))
          (if (not (bytevector? line))
              (apply bytevector-append (reverse parts))
              (let* ((s (utf8->string line))
                     (semi (string-index-of s #\; 0))
                     (n (string->number (trim (if semi (substring s 0 semi) s)) 16)))
                (cond ((not n) (error (string-append who ": bad chunked encoding")))
                      ((= n 0)
                       (let trailers ()
                         (let ((l (read-line-bytes r 4096 #f)))
                           (when (and (bytevector? l) (> (bytevector-length l) 0)) (trailers))))
                       (apply bytevector-append (reverse parts)))
                      (else
                       (let ((data (read-n r n #f)))
                         (read-line-bytes r 4096 #f)
                         (loop (cons (if (bytevector? data) data (bytevector)) parts))))))))))

    ;; Redirects as the JDK client's (Redirect.NORMAL): 301 302 303 307 308,
    ;; at most 4 followed, never from https to http
    (define (client-request who method url headers body send-length? timeout follow? binary?)
      (check-headers who headers)
      (for-each (lambda (h)
                  (when (member (lower (car h)) restricted-headers)
                    (error (string-append who ": restricted header name: \"" (car h) "\""))))
                headers)
      (let loop ((method method) (url url) (body body) (count 0))
        (let* ((res (exchange who method url headers body send-length? timeout))
               (status (car res))
               (location (header-value (cadr res) "Location")))
          (if (and follow? location (memv status '(301 302 303 307 308)) (< count 4)
                   (not (and (starts-with? (lower url) "https:")
                             (starts-with? (lower (resolve-url url location)) "http:"))))
              (let ((to-get? (or (= status 303) (and (memv status '(301 302)) (string=? method "POST")))))
                (loop (if (and to-get? (not (string=? method "HEAD"))) "GET" method)
                      (resolve-url url location)
                      (if to-get? #f body)
                      (+ count 1)))
              (build-response res binary?)))))

    ;; headers lower-cased and sorted by name (as the JDK client's), the
    ;; body a string for text content, else a bytevector
    (define (build-response res binary?)
      (let* ((status (car res))
             (hs (sort-headers (map (lambda (h) (cons (lower (car h)) (cdr h))) (cadr res))))
             (bytes (caddr res))
             (type (header-value hs "content-type")))
        (if (or binary? (not (text-type? type)))
            (%make-response status hs 'bytes bytes 0 0)
            (%make-response status hs 'string (decode-text bytes (charset-name type)) 0 0))))

    (define (sort-headers hs)
      ;; a stable insertion sort by name
      (let loop ((l hs) (acc '()))
        (if (null? l)
            acc
            (loop (cdr l)
                  (let ins ((acc acc))
                    (cond ((null? acc) (list (car l)))
                          ((string<? (car (car l)) (car (car acc))) (cons (car l) acc))
                          (else (cons (car acc) (ins (cdr acc))))))))))

    (define (charset-name type)
      (and type
           (let loop ((parts (split type #\;)))
             (cond ((null? parts) #f)
                   ((starts-with? (lower (trim (car parts))) "charset=")
                    (let* ((p (trim (car parts)))
                           (v (trim (substring p 8 (string-length p))))
                           (v (list->string (filter-list (lambda (c) (not (char=? c #\"))) (string->list v)))))
                      (if (string=? v "") #f v)))
                   (else (loop (cdr parts)))))))

    (define (text-type? type)
      (or (not type)
          (let* ((t (lower (trim (car (split type #\;)))))
                 (cs (charset-name type)))
            (or (string=? t "")
                (starts-with? t "text/")
                (and cs (not (string-ci=? cs "binary")))
                (ends-with? t "+json")
                (ends-with? t "+xml")
                (member t '("application/json" "application/xml" "application/javascript"
                            "application/ecmascript" "application/x-www-form-urlencoded"
                            "application/x-ndjson"))))))

    (define (ends-with? s p)
      (and (>= (string-length s) (string-length p))
           (string=? (substring s (- (string-length s) (string-length p)) (string-length s)) p)))

    (define (decode-text bytes charset)
      (let ((cs (and charset (lower charset))))
        (if (member cs '("iso-8859-1" "latin1" "iso8859-1" "us-ascii" "ascii" "windows-1252" "cp1252"))
            (latin1->string bytes)
            (utf8->string bytes))))

    (define (timeout-arg who opts i)
      (if (> (length opts) i)
          (let ((t (list-ref opts i)))
            (unless (exact-integer? t) (error (string-append "Failed in " who ": wrong argument type")))
            t)
          600))

    (define (url-arg who url)
      (unless (string? url) (error (string-append "Failed in " who ": wrong argument type")))
      url)

    (define (http-get url . opts)
      (client-request "http-get" "GET" (url-arg "http-get" url) (if (pair? opts) (car opts) '()) #f #f
                      (timeout-arg "http-get" opts 1) #t #f))

    (define (http-get-bytevector url . opts)
      (client-request "http-get-bytevector" "GET" (url-arg "http-get-bytevector" url) (if (pair? opts) (car opts) '()) #f #f
                      (timeout-arg "http-get-bytevector" opts 1) #t #t))

    (define (http-post url body . opts)
      (url-arg "http-post" url)
      (unless (string? body) (error "Failed in http-post: wrong argument type"))
      (client-request "http-post" "POST" url (if (pair? opts) (car opts) '()) (string->utf8 body) #t
                      (timeout-arg "http-post" opts 1) #t #f))

    (define (http-send r)
      (unless (http-request? r) (error "Failed in http-send: wrong argument type"))
      (let ((m (request-method r)))
        (when (or (string=? m "") (string-index-of m #\space 0))
          (error (string-append "http-send: illegal method \"" m "\"")))
        (when (string-ci=? m "CONNECT") (error "http-send: method CONNECT is not supported"))
        (client-request "http-send" m (request-url r) (request-headers r)
                        (cond ((request-bytes r) => (lambda (b) b))
                              ((request-body-string r) => string->utf8)
                              (else #f))
                        #t (request-timeout r) (request-follow? r) #f)))

    ;; --- the server --------------------------------------------------------------

    (define-record-type server
      (%make-server listener handler read-timeout max-body graceful spool running)
      server?
      (listener server-listener)
      (handler server-handler)
      (read-timeout server-read-timeout)
      (max-body server-max-body)
      (graceful server-graceful)
      (spool server-spool)
      (running server-running? set-server-running!))
    (set-record-printer! server '("#<server>"))

    (define (int-arg x)
      (unless (exact-integer? x) (error (string-append "value out of range: " (datum->string x))))
      x)

    (define (tcp-http-serve port handler . opts)
      (define (opt i default) (if (> (length opts) i) (list-ref opts i) default))
      (int-arg port)
      (unless (procedure? handler) (error "Failed in tcp-http-serve: wrong argument type"))
      (let* ((host (let ((h (opt 1 ""))) (if (string=? h "") "0.0.0.0" h)))
             (read-timeout (let ((v (int-arg (opt 2 0)))) (if (<= v 0) 30000 v)))
             (max-body (let ((v (int-arg (opt 3 0)))) (if (<= v 0) 4194304 v)))
             (graceful (let ((v (int-arg (opt 4 0)))) (if (<= v 0) 10000 v)))
             (spool (let ((v (int-arg (opt 5 0)))) (if (<= v 0) 1048576 v))))
        (int-arg (opt 0 0))
        (when (or (< port 0) (> port 65535))
          (error (string-append "tcp-http-serve: port out of range:" (number->string port))))
        (let* ((listener (tcp-listen-host host port))
               (s (%make-server listener handler read-timeout max-body graceful spool #t)))
          (set! servers (cons s servers))
          (update-pollers!)
          s)))

    (define (server-stop s . grace)
      (when (server-running? s)
        (set-server-running! s #f)
        (set! servers (remove-eq s servers))
        (update-pollers!)
        (socket-close (server-listener s)))
      #t)

    (define (server-wait s)
      (wait-until! (lambda () (and (not (server-running? s)) (not shutting-down))))
      #t)

    ;; SIGINT and SIGTERM stop the hooked servers, let their connections
    ;; finish for the grace time and exit (130, 143) as the JVM does; the
    ;; signal is seen while the program waits in the scheduler
    (define shutdown-signal (%primitive "%shutdown-signal"))
    (define shutdown-hooks '())           ; (server . grace-ms)
    (define active-connections 0)
    (define shutting-down #f)             ; server-wait does not return meanwhile

    (define (server-install-shutdown-hook s . grace)
      (unless (server? s) (error "Failed in server-install-shutdown-hook: wrong argument type"))
      (let ((g (if (pair? grace) (max 0 (int-arg (car grace))) (server-graceful s))))
        (when (null? shutdown-hooks)
          (shutdown-signal)
          (spawn! (lambda ()
                    (wait-until! (lambda () (> (shutdown-signal) 0)))
                    (run-shutdown-hooks!))))
        (set! shutdown-hooks (cons (cons s g) shutdown-hooks)))
      #t)

    (define (run-shutdown-hooks!)
      (let ((sig (shutdown-signal))
            (deadline (+ (now-ms) (apply max 0 (map cdr shutdown-hooks)))))
        (set! shutting-down #t)
        (for-each (lambda (h) (server-stop (car h))) shutdown-hooks)
        (wait-until! (lambda () (or (= active-connections 0) (>= (now-ms) deadline))))
        (exit (+ 128 sig))))

    (define (accept-connection! s)
      (let ((socket (guard (e (#t #f)) (tcp-accept (server-listener s)))))
        (when socket
          (set! active-connections (+ active-connections 1))
          (spawn! (lambda ()
                    (serve-connection s socket)
                    (set! active-connections (- active-connections 1)))))))

    (define (log-error method url detail)
      (let ((err (current-error-port)))
        (write-string (string-append (timestamp->string (now-ms) "yyyy-MM-dd HH:mm:ss")
                                     " ERROR [http] " method " " url " " detail "\n")
                      err)
        (flush-output-port err)))

    (define (error-text e)
      (cond ((error-object? e)
             (let ((o (open-output-string)))
               (display (error-object-message e) o)
               (for-each (lambda (x) (write-char #\space o) (write x o)) (error-object-irritants e))
               (get-output-string o)))
            (else (datum->string e))))

    (define reasons
      '((100 . "Continue") (101 . "Switching Protocols") (200 . "OK") (201 . "Created") (202 . "Accepted")
        (204 . "No Content") (206 . "Partial Content") (301 . "Moved Permanently") (302 . "Found")
        (303 . "See Other") (304 . "Not Modified") (307 . "Temporary Redirect") (308 . "Permanent Redirect")
        (400 . "Bad Request") (401 . "Unauthorized") (403 . "Forbidden") (404 . "Not Found")
        (405 . "Method Not Allowed") (406 . "Not Acceptable") (408 . "Request Timeout") (409 . "Conflict")
        (410 . "Gone") (411 . "Length Required") (412 . "Precondition Failed") (413 . "Payload Too Large")
        (414 . "URI Too Long") (415 . "Unsupported Media Type") (416 . "Range Not Satisfiable")
        (422 . "Unprocessable Content") (428 . "Precondition Required") (429 . "Too Many Requests")
        (431 . "Request Header Fields Too Large") (500 . "Internal Server Error") (501 . "Not Implemented")
        (502 . "Bad Gateway") (503 . "Service Unavailable") (504 . "Gateway Timeout")))

    (define (reason status) (cond ((assv status reasons) => cdr) (else "Unknown")))

    (define (status-only socket status)
      (send-all socket (string->utf8 (string-append "HTTP/1.1 " (number->string status) " " (reason status)
                                                    "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"))))

    ;; after an error response: let the client read it before the close
    (define (linger-close socket r)
      (shutdown-output socket)
      (let ((deadline (+ (now-ms) 2000)))
        (let loop ((total 0))
          (when (< total 16777216)
            (let ((f (reader-fill! r deadline)))
              (when (eq? f #t)
                (set-reader-pos! r (bytevector-length (reader-buf r)))
                (loop (+ total 65536)))))))
      (socket-close socket))

    (define (serve-connection s socket)
      (let ((r (make-reader socket))
            (spool-file #f))
        (guard (e (#t (log-error "-" "-" (string-append "connection failed: " (error-text e)))))
          (with-cleanup
           (lambda ()
             (let* ((deadline (+ (now-ms) (server-read-timeout s)))
                    (head (read-head r 65536 deadline)))
               (when (bytevector? head)
                 (let* ((lines (head-lines (latin1->string head)))
                        (parts (filter-list (lambda (x) #t) (split-request-line (car lines)))))
                   (when (>= (length parts) 2)
                     (let* ((method (car parts))
                            (url (cadr parts))
                            (headers (parse-header-lines (cdr lines)))
                            (length-info (content-length headers))
                            (chunked (let ((te (header-value headers "Transfer-Encoding")))
                                       (and te (string-ci=? (trim te) "chunked")))))
                       (cond
                        ((or (eq? length-info 'bad) (and (number? length-info) (< length-info 0)))
                         (status-only socket 400))
                        ((and (not chunked) (number? length-info) (> length-info (server-max-body s)))
                         (status-only socket 413)
                         (linger-close socket r))
                        (else
                         (let ((body (cond (chunked (read-chunked-body r s))
                                           ((and (number? length-info) (> length-info 0))
                                            (read-fixed-body r s length-info))
                                           (else #f))))
                           (cond
                            ((eq? body 'too-large) (status-only socket 413) (linger-close socket r))
                            ((eq? body 'malformed) (status-only socket 400) (linger-close socket r))
                            ((eq? body 'timeout) #f)
                            (else
                             (when (and (pair? body) (eq? (car body) 'file)) (set! spool-file (cdr body)))
                             (let* ((req (%make-request method url headers #f
                                                        (and (bytevector? body) body)
                                                        (and (pair? body) (cdr body))
                                                        600 #t))
                                    (res (guard (e (#t (log-error method url (string-append "raised: " (error-text e)))
                                                       (internal-error)))
                                           (let ((x ((server-handler s) req)))
                                             (if (http-response? x)
                                                 x
                                                 (begin (log-error method url "handler did not return an http-response")
                                                        (internal-error)))))))
                               (if (eq? (response-kind res) 'websocket)
                                   (upgrade socket r method headers res url)
                                   (send-response socket method url res))))))))))))))
           (lambda ()
             (socket-close socket)
             (when (and spool-file (file-exists? spool-file)) (delete-file spool-file)))))))

    ;; the request line split on spaces (Java's split: trailing empty parts dropped)
    (define (split-request-line l)
      (let loop ((parts (reverse (split l #\space))))
        (if (and (pair? parts) (string=? (car parts) ""))
            (loop (cdr parts))
            (reverse parts))))

    (define (internal-error) (%make-response 500 '() 'string "Internal Server Error" 0 0))

    ;; #f (none), a number, or 'bad
    (define (content-length headers)
      (let loop ((hs headers) (result #f))
        (cond ((null? hs) result)
              ((string-ci=? (caar hs) "Content-Length")
               (let ((n (string->number (trim (cdar hs)))))
                 (if (and n (exact-integer? n)) (loop (cdr hs) n) 'bad)))
              (else (loop (cdr hs) result)))))

    ;; The body as a bytevector, ('file . path) when spooled, or 'too-large, 'malformed, 'timeout
    (define (body-collector s)
      (let ((parts '()) (size 0) (file #f) (port #f))
        (lambda (msg . args)
          (case msg
            ((add)
             (let ((bv (car args)))
               (set! size (+ size (bytevector-length bv)))
               (cond (port (write-bytevector bv port))
                     ((> size (server-spool s))
                      (set! file (mktemp '(prefix . "scm-http-") '(suffix . ".body")))
                      (set! port (open-binary-output-file file))
                      (for-each (lambda (p) (write-bytevector p port)) (reverse parts))
                      (write-bytevector bv port)
                      (set! parts '()))
                     (else (set! parts (cons bv parts))))))
            ((size) size)
            ((result)
             (if port
                 (begin (close-port port) (cons 'file file))
                 (apply bytevector-append (reverse parts))))
            ((discard)
             (when port (close-port port) (delete-file file)))))))

    (define (body-deadline s bytes)
      (+ (now-ms) (server-read-timeout s) (quotient (* bytes 1000) 16384)))

    (define (read-fixed-body r s n)
      (let ((c (body-collector s))
            (deadline (body-deadline s n)))
        (let loop ((left n))
          (if (= left 0)
              (c 'result)
              (let ((part (read-n r (min left 65536) deadline)))
                (cond ((eq? part 'timeout) (c 'discard) 'timeout)
                      ((= (bytevector-length part) 0) (c 'result)) ; the client stopped early
                      (else (c 'add part) (loop (- left (bytevector-length part))))))))))

    (define (read-chunked-body r s)
      (let ((c (body-collector s))
            (deadline (body-deadline s (server-max-body s))))
        (define (fail what) (c 'discard) what)
        (let loop ()
          (let ((line (read-line-bytes r 4096 deadline)))
            (cond ((eq? line 'timeout) (fail 'timeout))
                  ((not (bytevector? line)) (fail 'malformed))
                  (else
                   (let* ((text (latin1->string line))
                          (semi (string-index-of text #\; 0))
                          (n (string->number (trim (if semi (substring text 0 semi) text)) 16)))
                     (cond ((or (not n) (not (exact-integer? n)) (< n 0)) (fail 'malformed))
                           ((= n 0)
                            (let trailers ()
                              (let ((l (read-line-bytes r 4096 deadline)))
                                (when (and (bytevector? l) (> (bytevector-length l) 0)) (trailers))))
                            (c 'result))
                           ((> (+ (c 'size) n) (server-max-body s)) (fail 'too-large))
                           (else
                            (let ((data (read-n r n deadline)))
                              (cond ((eq? data 'timeout) (fail 'timeout))
                                    ((< (bytevector-length data) n) (fail 'malformed))
                                    (else
                                     (c 'add data)
                                     (let ((end (read-line-bytes r 4096 deadline)))
                                       (if (and (bytevector? end) (= (bytevector-length end) 0))
                                           (loop)
                                           (fail 'malformed)))))))))))))))

    (define (send-response socket method url res)
      (let* ((headers (response-headers res))
             (kind (response-kind res))
             (out (open-output-string))
             (len (case kind
                    ((string bytes) (bytevector-length (response-bytes res)))
                    ((file) (response-length res))
                    (else #f))))
        (write-string (string-append "HTTP/1.1 " (number->string (response-status res)) " "
                                     (reason (response-status res)) "\r\n")
                      out)
        (for-each (lambda (h) (write-string (string-append (crlf-free (car h)) ": " (crlf-free (cdr h)) "\r\n") out))
                  headers)
        (when (and len (not (header-value headers "Content-Length")))
          (write-string (string-append "Content-Length: " (number->string len) "\r\n") out))
        (unless (header-value headers "Content-Type")
          (write-string "Content-Type: text/plain; charset=utf-8\r\n" out))
        (write-string "Connection: close\r\n\r\n" out)
        (when (send-all socket (string->utf8 (get-output-string out)))
          (unless (string-ci=? method "HEAD")
            (case kind
              ((string bytes) (send-all socket (response-bytes res)))
              ((file) (send-file socket (response-body-value res) (response-offset res) (response-length res)))
              ((stream)
               ;; the writer's output, sent when it returns
               (let ((port (open-output-bytevector)))
                 (guard (e (#t (log-error method url (string-append "stream writer raised: " (error-text e)))))
                   ((response-body-value res) port))
                 (send-all socket (get-output-bytevector port)))))))))

    (define (send-file socket path offset len)
      (guard (e (#t #f))
        (call-with-port (open-binary-input-file path)
          (lambda (p)
            (let skip ((left offset))
              (when (> left 0)
                (let ((got (read-bytevector (min left 65536) p)))
                  (unless (eof-object? got) (skip (- left (bytevector-length got)))))))
            (let loop ((left len))
              (when (> left 0)
                (let ((part (read-bytevector (min left 65536) p)))
                  (unless (eof-object? part)
                    (when (send-all socket part)
                      (loop (- left (bytevector-length part))))))))))))

    ;; --- WebSockets ----------------------------------------------------------------

    (define-record-type websocket
      (%make-ws socket reader server? close-sent closed)
      ws?
      (socket ws-socket)
      (reader ws-reader)
      (server? ws-server?)
      (close-sent ws-close-sent? set-ws-close-sent!)
      (closed ws-closed? set-ws-closed!))
    (set-record-printer! websocket '("#<websocket>"))

    (define ws-guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    (define max-message 16777216)

    (define (accept-key key) (base64-encode (hex->bytevector (sha1-hash (string->utf8 (string-append key ws-guid))))))

    (define (upgrade socket r method headers res url)
      (let ((key (header-value headers "Sec-WebSocket-Key")))
        (cond
         ((not (and (string=? method "GET")
                    (has-token? (header-value headers "Upgrade") "websocket")
                    (has-token? (header-value headers "Connection") "upgrade")
                    key (not (string=? key ""))))
          (status-only socket 400))
         ((not (equal? (header-value headers "Sec-WebSocket-Version") "13"))
          (send-all socket (string->utf8 "HTTP/1.1 426 Upgrade Required\r\nSec-WebSocket-Version: 13\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")))
         (else
          (let ((out (open-output-string)))
            (write-string (string-append "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "
                                         (accept-key key) "\r\n")
                          out)
            (for-each (lambda (h) (write-string (string-append (crlf-free (car h)) ": " (crlf-free (cdr h)) "\r\n") out))
                      (response-headers res))
            (write-string "\r\n" out)
            (when (send-all socket (string->utf8 (get-output-string out)))
              (let ((ws (%make-ws socket r #t #f #f)))
                (guard (e (#t (unless (ws-closed? ws)
                                (log-error method url (string-append "websocket handler raised: " (error-text e))))))
                  ((response-body-value res) ws))
                (ws-close ws))))))))

    (define (ws-connect host port path)
      (unless (and (string? host) (string? path)) (error "Failed in ws-connect: wrong argument type"))
      (int-arg port)
      (let* ((socket (guard (e (#t (let ((m (error-object-message e)))
                                     (error (string-append "ws-connect: "
                                                           (if (starts-with? m "tcp-connect: ") (substring m 13 (string-length m)) m))))))
                       (tcp-connect host port)))
             (key (base64-encode (random-bytes 16))))
        (send-all socket (string->utf8 (string-append "GET " path " HTTP/1.1\r\nHost: " host ":" (number->string port)
                                                      "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: " key
                                                      "\r\nSec-WebSocket-Version: 13\r\n\r\n")))
        (let* ((r (make-reader socket))
               (head (read-head r 65536 #f)))
          (cond
           ((not (bytevector? head))
            (socket-close socket)
            (error "ws-connect: the server refused the upgrade: no response"))
           (else
            (let ((text (latin1->string head)))
              (unless (starts-with? text "HTTP/1.1 101")
                (socket-close socket)
                (error (string-append "ws-connect: the server refused the upgrade: " (car (head-lines text)))))
              (unless (string-search (lower text) (string-append "sec-websocket-accept: " (lower (accept-key key))))
                (socket-close socket)
                (error "ws-connect: bad Sec-WebSocket-Accept"))
              (%make-ws socket r #f #f #f)))))))

    (define (ws-accept socket)
      (unless (socket? socket) (error "Failed in ws-accept: wrong argument type"))
      (let* ((r (make-reader socket))
             (head (read-head r 65536 #f)))
        (when (eq? head 'too-long) (error "ws-accept: headers too long"))
        (let ((key (and (bytevector? head)
                        (let loop ((lines (head-lines (latin1->string head))) (key #f))
                          (cond ((null? lines) key)
                                ((starts-with? (lower (car lines)) "sec-websocket-key:")
                                 (let ((l (car lines)))
                                   (loop (cdr lines) (trim (substring l (+ 1 (string-index-of l #\: 0)) (string-length l))))))
                                (else (loop (cdr lines) key)))))))
          (unless key (error "ws-accept: missing Sec-WebSocket-Key header"))
          (send-all socket (string->utf8 (string-append "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "
                                                        (accept-key key) "\r\n\r\n")))
          (%make-ws socket r #t #f #f))))

    (define (frame ws opcode payload)
      (let* ((n (bytevector-length payload))
             (mask? (not (ws-server? ws)))
             (len-bytes (cond ((< n 126) (bytevector (+ n (if mask? 128 0))))
                              ((< n 65536) (bytevector (+ 126 (if mask? 128 0)) (quotient n 256) (remainder n 256)))
                              (else (let ((b (make-bytevector 9 0)))
                                      (bytevector-u8-set! b 0 (+ 127 (if mask? 128 0)))
                                      (let loop ((i 8) (v n))
                                        (when (> i 0)
                                          (bytevector-u8-set! b i (remainder v 256))
                                          (loop (- i 1) (quotient v 256))))
                                      b))))
             (key (if mask? (random-bytes 4) (bytevector)))
             (data (if mask?
                       (let ((m (bytevector-copy payload)))
                         (let loop ((i 0))
                           (when (< i n)
                             (bytevector-u8-set! m i (bitwise-xor (bytevector-u8-ref m i) (bytevector-u8-ref key (remainder i 4))))
                             (loop (+ i 1))))
                         m)
                       payload)))
        (bytevector-append (bytevector (+ 128 opcode)) len-bytes key data)))

    (define (send-frame ws opcode payload who)
      (when (ws-close-sent? ws) (error (string-append who ": the connection is closed")))
      (unless (send-all (ws-socket ws) (frame ws opcode payload))
        (error (string-append who ": Broken pipe"))))

    (define (ws-send ws message)
      (unless (ws? ws) (error "Failed in ws-send: wrong argument type"))
      (cond ((string? message) (send-frame ws 1 (string->utf8 message) "ws-send"))
            ((bytevector? message) (send-frame ws 2 message "ws-send"))
            (else (error "Failed in ws-send: wrong argument type")))
      #t)

    (define (close-payload code) (bytevector (quotient code 256) (remainder code 256)))

    (define (ws-shutdown! ws)
      (set-ws-closed! ws #t)
      (set-ws-close-sent! ws #t)
      (socket-close (ws-socket ws)))

    (define (ws-close ws)
      (unless (ws? ws) (error "Failed in ws-close: wrong argument type"))
      (unless (ws-close-sent? ws)
        (guard (e (#t #f)) (send-all (ws-socket ws) (frame ws 8 (close-payload 1000)))))
      (unless (ws-closed? ws) (ws-shutdown! ws))
      #t)

    (define (ws-fail ws code)
      (unless (ws-close-sent? ws)
        (guard (e (#t #f)) (send-all (ws-socket ws) (frame ws 8 (close-payload code)))))
      (ws-shutdown! ws)
      #f)

    (define (ws-receive ws . timeout)
      (unless (ws? ws) (error "Failed in ws-receive: wrong argument type"))
      (let ((ms (if (pair? timeout) (int-arg (car timeout)) 0))
            (r (ws-reader ws)))
        (if (ws-closed? ws)
            #f
            (let loop ((message #f) (opcode #f))
              (let ((head (read-n r 2 (and (not message) (> ms 0) (+ (now-ms) ms)))))
                (cond
                 ((eq? head 'timeout) 'timeout)
                 ((< (bytevector-length head) 2) (ws-shutdown! ws) #f)
                 (else
                  (let* ((b0 (bytevector-u8-ref head 0))
                         (b1 (bytevector-u8-ref head 1))
                         (fin (>= b0 128))
                         (op (bitwise-and b0 15))
                         (masked (>= b1 128))
                         (len7 (bitwise-and b1 127))
                         (len (cond ((< len7 126) len7)
                                    ((= len7 126) (let ((b (read-n r 2 #f))) (if (= (bytevector-length b) 2) (+ (* 256 (bytevector-u8-ref b 0)) (bytevector-u8-ref b 1)) -1)))
                                    (else (let ((b (read-n r 8 #f)))
                                            (if (= (bytevector-length b) 8)
                                                (let l ((i 0) (v 0)) (if (= i 8) v (l (+ i 1) (+ (* v 256) (bytevector-u8-ref b i)))))
                                                -1))))))
                    (cond
                     ((and (ws-server? ws) (not masked)) (ws-fail ws 1002))
                     ((and (>= op 8) (or (> len 125) (not fin))) (ws-fail ws 1002))
                     ((or (< len 0) (> (+ len (if message (bytevector-length message) 0)) max-message)) (ws-fail ws 1009))
                     (else
                      (let* ((key (if masked (read-n r 4 #f) #f))
                             (data (read-n r len #f)))
                        (if (or (< (bytevector-length data) len) (and key (< (bytevector-length key) 4)))
                            (begin (ws-shutdown! ws) #f)
                            (let ((payload (if key
                                               (let ((m (bytevector-copy data)))
                                                 (let l ((i 0))
                                                   (when (< i len)
                                                     (bytevector-u8-set! m i (bitwise-xor (bytevector-u8-ref m i) (bytevector-u8-ref key (remainder i 4))))
                                                     (l (+ i 1))))
                                                 m)
                                               data)))
                              (case op
                                ((9) (unless (ws-close-sent? ws)
                                       (guard (e (#t #f)) (send-all (ws-socket ws) (frame ws 10 payload))))
                                 (loop message opcode))
                                ((10) (loop message opcode))
                                ((8)
                                 (let* ((code (if (>= len 2) (+ (* 256 (bytevector-u8-ref payload 0)) (bytevector-u8-ref payload 1)) 1000))
                                        (reply (if (memv code '(1005 1006)) 1000 code)))
                                   (unless (ws-close-sent? ws)
                                     (guard (e (#t #f)) (send-all (ws-socket ws) (frame ws 8 (close-payload reply)))))
                                   (ws-shutdown! ws)
                                   #f))
                                ((0)
                                 (if (not message)
                                     (ws-fail ws 1002)
                                     (let ((m (bytevector-append message payload)))
                                       (if fin (finish opcode m) (loop m opcode)))))
                                ((1 2)
                                 (if message
                                     (ws-fail ws 1002)
                                     (if fin (finish op payload) (loop payload op))))
                                (else (ws-fail ws 1002))))))))))))))))

    (define (finish opcode bytes)
      (if (= opcode 1) (utf8->string bytes) bytes))))
