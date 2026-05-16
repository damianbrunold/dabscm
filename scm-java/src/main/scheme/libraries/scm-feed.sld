(define-library (scm feed)
  (import (scm core)
          (scheme base)
          (scheme char)
          (scheme cxr)
          (srfi 1)
          (srfi 13)
          (scm string)
          (scm xml))
  (export parse-feed-file
          parse-feed-string
          parse-feed-bytevector
          local-name
          qname-field)
  (begin

    ;; --------------------------------------------------------------
    ;; Atom / RSS 2.0 feed parser.
    ;;
    ;; Three entry points, depending on where the feed bytes live:
    ;;   parse-feed-file       — feed is on disk
    ;;   parse-feed-string     — feed is an in-memory string
    ;;   parse-feed-bytevector — feed is an in-memory bytevector
    ;;
    ;; All three return:
    ;;   (cons feed-title entry-list)
    ;; where entry-list is a list of alists with keys
    ;;   \"title\" \"link\" \"guid\" \"summary\" \"published\"
    ;; All values are strings; missing fields default to \"\".
    ;;
    ;; Date strings are returned as-is — use (scm datetime) parse-pubdate
    ;; to convert them to Unix seconds.
    ;; --------------------------------------------------------------

    (define (local-name qname)
      ;; Strip any namespace prefix and downcase. Used for item/entry
      ;; element detection where namespacing doesn't matter.
      (let ((n (string-length qname)))
        (let loop ((i 0))
          (cond
            ((= i n) (string-downcase qname))
            ((char=? (string-ref qname i) #\:)
             (string-downcase (substring qname (+ i 1) n)))
            (else (loop (+ i 1)))))))

    (define entry-field-names
      '("title" "link" "id" "guid" "description" "summary" "content"
        "published" "pubdate" "updated"))

    (define (qname-field qname)
      ;; Returns the entry-field name (lowercased) for a qname if it is
      ;; unprefixed or uses the atom: prefix, else #f. Guards against
      ;; namespaced extension elements (e.g. <media:content>, <dc:creator>)
      ;; that would otherwise collide with real Atom fields.
      (let ((colon (string-index qname #\:)))
        (cond
          ((not colon)
           (let ((n (string-downcase qname)))
             (cond ((member n entry-field-names string=?) n)
                   (else #f))))
          (else
           (let ((prefix (string-downcase (substring qname 0 colon)))
                 (rest   (string-downcase
                           (substring qname (+ colon 1) (string-length qname)))))
             (cond
               ((string=? prefix "atom")
                (cond ((member rest entry-field-names string=?) rest)
                      (else #f)))
               (else #f)))))))

    (define (pick alist . keys)
      ;; Returns the first non-empty value for any of keys, or "".
      (let loop ((ks keys))
        (cond
          ((null? ks) "")
          (else
           (let ((p (assoc (car ks) alist)))
             (cond
               ((and p (not (= 0 (string-length (cdr p))))) (cdr p))
               (else (loop (cdr ks)))))))))

    (define (normalise-entry raw)
      (list (cons "title"     (pick raw "title"))
            (cons "link"      (pick raw "link"))
            (cons "guid"      (pick raw "id" "guid" "link"))
            (cons "summary"   (pick raw "summary" "description" "content"))
            (cons "published" (pick raw "published" "updated" "pubdate"))))

    (define (xml-text-or-empty r)
      (or (xml-value r) ""))

    (define (parse-from-reader r)
      (let scan ((feed-title #f)
                 (entries '())
                 (entry #f)
                 (continue? #t))
        (cond
          ((not continue?)
           (cons (or feed-title "") (reverse entries)))

          (else
           (case (xml-node-type r)
             ((element)
              (let* ((qname (xml-name r))
                     (lnm   (local-name qname))
                     (field (qname-field qname)))
                (cond
                  ((or (string=? lnm "item") (string=? lnm "entry"))
                   (scan feed-title entries '() (xml-read r)))

                  (entry
                   (cond
                     ;; Atom uses <link href="..."/>; RSS has text content.
                     ((and field (string=? field "link"))
                      (let ((href (xml-attribute r "href")))
                        (cond
                          (href
                           (scan feed-title entries
                                 (cons (cons "link" href) entry)
                                 (xml-read r)))
                          (else
                           (let ((v (xml-text-or-empty r)))
                             (scan feed-title entries
                                   (cons (cons "link" v) entry)
                                   #t))))))
                     (field
                      (let ((v (xml-text-or-empty r)))
                        (scan feed-title entries
                              (cons (cons field v) entry)
                              #t)))
                     (else
                      (scan feed-title entries entry (xml-read r)))))

                  ((and (not feed-title) (string=? lnm "title")
                        (qname-field qname))
                   (let ((v (xml-text-or-empty r)))
                     (scan v entries entry #t)))

                  (else
                   (scan feed-title entries entry (xml-read r))))))

             ((end-element)
              (let ((nm (local-name (xml-name r))))
                (cond
                  ((and entry
                        (or (string=? nm "item") (string=? nm "entry")))
                   (scan feed-title
                         (cons (normalise-entry (reverse entry)) entries)
                         #f
                         (xml-read r)))
                  (else
                   (scan feed-title entries entry (xml-read r))))))

             (else
              (scan feed-title entries entry (xml-read r))))))))

    (define (with-reader open-thunk)
      (let ((r (open-thunk)))
        (guard (exn (#t (close-xml r) (raise exn)))
          (let ((result (parse-from-reader r)))
            (close-xml r)
            result))))

    (define (parse-feed-file path)
      "Syntax: (parse-feed-file path)
Library: (scm feed)
Description: Parses an Atom or RSS 2.0 feed from a file. Returns a pair
  (feed-title . entries), where entries is a list of alists with keys
  'title', 'link', 'guid', 'summary', 'published' (all strings; missing
  fields default to ''). Dates are returned verbatim — use parse-pubdate
  from (scm datetime) to convert.
Example:
  (parse-feed-file \"/tmp/feed.xml\")
    => (\"Example\" ((\"title\" . \"Post 1\") (\"link\" . \"...\") ...))"
      (with-reader (lambda () (open-xml-file path))))

    (define (parse-feed-string s)
      "Syntax: (parse-feed-string s)
Library: (scm feed)
Description: Parses an Atom or RSS 2.0 feed from an in-memory string.
  Same result shape as parse-feed-file.
Example:
  (parse-feed-string \"<rss>...</rss>\") => (\"Example\" (... ...))"
      (with-reader (lambda () (open-xml-string s))))

    (define (parse-feed-bytevector bv)
      "Syntax: (parse-feed-bytevector bv)
Library: (scm feed)
Description: Parses an Atom or RSS 2.0 feed from an in-memory bytevector.
  Same result shape as parse-feed-file. Use this when fetching feed bytes
  over HTTP so the XML declaration's encoding is honoured.
Example:
  (parse-feed-bytevector (http-response-body resp))"
      (with-reader (lambda () (open-xml-bytevector bv))))
))
