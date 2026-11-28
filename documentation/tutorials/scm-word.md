---
title: (scm ooxml word) and friends: Word and OpenDocument texts
part: libraries
order: 1021
libraries: (scm ooxml word) (scm ooxml word-reader) (scm odf writer) (scm ooxml docprops)
summary: Writing .docx documents with headings, styled runs, paragraph styles, headers and page numbers, a table of contents; generating letters from data; reading the text and structure of Word files; OpenDocument .odt with the same API.
---
# (scm ooxml word) and friends: Word and OpenDocument texts

- `(scm ooxml word)` writes `.docx` documents;
- `(scm ooxml word-reader)` reads their text and structure;
- `(scm odf writer)` writes OpenDocument `.odt` with the same procedures.

```scheme
(import (scheme base) (scheme cxr) (scheme write) (srfi 1)
        (scm fs) (scm ooxml word) (scm ooxml word-reader))

(define dir (mktempdir '(prefix . "docx")))
(define (at name) (join-path dir name))
```

## A document

A document is a list of paragraphs; a paragraph holds *runs*, pieces of
text with their own formatting:

```scheme
(define doc (make-document))
(document-add-heading! doc 1 "Offer 2025-17")

(define p (document-add-paragraph! doc))
(paragraph-add-run! p "Dear Ada, we are pleased to offer ")
(paragraph-add-run! p "12 kg of Sencha" bold)
(paragraph-add-run! p " at ")
(paragraph-add-run! p "CHF 4.20 per kg" bold color: 'darkgreen)
(paragraph-add-run! p ".")

(document-save doc (at "offer.docx"))
(file-exists? (at "offer.docx"))           ;; => #t
```

`paragraph-add-run!` takes the flags `bold`, `italic` and `underline` and
the settings `font:`, `size:` (points) and `color:`, written without
quotes as in the example. Headings use Word's built-in heading styles, so
they appear in Word's navigation pane and its table of contents.

## Styles

Define a paragraph style once and use it by name:

```scheme
(document-define-style! doc "Small print" font: "Arial" size: 8 italic color: 'gray spacing-before: 12)
(document-add-heading! doc 2 "Terms")
(paragraph-add-run! (document-add-paragraph! doc "Small print") "Valid for 30 days. Prices without VAT.")
(document-save doc (at "offer.docx"))
```

Built-in style names (`"Heading1"`, `"Title"`, `"Quote"` …) work too.
Alignment, indentation, spacing and tab stops can also be set per
paragraph: `paragraph-set-alignment!`, `paragraph-set-indent!`,
`paragraph-set-spacing!`, `paragraph-set-tab-stops!`.

## Headers, footers, page numbers, contents

```scheme no-test
(let ((h (document-add-paragraph! doc)))
  (paragraph-set-alignment! h 'right)
  (paragraph-add-run! h "Teashop · Offer 2025-17" italic size: 8)
  (document-set-header! doc h))

(let ((f (document-add-paragraph! doc)))
  (paragraph-set-alignment! f 'center)
  (paragraph-add-run! f "Page ")
  (paragraph-add-page-number! f)
  (document-set-footer! doc f))

(document-add-table-of-contents! doc "Contents" 2)
(document-add-page-break! doc)
(paragraph-add-image! (document-add-paragraph! doc) "chart.png" 400 300)
```

Page numbers and the table of contents are *fields*: Word fills them in
when it shows or prints the document. `document-set-page-size!` switches
to landscape or another paper size.

## Example: letters from data

One document per customer, from a template procedure:

```scheme
(define customers
  '(("Ada Lovelace" "ada" ("Sencha" "Matcha"))
    ("Alan Turing" "alan" ("Assam"))))

(define (letter name teas)
  (let ((doc (make-document)))
    (document-set-properties! doc `((title . ,(string-append "Letter to " name)) (creator . "Teashop")))
    (document-add-heading! doc 1 "Your new teas")
    (paragraph-add-run! (document-add-paragraph! doc) (string-append "Dear " name ","))
    (paragraph-add-run! (document-add-paragraph! doc) "the following teas have arrived:")
    (for-each (lambda (tea)
                (let ((item (document-add-paragraph! doc "ListBullet")))
                  (paragraph-add-run! item tea bold)))
              teas)
    doc))

(for-each (lambda (c)
            (document-save (letter (car c) (caddr c))
                           (at (string-append "letter-" (cadr c) ".docx"))))
          customers)
(map file-exists? (list (at "letter-ada.docx") (at "letter-alan.docx"))) ;; => (#t #t)
```

`document-save-to-bytevector` gives the file as bytes, to attach it to an
e-mail or send it as a download.

## Document properties

`document-set-properties!` (and `workbook-set-properties!` for Excel)
sets what Word and Excel show under File › Info, and what search tools
and document management index: title, subject, creator, keywords,
description, category, and custom properties of your own, such as a
classification:

```scheme
(import (scm zip) (scm ooxml docprops))
(define (string-prefix-of? prefix s)
  (and (<= (string-length prefix) (string-length s)) (string=? prefix (substring s 0 (string-length prefix)))))

(define memo (make-document))
(paragraph-add-run! (document-add-paragraph! memo) "Prices for 2026.")
(define props '((title . "Price list 2026") (category . "Internal")
                (custom . (("Classification" . "Internal") ("Department" . "Purchasing")))))
(docprops-valid? props)                     ;; => #t
(document-set-properties! memo props)
(document-save memo (at "memo.docx"))

(define z (open-input-zip-file (at "memo.docx")))
(filter (lambda (n) (string-prefix-of? "docProps/" n)) (zip-entry-names z))
;; => ("docProps/core.xml" "docProps/app.xml" "docProps/custom.xml")
(close-input-zip z)
```

`(scm ooxml docprops)` writes these parts for both formats. A property
list it does not accept (`docprops-valid?` is `#f`, for example an
unknown key) is refused by `document-set-properties!` with an error.

## Reading

`(scm ooxml word-reader)` gives the text and the structure of a document,
for indexing, checking or converting:

```scheme
(define d (read-document (at "offer.docx")))
(document-text d)
;; => "Offer 2025-17\nDear Ada, we are pleased to offer 12 kg of Sencha at CHF 4.20 per kg.\nTerms\nValid for 30 days. Prices without VAT."
(map paragraph-text (document-headings d))  ;; => ("Offer 2025-17" "Terms")
(map paragraph-heading-level (document-headings d)) ;; => (1 2)
(map paragraph-style (document-paragraphs d)) ;; => ("Heading1" #f "Heading2" "Smallprint")
```

`paragraph-style` is the style's id, which Word derives from the name
without its spaces: `"Small print"` becomes `"Smallprint"`, as Word's own
"heading 1" is `"Heading1"`.

An outline of any Word file:

```scheme
(define (outline path)
  (map (lambda (h)
         (string-append (make-string (* 2 (- (paragraph-heading-level h) 1)) #\space)
                        (paragraph-text h)))
       (document-headings (read-document path))))

(outline (at "offer.docx"))                 ;; => ("Offer 2025-17" "  Terms")
```

`paragraph-in-table?` tells paragraphs in tables apart;
`read-document-from-bytevector` reads an upload.

## OpenDocument texts

`(scm odf writer)` mirrors the Word writer for LibreOffice's `.odt`
format; with a prefix, both can be used side by side:

```scheme
(import (prefix (scm odf writer) odt:))

(define o (odt:make-document))
(odt:document-add-heading! o 1 "Offer 2025-17")
(odt:paragraph-add-run! (odt:document-add-paragraph! o) "12 kg of Sencha" bold)
(odt:document-save o (at "offer.odt"))
(file-exists? (at "offer.odt"))             ;; => #t

(rm dir 'recursive)
```

## Where next

- [Spreadsheets](scm-excel.md), [presentations](scm-presentation.md),
  [PDF](scm-pdf.md); `(scm markdown)` for writing documents as Markdown.
- Reference: `(scm ooxml word)`, `(scm ooxml word-reader)`, `(scm odf writer)`.
