(import (scheme base)
        (scheme write)
        (scm net http response)
        (scm net http route))

(get! "/" (lambda (req params)
  (make-http-response 200
                      '(("Content-Type" . "text/html"))
                      "<html><body><h1>Hello, World!</h1></body></html>")))

(display "Starting server on port 8088...")
(newline)
(run-app 8088)
