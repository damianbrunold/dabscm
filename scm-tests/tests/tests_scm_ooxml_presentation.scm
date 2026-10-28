;; Tests for (scm ooxml presentation): the package's parts are there,
;; well-formed and wired together. (Opening the files in PowerPoint or
;; LibreOffice is the real check: soffice --headless --convert-to pdf.)

(import (scheme base)
        (scheme file)
        (scm test)
        (scm fs)
        (scm string)
        (scm zip)
        (scm xml)
        (scm png)
        (scm ooxml presentation))

(test-runner-factory scm-test-runner)
(test-begin "scm ooxml presentation")

(define dir (mktempdir '(prefix . "pptx-test")))
(define file (string-append dir "/t.pptx"))
(define png (png-encode-rgb 1 1 (bytevector 0 112 180)))
(define png-file (string-append dir "/p.png"))
(let ((p (open-binary-output-file png-file))) (write-bytevector png p) (close-port p))

(define p (make-presentation))
(presentation-set-title! p "Probe & Test")

(define s1 (presentation-add-slide! p))
(slide-set-background! s1 "F0F0F0")
(define title-id
  (slide-add-shape! s1 'text 0 0 9144000 914400
    '((text . (((align . center)
                (runs . (((text . "<Titel>\nzweite Zeile") (size . 40) (bold . #t) (color . "0070B4")))))
               ((bullet . "–") (margin-left . 342900) (indent . -342900)
                (runs . (((text . "zh.ch") (link . "https://www.zh.ch/?a=1&b=2")))))))
      (anchor . middle)
      (build . (1 fade)))))
(slide-add-shape! s1 'arrow 0 1000000 2000000 1000000 '((fill . "D93C1A") (fill-alpha . 0.5) (rotation . -30)
                                                         (build . (2 fly-left))))
(slide-add-line! s1 0 2000000 3000000 0 '((color . "000000") (width . 12700) (flip . #t)))
(slide-add-picture! s1 png "image/png" 0 3000000 1000000 1000000 '((key . "blue") (description . "Blau")))
(slide-set-notes! s1 '(((runs . (((text . "Eine Notiz")))))))

(define s2 (presentation-add-slide! p))
(slide-set-transition! s2 'fade 300)
;; the same image again (same key): stored once; a file source too
(slide-add-picture! s2 png "image/png" 0 0 1000000 1000000 '((key . "blue") (crop . (0.1 0 0.1 0)) (alpha . 0.4)))
(slide-add-picture! s2 png-file "image/png" 0 0 1000000 1000000)
(slide-add-video! s2 png-file png "image/png" 0 0 1000000 1000000 '((poster-key . "blue")))

(presentation-save p file)

(define (part z name) (utf8->string (zip-read-entry-bytevector z name)))
(define (has? s x) (and (string-contains-from s x 0) #t))
(define (well-formed? bv)
  (guard (e (#t #f))
    (let ((r (open-xml-bytevector bv)))
      (let loop () (when (xml-read r) (loop)))
      (close-xml r)
      #t)))

(define (filter-media names)
  (let loop ((ns names) (acc '()))
    (cond ((null? ns) (reverse acc))
          ((and (>= (string-length (car ns)) 10) (string=? (substring (car ns) 0 10) "ppt/media/"))
           (loop (cdr ns) (cons (car ns) acc)))
          (else (loop (cdr ns) acc)))))

(define (string-suffix? suffix s)
  (and (>= (string-length s) (string-length suffix))
       (string=? (substring s (- (string-length s) (string-length suffix)) (string-length s)) suffix)))

(call-with-input-zip file
  (lambda (z)
    (let ((names (zip-entry-names z)))
      (test-group "parts"
        (for-each (lambda (n) (test-assert n (member n names)))
                  '("[Content_Types].xml" "_rels/.rels" "ppt/presentation.xml"
                    "ppt/_rels/presentation.xml.rels" "ppt/slides/slide1.xml" "ppt/slides/slide2.xml"
                    "ppt/slides/_rels/slide1.xml.rels" "ppt/notesSlides/notesSlide1.xml"
                    "ppt/slideMasters/slideMaster1.xml" "ppt/slideLayouts/slideLayout1.xml"
                    "ppt/notesMasters/notesMaster1.xml" "ppt/theme/theme1.xml" "docProps/core.xml"))
        ;; blue (twice, by key, and as the poster), the file, the video
        (test-equal 3 (length (filter-media names))))
      (test-group "every XML part is well-formed"
        (for-each (lambda (n)
                    (when (or (string-suffix? ".xml" n) (string-suffix? ".rels" n))
                      (test-assert n (well-formed? (zip-read-entry-bytevector z n)))))
                  names))
      (test-group "content"
        (let ((s1 (part z "ppt/slides/slide1.xml"))
              (s2 (part z "ppt/slides/slide2.xml"))
              (rels (part z "ppt/slides/_rels/slide1.xml.rels")))
          (test-assert (has? s1 "&lt;Titel&gt;"))
          (test-assert "line break" (has? s1 "<a:br>"))
          (test-assert (has? s1 "sz=\"4000\""))
          (test-assert (has? s1 "<a:buChar char=\"–\"/>"))
          (test-assert (has? s1 "anchor=\"ctr\""))
          (test-assert (has? s1 "rot=\"19800000\""))   ; -30 degrees
          (test-assert (has? s1 "<a:alpha val=\"50000\"/>"))
          (test-assert (has? s1 "flipV=\"1\""))
          (test-assert (has? s1 "descr=\"Blau\""))
          (test-assert "builds" (has? s1 "presetID=\"10\""))
          (test-assert (has? s1 "presetID=\"2\""))
          (test-assert (has? s1 (string-append "<p:bldP spid=\"" (number->string title-id) "\"")))
          (test-assert (has? rels "https://www.zh.ch/?a=1&amp;b=2"))
          (test-assert (has? rels "TargetMode=\"External\""))
          (test-assert (has? rels "notesSlide1.xml"))
          (test-assert (has? s2 "<p:fade/>"))
          (test-assert (has? s2 "spd=\"fast\""))
          (test-assert (has? s2 "<a:srcRect l=\"10000\""))
          (test-assert (has? s2 "<a:alphaModFix amt=\"40000\"/>"))
          (test-assert "video" (has? s2 "<a:videoFile"))
          (test-assert (has? (part z "ppt/notesSlides/notesSlide1.xml") "Eine Notiz"))
          (test-assert (has? (part z "docProps/core.xml") "Probe &amp; Test"))
          (test-assert (has? (part z "ppt/presentation.xml") "<p:sldId id=\"257\""))
          (test-equal png (zip-read-entry-bytevector z "ppt/media/media1.png")))))))

(test-assert "bytevector output" (> (bytevector-length (presentation->bytevector p)) 1000))

(delete-file file)
(delete-file png-file)
(delete-directory dir)

(test-end "scm ooxml presentation")
