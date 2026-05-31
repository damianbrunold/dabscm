(define-library (scm ooxml word-reader)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (srfi 1)
          (srfi 13)
          (scm fs)
          (scm zip)
          (scm xml))
  (export read-document
          read-document-from-bytevector
          document-paragraphs
          document-text
          document-headings
          paragraph-text
          paragraph-style
          paragraph-heading-level
          paragraph-in-table?)
  (begin

    ;; --------------------------------------------------------------
    ;; Reader for the text content of DOCX (WordprocessingML)
    ;; documents. Built purely on (scm zip) and (scm xml).
    ;;
    ;; Extracts paragraphs in document order, each carrying its text,
    ;; its paragraph style name and, for headings, a heading level
    ;; (1..n). Text inside tables is included, with the in-table? flag
    ;; set so callers can distinguish it.
    ;;
    ;; Not read: run formatting (bold/italic/colour), images, headers,
    ;; footers, fields/TOC and list numbering.
    ;; --------------------------------------------------------------

    (define (local-name qname)
      (let ((i (string-index qname #\:)))
        (if i (substring qname (+ i 1) (string-length qname)) qname)))

    (define (attr r . names)
      (let loop ((ns names))
        (if (null? ns)
            #f
            (or (xml-attribute r (car ns)) (loop (cdr ns))))))

    (define (heading-level-from-style style)
      ;; "Heading1" -> 1, "Heading2" -> 2, ...; #f otherwise.
      (and (string? style)
           (let ((n (string-length style)))
             (and (> n 7)
                  (string-ci=? (substring style 0 7) "Heading")
                  (let ((rest (substring style 7 n)))
                    (and (string-every char-numeric? rest)
                         (string->number rest)))))))

    (define (make-paragraph text style outline in-table?)
      (let ((level (or (heading-level-from-style style) outline)))
        (list (cons "text" text)
              (cons "style" style)
              (cons "level" level)
              (cons "in-table" in-table?))))

    (define (parse-body bv)
      ;; Walk word/document.xml and return a list of paragraph records.
      (let ((paragraphs '())
            (table-depth 0)
            (in-p #f)
            (cur-text "")
            (cur-style #f)
            (cur-outline #f)
            (cur-in-table #f))
        (define (append-text! s) (set! cur-text (string-append cur-text s)))
        (define (push!)
          (set! paragraphs
                (cons (make-paragraph cur-text cur-style cur-outline cur-in-table)
                      paragraphs)))
        (let ((r (open-xml-bytevector bv)))
          (guard (exn (#t (close-xml r) (raise exn)))
            (let loop ((cont #t))
              (cond
                ((not cont) #t)
                (else
                 (case (xml-node-type r)
                   ((element)
                    (let ((nm (local-name (xml-name r))))
                      (cond
                        ((string=? nm "tbl")
                         (set! table-depth (+ table-depth 1))
                         (loop (xml-read r)))
                        ((string=? nm "p")
                         (set! in-p #t)
                         (set! cur-text "")
                         (set! cur-style #f)
                         (set! cur-outline #f)
                         (set! cur-in-table (> table-depth 0))
                         (loop (xml-read r)))
                        ((and in-p (string=? nm "pStyle"))
                         (set! cur-style (attr r "w:val" "val"))
                         (loop (xml-read r)))
                        ((and in-p (string=? nm "outlineLvl"))
                         (let ((v (string->number (or (attr r "w:val" "val") ""))))
                           (when v (set! cur-outline (+ v 1))))
                         (loop (xml-read r)))
                        ((and in-p (string=? nm "t"))
                         (append-text! (or (xml-value r) ""))
                         ;; xml-value consumed the element; do not re-read.
                         (loop #t))
                        ((and in-p (string=? nm "tab")
                              ;; A run tab <w:tab/> has no attributes; the
                              ;; tab-stop definitions in <w:tabs> carry w:val.
                              (not (attr r "w:val" "val")))
                         (append-text! "\t")
                         (loop (xml-read r)))
                        ((and in-p (or (string=? nm "br") (string=? nm "cr")))
                         (append-text! "\n")
                         (loop (xml-read r)))
                        (else (loop (xml-read r))))))
                   ((end-element)
                    (let ((nm (local-name (xml-name r))))
                      (cond
                        ((string=? nm "p")
                         (when in-p (push!) (set! in-p #f))
                         (loop (xml-read r)))
                        ((string=? nm "tbl")
                         (set! table-depth (max 0 (- table-depth 1)))
                         (loop (xml-read r)))
                        (else (loop (xml-read r))))))
                   (else (loop (xml-read r)))))))
            (close-xml r)))
        ;; Drop empty paragraphs (no text and not a heading). This removes the
        ;; structural trailing <w:p/> that DOCX requires and keeps the result
        ;; identical regardless of how the host XML parser reports self-closing
        ;; elements.
        (filter (lambda (p)
                  (or (> (string-length (cdr (assoc "text" p))) 0)
                      (cdr (assoc "level" p))))
                (reverse paragraphs))))

    (define (read-document-from-zip z)
      (let ((bv (and (member "word/document.xml" (zip-entry-names z))
                     (zip-read-entry-bytevector z "word/document.xml"))))
        (vector 'docx-document (if bv (parse-body bv) '()))))

    ;; ---- public API ----------------------------------------------

    (define (read-document path)
      "Syntax: (read-document path)
Library: (scm ooxml word-reader)
Description: Reads the text content of the DOCX document at path and returns a
  document object. Use document-paragraphs, document-text and document-headings
  to access the content. Run formatting, images, headers/footers and fields are
  not read.
Example:
  (let ((doc (read-document \"letter.docx\")))
    (document-text doc)) => \"Dear Sir\\nThank you ...\""
      (call-with-input-zip path read-document-from-zip))

    (define (read-document-from-bytevector bv)
      "Syntax: (read-document-from-bytevector bv)
Library: (scm ooxml word-reader)
Description: Like read-document, but reads from an in-memory bytevector holding
  the bytes of a DOCX file. The bytes are written to a temporary file (the
  underlying zip reader is file-based) which is removed before returning.
Example:
  (read-document-from-bytevector (document-save-to-bytevector doc))"
      (let ((path (mktemp '(prefix . "scm-docx-read"))))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (let ((p (open-binary-output-file path)))
              (write-bytevector bv p)
              (close-port p))
            (read-document path))
          (lambda () (delete-file path)))))

    (define (document-paragraphs doc)
      "Syntax: (document-paragraphs doc)
Library: (scm ooxml word-reader)
Description: Returns the document's paragraphs in document order, as a list of
  paragraph records. Use paragraph-text, paragraph-style, paragraph-heading-level
  and paragraph-in-table? to inspect each record. Paragraphs inside tables are
  included. Empty paragraphs (no text and not a heading) are omitted.
Example:
  (map paragraph-text (document-paragraphs doc)) => (\"Title\" \"Body text\")"
      (vector-ref doc 1))

    (define (document-text doc)
      "Syntax: (document-text doc)
Library: (scm ooxml word-reader)
Description: Returns the whole document body as a single string, with paragraph
  texts joined by newlines.
Example:
  (document-text doc) => \"Title\\nBody text\""
      (string-join (map paragraph-text (vector-ref doc 1)) "\n"))

    (define (document-headings doc)
      "Syntax: (document-headings doc)
Library: (scm ooxml word-reader)
Description: Returns only the heading paragraph records (those with a heading
  level), in document order.
Example:
  (map paragraph-text (document-headings doc)) => (\"Chapter 1\" \"Section 1.1\")"
      (filter (lambda (p) (paragraph-heading-level p)) (vector-ref doc 1)))

    (define (paragraph-text p)
      "Syntax: (paragraph-text p)
Library: (scm ooxml word-reader)
Description: Returns the text of a paragraph record (all runs concatenated).
Example:
  (paragraph-text p) => \"Hello world\""
      (cdr (assoc "text" p)))

    (define (paragraph-style p)
      "Syntax: (paragraph-style p)
Library: (scm ooxml word-reader)
Description: Returns the paragraph's style name (e.g. \"Heading1\", \"Normal\"),
  or #f if the paragraph has no explicit style.
Example:
  (paragraph-style p) => \"Heading1\""
      (cdr (assoc "style" p)))

    (define (paragraph-heading-level p)
      "Syntax: (paragraph-heading-level p)
Library: (scm ooxml word-reader)
Description: Returns the heading level (1..n) of a heading paragraph, or #f if
  the paragraph is not a heading. The level comes from a Heading<n> style or,
  failing that, from the paragraph's outline level.
Example:
  (paragraph-heading-level p) => 1"
      (cdr (assoc "level" p)))

    (define (paragraph-in-table? p)
      "Syntax: (paragraph-in-table? p)
Library: (scm ooxml word-reader)
Description: Returns #t if the paragraph was extracted from a table cell.
Example:
  (paragraph-in-table? p) => #f"
      (cdr (assoc "in-table" p)))
))
