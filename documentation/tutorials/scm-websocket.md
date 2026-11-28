---
title: (scm net sockets) and (scm net websocket): TCP and WebSockets
part: libraries
order: 1028
libraries: (scm net sockets) (scm net websocket)
summary: A line-based TCP protocol with a threaded server and a client, binary sockets, TLS; WebSockets in an HTTP server, a chat room that broadcasts to every client, binary messages, timeouts and keep-alive, the browser side.
---
# (scm net sockets) and (scm net websocket): TCP and WebSockets

- `(scm net sockets)` is plain TCP: connect, listen, accept, and read and
  write through ordinary ports.
- `(scm net websocket)` is two-way messaging over an HTTP connection, the
  way browsers talk to servers in real time.

```scheme
(import (scheme base) (scheme char) (scheme write) (srfi 18)
        (scm net sockets) (scm net websocket)
        (scm net http response) (scm net http route) (scm net http server))
```

## A line protocol over TCP

A tiny stock service: a client sends commands, one per line, and gets one
line back for each. This is how SMTP, Redis or memcached work.

```text
STOCK sencha        -> 40
SET sencha 35       -> OK
QUIT                -> BYE
```

The server keeps the stock in an alist and serves each connection on its
own thread. `socket-input-port` and `socket-output-port` are textual ports
over the connection; output has to be flushed to be sent:

```scheme
(define stock (list (cons "sencha" 40) (cons "assam" 12)))
(define stock-lock (make-mutex))

(define (answer line)
  (let ((words (split-words line)))
    (cond ((null? words) "ERR empty")
          ((and (string=? (car words) "STOCK") (= (length words) 2))
           (let ((e (assoc (cadr words) stock)))
             (if e (number->string (cdr e)) "ERR unknown tea")))
          ((and (string=? (car words) "SET") (= (length words) 3) (string->number (caddr words)))
           (mutex-lock! stock-lock)
           (set! stock (cons (cons (cadr words) (string->number (caddr words))) stock))
           (mutex-unlock! stock-lock)
           "OK")
          (else "ERR unknown command"))))

(define (split-words s)
  (let loop ((cs (string->list s)) (word '()) (words '()))
    (define (flush) (if (null? word) words (cons (list->string (reverse word)) words)))
    (cond ((null? cs) (reverse (flush)))
          ((char-whitespace? (car cs)) (loop (cdr cs) '() (flush)))
          (else (loop (cdr cs) (cons (car cs) word) words)))))

(define (serve-connection sock)
  (let ((in (socket-input-port sock)) (out (socket-output-port sock)))
    (let loop ()
      (let ((line (read-line in)))
        (cond ((eof-object? line) (socket-close sock))
              ((string=? line "QUIT")
               (write-string "BYE\n" out) (flush-output-port out) (socket-close sock))
              (else (write-string (answer line) out) (newline out) (flush-output-port out)
                    (loop)))))))

(define listener (tcp-listen 18911))

(define acceptor
  (make-thread
   (lambda ()
     (let loop ()
       (let ((sock (guard (e (#t #f)) (tcp-accept listener))))   ; #f once the listener is closed
         (when sock
           (thread-start! (make-thread (lambda () (serve-connection sock))))
           (loop)))))))
(thread-start! acceptor)
```

A client connects, writes a line, reads a line:

```scheme
(define (ask sock command)
  (write-string command (socket-output-port sock))
  (newline (socket-output-port sock))
  (flush-output-port (socket-output-port sock))
  (read-line (socket-input-port sock)))

(with-tcp-connection "127.0.0.1" 18911
  (lambda (sock)
    (list (ask sock "STOCK sencha")
          (ask sock "SET sencha 35")
          (ask sock "STOCK sencha")
          (ask sock "STOCK oolong")
          (ask sock "QUIT"))))
;; => ("40" "OK" "35" "ERR unknown tea" "BYE")

(define a (tcp-connect "127.0.0.1" 18911))
(define b (tcp-connect "127.0.0.1" 18911))
(list (ask a "STOCK assam") (ask b "SET assam 0") (ask a "STOCK assam")) ;; => ("12" "OK" "0")
(socket-close a)
(socket-close b)
(socket-close listener)
(thread-join! acceptor)
```

`with-tcp-connection` closes the socket however the procedure ends, and
`call-with-tcp-server` does the same for a listener. Two clients at once
work because each connection has its own thread.

## Binary data and TLS

`socket-binary-input-port` and `socket-binary-output-port` carry bytes,
for binary protocols. A common way to send messages over a byte stream is
a length prefix:

```scheme
(define (send-frame out bv)
  (let ((n (bytevector-length bv)))
    (write-bytevector (bytevector (quotient n 256) (remainder n 256)) out)
    (write-bytevector bv out)
    (flush-output-port out)))

(define (receive-frame in)
  (let ((len (read-bytevector 2 in)))
    (and (bytevector? len)
         (read-bytevector (+ (* 256 (bytevector-u8-ref len 0)) (bytevector-u8-ref len 1)) in))))

(call-with-tcp-server 18913
  (lambda (l)
    (let ((t (make-thread (lambda ()
                            (let* ((s (tcp-accept l))
                                   (msg (receive-frame (socket-binary-input-port s))))
                              (send-frame (socket-binary-output-port s)
                                          (string->utf8 (number->string (bytevector-length msg))))
                              (socket-close s))))))
      (thread-start! t)
      (with-tcp-connection "127.0.0.1" 18913
        (lambda (s)
          (send-frame (socket-binary-output-port s) (make-bytevector 300 7))
          (utf8->string (receive-frame (socket-binary-input-port s))))))))
;; => "300"
```

The server answers with the number of bytes it received, as text in a
frame of its own. If the server thread had failed, the client would wait
forever for its answer: real protocols put timeouts around such reads.
`tls-connect` opens an encrypted connection with certificate
checks, and `socket-starttls!` upgrades a connection that began in plain
text, as SMTP does.

## WebSockets

A WebSocket starts as an HTTP request that the server *upgrades*; from
then on both sides send messages whenever they like. In the server a
route returns `http-websocket-upgrade` with a procedure that talks to the
client:

```scheme
(define r (make-router))
(router-add! r "GET" "/echo"
  (lambda (req params)
    (http-websocket-upgrade
     (lambda (ws)
       (let loop ((m (ws-receive ws)))
         (when m                            ; #f: the client has gone
           (ws-send ws (if (string? m) (string-upcase m) (bytevector-length m)))
           (loop (ws-receive ws))))))))
```

Oops: `ws-send` takes a string or a bytevector, not a number. The
procedure runs on a server thread; when it raises, the server logs the
error and closes the connection, and the client sees `#f`:

```scheme
(define server (start-app-with-router r 18912 16 "127.0.0.1"))

(define ws (ws-connect "127.0.0.1" 18912 "/echo"))
(ws-send ws "hello")
(ws-receive ws)                             ;; => "HELLO"
(ws-send ws (bytevector 1 2 3))
(ws-receive ws)                             ;; => #f
```

Text messages arrive as strings and binary ones as bytevectors, so a
handler can tell them apart. Fixed:

```scheme
(router-add! r "GET" "/echo2"
  (lambda (req params)
    (http-websocket-upgrade
     (lambda (ws)
       (let loop ((m (ws-receive ws)))
         (when m
           (ws-send ws (if (string? m) (string-upcase m) (bytevector (bytevector-length m))))
           (loop (ws-receive ws))))))))

(define ws2 (ws-connect "127.0.0.1" 18912 "/echo2"))
(ws-send ws2 (bytevector 1 2 3))
(ws-receive ws2)                            ;; => #u8(3)
(ws-close ws2)
```

## Example: a chat room

Every message a client sends goes to all connected clients. The server
keeps the open connections in a list; `ws-send` may be called from any
thread, so one client's handler can send to the others.

```scheme
(define room '())
(define room-lock (make-mutex))

(define (with-room proc)
  (mutex-lock! room-lock)
  (let ((v (proc)))
    (mutex-unlock! room-lock)
    v))

(define (broadcast text)
  (for-each (lambda (c) (guard (e (#t #f)) (ws-send c text)))   ; skip clients that just left
            (with-room (lambda () room))))

(router-add! r "GET" "/chat/:name"
  (lambda (req params)
    (let ((name (params-ref params "name")))
      (http-websocket-upgrade
       (lambda (ws)
         (with-room (lambda () (set! room (cons ws room))))
         (ws-send ws (string-append "welcome, " name))
         (broadcast (string-append name " joined"))
         (let loop ((m (ws-receive ws)))
           (when (string? m)
             (broadcast (string-append name ": " m))
             (loop (ws-receive ws))))
         (with-room (lambda () (set! room (remove-ws ws room))))
         (broadcast (string-append name " left")))))))

(define (remove-ws ws lst)
  (cond ((null? lst) '()) ((eq? (car lst) ws) (cdr lst)) (else (cons (car lst) (remove-ws ws (cdr lst))))))
```

A client waits for its welcome before going on, so it is in the room when
the next message is sent:

```scheme
(define (join name)
  (let ((c (ws-connect "127.0.0.1" 18912 (string-append "/chat/" name))))
    (ws-receive c)                          ; "welcome, ..."
    c))

(define ada (join "ada"))
(ws-receive ada)                            ;; => "ada joined"
(define alan (join "alan"))
(list (ws-receive ada) (ws-receive alan))   ;; => ("alan joined" "alan joined")

(ws-send alan "tea at five?")
(list (ws-receive ada) (ws-receive alan))   ;; => ("alan: tea at five?" "alan: tea at five?")

(ws-close alan)
(ws-receive ada)                            ;; => "alan left"
(ws-receive ada 100)                        ;; => timeout
(ws-close ada)
(server-stop server)                        ;; => #t
```

With a timeout, `ws-receive` returns the symbol `timeout` when nothing
came; the connection stays open. A server uses that to notice quiet
clients, for example sending something every 30 seconds so that proxies
do not close idle connections. Each open WebSocket holds a server thread,
so the thread count given to the server bounds the number of clients.

## The browser side

The page opens the socket with the URL of the route (`wss://` on HTTPS
sites) and sends and receives messages with events:

```text
const ws = new WebSocket(`wss://${location.host}/chat/ada`);
ws.onmessage = (e) => show(e.data);
form.onsubmit = (e) => { e.preventDefault(); ws.send(input.value); input.value = ""; };
```

Session cookies come along with the upgrade request, so the route can
check `session-ref` before upgrading, as any other route does.

## Where next

- [HTTP servers](scm-http-server.md), [web applications](scm-web-app.md),
  [threads](srfi-18.md).
- [E-mail](scm-email.md) is a line protocol over TCP with STARTTLS.
- Reference: `(scm net sockets)`, `(scm net websocket)`.
