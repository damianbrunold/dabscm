(define-library (scm net websocket)
  (import (scheme base)
          (scm core))
  (export ws-accept
          ws-close
          ws-connect
          ws-receive
          ws-send
          ws?)
  (begin
    (define ws-accept (%primitive "ws-accept"))
    (define ws-connect (%primitive "ws-connect"))
    (define ws-send (%primitive "ws-send"))
    (define ws-receive (%primitive "ws-receive"))
    (define ws-close (%primitive "ws-close"))
    (define ws? (%primitive "ws?"))))
