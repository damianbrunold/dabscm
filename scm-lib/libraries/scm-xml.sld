(define-library (scm xml)
  (export close-xml
          open-xml-bytevector
          open-xml-file
          open-xml-string
          xml-attribute
          xml-name
          xml-node-type
          xml-read
          xml-read-to
          xml-value)
  (begin
    (define open-xml-bytevector (%primitive "open-xml-bytevector"))
    (define open-xml-file (%primitive "open-xml-file"))
    (define open-xml-string (%primitive "open-xml-string"))
    (define xml-attribute (%primitive "xml-attribute"))
    (define xml-name (%primitive "xml-name"))
    (define xml-node-type (%primitive "xml-node-type"))
    (define xml-read (%primitive "xml-read"))
    (define xml-read-to (%primitive "xml-read-to"))
    (define xml-value (%primitive "xml-value"))
    (define close-xml (%primitive "close-xml"))))
