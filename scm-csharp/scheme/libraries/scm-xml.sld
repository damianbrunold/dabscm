(define-library (scm xml)
  (export close-xml
          open-xml-file
          xml-attribute
          xml-name
          xml-node-type
          xml-read
          xml-read-to
          xml-value)
  (begin
    (define open-xml-file (%primitive "open-xml-file"))
    (define xml-attribute (%primitive "xml-attribute"))
    (define xml-name (%primitive "xml-name"))
    (define xml-node-type (%primitive "xml-node-type"))
    (define xml-read (%primitive "xml-read"))
    (define xml-read-to (%primitive "xml-read-to"))
    (define xml-value (%primitive "xml-value"))
    (define close-xml (%primitive "close-xml"))))
