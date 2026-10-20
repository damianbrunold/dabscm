(define-library (scm geo shapefile)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (srfi 1)
          (srfi 13)
          (scm bytevector)
          (scm geo))
  (export read-shapefile
          shapefile->features
          dbf->records)
  (begin

    (define (read-file-bytevector path)
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let loop ((chunks '()))
            (let ((bv (read-bytevector 1048576 p)))
              (if (eof-object? bv)
                  (apply bytevector-append (reverse chunks))
                  (loop (cons bv chunks))))))))

    (define (sibling path ext)
      (let ((dot (string-index-right path #\.)))
        (string-append (if dot (substring path 0 dot) path) ext)))

    (define (read-shapefile path . encoding)
      "Syntax: (read-shapefile path [encoding])
Library: (scm geo shapefile)
Description: Reads the ESRI shapefile path (the .shp file) and its attribute
  table (the .dbf file next to it) and returns a list of features, in file
  order. Text attributes are decoded with encoding, the symbol utf-8 or
  latin-1; by default the one named in the .cpg file next to it, else utf-8.
  See shapefile->features for the geometry and attribute types.
Example:
  (map (lambda (f) (feature-ref f \"NAME\")) (read-shapefile \"cantons.shp\")) => (\"Zürich\" ...)"
      (let* ((cpg (sibling path ".cpg"))
             (enc (cond ((pair? encoding) (car encoding))
                        ((file-exists? cpg)
                         (let ((s (string-downcase
                                   (string-trim-both (utf8->string (read-file-bytevector cpg))))))
                           (if (member s '("utf-8" "utf8" "65001")) 'utf-8 'latin-1)))
                        (else 'utf-8)))
             (dbf (sibling path ".dbf")))
        (shapefile->features (read-file-bytevector path)
                             (and (file-exists? dbf) (read-file-bytevector dbf))
                             enc)))

    (define (shapefile->features shp dbf . encoding)
      "Syntax: (shapefile->features shp dbf [encoding])
Library: (scm geo shapefile)
Description: Returns the features of a shapefile given as bytevectors: shp the
  contents of the .shp file, dbf those of the .dbf file or #f. This reads a
  shapefile straight out of a ZIP archive. Polygons (types 5, 15, 25) become
  polygon geometries, polylines (3, 13, 23) polylines and points (1, 8, 11,
  18, 21, 28) multipoints; Z and M values are dropped. A null shape has the
  geometry #f. Attributes are as returned by dbf->records.
Example:
  (length (shapefile->features shp-bytes dbf-bytes 'utf-8)) => 26"
      (let ((records (if dbf (dbf->records dbf (if (pair? encoding) (car encoding) 'utf-8)) #f)))
        (let loop ((shapes (read-shapes shp)) (records records) (out '()))
          (if (null? shapes)
              (reverse out)
              (loop (cdr shapes)
                    (and (pair? records) (cdr records))
                    (cons (make-feature (if (pair? records) (car records) '()) (car shapes))
                          out))))))

    ;; --- .shp --------------------------------------------------------

    (define (read-shapes bv)
      (unless (and (>= (bytevector-length bv) 100) (= (bytevector-u32-ref bv 0 'big) 9994))
        (error "shapefile->features: not a shapefile"))
      (let ((n (min (bytevector-length bv) (* 2 (bytevector-u32-ref bv 24 'big)))))
        (let loop ((o 100) (out '()))
          (if (> (+ o 12) n)
              (reverse out)
              (let* ((len (* 2 (bytevector-u32-ref bv (+ o 4) 'big)))
                     (c (+ o 8)))
                (loop (+ c len) (cons (read-shape bv c) out)))))))

    (define (read-shape bv c)
      (let ((type (bytevector-s32-ref bv c 'little)))
        (case type
          ((0) #f)
          ((1 11 21)
           (make-multipoint (list (vector (bytevector-ieee-double-ref bv (+ c 4) 'little)
                                          (bytevector-ieee-double-ref bv (+ c 12) 'little)))))
          ((8 18 28)
           (let ((np (bytevector-s32-ref bv (+ c 36) 'little)))
             (make-multipoint
              (list-tabulate np (lambda (i)
                                  (let ((p (+ c 40 (* 16 i))))
                                    (vector (bytevector-ieee-double-ref bv p 'little)
                                            (bytevector-ieee-double-ref bv (+ p 8) 'little))))))))
          ((3 13 23 5 15 25)
           (let* ((nparts (bytevector-s32-ref bv (+ c 36) 'little))
                  (np (bytevector-s32-ref bv (+ c 40) 'little))
                  (p0 (+ c 44 (* 4 nparts)))
                  (starts (append (list-tabulate nparts
                                                 (lambda (i)
                                                   (bytevector-s32-ref bv (+ c 44 (* 4 i)) 'little)))
                                  (list np)))
                  (parts (let loop ((s starts) (out '()))
                           (if (null? (cdr s))
                               (reverse out)
                               (loop (cdr s) (cons (read-points bv p0 (car s) (cadr s)) out))))))
             (if (memv type '(5 15 25))
                 (make-polygon (filter (lambda (r) (>= (vector-length r) 8)) parts))
                 (make-polyline parts))))
          (else (error "shapefile->features: unsupported shape type" type)))))

    (define (read-points bv p0 from to)
      (let ((v (make-vector (* 2 (- to from)))))
        (do ((i from (+ i 1)) (j 0 (+ j 2))) ((= i to) v)
          (let ((p (+ p0 (* 16 i))))
            (vector-set! v j (bytevector-ieee-double-ref bv p 'little))
            (vector-set! v (+ j 1) (bytevector-ieee-double-ref bv (+ p 8) 'little))))))

    ;; --- .dbf --------------------------------------------------------

    (define (dbf->records bv . encoding)
      "Syntax: (dbf->records dbf [encoding])
Library: (scm geo shapefile)
Description: Returns the records of a dBASE table, dbf a bytevector with the
  contents of a .dbf file, as a list of alists from field name to value.
  Character fields become strings (decoded with encoding, the symbol utf-8,
  the default, or latin-1) without trailing blanks, numeric and float fields
  numbers (exact when integral), logical fields #t or #f, date fields strings
  \"YYYY-MM-DD\". An empty value is the symbol null, as in (scm json simple).
  Deleted records are skipped.
Example:
  (dbf->records dbf-bytes) => (((\"NAME\" . \"Bern\") (\"KANTONSNUM\" . 2)) ...)"
      (let* ((enc (if (pair? encoding) (car encoding) 'utf-8))
             (n (bytevector-u32-ref bv 4 'little))
             (header (bytevector-u16-ref bv 8 'little))
             (size (bytevector-u16-ref bv 10 'little))
             (fields (let loop ((o 32) (pos 1) (out '()))
                       (if (or (>= o header) (= (bytevector-u8-ref bv o) 13))
                           (reverse out)
                           (let ((len (bytevector-u8-ref bv (+ o 16))))
                             (loop (+ o 32) (+ pos len)
                                   (cons (list (field-name bv o)
                                               (integer->char (bytevector-u8-ref bv (+ o 11)))
                                               pos len)
                                         out)))))))
        (let loop ((i 0) (out '()))
          (if (= i n)
              (reverse out)
              (let ((r (+ header (* i size))))
                (loop (+ i 1)
                      (if (or (>= (+ r size) (+ 1 (bytevector-length bv)))
                              (= (bytevector-u8-ref bv r) 42)) ; * marks deleted
                          out
                          (cons (map (lambda (f)
                                       (cons (car f)
                                             (field-value bv (+ r (caddr f)) (cadddr f) (cadr f) enc)))
                                     fields)
                                out))))))))

    (define (field-name bv o)
      (let loop ((i 0) (cs '()))
        (let ((b (if (< i 11) (bytevector-u8-ref bv (+ o i)) 0)))
          (if (zero? b)
              (list->string (reverse cs))
              (loop (+ i 1) (cons (integer->char b) cs))))))

    (define (decode bv start end enc)
      (if (eq? enc 'latin-1)
          (let loop ((i (- end 1)) (cs '()))
            (if (< i start) (list->string cs)
                (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) cs))))
          (utf8->string bv start end)))

    (define (field-value bv o len type enc)
      (let* ((end (let loop ((e (+ o len)))
                    (if (and (> e o) (memv (bytevector-u8-ref bv (- e 1)) '(0 32)))
                        (loop (- e 1))
                        e)))
             (start (if (char=? type #\C)
                        o
                        (let loop ((s o))
                          (if (and (< s end) (= (bytevector-u8-ref bv s) 32)) (loop (+ s 1)) s)))))
        (if (= start end)
            'null
            (case type
              ((#\C) (decode bv start end enc))
              ((#\N #\F)
               (let* ((s (decode bv start end 'latin-1))
                      (x (string->number s)))
                 (cond ((not x) 'null)
                       ((and (inexact? x) (integer? x) (not (string-index s #\.))) (exact x))
                       ((and (exact? x) (not (integer? x))) (inexact x))
                       (else x))))
              ((#\L) (if (memv (bytevector-u8-ref bv start) '(84 116 89 121)) #t
                         (if (memv (bytevector-u8-ref bv start) '(70 102 78 110)) #f 'null)))
              ((#\D)
               (let ((s (decode bv start end 'latin-1)))
                 (if (= (string-length s) 8)
                     (string-append (substring s 0 4) "-" (substring s 4 6) "-" (substring s 6 8))
                     s)))
              (else (decode bv start end enc))))))))
