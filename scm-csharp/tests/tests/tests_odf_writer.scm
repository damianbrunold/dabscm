(import (scheme base)
        (scheme file)
        (scm test)
        (scm fs)
        (scm odf writer)
        (scm zip))

(test-runner-factory scm-test-runner)

(test-begin "odf_writer")

;; resolve-color: named colors
(test-group "resolve-color-named"
  (test-equal "FF000000" (resolve-color 'black))
  (test-equal "FFFF0000" (resolve-color 'red))
  (test-equal "FFADD8E6" (resolve-color 'lightblue)))

;; resolve-color: string passthrough
(test-group "resolve-color-string"
  (test-equal "FFAABBCC" (resolve-color "FFAABBCC")))

;; register-color!
(test-group "register-color"
  (register-color! 'test-coral "FFFF7F50")
  (test-equal "FFFF7F50" (resolve-color 'test-coral)))

;; make-document: creates a vector tagged 'doc
(test-group "make-document"
  (test-equal #t
    (let ((doc (make-document)))
      (vector? doc))))

;; document-add-paragraph!: returns a vector
(test-group "document-add-paragraph"
  (test-equal #t
    (let* ((doc (make-document))
           (p   (document-add-paragraph! doc)))
      (vector? p)))
  ;; second paragraph also a vector
  (test-equal #t
    (let* ((doc (make-document))
           (p1  (document-add-paragraph! doc))
           (p2  (document-add-paragraph! doc "Standard")))
      (and (vector? p1) (vector? p2)))))

;; paragraph-set-alignment! + document-save: returns 'ok
(test-group "paragraph-alignment-save"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-align.odt"))
           (doc  (make-document))
           (p    (document-add-paragraph! doc)))
      (paragraph-add-run! p "centered text")
      (paragraph-set-alignment! p 'center)
      (document-save doc path))))

;; paragraph-add-run!: bold + color + font + size, save returns 'ok
(test-group "paragraph-add-run-styles"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-run.odt"))
           (doc  (make-document))
           (p    (document-add-paragraph! doc)))
      (paragraph-add-run! p "plain text")
      (paragraph-add-run! p "bold red" bold color: 'red)
      (paragraph-add-run! p "arial 14" font: "Arial" size: 14)
      (paragraph-add-run! p "italic underline" italic underline)
      (document-save doc path))))

;; paragraph-add-tab! and paragraph-add-break!
(test-group "paragraph-tab-break"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-tab.odt"))
           (doc  (make-document))
           (p    (document-add-paragraph! doc)))
      (paragraph-add-run! p "col1")
      (paragraph-add-tab! p)
      (paragraph-add-run! p "col2")
      (paragraph-add-break! p)
      (paragraph-add-run! p "next line")
      (document-save doc path))))

;; paragraph-set-spacing! and paragraph-set-indent!
(test-group "paragraph-spacing-indent"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-spacing.odt"))
           (doc  (make-document))
           (p    (document-add-paragraph! doc)))
      (paragraph-add-run! p "indented spaced")
      (paragraph-set-spacing! p 12 6)
      (paragraph-set-indent! p 1.0)
      (document-save doc path))))

;; paragraph-set-tab-stops!
(test-group "paragraph-tab-stops"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-tabs.odt"))
           (doc  (make-document))
           (p    (document-add-paragraph! doc)))
      (paragraph-add-run! p "tabbed")
      (paragraph-set-tab-stops! p '((2.5 left) (5.0 center)))
      (document-save doc path))))

;; document-define-style!: define + use a named style, save returns 'ok
(test-group "document-define-style"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-style.odt"))
           (doc  (make-document)))
      (document-define-style! doc "My Heading"
        font: "Arial" size: 16 bold
        alignment: 'center
        spacing-before: 12 spacing-after: 6)
      (let ((p (document-add-paragraph! doc "My Heading")))
        (paragraph-add-run! p "Chapter One"))
      (document-save doc path))))

;; document-define-style! with based-on:
(test-group "document-define-style-based-on"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-style2.odt"))
           (doc  (make-document)))
      (document-define-style! doc "Body" based-on: "Standard" font: "Times New Roman" size: 12)
      (let ((p (document-add-paragraph! doc "Body")))
        (paragraph-add-run! p "Some body text."))
      (document-save doc path))))

;; call-with-document convenience wrapper
(test-group "call-with-document"
  (test-equal 'ok
    (let ((path (join-path (special-folder-temp) "test-scm-odf-writer-cwdoc.odt")))
      (call-with-document path
        (lambda (doc)
          (let ((p (document-add-paragraph! doc)))
            (paragraph-add-run! p "Hello from call-with-document")
            (paragraph-add-run! p " bold" bold)))))))

;; make-run-style and paragraph-add-styled-run!
(test-group "run-style"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-rs.odt"))
           (doc  (make-document))
           (p    (document-add-paragraph! doc))
           (rs   (make-run-style)))
      (rs 'set-bold #t)
      (rs 'set-color (resolve-color 'blue))
      (rs 'set-font-size 14)
      (paragraph-add-styled-run! p "styled run" rs)
      (paragraph-add-styled-run! p " plain" #f)
      (document-save doc path))))

;; paragraph-add-image!: embed a temp file, save returns 'ok
(test-group "paragraph-add-image"
  (test-equal 'ok
    (let* ((img-path (join-path (special-folder-temp) "test-scm-odf-writer-img.png"))
           (doc-path (join-path (special-folder-temp) "test-scm-odf-writer-img.odt")))
      ;; Write minimal PNG signature bytes to temp file
      (let ((p (open-binary-output-file img-path)))
        (write-bytevector #u8(137 80 78 71 13 10 26 10
                              0 0 0 0 73 69 78 68 174 66 96 130)
                          p)
        (close-output-port p))
      (let* ((doc (make-document))
             (p   (document-add-paragraph! doc)))
        (paragraph-add-run! p "Image below:")
        (paragraph-add-image! p img-path 100 50)
        (document-save doc doc-path)))))

;; document-save-to-bytevector: returns a non-empty bytevector
(test-group "document-save-to-bytevector"
  (test-equal #t
    (let* ((doc (make-document))
           (p   (document-add-paragraph! doc)))
      (paragraph-add-run! p "Hello, in-memory!")
      (let ((bv (document-save-to-bytevector doc)))
        (and (bytevector? bv) (> (bytevector-length bv) 0))))))

;; document-save-to-bytevector: ZIP magic bytes at offset 0
(test-group "document-save-to-bytevector-zip-magic"
  (test-equal #t
    (let* ((doc (make-document))
           (p   (document-add-paragraph! doc)))
      (paragraph-add-run! p "zip magic test")
      (let ((bv (document-save-to-bytevector doc)))
        (and (= (bytevector-u8-ref bv 0) #x50)   ; P
             (= (bytevector-u8-ref bv 1) #x4B)   ; K
             (= (bytevector-u8-ref bv 2) #x03)
             (= (bytevector-u8-ref bv 3) #x04))))))

;; mimetype entry content is correct
(test-group "mimetype"
  (test-equal "application/vnd.oasis.opendocument.text"
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-writer-mime.odt"))
           (doc (make-document))
           (p   (document-add-paragraph! doc)))
      (paragraph-add-run! p "test")
      (document-save doc path)
      (call-with-input-zip path
        (lambda (z)
          (utf8->string (zip-read-entry-bytevector z "mimetype")))))))

;; document-add-heading!: creates heading paragraphs and saves
(test-group "document-add-heading"
  (test-equal #t
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-heading.odt"))
           (doc (make-document))
           (h1 (document-add-heading! doc 1 "Chapter One"))
           (p  (document-add-paragraph! doc))
           (h2 (document-add-heading! doc 2 "Section")))
      (paragraph-add-run! p "body text")
      (and (vector? h1) (vector? h2)
           (eq? (document-save doc path) 'ok)))))

;; document-add-table-of-contents!: saves successfully
(test-group "document-add-table-of-contents"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-toc.odt"))
           (doc (make-document)))
      (document-add-table-of-contents! doc)
      (document-add-heading! doc 1 "Introduction")
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "body"))
      (document-add-heading! doc 1 "Conclusion")
      (document-save doc path))))

;; paragraph-add-index-entry! + document-add-index!: saves
(test-group "index-entry"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-index.odt"))
           (doc (make-document))
           (p   (document-add-paragraph! doc)))
      (paragraph-add-run! p "Some text about cats")
      (paragraph-add-index-entry! p "cats")
      (document-add-index! doc)
      (document-save doc path))))

;; combined headings, TOC, index entries, and index block
(test-group "combined-headings-toc-index"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-combined.odt"))
           (doc (make-document)))
      (document-add-table-of-contents! doc "Contents" 2)
      (document-add-heading! doc 1 "Animals")
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Cats are great")
        (paragraph-add-index-entry! p "cats"))
      (document-add-heading! doc 2 "Dogs")
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Dogs too")
        (paragraph-add-index-entry! p "dogs"))
      (document-add-index! doc "Alphabetical Index")
      (document-save doc path))))

;; page break between sections
(test-group "page-break"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-pagebreak.odt"))
           (doc (make-document)))
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Page one"))
      (document-add-page-break! doc)
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Page two"))
      (document-save doc path))))

;; header and footer with page number
(test-group "header-footer"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-hdrftr.odt"))
           (doc (make-document)))
      (let ((h (document-add-paragraph! doc)))
        (paragraph-set-alignment! h 'right)
        (paragraph-add-run! h "My Document" italic size: 8)
        (document-set-header! doc h))
      (let ((f (document-add-paragraph! doc)))
        (paragraph-set-alignment! f 'center)
        (paragraph-add-page-number! f)
        (document-set-footer! doc f))
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Body text"))
      (document-save doc path))))

(test-end "odf_writer")
