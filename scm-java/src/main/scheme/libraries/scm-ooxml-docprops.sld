(define-library (scm ooxml docprops)
  ;; Document properties (docProps/core.xml, app.xml, custom.xml) shared by
  ;; (scm ooxml excel) and (scm ooxml word).
  (export docprops-valid?
          docprops-present?
          docprops-relationships
          docprops-content-types
          docprops-parts)
  (import (scheme base)
          (scheme write)
          (scm io))

  (begin
    (define xml-preamble
      "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")

    (define ns-rel-base
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
    (define ns-pkg-rel-base
      "http://schemas.openxmlformats.org/package/2006/relationships/metadata")
    (define ct-base "application/vnd.openxmlformats")

    ;; Core property key -> element name (in core.xml order).
    (define core-keys
      '((title       . "dc:title")
        (subject     . "dc:subject")
        (creator     . "dc:creator")
        (keywords    . "cp:keywords")
        (description . "dc:description")
        (category    . "cp:category")))

    (define (xml-escape str)
      (let loop ((chars (string->list str)) (acc '()))
        (if (null? chars)
            (list->string (reverse acc))
            (let* ((c (car chars))
                   (replacement (cond ((char=? c #\&) (string->list "&amp;"))
                                      ((char=? c #\<) (string->list "&lt;"))
                                      ((char=? c #\>) (string->list "&gt;"))
                                      ((char=? c #\") (string->list "&quot;"))
                                      (else           (list c)))))
              (loop (cdr chars) (append (reverse replacement) acc))))))

    (define (prop-ref props key)
      (let ((p (and (list? props) (assq key props))))
        (and p (cdr p))))

    (define (core-entries props)
      (let loop ((ks core-keys) (acc '()))
        (if (null? ks)
            (reverse acc)
            (let ((v (prop-ref props (caar ks))))
              (loop (cdr ks)
                    (if (and (string? v) (not (string=? v "")))
                        (cons (cons (cdar ks) v) acc)
                        acc))))))

    (define (custom-entries props)
      (let ((c (prop-ref props 'custom)))
        (if (list? c)
            (let loop ((c c) (acc '()))
              (cond ((null? c) (reverse acc))
                    ((and (pair? (car c)) (string? (caar c)) (string? (cdar c)))
                     (loop (cdr c) (cons (car c) acc)))
                    (else (loop (cdr c) acc))))
            '())))

    (define (docprops-valid? props)
      "Syntax: (docprops-valid? props)
Library: (scm ooxml docprops)
Description: Returns #t when props is a properties alist accepted by
workbook-set-properties! / document-set-properties!: keys title, subject,
creator, keywords, description, category map to strings; custom maps to an
alist of (name . value) strings.
Example:
  (docprops-valid? '((category . \"Intern\"))) => #t"
      (and (list? props)
           (let loop ((ps props))
             (cond ((null? ps) #t)
                   ((not (pair? (car ps))) #f)
                   ((assq (caar ps) core-keys)
                    (and (string? (cdar ps)) (loop (cdr ps))))
                   ((eq? (caar ps) 'custom)
                    (and (list? (cdar ps))
                         (let check ((c (cdar ps)))
                           (or (null? c)
                               (and (pair? (car c)) (string? (caar c))
                                    (string? (cdar c)) (check (cdr c)))))
                         (loop (cdr ps))))
                   (else #f)))))

    (define (docprops-present? props)
      "Syntax: (docprops-present? props)
Library: (scm ooxml docprops)
Description: Returns #t when props (an alist, or #f) carries at least one
core or custom property, i.e. when docProps parts are written.
Example:
  (docprops-present? '()) => #f"
      (or (pair? (core-entries props)) (pair? (custom-entries props))))

    (define (docprops-relationships props)
      "Syntax: (docprops-relationships props)
Library: (scm ooxml docprops)
Description: Returns the <Relationship> elements for the package _rels/.rels
pointing at the docProps parts (empty string when nothing is set).
Example:
  (docprops-relationships '()) => \"\""
      (if (not (docprops-present? props))
          ""
          (call-with-output-string
           (lambda (port)
             (format port "<Relationship Id=\"rIdDpCore\" Type=\"~a/core-properties\" Target=\"docProps/core.xml\"/>"
                     ns-pkg-rel-base)
             (format port "<Relationship Id=\"rIdDpApp\" Type=\"~a/extended-properties\" Target=\"docProps/app.xml\"/>"
                     ns-rel-base)
             (when (pair? (custom-entries props))
               (format port "<Relationship Id=\"rIdDpCustom\" Type=\"~a/custom-properties\" Target=\"docProps/custom.xml\"/>"
                       ns-rel-base))))))

    (define (docprops-content-types props)
      "Syntax: (docprops-content-types props)
Library: (scm ooxml docprops)
Description: Returns the [Content_Types].xml <Override> elements for the
docProps parts (empty string when nothing is set).
Example:
  (docprops-content-types '()) => \"\""
      (if (not (docprops-present? props))
          ""
          (call-with-output-string
           (lambda (port)
             (format port "<Override PartName=\"/docProps/core.xml\" ContentType=\"~a-package.core-properties+xml\"/>"
                     ct-base)
             (format port "<Override PartName=\"/docProps/app.xml\" ContentType=\"~a-officedocument.extended-properties+xml\"/>"
                     ct-base)
             (when (pair? (custom-entries props))
               (format port "<Override PartName=\"/docProps/custom.xml\" ContentType=\"~a-officedocument.custom-properties+xml\"/>"
                       ct-base))))))

    (define (render-core props)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (display "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">" port)
         (for-each (lambda (e)
                     (format port "<~a>~a</~a>" (car e) (xml-escape (cdr e)) (car e)))
                   (core-entries props))
         (display "</cp:coreProperties>" port))))

    (define (render-app)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (display "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\"><Application>scm</Application></Properties>" port))))

    (define (render-custom props)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (display "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/custom-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">" port)
         (let loop ((es (custom-entries props)) (pid 2))
           (unless (null? es)
             (format port "<property fmtid=\"{D5CDD505-2E9C-101B-9397-08002B2CF9AE}\" pid=\"~a\" name=\"~a\"><vt:lpwstr>~a</vt:lpwstr></property>"
                     pid (xml-escape (caar es)) (xml-escape (cdar es)))
             (loop (cdr es) (+ pid 1))))
         (display "</Properties>" port))))

    (define (docprops-parts props)
      "Syntax: (docprops-parts props)
Library: (scm ooxml docprops)
Description: Returns a list of (part-name . xml-string) for the docProps parts
to add to the package; '() when nothing is set.
Example:
  (map car (docprops-parts '((category . \"Intern\"))))
    => (\"docProps/core.xml\" \"docProps/app.xml\")"
      (if (not (docprops-present? props))
          '()
          (append
           (list (cons "docProps/core.xml" (render-core props))
                 (cons "docProps/app.xml" (render-app)))
           (if (pair? (custom-entries props))
               (list (cons "docProps/custom.xml" (render-custom props)))
               '()))))))
