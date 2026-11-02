(import (scheme base) (srfi 13) (scm xml) (scm test))

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

(test-group "no DTDs or external entities (XXE)"
  ;; Every text value of the document, or 'error when it is refused.
  (define (values-of s)
    (guard (e (#t 'error))
      (let ((r (open-xml-string s)))
        (let loop ((acc '()))
          (if (xml-read r)
              (loop (cons (guard (e (#t #f)) (xml-value r)) acc))
              (begin (close-xml r) acc))))))
  (define (expanded? v needle)
    (and (pair? v)
         (let loop ((xs v))
           (cond ((null? xs) #f)
                 ((and (string? (car xs)) (string-contains (car xs) needle)) #t)
                 (else (loop (cdr xs)))))))
  (test-equal "external entity not expanded" #f
              (expanded? (values-of "<?xml version=\"1.0\"?><!DOCTYPE r [<!ENTITY e SYSTEM \"file:///etc/passwd\">]><r>&e;</r>")
                         "root"))
  (test-equal "internal entity not expanded" #f
              (expanded? (values-of "<?xml version=\"1.0\"?><!DOCTYPE r [<!ENTITY a \"zzzzz\">]><r>&a;&a;</r>")
                         "zzzzz"))
  ;; predefined entities still work
  (let ((r (open-xml-string "<r>a &amp; b &lt;c&gt;</r>")))
    (test-equal #t (xml-read-to r "r"))
    (test-equal "a & b <c>" (xml-value r))
    (close-xml r)))

(test-end "xml")
