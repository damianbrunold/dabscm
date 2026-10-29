;; (scm fonts) — fonts by family name, from font files: the dabscm-fonts
;; package (Inter, Roboto, Roboto Slab, Source Serif 4, JetBrains Mono,
;; Noto Sans and Serif, Carlito, IBM Plex) or any directory of .ttf files.
;;
;; The fonts are looked up along a search path of directories and zip
;; files. Each holds .ttf files (at its top or one directory down) and,
;; optionally, an index, fonts-index.scm, that lists them, so they need
;; not be opened to be found: a list of entries
;;
;;   ((family . "Inter") (weight . 400) (italic . #f)
;;    (file . "inter/Inter-Regular.ttf") (license . "inter/LICENSE.txt"))
;;
;; Without an index every .ttf is opened once and asked (truetype-info).
;; The default path: the directories in SCM_FONT_PATH (separated by ":",
;; ";" on Windows), then the user's (~/.local/share/dabscm/fonts, or
;; <application data>/dabscm/fonts on Windows), then
;; /usr/local/share/dabscm/fonts and /usr/share/dabscm/fonts, where the
;; dabscm-fonts package installs them; a zip of the package
;; (dabscm-fonts-<version>.zip) works anywhere on the path.
;;
;; A face is chosen as CSS chooses one: the style first (italic, else
;; the upright face), then the weight nearest the one asked for. Faces
;; are read once per process and options.
;;
;; The built-in fonts of (scm fonts dejavu) and (scm fonts inter) need no
;; files; this library is for everything else.

(define-library (scm fonts)
  (export font-search-path
          font-search-path!
          font-families
          font-faces
          find-font
          find-font-file
          font-license)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme file)
          (scheme read)
          (scheme process-context)
          (scm fs)
          (scm string)
          (only (scm system) sys-platform)
          (scm zip)
          (scm truetype))
  (begin

    ;; --- search path ----------------------------------------------------

    (define (windows?) (eq? (sys-platform) 'windows))

    (define (default-search-path)
      (let* ((env (get-environment-variable "SCM_FONT_PATH"))
             (from-env (if (and env (not (string=? env "")))
                           (filter-list (lambda (s) (not (string=? s "")))
                                        (string-split-char env (if (windows?) #\; #\:)))
                           '()))
             (home (get-environment-variable "HOME"))
             (data-home (get-environment-variable "XDG_DATA_HOME")))
        (append
         from-env
         (if (windows?)
             (list (join-path (special-folder-application-data) "dabscm" "fonts"))
             (append
              (cond ((and data-home (not (string=? data-home "")))
                     (list (join-path data-home "dabscm" "fonts")))
                    (home (list (join-path home ".local" "share" "dabscm" "fonts")))
                    (else '()))
              (list "/usr/local/share/dabscm/fonts" "/usr/share/dabscm/fonts"))))))

    ;; The path, the faces found along it (#f until first asked for) and
    ;; the fonts read. Each is replaced as a whole, never changed in
    ;; place, so threads that look fonts up at the same time see a
    ;; consistent value (at worst one reads a font twice).
    (define search-path #f)
    (define faces-cache #f)
    (define fonts-cache '())

    (define (font-search-path)
      "Syntax: (font-search-path)
Library: (scm fonts)
Description: The directories and zip files fonts are looked up in, in
  order.
Example:
  (font-search-path) => (\"/home/me/.local/share/dabscm/fonts\" \"/usr/local/share/dabscm/fonts\" \"/usr/share/dabscm/fonts\")"
      (unless search-path (set! search-path (default-search-path)))
      search-path)

    (define (font-search-path! paths)
      "Syntax: (font-search-path! paths)
Library: (scm fonts)
Description: Sets the directories and zip files fonts are looked up in
  (a list of paths), and forgets the fonts found so far.
Example:
  (font-search-path! (cons \"/srv/app/fonts\" (font-search-path)))"
      (set! search-path paths)
      (set! faces-cache #f)
      (set! fonts-cache '()))

    ;; --- finding the faces ----------------------------------------------

    ;; A face: family, weight, italic?, where (directory or zip) and the
    ;; file and licence (relative names, the licence #f when unknown).
    (define-record-type face
      (make-face family weight italic? source zip? file license)
      face?
      (family face-family)
      (weight face-weight)
      (italic? face-italic?)
      (source face-source)
      (zip? face-zip?)
      (file face-file)
      (license face-license))

    (define (zip-path? p)
      (let ((n (string-length p)))
        (and (> n 4) (string-ci=? (substring p (- n 4) n) ".zip"))))

    (define (ttf-name? n)
      (let ((l (string-length n)))
        (and (> l 4) (string-ci=? (substring n (- l 4) l) ".ttf"))))

    (define (read-file path)
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let ((bv (read-bytevector (max 1 (file-size path)) p)))
            (if (eof-object? bv) (bytevector) bv)))))

    ;; The bytes of file in source.
    (define (source-bytes source zip? file)
      (if zip?
          (call-with-input-zip source (lambda (z) (zip-read-entry-bytevector z file)))
          (read-file (join-path source file))))

    (define (index->faces source zip? entries)
      (map (lambda (e)
             (let ((get (lambda (k d) (let ((p (assq k e))) (if p (cdr p) d)))))
               (make-face (get 'family "") (get 'weight 400) (get 'italic #f)
                          source zip? (get 'file "") (get 'license #f))))
           entries))

    ;; A licence beside a font: a file in the same directory whose name
    ;; says so.
    (define (license-near names file)
      (let ((dir (directory-part file)))
        (let loop ((ns names))
          (cond ((null? ns) #f)
                ((and (string=? (directory-part (car ns)) dir)
                      (let ((b (string-upcase (base-part (car ns)))))
                        (or (string-prefix? "LICENSE" b) (string-prefix? "OFL" b)
                            (string-prefix? "COPYING" b))))
                 (car ns))
                (else (loop (cdr ns)))))))

    (define (directory-part name)
      (let loop ((i (- (string-length name) 1)))
        (cond ((< i 0) "")
              ((char=? (string-ref name i) #\/) (substring name 0 i))
              (else (loop (- i 1))))))

    (define (base-part name)
      (let ((d (directory-part name)))
        (if (string=? d "") name (substring name (+ (string-length d) 1) (string-length name)))))

    (define (string-prefix? p s)
      (and (>= (string-length s) (string-length p))
           (string=? (substring s 0 (string-length p)) p)))

    ;; Opens each font of names (relative, "/"-separated) and asks it.
    (define (scan->faces source zip? names read-bytes)
      (filter-map-list
       (lambda (n)
         (and (ttf-name? n)
              (guard (e (#t #f))           ; not a TrueType font: skip it
                (let ((info (truetype-info (read-bytes n))))
                  (make-face (cdr (assq 'family info)) (cdr (assq 'weight info))
                             (cdr (assq 'italic info)) source zip? n
                             (license-near names n))))))
       names))

    (define (read-index bv)
      (read (open-input-string (utf8->string bv))))

    (define (directory-faces dir)
      (let ((index (join-path dir "fonts-index.scm")))
        (if (file-exists? index)
            (index->faces dir #f (read-index (read-file index)))
            (let ((names (append
                          (directory-files dir)
                          (apply append
                                 (map (lambda (sub)
                                        (map (lambda (f) (string-append sub "/" f))
                                             (directory-files (join-path dir sub))))
                                      (directory-directories dir))))))
              (scan->faces dir #f names (lambda (n) (read-file (join-path dir n))))))))

    (define (zip-faces path)
      (call-with-input-zip path
        (lambda (z)
          (let ((names (zip-entry-names z)))
            (if (member "fonts-index.scm" names)
                (index->faces path #t (read-index (zip-read-entry-bytevector z "fonts-index.scm")))
                (scan->faces path #t names (lambda (n) (zip-read-entry-bytevector z n))))))))

    ;; Every face along the path, in path order.
    (define (all-faces)
      (or faces-cache
          (let ((faces (apply append
                              (map (lambda (p)
                                     (cond ((and (zip-path? p) (file-exists? p)) (zip-faces p))
                                           ((directory-exists? p) (directory-faces p))
                                           (else '())))
                                   (font-search-path)))))
            (set! faces-cache faces)
            faces)))

    (define (family-faces family)
      (filter-map-list (lambda (f) (and (string-ci=? (face-family f) family) f))
                       (all-faces)))

    (define (font-families)
      "Syntax: (font-families)
Library: (scm fonts)
Description: The names of the font families found along the search
  path, sorted.
Example:
  (font-families) => (\"IBM Plex Mono\" \"IBM Plex Sans\" \"Inter\" \"JetBrains Mono\" ...)"
      (sort-strings
       (let loop ((fs (all-faces)) (acc '()))
         (cond ((null? fs) acc)
               ((member (face-family (car fs)) acc) (loop (cdr fs) acc))
               (else (loop (cdr fs) (cons (face-family (car fs)) acc)))))))

    (define (font-faces family)
      "Syntax: (font-faces family)
Library: (scm fonts)
Description: The faces of family as (weight italic?) lists, upright
  before italic, lighter first; () when the family is not found.
Example:
  (font-faces \"JetBrains Mono\") => ((400 #f) (700 #f) (400 #t) (700 #t))"
      (let ((fs (map (lambda (f) (list (face-weight f) (face-italic? f))) (family-faces family))))
        (let sort ((xs fs) (out '()))
          (if (null? xs)
              out
              (sort (cdr xs)
                    (let ins ((ys out))
                      (cond ((null? ys) (list (car xs)))
                            ((equal? (car xs) (car ys)) ys)
                            ((face<? (car xs) (car ys)) (cons (car xs) ys))
                            (else (cons (car ys) (ins (cdr ys)))))))))))

    (define (face<? a b)
      (cond ((and (not (cadr a)) (cadr b)) #t)
            ((and (cadr a) (not (cadr b))) #f)
            (else (< (car a) (car b)))))

    ;; --- choosing a face --------------------------------------------------

    (define weight-names
      '((thin . 100) (extra-light . 200) (light . 300) (regular . 400) (normal . 400)
        (medium . 500) (semi-bold . 600) (bold . 700) (extra-bold . 800) (black . 900)))

    (define (weight-value w)
      (cond ((and (integer? w) (exact? w)) w)
            ((and (symbol? w) (assq w weight-names)) => cdr)
            (else (error "find-font: not a weight" w))))

    ;; CSS's order for weights: the weight itself; for 400 then 500; for
    ;; 500 then 400; then, below 400 lighter before heavier, above 500
    ;; heavier before lighter, each nearest first.
    (define (weight-rank wanted w)
      (cond ((= w wanted) 0)
            ((and (= wanted 400) (= w 500)) 1)
            ((and (= wanted 500) (= w 400)) 1)
            ((<= wanted 500)
             (if (< w wanted) (+ 2 (- wanted w)) (+ 1000 (- w wanted))))
            (else
             (if (> w wanted) (+ 2 (- w wanted)) (+ 1000 (- wanted w))))))

    (define (choose family weight italic?)
      (let* ((faces (family-faces family))
             (styled (let ((same (filter-map-list (lambda (f) (and (eq? (face-italic? f) italic?) f)) faces)))
                       (if (null? same) faces same))))
        (and (pair? styled)
             (let loop ((fs (cdr styled)) (best (car styled)))
               (cond ((null? fs) best)
                     ((< (weight-rank weight (face-weight (car fs)))
                         (weight-rank weight (face-weight best)))
                      (loop (cdr fs) (car fs)))
                     (else (loop (cdr fs) best)))))))

    (define (parse-args who args)
      ;; [weight [style [options]]] -> (weight italic? options)
      (let* ((weight (if (pair? args) (weight-value (car args)) 400))
             (style (if (and (pair? args) (pair? (cdr args))) (cadr args) 'normal))
             (options (if (and (pair? args) (pair? (cdr args)) (pair? (cddr args))) (caddr args) '())))
        (unless (memq style '(normal italic))
          (error (string-append (symbol->string who) ": style is normal or italic") style))
        (list weight (eq? style 'italic) options)))

    (define (find-font family . args)
      "Syntax: (find-font family [weight [style [options]]])
Library: (scm fonts)
Description: The font (see (scm truetype)) of family nearest to weight
  (100 to 900, or thin, extra-light, light, regular, medium, semi-bold,
  bold, extra-bold, black; default 400) and style (normal or italic,
  default normal), or #f when the family is not found. options go to
  read-truetype, e.g. ((features \"tnum\")). Fonts are read once.
Example:
  (find-font \"JetBrains Mono\" 'bold 'italic)
  (find-font \"Inter\" 400 'normal '((features \"tnum\")))"
      (let* ((a (parse-args 'find-font args))
             (f (choose family (car a) (cadr a))))
        (and f
             (let* ((key (list (face-source f) (face-file f) (caddr a)))
                    (hit (assoc key fonts-cache)))
               (if hit
                   (cdr hit)
                   (let ((font (read-truetype (source-bytes (face-source f) (face-zip? f) (face-file f))
                                              (caddr a))))
                     (set! fonts-cache (cons (cons key font) fonts-cache))
                     font))))))

    (define (find-font-file family . args)
      "Syntax: (find-font-file family [weight [style]])
Library: (scm fonts)
Description: The TrueType file (bytevector) of the face find-font
  would choose, or #f: for embedding the font as it is, e.g. with
  pdf-embed-truetype-font (which subsets it).
Example:
  (pdf-embed-truetype-font doc (find-font-file \"Roboto\" 'bold) \"Roboto-Bold\")"
      (let* ((a (parse-args 'find-font-file args))
             (f (choose family (car a) (cadr a))))
        (and f (source-bytes (face-source f) (face-zip? f) (face-file f)))))

    (define (font-license family)
      "Syntax: (font-license family)
Library: (scm fonts)
Description: The licence text of family's fonts, or #f when the family
  is not found or no licence file is beside its fonts.
Example:
  (font-license \"JetBrains Mono\") => \"Copyright 2020 The JetBrains Mono Project Authors ...\""
      (let ((f (let loop ((fs (family-faces family)))
                 (cond ((null? fs) #f)
                       ((face-license (car fs)) (car fs))
                       (else (loop (cdr fs)))))))
        (and f (utf8->string (source-bytes (face-source f) (face-zip? f) (face-license f))))))

    ;; --- helpers ----------------------------------------------------------

    (define (filter-list keep? l)
      (let loop ((l l) (acc '()))
        (cond ((null? l) (reverse acc))
              ((keep? (car l)) (loop (cdr l) (cons (car l) acc)))
              (else (loop (cdr l) acc)))))

    (define (filter-map-list f l)
      (let loop ((l l) (acc '()))
        (if (null? l)
            (reverse acc)
            (let ((v (f (car l)))) (loop (cdr l) (if v (cons v acc) acc))))))

    (define (sort-strings l)
      (let loop ((l l) (out '()))
        (if (null? l)
            out
            (loop (cdr l)
                  (let ins ((ys out))
                    (cond ((null? ys) (list (car l)))
                          ((string<? (car l) (car ys)) (cons (car l) ys))
                          (else (cons (car ys) (ins (cdr ys))))))))))))
