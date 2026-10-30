(define-library (scm data io)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (scheme read)
          (scheme write)
          (srfi 1)
          (srfi 13)
          (scm csv)
          (scm json simple)
          (scm ooxml excel)
          (scm ooxml excel-reader)
          (scm geo)
          (scm geo shapefile)
          (scm geo topojson)
          (scm data core)
          (scm data format)
          (scm data frame))
  (export read-csv
          read-csv-string
          csv-for-each
          write-csv
          df->csv-string
          read-xlsx
          write-xlsx
          read-json-records
          write-json-records
          read-jsonl
          write-jsonl
          read-sexp-lines
          write-sexp-lines
          strings->df
          query-result->df
          read-sf
          features->df
          df->features
          write-geojson)
  (begin

    ;; ================================================================
    ;; (scm data io) — reading and writing data frames: CSV, XLSX, JSON
    ;; (array of objects and JSON Lines) and s-expression lines (one
    ;; datum per line, e.g. platform job results).
    ;;
    ;; Options are given as a quoted property list after the required
    ;; arguments, e.g. (read-csv "a.csv" 'sep #\; 'decimal #\,).
    ;; Column types are inferred (see infer-column in (scm data core))
    ;; unless 'col-types names them: '((plz . string) (n . int)).
    ;; ================================================================

    (define (opt opts key dflt)
      (let loop ((o opts))
        (cond ((or (null? o) (null? (cdr o))) dflt)
              ((eq? (car o) key) (cadr o))
              (else (loop (cddr o))))))

    (define default-na '("" "NA" "N/A" "NULL" "null" "#N/A"))

    (define (->symbol x) (if (symbol? x) x (string->symbol x)))

    (define (strings->df names columns opts)
      "Syntax: (strings->df names string-vectors opts)
Library: (scm data io)
Description: Builds a frame from columns of strings, converting each column
  by type inference or by 'col-types; honours 'na and 'decimal like
  read-csv. Used by the readers; handy for other text sources (SQL results).
Example:
  (df-types (strings->df '(a) (list (vector \"1\" \"2\")) '())) => ((a . int))"
      (let ((na-strings (opt opts 'na default-na))
            (decimal (opt opts 'decimal #\.))
            (types (opt opts 'col-types '())))
        (make-df
         (map (lambda (name col)
                (let ((t (assq name types)))
                  (cons name
                        (if t
                            (vector-map (lambda (s)
                                          (if (or (not (string? s)) (member s na-strings))
                                              na
                                              (parse-cell s (cdr t) decimal)))
                                        col)
                            (infer-column col na-strings decimal)))))
              names columns))))

    (define (query-result->df result . opts)
      "Syntax: (query-result->df result option ...)
Library: (scm data io)
Description: A frame from a database query result of (scm database
  postgres) pg-query or (scm database sqlserver) ss-query: column names
  from the result, NULL as na, values converted by type inference or
  'col-types (other options as strings->df).
Example:
  (query-result->df (pg-query conn \"SELECT splg, pts FROM mfzo_summary\"))"
      (let* ((names (map string->symbol (vector->list (vector-ref result 0))))
             (rows (list->vector (vector-ref result 1)))
             (cols (map (lambda (j) (vector-map (lambda (r) (or (vector-ref r j) "")) rows))
                        (iota (length names)))))
        (strings->df names cols opts)))

    ;; --- CSV --------------------------------------------------------

    (define (detect-sep line)
      (let ((count (lambda (c) (string-count line c))))
        (let ((best (fold (lambda (c b) (if (> (count c) (count b)) c b))
                          #\, (list #\; #\tab #\|))))
          best)))

    ;; Parses one record starting with line; reads continuation lines
    ;; from port while a quoted field is open. -> list of strings
    (define (parse-record line sep port)
      (if (not (string-index line #\"))
          (vector->list (csv-line->fields line (string sep)))
          (let ((out (open-output-string)))
            (let loop ((s line) (i 0) (quoted #f) (fields '()))
              (let ((n (string-length s)))
                (cond
                 ((= i n)
                  (if quoted
                      (let ((next (read-line port)))
                        (if (eof-object? next)
                            (reverse (cons (get-output-string out) fields))
                            (begin (write-char #\newline out) (loop next 0 #t fields))))
                      (reverse (cons (get-output-string out) fields))))
                 (else
                  (let ((c (string-ref s i)))
                    (cond
                     (quoted
                      (cond ((and (char=? c #\") (< (+ i 1) n) (char=? (string-ref s (+ i 1)) #\"))
                             (write-char #\" out) (loop s (+ i 2) #t fields))
                            ((char=? c #\") (loop s (+ i 1) #f fields))
                            (else (write-char c out) (loop s (+ i 1) #t fields))))
                     ((char=? c sep)
                      (let ((f (get-output-string out)))
                        (set! out (open-output-string))
                        (loop s (+ i 1) #f (cons f fields))))
                     ((char=? c #\") (loop s (+ i 1) #t fields))
                     (else (write-char c out) (loop s (+ i 1) #f fields)))))))))))

    (define (strip-cr line)
      (let ((n (string-length line)))
        (if (and (> n 0) (char=? (string-ref line (- n 1)) #\return))
            (substring line 0 (- n 1))
            line)))

    (define (strip-bom line)
      (if (and (> (string-length line) 0) (char=? (string-ref line 0) #\xFEFF))
          (substring line 1 (string-length line))
          line))

    ;; -> (values names list-of-records sep), records are lists of strings
    (define (read-csv-records port opts limit)
      (let skip ((k (opt opts 'skip 0)))
        (when (> k 0) (read-line port) (skip (- k 1))))
      (let ((first (read-line port)))
        (if (eof-object? first)
            (values '() '() #\,)
            (let* ((first (strip-cr (strip-bom first)))
                   (sep (let ((s (opt opts 'sep 'auto))) (if (char? s) s (detect-sep first))))
                   (header? (opt opts 'header #t))
                   (r1 (map strip-cr (parse-record first sep port)))
                   (names (cond ((opt opts 'names #f) => (lambda (ns) (map ->symbol ns)))
                                (header? (map (lambda (s) (string->symbol (string-trim-both s))) r1))
                                (else (list-tabulate (length r1)
                                                     (lambda (i) (string->symbol
                                                                  (string-append "X" (number->string (+ i 1))))))))))
              (let loop ((acc (if header? '() (list r1))) (n (if header? 0 1)))
                (if (and limit (>= n limit))
                    (values names (reverse acc) sep)
                    (let ((line (read-line port)))
                      (cond ((eof-object? line) (values names (reverse acc) sep))
                            ((string=? (strip-cr line) "") (loop acc n))
                            (else (loop (cons (map strip-cr (parse-record (strip-cr line) sep port)) acc)
                                        (+ n 1)))))))))))

    (define (records->df names records opts)
      (let* ((k (length names))
             (n (length records))
             (cols (list-tabulate k (lambda (_) (make-vector n "")))))
        (let loop ((rs records) (i 0))
          (unless (null? rs)
            (let fill ((fs (car rs)) (cs cols))
              (unless (or (null? fs) (null? cs))
                (vector-set! (car cs) i (car fs))
                (fill (cdr fs) (cdr cs))))
            (loop (cdr rs) (+ i 1))))
        (strings->df names cols opts)))

    (define (read-csv-port port opts)
      (call-with-values (lambda () (read-csv-records port opts (opt opts 'n-max #f)))
        (lambda (names records sep) (records->df names records opts))))

    (define (read-csv path . opts)
      "Syntax: (read-csv path option ...)
Library: (scm data io)
Description: Reads a CSV file (RFC 4180: quoted fields may hold separators,
  quotes as \"\" and line breaks) into a frame. Options:
  'sep char (default: detected from , ; tab |), 'header #t|#f,
  'names (a b …) to name the columns, 'na (\"\" \"NA\" …) strings read as
  na, 'decimal char (#\\. or #\\,), 'col-types ((col . type) …),
  'skip n lines before the header, 'n-max rows to read.
Example:
  (read-csv \"cases.csv\" 'sep #\\; 'col-types '((plz . string)))"
      (call-with-input-file path (lambda (port) (read-csv-port port opts))))

    (define (read-csv-string s . opts)
      "Syntax: (read-csv-string string option ...)
Library: (scm data io)
Description: read-csv on a string.
Example:
  (df-nrow (read-csv-string \"a,b\\n1,2\\n\")) => 1"
      (read-csv-port (open-input-string s) opts))

    (define (csv-for-each path proc . opts)
      "Syntax: (csv-for-each path proc option ...)
Library: (scm data io)
Description: Streams a large CSV file: calls proc with each record as an
  alist ((column . string) …), without building a frame. Takes the
  options 'sep, 'header, 'names and 'skip of read-csv.
Example:
  (csv-for-each \"big.csv\" (lambda (r) (display (cdr (assq 'id r)))))"
      (call-with-input-file path
        (lambda (port)
          (let skip ((k (opt opts 'skip 0)))
            (when (> k 0) (read-line port) (skip (- k 1))))
          (let ((first (read-line port)))
            (unless (eof-object? first)
              (let* ((first (strip-cr (strip-bom first)))
                     (sep (let ((s (opt opts 'sep 'auto))) (if (char? s) s (detect-sep first))))
                     (header? (opt opts 'header #t))
                     (r1 (parse-record first sep port))
                     (names (cond ((opt opts 'names #f) => (lambda (ns) (map ->symbol ns)))
                                  (header? (map string->symbol r1))
                                  (else (list-tabulate (length r1)
                                                       (lambda (i) (string->symbol
                                                                    (string-append "X" (number->string (+ i 1))))))))))
                (define (emit fields)
                  (proc (let loop ((ns names) (fs fields) (acc '()))
                          (if (null? ns) (reverse acc)
                              (loop (cdr ns) (if (null? fs) '() (cdr fs))
                                    (cons (cons (car ns) (if (null? fs) "" (strip-cr (car fs)))) acc))))))
                (unless header? (emit r1))
                (let loop ()
                  (let ((line (read-line port)))
                    (unless (eof-object? line)
                      (unless (string=? (strip-cr line) "")
                        (emit (parse-record (strip-cr line) sep port)))
                      (loop))))))))))

    (define (csv-field x sep decimal na-str)
      (let* ((s (cond ((na? x) na-str)
                      ((and (real? x) (inexact? x) (not (char=? decimal #\.)))
                       (string-map (lambda (c) (if (char=? c #\.) decimal c)) (fmt-value x)))
                      (else (parameterize ((na-string na-str)) (fmt-value x))))))
        (if (or (string-index s sep) (string-index s #\") (string-index s #\newline)
                (string-index s #\return))
            (string-append "\"" (string-join (string-split-quotes s) "\"\"") "\"")
            s)))

    (define (string-split-quotes s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) #\") (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    (define (write-csv-port df port opts)
      (let ((sep (opt opts 'sep #\,))
            (decimal (opt opts 'decimal #\.))
            (na-str (opt opts 'na ""))
            (cols (map cdr (df-columns df))))
        (when (opt opts 'bom #f) (write-char #\xFEFF port))
        (write-string (string-join (map (lambda (n) (csv-field (symbol->string n) sep decimal na-str))
                                        (df-names df))
                                   (string sep))
                      port)
        (write-string "\r\n" port)
        (do ((i 0 (+ i 1))) ((= i (df-nrow df)))
          (write-string (string-join (map (lambda (c) (csv-field (vector-ref c i) sep decimal na-str)) cols)
                                     (string sep))
                        port)
          (write-string "\r\n" port))))

    (define (write-csv df path . opts)
      "Syntax: (write-csv df path option ...)
Library: (scm data io)
Description: Writes a frame as CSV (header row, CRLF line ends, fields
  quoted when needed). Options: 'sep char (default #\\,), 'decimal char,
  'na string for missing cells (default \"\"), 'bom #t to start with a
  UTF-8 byte order mark (so Excel detects UTF-8).
Example:
  (write-csv df \"out.csv\" 'sep #\\; 'decimal #\\, 'bom #t)"
      (call-with-output-file path (lambda (port) (write-csv-port df port opts))))

    (define (df->csv-string df . opts)
      (let ((p (open-output-string))) (write-csv-port df p opts) (get-output-string p)))

    ;; --- XLSX -------------------------------------------------------

    (define (cell->string x)
      (cond ((not x) #f)
            ((string? x) x)
            (else (fmt-value x))))

    (define (xlsx-column cells opts name)
      ;; cells: list of raw values (#f empty). Numbers stay numbers.
      (let ((types (opt opts 'col-types '())))
        (cond
         ((assq name types)
          (let ((t (cdr (assq name types))))
            (list->vector (map (lambda (x) (if x (parse-cell (cell->string x) t) na)) cells))))
         ((every (lambda (x) (or (not x) (real? x))) cells)
          (let ((ints? (every (lambda (x) (or (not x) (integer? x))) cells)))
            (list->vector (map (lambda (x) (cond ((not x) na) (ints? (exact x)) (else (inexact x))))
                               cells))))
         ((every (lambda (x) (or (not x) (boolean? x))) cells)
          (list->vector (map (lambda (x) (if (eq? x #f) na x)) cells)))
         (else
          (infer-column (list->vector (map (lambda (x) (or (cell->string x) "")) cells))
                        (opt opts 'na default-na))))))

    (define (read-xlsx path . opts)
      "Syntax: (read-xlsx path option ...)
Library: (scm data io)
Description: Reads one sheet of an XLSX file into a frame. Options:
  'sheet name or 1-based number (default 1), 'header #t|#f, 'skip rows
  before the header, 'names, 'na, 'col-types (as read-csv). Numeric
  columns stay numeric; date cells are recognised as dates.
Example:
  (read-xlsx \"list.xlsx\" 'sheet \"Daten\" 'skip 2)"
      (let* ((wb (read-workbook path))
             (sh (let ((s (opt opts 'sheet 1)))
                   (or (workbook-sheet wb (if (integer? s) (- s 1) s))
                       (error "read-xlsx: no such sheet" s))))
             (rows (let skip ((rs (sheet-rows sh)) (k (opt opts 'skip 0)))
                     (if (or (= k 0) (null? rs)) rs (skip (cdr rs) (- k 1)))))
             (header? (opt opts 'header #t)))
        (if (null? rows)
            empty-df
            (let* ((width (fold (lambda (r m) (max m (length r))) 0 rows))
                   (pad (lambda (r) (append r (make-list (- width (length r)) #f))))
                   (rows (map pad rows))
                   (names (cond ((opt opts 'names #f) => (lambda (ns) (map ->symbol ns)))
                                (header? (map (lambda (x i)
                                                (string->symbol
                                                 (or (and x (string-trim-both (cell->string x)))
                                                     (string-append "X" (number->string i)))))
                                              (car rows) (iota width 1)))
                                (else (map (lambda (i) (string->symbol (string-append "X" (number->string i))))
                                           (iota width 1)))))
                   (data (if header? (cdr rows) rows))
                   ;; drop trailing empty rows
                   (data (reverse (drop-while (lambda (r) (every not r)) (reverse data)))))
              (make-df (map (lambda (name j)
                              (cons name (xlsx-column (map (lambda (r) (list-ref r j)) data) opts name)))
                            names (iota width)))))))

    (define (xlsx-cell-string x)
      (cond ((day? x) (day->string x))
            (else (fmt-value x))))

    (define (write-xlsx sheets path . opts)
      "Syntax: (write-xlsx df-or-sheets path option ...)
Library: (scm data io)
Description: Writes one frame, or several given as an alist
  ((\"Sheet name\" . df) …), to an XLSX file: bold header row with an
  AutoFilter, the header frozen, column widths fitted to the content,
  numbers as numeric cells, na as empty cells, dates as ISO text.
  Option 'sheet-name for a single frame (default \"Data\").
Example:
  (write-xlsx `((\"2024\" . ,df24) (\"2025\" . ,df25)) \"points.xlsx\")"
      (let* ((sheets (if (data-frame? sheets)
                         (list (cons (opt opts 'sheet-name "Data") sheets))
                         sheets))
             (wb (make-workbook))
             (bold (workbook-add-style wb (font bold) (fill fgcolor: "FFE8EEF4"))))
        (for-each
         (lambda (entry)
           (let* ((df (cdr entry))
                  (ws (workbook-add-worksheet! wb (car entry)))
                  (names (df-names df))
                  (k (length names))
                  (n (df-nrow df)))
             (for-each (lambda (name j)
                         (worksheet-set-cell! ws (row-col->cell-id 1 (+ j 1))
                                              (symbol->string name) 'string bold))
                       names (iota k))
             (for-each
              (lambda (name j)
                (let ((col (df-column df name))
                      (width (string-length (symbol->string name))))
                  (do ((i 0 (+ i 1))) ((= i n))
                    (let ((x (vector-ref col i))
                          (id (row-col->cell-id (+ i 2) (+ j 1))))
                      (cond ((na? x) #f)
                            ((real? x)
                             (worksheet-set-cell! ws id (if (exact? x) x (inexact x)) 'num #f)
                             (set! width (max width (string-length (fmt-value x)))))
                            (else
                             (let ((s (xlsx-cell-string x)))
                               (worksheet-set-cell! ws id s 'string #f)
                               (set! width (max width (string-length s))))))))
                  (worksheet-set-col-width! ws (col-index->string (+ j 1))
                                            (min 60 (+ 2 width)))))
              names (iota k))
             (when (> k 0)
               (worksheet-set-autofilter! ws (string-append "A1:" (row-col->cell-id 1 k)))
               (worksheet-freeze-panes! ws "A2"))))
         sheets)
        (workbook-save wb path)))

    ;; --- JSON -------------------------------------------------------

    (define (json->cell x)
      (cond ((json-null? x) na)
            ((vector? x) (map json->cell (vector->list x)))
            (else x)))

    (define (cell->json x)
      (cond ((na? x) 'null)
            ((day? x) (day->string x))
            ((symbol? x) (symbol->string x))
            ((list? x) (list->vector (map cell->json x)))
            (else x)))

    (define (objects->df objs)
      (alists->df (map (lambda (o)
                         (unless (list? o) (error "JSON records: expected objects" o))
                         (map (lambda (p) (cons (car p) (json->cell (cdr p)))) o))
                       objs)))

    (define (read-json-records path)
      "Syntax: (read-json-records path)
Library: (scm data io)
Description: Reads a JSON file holding an array of objects into a frame,
  one row per object; null becomes na, arrays become list cells.
Example:
  (read-json-records \"cases.json\")"
      (let ((v (call-with-input-file path json-read)))
        (unless (vector? v) (error "read-json-records: expected a JSON array"))
        (objects->df (vector->list v))))

    (define (df->objects df)
      (map (lambda (row)
             (map (lambda (p) (cons (symbol->string (car p)) (cell->json (cdr p)))) row))
           (df->alists df)))

    (define (write-json-records df path . opts)
      "Syntax: (write-json-records df path [pretty?])
Library: (scm data io)
Description: Writes a frame as a JSON array of objects (na as null, dates
  as ISO strings, list cells as arrays).
Example:
  (write-json-records df \"out.json\" #t)"
      (call-with-output-file path
        (lambda (port)
          (let ((v (list->vector (df->objects df))))
            (if (and (pair? opts) (car opts)) (json-write-pretty v port) (json-write v port))
            (newline port)))))


    ;; --- geometry (shapefile, GeoJSON, TopoJSON) ----------------------

    (define (features->df features . col)
      "Syntax: (features->df features [geometry-column])
Library: (scm data io)
Description: A frame of (scm geo) features, as R's sf has them: one
  column per property (null becomes na) and their geometries in the
  column geometry (or the name given).
Example:
  (features->df (read-shapefile \"cantons.shp\"))"
      (let* ((col (if (pair? col) (car col) 'geometry))
             (props (map (lambda (f)
                           (map (lambda (p) (cons (car p) (json->cell (cdr p))))
                                (feature-properties f)))
                         features))
             (df (if (every null? props)
                     (make-df (list (cons 'id (list->vector (iota (length features) 1)))))
                     (alists->df props))))
        (df-with-column df col (list->vector (map feature-geometry features)))))

    (define (df->features df . col)
      "Syntax: (df->features df [geometry-column])
Library: (scm data io)
Description: The rows of a frame with a geometry column as (scm geo)
  features, the other columns as their properties (keys are strings, na
  becomes null). Rows without a geometry are left out.
Example:
  (features->geojson (df->features regions))"
      (let* ((col (if (pair? col) (car col) 'geometry))
             (geoms (df-column df col))
             (names (remove (lambda (n) (eq? n col)) (df-names df))))
        (filter-map (lambda (i)
                      (let ((g (vector-ref geoms i)))
                        (and (pair? g)
                             (make-feature (map (lambda (n) (cons (symbol->string n) (cell->json (vector-ref (df-column df n) i))))
                                                names)
                                           g))))
                    (iota (df-nrow df)))))

    (define (read-sf path . opts)
      "Syntax: (read-sf path option ...)
Library: (scm data io)
Description: Reads geometries with their attributes into a frame (see
  features->df): an ESRI shapefile (.shp, with the .dbf next to it), a
  GeoJSON FeatureCollection (.geojson, .json) or a TopoJSON topology
  (.topojson, or any JSON file of type Topology). Options: 'layer name
  (TopoJSON object, default the first), 'encoding utf-8|latin-1 (the
  shapefile's attributes, default from its .cpg file).
Example:
  (read-sf \"cantons.shp\" 'encoding 'latin-1)"
      (features->df
       (if (string-suffix-ci? ".shp" path)
           (let ((enc (opt opts 'encoding #f)))
             (if enc (read-shapefile path enc) (read-shapefile path)))
           (let ((json (call-with-input-file path json-read)))
             (if (equal? (let ((t (and (list? json) (assoc "type" json)))) (and t (cdr t))) "Topology")
                 (let ((layer (opt opts 'layer #f)))
                   (if layer (topojson->features json layer) (topojson->features json)))
                 (geojson->features json))))))

    (define (write-geojson df path . col)
      "Syntax: (write-geojson df path [geometry-column])
Library: (scm data io)
Description: Writes a frame with a geometry column as a GeoJSON
  FeatureCollection (see df->features).
Example:
  (write-geojson regions \"regions.geojson\")"
      (call-with-output-file path
        (lambda (port)
          (json-write (features->geojson (apply df->features df col)) port)
          (newline port))))

    (define (read-jsonl path)
      "Syntax: (read-jsonl path)
Library: (scm data io)
Description: Reads JSON Lines (one object per line) into a frame.
Example:
  (read-jsonl \"events.jsonl\")"
      (call-with-input-file path
        (lambda (port)
          (let loop ((acc '()))
            (let ((line (read-line port)))
              (cond ((eof-object? line) (objects->df (reverse acc)))
                    ((string=? (string-trim-both line) "") (loop acc))
                    (else (loop (cons (json-parse line) acc)))))))))

    (define (write-jsonl df path)
      (call-with-output-file path
        (lambda (port)
          (for-each (lambda (o) (write-string (json->string o) port) (newline port))
                    (df->objects df)))))

    ;; --- s-expression lines -------------------------------------------

    ;; ((k v) (k v1 v2) (k . v) (k)) -> ((k . v) (k . (v1 v2)) (k . v) (k . ()));
    ;; keys in list-cols always get the list of values: (k v) -> (k . (v))
    (define (datum->row d list-cols)
      (map (lambda (e)
             (cond ((not (pair? e)) (error "read-sexp-lines: not an entry" e))
                   ((not (list? e)) (cons (car e) (cdr e)))
                   ((memq (car e) list-cols) (cons (car e) (cdr e)))
                   ((null? (cdr e)) (cons (car e) '()))
                   ((null? (cddr e)) (cons (car e) (cadr e)))
                   (else (cons (car e) (cdr e)))))
           d))

    (define (read-sexp-lines path . opts)
      "Syntax: (read-sexp-lines path option ...)
Library: (scm data io)
Description: Reads a file of data, one per line, each an alist of entries
  into a frame. An entry (key value) gives the cell value, (key v1 v2 …)
  a list cell, (key . value) the value, (key) the empty list. Options:
  'list-cols (k …) columns whose entries are always lists, so (k v) gives
  (v) and a missing entry the empty list; 'map proc to turn each datum
  into an alist yourself (return #f to skip it); 'names to fix the
  columns; 'add ((col . value) …) for constant columns (e.g. which run a
  file comes from).
Example:
  (read-sexp-lines \"splg.scm\" 'list-cols '(lgs operateure)
                   'add '((year . 2024) (model . v1)))"
      (let ((mapper (opt opts 'map #f))
            (add (opt opts 'add '()))
            (list-cols (opt opts 'list-cols '())))
        (call-with-input-file path
          (lambda (port)
            (let loop ((acc '()))
              (let ((d (read port)))
                (if (eof-object? d)
                    (let* ((rows (reverse acc))
                           (names (opt opts 'names #f))
                           (df (if names (alists->df rows names) (alists->df rows)))
                           (df (fold (lambda (c df)
                                       (if (df-has-column? df c) df (df-with-column df c na)))
                                     df list-cols)))
                      (fold (lambda (c df)
                              (df-with-column df c
                                (vector-map (lambda (x) (if (na? x) '() x)) (df-column df c))))
                            df list-cols))
                    (let ((row (if mapper (mapper d) (datum->row d list-cols))))
                      (loop (if row (cons (append row add) acc) acc))))))))))

    (define (write-sexp-lines df path)
      "Syntax: (write-sexp-lines df path)
Library: (scm data io)
Description: Writes each row as one line ((column value) …), the format
  read-sexp-lines reads back; list cells are written as (column v1 v2 …),
  na cells are left out, dates are written as ISO strings.
Example:
  (write-sexp-lines df \"rows.scm\")"
      (call-with-output-file path
        (lambda (port)
          (for-each (lambda (row)
                      (write (filter-map
                              (lambda (p)
                                (let ((v (cdr p)))
                                  (cond ((na? v) #f)
                                        ((list? v) (cons (car p) v))
                                        ((day? v) (list (car p) (day->string v)))
                                        (else (list (car p) v)))))
                              row)
                             port)
                      (newline port))
                    (df->alists df)))))))
