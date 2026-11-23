;; Native objects (sockets and their ports, listeners, JSON and XML readers,
;; zips, random-access files, file locks, processes) made in loops and
;; dropped without closing, with collections in between: natively the
;; collector frees what they hold. What is still reachable keeps working:
;; a socket's ports, a port whose socket is gone, a JSON object whose
;; reader is gone.
(import (scheme base) (scheme write) (scheme file)
        (scm net sockets) (scm json) (scm xml) (scm zip) (scm random access)
        (scm fs) (scm system))

(define (garbage)
  ;; enough allocation for several collections
  (let loop ((i 0) (acc '()))
    (if (< i 20000)
        (loop (+ i 1) (if (= 0 (modulo i 1000)) '() (cons (make-vector 8 i) acc)))
        (length acc))))

(define port-number 18391)
(define listener (tcp-listen port-number))

;; a connection: a line from the client to the server and back
(define (exchange text close?)
  (let* ((c (tcp-connect "127.0.0.1" port-number))
         (s (tcp-accept listener)))
    (write-string text (socket-output-port c))
    (newline (socket-output-port c))
    (flush-output-port (socket-output-port c))
    (let ((line (read-line (socket-input-port s))))
      (write-string line (socket-output-port s))
      (newline (socket-output-port s))
      (flush-output-port (socket-output-port s))
      (let ((back (read-line (socket-input-port c))))
        (when close?
          (socket-close c)
          (socket-close s))
        back))))

(define (count-ok n f)
  (let loop ((i 0) (ok 0))
    (if (< i n)
        (begin
          (when (= 0 (modulo i 50)) (garbage))
          (loop (+ i 1) (if (f i) (+ ok 1) ok)))
        ok)))

(write (list 'sockets-closed
             (count-ok 300 (lambda (i) (equal? (exchange (number->string i) #t) (number->string i))))))
(newline)
(write (list 'sockets-dropped
             (count-ok 300 (lambda (i) (equal? (exchange (number->string i) #f) (number->string i))))))
(newline)

;; the ports stay the same objects across collections
(define c1 (tcp-connect "127.0.0.1" port-number))
(define s1 (tcp-accept listener))
(define in1 (socket-input-port s1))
(garbage)
(write (list 'same-port (eq? in1 (socket-input-port s1))))
(newline)

;; a port whose socket object is gone keeps the connection
(define out-only (let ((c (tcp-connect "127.0.0.1" port-number))) (socket-output-port c)))
(define s2 (tcp-accept listener))
(garbage)
(garbage)
(write-string "still here" out-only)
(newline out-only)
(flush-output-port out-only)
(write (list 'port-without-socket (read-line (socket-input-port s2))))
(newline)
(socket-close c1)
(socket-close s1)
(socket-close s2)
(socket-close listener)

;; listeners dropped without closing
(write (list 'listeners
             (count-ok 20 (lambda (i) (tcp-listener? (tcp-listen (+ port-number 1 i)))))))
(newline)

;; JSON objects outlive their reader
(define json-text "{\"data\": [{\"a\": 1, \"b\": {\"c\": \"x\"}, \"l\": [{\"d\": 2}]}, {\"a\": 3}]}")
(define kept
  (let ((r (open-json-string json-text)))
    (json-next-object r)))
(write (list 'json
             (count-ok 300 (lambda (i)
                             (let* ((r (open-json-string json-text))
                                    (o (json-next-object r)))
                               (= 1 (json-attribute o "a")))))))
(newline)
(garbage)
(write (list 'json-kept
             (json-attribute kept "a")
             (json-attribute (json-attribute kept "b") "c")
             (json-attribute (car (json-attribute kept "l")) "d")))
(newline)

;; XML readers
(define xml-text "<root a=\"1\"><item name=\"x&amp;y\">text</item><item name=\"z\"/></root>")
(write (list 'xml
             (count-ok 300 (lambda (i)
                             (let ((r (open-xml-string xml-text)))
                               (xml-read-to r "item")
                               (equal? (xml-attribute r "name") "x&y"))))))
(newline)

;; zips
(write (list 'zips
             (count-ok 200 (lambda (i)
                             (let ((z (open-output-zip-bytevector)))
                               (zip-add-stored-entry z "a.txt" (string->utf8 (number->string i)))
                               (close-output-zip z)
                               (> (bytevector-length (get-output-zip-bytevector z)) 0))))))
(newline)

;; zips dropped with a text entry being written
(write (list 'zips-dropped
             (count-ok 200 (lambda (i)
                             (let* ((z (open-output-zip-bytevector))
                                    (p (zip-add-text-entry z "a.txt")))
                               (write-string "text" p)
                               #t)))))
(newline)

;; random-access files left open
(define raf-file "natives-raf.tmp")
(call-with-output-file raf-file (lambda (p) (write-string "0123456789" p)))
(write (list 'random-access
             (count-ok 300 (lambda (i)
                             (let ((f (open-random-access-file raf-file 'read)))
                               (= 10 (random-access-file-size f)))))))
(newline)
(delete-file raf-file)

;; file locks
(define lock-file "natives-lock.tmp")
(write (list 'locks
             (count-ok 100 (lambda (i)
                             (let ((l (file-lock lock-file)))
                               (and l (file-unlock l)))))))
(newline)
(delete-file lock-file)
