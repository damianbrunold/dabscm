;; The dabscm-fonts package: the free fonts listed in fonts/manifest.scm,
;; for (scm fonts), as
;;   dist/dabscm-fonts_<version>_all.deb   installs /usr/share/dabscm/fonts
;;   dist/dabscm-fonts-<version>.zip       the same tree, for anywhere on
;;                                          the font search path (Windows,
;;                                          .NET deployments, containers)
;;
;;   ./builder.sh package-fonts.scm [--out <dir>]
;;
;; Downloads the files (once; they are kept in fonts/cache/), checks each
;; against its SHA-256 in the manifest, and lays them out one directory
;; per family with its licence, plus fonts-index.scm (the faces, so
;; (scm fonts) need not open every file) and README.md. The fonts are the
;; upstream files, unchanged. Pure Scheme: runs on Linux and Windows and
;; gives the same bytes for the same manifest.
;;
;; Installed layout:
;;   /usr/share/dabscm/fonts/fonts-index.scm, README.md
;;   /usr/share/dabscm/fonts/<family>/<files>.ttf, <licence>
;;   /usr/share/doc/dabscm-fonts/copyright

(import (scheme base)
        (scheme char)
        (scheme file)
        (scheme read)
        (scheme write)
        (scheme process-context)
        (srfi 1)
        (srfi 95)
        (scm crypto)
        (scm fs)
        (scm zip)
        (scm net http client)
        (scm net http response)
        (build tools)
        (build deb))

(define maintainer "Damian Brunold <damian.brunold@bluewin.ch>")

(define (say . parts)
  (for-each display parts)
  (newline))

(define (fail . parts)
  (apply say "package-fonts: " parts)
  (exit 1))

(define (repo . parts) (apply join-path base-dir parts))

(define (read-bytes path)
  (call-with-port (open-binary-input-file path)
    (lambda (in)
      (let ((out (open-output-bytevector)))
        (let loop ()
          (let ((chunk (read-bytevector 65536 in)))
            (unless (eof-object? chunk)
              (write-bytevector chunk out)
              (loop))))
        (get-output-bytevector out)))))

(define (write-bytes path bv)
  (call-with-port (open-binary-output-file path)
    (lambda (out) (write-bytevector bv out))))

;; --- arguments ---------------------------------------------------------------

(define out-dir (repo "dist"))

(let loop ((args (cdr (command-line))))
  (cond ((null? args))
        ((and (string=? (car args) "--out") (pair? (cdr args)))
         (set! out-dir (cadr args))
         (loop (cddr args)))
        (else
         (say "usage: package-fonts.scm [--out <dir>]")
         (exit 2))))

;; --- the manifest ------------------------------------------------------------

(define manifest
  (call-with-input-file (repo "fonts" "manifest.scm")
    (lambda (p)
      (let loop ((acc '()))
        (let ((x (read p)))
          (if (eof-object? x) (reverse acc) (loop (cons x acc))))))))

(define (forms tag) (filter (lambda (f) (eq? (car f) tag)) manifest))

(define version (cadr (car (forms 'version))))
(define archives (forms 'archive))      ; (archive name url sha)
(define families (forms 'family))       ; (family name dir . clauses)

(define (clauses fam tag) (filter (lambda (c) (eq? (car c) tag)) (cdddr fam)))

;; --- downloads -----------------------------------------------------------------

(define cache-dir (repo "fonts" "cache"))

(define (sha256-hex bv) (bytevector->hex (sha256-hash bv)))

(define (url-file-name url)
  ;; the cache name: the URL's path with "/" and ":" made safe
  (list->string (map (lambda (c) (if (memv c '(#\/ #\: #\? #\&)) #\_ c))
                     (string->list url))))

;; The bytes at url, checked against sha; from the cache when there.
(define (fetch url sha)
  (let ((cached (join-path cache-dir (url-file-name url))))
    (if (and (file-exists? cached) (string=? (sha256-hex (read-bytes cached)) sha))
        (read-bytes cached)
        (begin
          (say "  downloading " url)
          (let* ((r (http-get url '() 600))
                 (body (http-response-body r)))
            (unless (= (http-response-status r) 200)
              (fail url ": HTTP " (http-response-status r)))
            (let ((bv (if (string? body) (string->utf8 body) body)))
              (unless (string=? (sha256-hex bv) sha)
                (fail url ": SHA-256 " (sha256-hex bv) ", expected " sha))
              (unless (directory-exists? cache-dir) (make-directory cache-dir))
              (write-bytes cached bv)
              bv))))))

;; The cached path of a release archive, downloaded and checked.
(define (archive-path name)
  (let ((a (find (lambda (a) (eq? (cadr a) name)) archives)))
    (unless a (fail "unknown archive " name))
    (fetch (caddr a) (cadddr a))
    (join-path cache-dir (url-file-name (caddr a)))))

;; The bytes of a source, checked against sha.
(define (source-bytes source sha)
  (case (car source)
    ((url) (fetch (cadr source) sha))
    ((archive)
     (let ((bv (call-with-input-zip (archive-path (cadr source))
                 (lambda (z) (zip-read-entry-bytevector z (caddr source))))))
       (unless (string=? (sha256-hex bv) sha)
         (fail (caddr source) " in " (cadr source) ": SHA-256 " (sha256-hex bv) ", expected " sha))
       bv))
    (else (fail "unknown source " source))))

;; --- the tree --------------------------------------------------------------------

;; (relative-name . bytes) for every file of the package, and the index.
(define files '())
(define index '())

(define (add-file! name bv) (set! files (cons (cons name bv) files)))

(say "dabscm-fonts " version)
(for-each
 (lambda (fam)
   (let* ((name (cadr fam))
          (dir (caddr fam))
          (lic (car (clauses fam 'license)))
          (lic-file (string-append dir "/" (caddr lic))))
     (say "  " name)
     (add-file! lic-file (source-bytes (cadddr lic) (car (cddddr lic))))
     (for-each
      (lambda (face)                    ; (face weight italic? file source sha)
        (let ((file (string-append dir "/" (cadddr face))))
          (add-file! file (source-bytes (list-ref face 4) (list-ref face 5)))
          (set! index (cons `((family . ,name) (weight . ,(cadr face)) (italic . ,(caddr face))
                              (file . ,file) (license . ,lic-file))
                            index))))
      (clauses fam 'face))))
 families)
(set! index (reverse index))

(define index-text
  (let ((p (open-output-string)))
    (display ";; The faces of dabscm-fonts " p)
    (display version p)
    (display ", for (scm fonts). Generated by package-fonts.scm.\n(" p)
    (for-each (lambda (e) (newline p) (write e p)) index)
    (display ")\n" p)
    (get-output-string p)))

(define readme
  (apply string-append
         "# dabscm-fonts " version "\n\n"
         "Free fonts for dabscm's (scm fonts), unchanged from their projects'\n"
         "releases. Each family's directory holds its licence.\n\n"
         "| Family | Faces | Licence | Source |\n|---|---|---|---|\n"
         (map (lambda (fam)
                (string-append
                 "| " (cadr fam) " | "
                 (number->string (length (clauses fam 'face))) " | "
                 (cadr (car (clauses fam 'license))) " | "
                 (cadr (car (clauses fam 'source))) " |\n"))
              families)))

(add-file! "fonts-index.scm" (string->utf8 index-text))
(add-file! "README.md" (string->utf8 readme))
(set! files (sort files (lambda (a b) (string<? (car a) (car b)))))

;; --- write -----------------------------------------------------------------------

(unless (directory-exists? out-dir) (make-directory out-dir))

;; One timestamp for every entry, so the same manifest gives the same bytes:
;; 2026-01-01.
(define epoch 1767225600)

;; The zip. Fonts are stored compressed: TrueType files shrink by about half.
(let ((path (join-path out-dir (string-append "dabscm-fonts-" version ".zip"))))
  (when (file-exists? path) (delete-file path))
  (let ((z (open-output-zip-file path)))
    (for-each (lambda (f)
                (let ((port (zip-add-binary-entry z (car f) epoch)))
                  (write-bytevector (cdr f) port)
                  (flush-output-port port)))
              files)
    (close-output-zip z))
  (say path))

;; Words as description lines: indented by one space, at most 72 wide.
(define (wrap text)
  (let loop ((words (let split ((cs (string->list text)) (w '()) (acc '()))
                      (cond ((null? cs) (reverse (if (null? w) acc (cons (list->string (reverse w)) acc))))
                            ((char=? (car cs) #\space)
                             (split (cdr cs) '() (if (null? w) acc (cons (list->string (reverse w)) acc))))
                            (else (split (cdr cs) (cons (car cs) w) acc)))))
             (line "") (out ""))
    (cond ((null? words) (string-append out " " line "\n"))
          ((string=? line "") (loop (cdr words) (car words) out))
          ((> (+ (string-length line) 1 (string-length (car words))) 72)
           (loop (cdr words) (car words) (string-append out " " line "\n")))
          (else (loop (cdr words) (string-append line " " (car words)) out)))))

;; The licence's short name (SPDX) for the copyright file.
(define (license-short-name name)
  (cond ((string=? name "SIL Open Font License 1.1") "OFL-1.1")
        ((string=? name "Apache License 2.0") "Apache-2.0")
        (else name)))

;; The deb.
(define prefix "usr/share/dabscm/fonts/")

(define copyright
  (apply string-append
         "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/\n"
         "Upstream-Name: dabscm-fonts\n\n"
         (map (lambda (fam)
                (let ((lic (car (clauses fam 'license))))
                  (string-append
                   "Files: " prefix (caddr fam) "/*\n"
                   "Comment: " (cadr (car (clauses fam 'source))) "\n"
                   "License: " (license-short-name (cadr lic)) "\n"
                   " " (cadr lic) "; the full text is in " prefix (caddr fam) "/"
                   (caddr lic) "\n\n")))
              families)))

(define data
  (cons (list "usr/share/doc/dabscm-fonts/copyright" #o644 (string->utf8 copyright))
        (map (lambda (f) (list (string-append prefix (car f)) #o644 (cdr f))) files)))

(define installed-kib
  (+ (fold (lambda (e acc)
             (+ acc (quotient (+ (bytevector-length (entry-content e)) 1023) 1024)))
           0 data)
     (- (length (add-parent-dirs data)) (length data))))

(define control
  (string-append
    "Package: dabscm-fonts\n"
    "Version: " version "\n"
    "Architecture: all\n"
    "Maintainer: " maintainer "\n"
    "Installed-Size: " (number->string installed-kib) "\n"
    "Section: fonts\n"
    "Priority: optional\n"
    "Description: free fonts for dabscm's (scm fonts)\n"
    (wrap (string-append
           (fold (lambda (f acc) (string-append acc ", " (cadr f)))
                 (cadr (car families)) (cdr families))
           ", as their projects release them (TrueType), with their licences."))
    " Used by dabscm (Java and .NET) for text in PDFs, images and documents.\n"))

(define md5sums
  (apply string-append
    (map (lambda (e) (string-append (md5-hash (entry-content e)) "  " (entry-name e) "\n"))
         data)))

(let ((deb (join-path out-dir (string-append "dabscm-fonts_" version "_all.deb"))))
  (write-bytes deb (deb-bytevector (list (list "control" #o644 (string->utf8 control))
                                         (list "md5sums" #o644 (string->utf8 md5sums)))
                                   data epoch))
  (say deb " (" (length data) " files, " installed-kib " KiB installed)"))
