(define-library (scm net websocket)
  (import (scm core) (scheme base))
  (export ws-accept
          ws-connect
          ws-send
          ws-receive
          ws-close
          ws?)
  (begin
    (define ws-accept  (%primitive "ws-accept"))
    (define ws-connect (%primitive "ws-connect"))
    (define ws-send    (%primitive "ws-send"))
    (define ws-receive (%primitive "ws-receive"))
    (define ws-close   (%primitive "ws-close"))
    (define ws?        (%primitive "ws?"))))
