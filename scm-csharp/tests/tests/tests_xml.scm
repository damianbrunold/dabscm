(import (scheme base)
        (srfi 13)
        (scm test)
        (scm xml))

(test-runner-factory scm-test-runner)

(test-begin "xml")

;; xml-read-to scans forward to the named element regardless of the
;; reader's initial state, so these tests work on both C# (which primes
;; to the first element) and Java (which starts at the document node).

(test-group "open-xml-string"
  (let ((r (open-xml-string "<root><a>1</a><b>two</b></root>")))
    (test-equal #t (xml-read-to r "root"))
    (test-equal 'element (xml-node-type r))
    (test-equal "root" (xml-name r))
    (test-equal #t (xml-read-to r "a"))
    (test-equal "a" (xml-name r))
    (test-equal "1" (xml-value r))
    (close-xml r)))

(test-group "open-xml-string with prolog"
  (let ((r (open-xml-string "<?xml version=\"1.0\"?><doc><x/></doc>")))
    (test-equal #t (xml-read-to r "doc"))
    (test-equal "doc" (xml-name r))
    (close-xml r)))

(test-group "open-xml-bytevector"
  (let
      ((r (open-xml-bytevector (string->utf8
                                "<?xml version=\"1.0\"?><root><x>hi</x></root>"))))
    (test-equal #t (xml-read-to r "root"))
    (test-equal "root" (xml-name r))
    (test-equal #t (xml-read-to r "x"))
    (test-equal "hi" (xml-value r))
    (close-xml r)))

(test-group "open-xml-bytevector simple"
  (let ((r (open-xml-bytevector (string->utf8 "<a><b/></a>"))))
    (test-equal #t (xml-read-to r "b"))
    (test-equal "b" (xml-name r))
    (close-xml r)))

(test-group "no DTDs or external entities (XXE)"
  ;; Every text value of the document, or 'error when it is refused.
  (define (values-of s)
    (guard (e (#t 'error))
      (let ((r (open-xml-string s)))
        (let loop ((acc '()))
          (if (xml-read r)
              (loop (cons (guard (e (#t #f)) (xml-value r)) acc))
              (begin
                (close-xml r)
                acc))))))
  (define (expanded? v needle)
    (and (pair? v)
         (let loop ((xs v))
           (cond ((null? xs) #f)
                 ((and (string? (car xs)) (string-contains (car xs) needle))
                  #t)
                 (else (loop (cdr xs)))))))
  (test-equal "external entity not expanded" #f
              (expanded? (values-of
                          "<?xml version=\"1.0\"?><!DOCTYPE r [<!ENTITY e SYSTEM \"file:///etc/passwd\">]><r>&e;</r>")
                         "root"))
  (test-equal "internal entity not expanded" #f
              (expanded? (values-of
                          "<?xml version=\"1.0\"?><!DOCTYPE r [<!ENTITY a \"zzzzz\">]><r>&a;&a;</r>")
                         "zzzzz"))
  ;; predefined entities still work
  (let ((r (open-xml-string "<r>a &amp; b &lt;c&gt;</r>")))
    (test-equal #t (xml-read-to r "r"))
    (test-equal "a & b <c>" (xml-value r))
    (close-xml r)))

(test-group "characters XML does not allow"
  ;; a NUL or another control character in text or an attribute value is
  ;; an error, as XML 1.0 does not allow it (tab, newline and CR are fine)
  (let ((r (open-xml-string
            (string-append "<r><a>X" (string (integer->char 0)) "</a></r>"))))
    (test-equal #t (xml-read-to r "a"))
    (test-equal 'error (guard (e (#t 'error)) (xml-value r)))
    (close-xml r))
  (let ((r (open-xml-string
            (string-append "<r a=\"x" (string (integer->char 1)) "\"/>"))))
    (test-equal 'error (guard (e (#t 'error)) (xml-read-to r "r") 'read))
    (close-xml r))
  (let ((r (open-xml-string "<r><a>x\ty\nz\r</a></r>")))
    (test-equal #t (xml-read-to r "a"))
    (test-equal #t (string? (xml-value r)))
    (close-xml r)))

(test-group "the same event stream on every implementation"
  ;; the node types and names of a whole document
  (define (events s)
    (let ((r (open-xml-string s)))
      (let loop ((acc '()))
        (if (xml-read r)
            (loop (cons (list (xml-node-type r) (xml-name r)) acc))
            (begin (close-xml r) (reverse acc))))))
  (test-equal "declaration and outside white space skipped, empty element ends, text merged"
              '((element "a") (comment "") (element "b") (text "") (end-element "b")
                (element "c") (end-element "c") (element "d") (text "") (end-element "d")
                (element "ns:e") (text "") (end-element "ns:e") (end-element "a"))
              (events "<?xml version=\"1.0\"?>\n<a x=\"1\"><!-- c --><b>hi &amp; ho</b><c/><d>x<![CDATA[<raw>]]>y</d><ns:e xmlns:ns=\"urn:x\">t</ns:e></a>\n"))
  (test-equal "doctype skipped"
              '((element "r") (end-element "r"))
              (events "<!DOCTYPE r><r/>"))
  (test-equal "comment splits text"
              '((element "r") (text "") (comment "") (text "") (end-element "r"))
              (events "<r>a<!--x-->b</r>"))
  (test-equal "xml-read is #f once the document has ended" #f
              (let ((r (open-xml-string "<r/>")))
                (xml-read r) (xml-read r)
                (let ((more (xml-read r))) (close-xml r) more)))
  ;; xml-value leaves the reader on the end of the element, so adjacent
  ;; elements are all found
  (test-equal "adjacent elements" '("1" "" "3 & 4")
              (let ((r (open-xml-string "<r><v>1</v><v/><v>3 &amp; <![CDATA[4]]></v></r>")))
                (let loop ((acc '()))
                  (if (xml-read-to r "v")
                      (loop (cons (xml-value r) acc))
                      (begin (close-xml r) (reverse acc))))))
  (let ((r (open-xml-string "<r><v>1</v><w/></r>")))
    (xml-read-to r "v")
    (xml-value r)
    (test-equal 'end-element (xml-node-type r))
    (test-equal "v" (xml-name r))
    (test-equal #t (xml-read r))
    (test-equal "w" (xml-name r))
    (close-xml r))
  ;; qualified or local names
  (let ((r (open-xml-string "<f xmlns:m=\"urn:m\"><m:item m:id=\"7\" kind=\"k\"/><m:item m:id=\"8\"/></f>")))
    (test-equal #t (xml-read-to r "item"))
    (test-equal "m:item" (xml-name r))
    (test-equal "7" (xml-attribute r "id"))
    (test-equal "7" (xml-attribute r "m:id"))
    (test-equal "k" (xml-attribute r 'kind))
    (test-equal #f (xml-attribute r "nope"))
    (test-equal #t (xml-read-to r "m:item"))
    (test-equal "8" (xml-attribute r "m:id"))
    (xml-read r)
    (test-equal #f (xml-attribute r "m:id"))
    (close-xml r)))

(test-end "xml")
