(import (scheme base) (scm xml) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "xml")

;; xml-read-to scans forward to the named element regardless of the
;; reader's initial state, so these tests work on both C# (which primes
;; to the first element) and Java (which starts at the document node).

(test-group "open-xml-string"
  (let ((r (open-xml-string "<root><a>1</a><b>two</b></root>")))
    (test-equal #t (xml-read-to r "root"))
    (test-equal 'element (xml-node-type r))
    (test-equal "root"   (xml-name r))
    (test-equal #t (xml-read-to r "a"))
    (test-equal "a"      (xml-name r))
    (test-equal "1"      (xml-value r))
    (close-xml r)))

(test-group "open-xml-string with prolog"
  (let ((r (open-xml-string "<?xml version=\"1.0\"?><doc><x/></doc>")))
    (test-equal #t (xml-read-to r "doc"))
    (test-equal "doc" (xml-name r))
    (close-xml r)))

(test-group "open-xml-bytevector"
  (let ((r (open-xml-bytevector
            (string->utf8 "<?xml version=\"1.0\"?><root><x>hi</x></root>"))))
    (test-equal #t (xml-read-to r "root"))
    (test-equal "root" (xml-name r))
    (test-equal #t (xml-read-to r "x"))
    (test-equal "hi"   (xml-value r))
    (close-xml r)))

(test-group "open-xml-bytevector simple"
  (let ((r (open-xml-bytevector (string->utf8 "<a><b/></a>"))))
    (test-equal #t (xml-read-to r "b"))
    (test-equal "b" (xml-name r))
    (close-xml r)))

(test-end "xml")
