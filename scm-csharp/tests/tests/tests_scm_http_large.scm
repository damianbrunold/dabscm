;; tcp-http-serve with large and unusual bodies: request bodies spooled to
;; a file, chunked request bodies, file responses (with byte ranges via
;; file-response) and streamed responses. Each group runs a real server
;; on its own port and talks to it with the HTTP client or a raw socket.

(import (scheme base)
        (scheme file)
        (scheme write)
        (scm test)
        (scm fs)
        (scm string)
        (srfi 18)
        (scm net sockets)
        (scm net http request)
        (scm net http response)
        (scm net http client)
        (scm net http server)
        (scm net http static))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-large")

(define dir (mktempdir '(prefix . "scm-http-large")))

;; A bytevector of n bytes: 0, 1, ..., 255, 0, 1, ...
(define (pattern n)
  (let ((bv (make-bytevector n)))
    (do ((i 0 (+ i 1))) ((= i n) bv)
      (bytevector-u8-set! bv i (modulo i 256)))))

(define (write-bytes! path bv)
  (let ((p (open-binary-output-file path)))
    (write-bytevector bv p)
    (close-port p)))

(define (retry thunk)
  (let loop ((n 0))
    (if (< n 5)
        (guard (e (#t (thread-sleep! 0.1) (loop (+ n 1)))) (thunk))
        (thunk))))

(define (with-server port handler args thunk)
  (let ((server (apply tcp-http-serve port handler args)))
    (dynamic-wind
      (lambda () #f)
      thunk
      (lambda () (server-stop server)))))

;; Sends raw request bytes over a socket and returns the whole response as
;; a string (latin-1 safe for the ASCII parts we look at).
(define (raw-request port request-bytes)
  (retry
   (lambda ()
     (let* ((s (tcp-connect "127.0.0.1" port))
            (out (socket-binary-output-port s))
            (in (socket-binary-input-port s)))
       (write-bytevector request-bytes out)
       (flush-output-port out)
       (let loop ((acc '()))
         (let ((bv (read-bytevector 65536 in)))
           (if (eof-object? bv)
               (begin
                 (socket-close s)
                 (utf8->string (apply bytevector-append (reverse acc))))
               (loop (cons bv acc)))))))))

(define (has? s part) (and (string? s) (string-contains-from s part 0) #t))

(define (send method url headers body)
  (retry (lambda () (http-send (make-http-request method url headers body)))))

(test-group "large request bodies are spooled to a file"
  (let ((seen-file #f))
    (with-server 18121
      (lambda (req)
        (let* ((f (http-request-body-file req))
               (bv (http-request-body-bytes req)))
          (set! seen-file f)
          (http-ok (string-append
                    (if f "file " "memory ")
                    (number->string (if f (file-size f) 0)) " "
                    (number->string (bytevector-length bv)) " "
                    (number->string (bytevector-u8-ref bv (- (bytevector-length bv) 1)))))))
      ;; max-body 10 MB, spool above 1000 bytes
      '(0 "127.0.0.1" 0 10000000 0 1000)
      (lambda ()
        (test-equal "memory 0 500 243"
          (http-response-body (send "POST" "http://127.0.0.1:18121/" '() (pattern 500))))
        (test-equal "file 3000000 3000000 191"
          (http-response-body (send "POST" "http://127.0.0.1:18121/" '() (pattern 3000000))))
        ;; The spool file is gone once the response is out.
        (thread-sleep! 0.2)
        (test-assert "spool file deleted" (and seen-file (not (file-exists? seen-file))))
        (test-equal 413
          (http-response-status
           (send "POST" "http://127.0.0.1:18121/" '() (pattern 10000001))))))))

(test-group "chunked request bodies"
  (with-server 18122
    (lambda (req)
      (http-ok (string-append "got " (http-request-body req))))
    '(0 "127.0.0.1" 0 100)
    (lambda ()
      (let ((r (raw-request 18122
                 (string->utf8
                  (string-append
                   "POST /x HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n"
                   "5\r\nHallo\r\n6;ext=1\r\n Welt!\r\n0\r\nX-Trailer: y\r\n\r\n")))))
        (test-assert r (has? r "200 OK"))
        (test-assert r (has? r "got Hallo Welt!")))
      (let ((r (raw-request 18122
                 (string->utf8
                  (string-append
                   "POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
                   "zz\r\nHallo\r\n0\r\n\r\n")))))
        (test-assert "malformed chunk size" (has? r "400 Bad Request")))
      (let ((r (raw-request 18122
                 (string->utf8
                  (string-append
                   "POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
                   "80\r\n" (make-string 128 #\a) "\r\n0\r\n\r\n")))))
        (test-assert "chunked over max-body" (has? r "413 Payload Too Large")))
      (let ((r (raw-request 18122 (string->utf8 "POST /x HTTP/1.1\r\nContent-Length: abc\r\n\r\n"))))
        (test-assert "bad Content-Length" (has? r "400 Bad Request"))))))

(define big (string-append dir "/big.bin"))
(write-bytes! big (pattern 200000))

(test-group "file responses and byte ranges"
  (with-server 18123
    (lambda (req)
      (if (string=? (http-request-url req) "/raw")
          (make-http-file-response 200 '(("Content-Type" . "application/octet-stream")) big 1000 10)
          (file-response big `((request . ,req)))))
    '(0 "127.0.0.1")
    (lambda ()
      (let ((r (send "GET" "http://127.0.0.1:18123/raw" '() #f)))
        (test-equal 200 (http-response-status r))
        (test-equal (bytevector-copy (pattern 200000) 1000 1010) (http-response-body r)))
      (let ((r (send "GET" "http://127.0.0.1:18123/f" '() #f)))
        (test-equal 200 (http-response-status r))
        (test-equal "bytes" (http-response-header r "Accept-Ranges"))
        (test-equal (pattern 200000) (http-response-body r)))
      (let ((r (send "GET" "http://127.0.0.1:18123/f" '(("Range" . "bytes=100-199")) #f)))
        (test-equal 206 (http-response-status r))
        (test-equal "bytes 100-199/200000" (http-response-header r "Content-Range"))
        (test-equal (bytevector-copy (pattern 200000) 100 200) (http-response-body r)))
      (let ((r (send "GET" "http://127.0.0.1:18123/f" '(("Range" . "bytes=-5")) #f)))
        (test-equal 206 (http-response-status r))
        (test-equal "bytes 199995-199999/200000" (http-response-header r "Content-Range")))
      (let ((r (send "GET" "http://127.0.0.1:18123/f" '(("Range" . "bytes=999999-")) #f)))
        (test-equal 416 (http-response-status r))
        (test-equal "bytes */200000" (http-response-header r "Content-Range")))
      ;; HEAD: the length, no body.
      (let ((r (raw-request 18123 (string->utf8 "HEAD /f HTTP/1.1\r\nHost: x\r\n\r\n"))))
        (test-assert r (has? r "Content-Length: 200000"))
        (test-assert "no body" (string=? (substring r (- (string-length r) 4) (string-length r))
                                         "\r\n\r\n"))))))

(test-group "streamed responses"
  (with-server 18124
    (lambda (req)
      (make-http-stream-response
       200 '(("Content-Type" . "text/event-stream"))
       (lambda (port)
         (do ((i 0 (+ i 1))) ((= i 3))
           (write-bytevector (string->utf8 (string-append "data: " (number->string i) "\n\n")) port)
           (flush-output-port port)))))
    '(0 "127.0.0.1")
    (lambda ()
      (let ((r (raw-request 18124 (string->utf8 "GET /events HTTP/1.1\r\nHost: x\r\n\r\n"))))
        (test-assert r (has? r "200 OK"))
        (test-assert "no Content-Length" (not (has? r "Content-Length")))
        (test-assert r (has? r "text/event-stream"))
        (test-assert r (has? r "data: 0\n\ndata: 1\n\ndata: 2\n\n")))))
  (test-error (http-response-body
               (make-http-stream-response 200 '() (lambda (port) #t)))))

(test-group "file responses in memory"
  (let ((r (make-http-file-response 200 '() big 5 3)))
    (test-equal (bytevector 5 6 7) (http-response-body r)))
  (test-error (make-http-file-response 200 '() big 199999 2))
  (test-error (make-http-file-response 200 '() (string-append dir "/missing") 0 1)))

(delete-file big)
(delete-directory dir)

(test-end "scm-http-large")
