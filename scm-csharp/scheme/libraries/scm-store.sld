(define-library (scm store)
  (import (scheme base)
          (scheme cxr)
          (scheme write)
          (scheme read)
          (srfi 69)
          (srfi 132)
          (scm random access))
  (export ;; writing
          store-writer-open
          store-writer-add!
          store-writer-close
          ;; reading
          store-open
          store-close
          store?
          store-count
          store-ref
          store-field-values
          ;; querying
          store-query
          store-count-matching
          store-page
          store-page-records)
  (begin

    ;; ================================================================
    ;; (scm store) -- a small immutable on-disk indexed record store.
    ;;
    ;; Built on (scm random access). A store holds a sequence of records,
    ;; each with a dense integer key (0, 1, 2, ... in insertion order), an
    ;; opaque payload (any Scheme datum, serialised with write/read), and a
    ;; set of indexed fields:
    ;;
    ;;   - scalar fields: one value per record (equality + distinct)
    ;;   - multi  fields: a set of values per record (set membership)
    ;;
    ;; Writing streams payloads straight to disk; the inverted indexes are
    ;; built in memory during the batch write and flushed at close (only
    ;; small (value -> rowid-list) tables are held, never the payloads).
    ;; Reading is fully random-access: a query never loads the dataset --
    ;; it binary-searches on-disk value tables, reads sorted rowid postings
    ;; for the queried values, and fetches only the payloads on the page.
    ;;
    ;; File layout (all integers little-endian):
    ;;   header  (16 bytes): magic "SCMSTOR1" (8) + footer-offset u64 (8)
    ;;   data            : concatenated payload bytes
    ;;   primary index   : per key, u64 payload-offset + u32 payload-len
    ;;   field indexes   : per field, postings + value blob + value table
    ;;                       postings(value): u32 count + count*u32 rowids
    ;;                       value table[i] : u64 val-off, u32 val-len,
    ;;                                        u64 postings-off  (20 bytes,
    ;;                                        sorted by value -> binary search)
    ;;   footer          : magic, version, count, primary base, field dir
    ;; ================================================================

    (define store-magic-string "SCMSTOR1")
    (define store-version 1)

    ;; --- little-endian integer codecs over bytevectors ---

    (define (write-u32-le! bv i v)
      (bytevector-u8-set! bv i (modulo v 256))
      (bytevector-u8-set! bv (+ i 1) (modulo (quotient v 256) 256))
      (bytevector-u8-set! bv (+ i 2) (modulo (quotient v 65536) 256))
      (bytevector-u8-set! bv (+ i 3) (modulo (quotient v 16777216) 256)))

    (define (write-u64-le! bv i v)
      (let loop ((k 0) (v v))
        (when (< k 8)
          (bytevector-u8-set! bv (+ i k) (modulo v 256))
          (loop (+ k 1) (quotient v 256)))))

    (define (read-u32-le bv i)
      (+ (bytevector-u8-ref bv i)
         (* 256 (bytevector-u8-ref bv (+ i 1)))
         (* 65536 (bytevector-u8-ref bv (+ i 2)))
         (* 16777216 (bytevector-u8-ref bv (+ i 3)))))

    (define (read-u64-le bv i)
      (let loop ((k 7) (acc 0))
        (if (< k 0)
            acc
            (loop (- k 1) (+ (* acc 256) (bytevector-u8-ref bv (+ i k)))))))

    ;; --- payload (de)serialisation ---

    (define (datum->utf8 d)
      (let ((p (open-output-string)))
        (write d p)
        (string->utf8 (get-output-string p))))

    (define (utf8->datum bv)
      (read (open-input-string (utf8->string bv))))

    ;; --- sorted-list set operations (ascending integer rowids) ---

    (define (dedup-sorted lst)
      (cond ((null? lst) '())
            ((null? (cdr lst)) lst)
            ((= (car lst) (cadr lst)) (dedup-sorted (cdr lst)))
            (else (cons (car lst) (dedup-sorted (cdr lst))))))

    (define (merge-intersect a b)
      (let loop ((a a) (b b) (acc '()))
        (cond ((or (null? a) (null? b)) (reverse acc))
              ((= (car a) (car b)) (loop (cdr a) (cdr b) (cons (car a) acc)))
              ((< (car a) (car b)) (loop (cdr a) b acc))
              (else (loop a (cdr b) acc)))))

    (define (merge-union a b)
      (let loop ((a a) (b b) (acc '()))
        (cond ((and (null? a) (null? b)) (reverse acc))
              ((null? a) (loop a (cdr b) (cons (car b) acc)))
              ((null? b) (loop (cdr a) b (cons (car a) acc)))
              ((= (car a) (car b)) (loop (cdr a) (cdr b) (cons (car a) acc)))
              ((< (car a) (car b)) (loop (cdr a) b (cons (car a) acc)))
              (else (loop a (cdr b) (cons (car b) acc))))))

    ;; ================================================================
    ;; Writer
    ;; ================================================================

    (define-record-type <store-writer>
      (%make-store-writer raf wpos count scalar-names multi-names
                          offsets lens field-tables)
      store-writer?
      (raf swr-raf)
      (wpos swr-wpos set-swr-wpos!)
      (count swr-count set-swr-count!)
      (scalar-names swr-scalar-names)
      (multi-names swr-multi-names)
      (offsets swr-offsets set-swr-offsets!) ; reversed list: payload offsets
      (lens swr-lens set-swr-lens!)          ; reversed list: payload lengths
      (field-tables swr-field-tables))       ; vector of hash-tables, scalars then multis

    (define (store-writer-open filename scalar-names multi-names)
      "Syntax: (store-writer-open filename scalar-names multi-names)
Library: (scm store)
Description: Creates (truncating) a store file and returns a writer. scalar-names
  and multi-names are lists of field-name symbols: scalar fields hold one value
  per record (equality/distinct queries); multi fields hold a set of values per
  record (membership queries). Add records with store-writer-add! and finish with
  store-writer-close.
Example:
  (define w (store-writer-open \"r.store\" '(splg) '(quer)))"
      (let* ((nfields (+ (length scalar-names) (length multi-names)))
             (tables (make-vector nfields #f))
             (raf (open-random-access-file filename 'write))
             (hdr (make-bytevector 16 0))
             (magic (string->utf8 store-magic-string)))
        (bytevector-copy! hdr 0 magic 0 8)
        (random-access-file-write! raf 0 hdr)
        (let loop ((i 0))
          (when (< i nfields)
            (vector-set! tables i (make-hash-table))
            (loop (+ i 1))))
        (%make-store-writer raf 16 0 scalar-names multi-names '() '() tables)))

    (define (store-writer-add! w payload fields)
      "Syntax: (store-writer-add! w payload fields)
Library: (scm store)
Description: Appends one record to store writer w and returns its integer key.
  payload is any Scheme datum (serialised with write). fields is an alist mapping
  field-name symbols to index values: for a scalar field a string (or #f to skip),
  for a multi field a list of strings.
Example:
  (store-writer-add! w '((id . 7)) '((splg . \"A1\") (quer . (\"x\" \"y\"))))"
      (let* ((raf (swr-raf w))
             (rowid (swr-count w))
             (bytes (datum->utf8 payload))
             (off (swr-wpos w)))
        (random-access-file-write! raf off bytes)
        (set-swr-wpos! w (+ off (bytevector-length bytes)))
        (set-swr-offsets! w (cons off (swr-offsets w)))
        (set-swr-lens! w (cons (bytevector-length bytes) (swr-lens w)))
        (let loop ((i 0) (ns (swr-scalar-names w)))
          (when (pair? ns)
            (let ((p (assq (car ns) fields)))
              (when (and p (cdr p))
                (hash-table-update!/default
                  (vector-ref (swr-field-tables w) i)
                  (cdr p) (lambda (lst) (cons rowid lst)) '())))
            (loop (+ i 1) (cdr ns))))
        (let ((base (length (swr-scalar-names w))))
          (let loop ((i 0) (ns (swr-multi-names w)))
            (when (pair? ns)
              (let ((p (assq (car ns) fields))
                    (ht (vector-ref (swr-field-tables w) (+ base i))))
                (when p
                  (for-each
                    (lambda (v)
                      (when v
                        (hash-table-update!/default
                          ht v (lambda (lst) (cons rowid lst)) '())))
                    (cdr p))))
              (loop (+ i 1) (cdr ns)))))
        (set-swr-count! w (+ rowid 1))
        rowid))

    ;; Build one field index region; returns (name kind vtbase vcount).
    (define (write-field-index! emit! raf name kind ht)
      (let* ((values-sorted (list-sort string<? (hash-table-keys ht)))
             (postings-offsets
               (map (lambda (val)
                      (let* ((rows (dedup-sorted
                                     (list-sort < (hash-table-ref/default ht val '()))))
                             (n (length rows))
                             (bv (make-bytevector (+ 4 (* 4 n)) 0)))
                        (write-u32-le! bv 0 n)
                        (let loop ((i 0) (rs rows))
                          (when (pair? rs)
                            (write-u32-le! bv (+ 4 (* 4 i)) (car rs))
                            (loop (+ i 1) (cdr rs))))
                        (emit! bv)))
                    values-sorted))
             (val-locs
               (map (lambda (val)
                      (let ((vb (string->utf8 val)))
                        (cons (emit! vb) (bytevector-length vb))))
                    values-sorted))
             (vc (length values-sorted))
             (vt (make-bytevector (* 20 vc) 0)))
        (let loop ((i 0) (vls val-locs) (pos postings-offsets))
          (when (pair? vls)
            (write-u64-le! vt (* 20 i) (car (car vls)))
            (write-u32-le! vt (+ (* 20 i) 8) (cdr (car vls)))
            (write-u64-le! vt (+ (* 20 i) 12) (car pos))
            (loop (+ i 1) (cdr vls) (cdr pos))))
        (list name kind (emit! vt) vc)))

    (define (build-footer count prim-base field-dir)
      (let ((parts '()))
        (define (push! bv) (set! parts (cons bv parts)))
        (let ((head (make-bytevector 28 0))
              (magic (string->utf8 store-magic-string)))
          (bytevector-copy! head 0 magic 0 8)
          (write-u32-le! head 8 store-version)
          (write-u64-le! head 12 count)
          (write-u64-le! head 20 prim-base)
          (push! head))
        (let ((fc (make-bytevector 4 0)))
          (write-u32-le! fc 0 (length field-dir))
          (push! fc))
        (for-each
          (lambda (fd)
            (let* ((name (car fd)) (kind (cadr fd))
                   (vtbase (caddr fd)) (vc (cadddr fd))
                   (nb (string->utf8 (symbol->string name)))
                   (rec (make-bytevector (+ 4 (bytevector-length nb) 1 8 8) 0)))
              (write-u32-le! rec 0 (bytevector-length nb))
              (bytevector-copy! rec 4 nb 0 (bytevector-length nb))
              (let ((o (+ 4 (bytevector-length nb))))
                (bytevector-u8-set! rec o (if (eq? kind 'multi) 1 0))
                (write-u64-le! rec (+ o 1) vtbase)
                (write-u64-le! rec (+ o 9) vc))
              (push! rec)))
          field-dir)
        (let* ((ordered (reverse parts))
               (total (apply + (map bytevector-length ordered)))
               (out (make-bytevector total 0)))
          (let loop ((ps ordered) (o 0))
            (when (pair? ps)
              (bytevector-copy! out o (car ps) 0 (bytevector-length (car ps)))
              (loop (cdr ps) (+ o (bytevector-length (car ps))))))
          out)))

    (define (store-writer-close w)
      "Syntax: (store-writer-close w)
Library: (scm store)
Description: Finalises store writer w: writes the primary key index and all field
  indexes, appends the footer, flushes, and closes the file. The store is only
  readable after the writer is closed.
Example:
  (store-writer-close w)"
      (let* ((raf (swr-raf w))
             (count (swr-count w))
             (offsets (list->vector (reverse (swr-offsets w))))
             (lens (list->vector (reverse (swr-lens w))))
             (wpos (swr-wpos w)))
        (define (emit! bv)
          (let ((p wpos))
            (random-access-file-write! raf p bv)
            (set! wpos (+ p (bytevector-length bv)))
            p))
        (let* ((prim-base
                 (let ((prim (make-bytevector (* 12 count) 0)))
                   (let loop ((k 0))
                     (when (< k count)
                       (write-u64-le! prim (* 12 k) (vector-ref offsets k))
                       (write-u32-le! prim (+ (* 12 k) 8) (vector-ref lens k))
                       (loop (+ k 1))))
                   (emit! prim)))
               (scalar-dir
                 (let loop ((i 0) (ns (swr-scalar-names w)) (acc '()))
                   (if (pair? ns)
                       (loop (+ i 1) (cdr ns)
                             (cons (write-field-index! emit! raf (car ns) 'scalar
                                     (vector-ref (swr-field-tables w) i))
                                   acc))
                       (reverse acc))))
               (base (length (swr-scalar-names w)))
               (multi-dir
                 (let loop ((i 0) (ns (swr-multi-names w)) (acc '()))
                   (if (pair? ns)
                       (loop (+ i 1) (cdr ns)
                             (cons (write-field-index! emit! raf (car ns) 'multi
                                     (vector-ref (swr-field-tables w) (+ base i)))
                                   acc))
                       (reverse acc))))
               (field-dir (append scalar-dir multi-dir))
               (footer-offset wpos))
          (emit! (build-footer count prim-base field-dir))
          (let ((hdr (make-bytevector 8 0)))
            (write-u64-le! hdr 0 footer-offset)
            (random-access-file-write! raf 8 hdr))
          (random-access-file-flush raf)
          (close-random-access-file raf))))

    ;; ================================================================
    ;; Reader
    ;; ================================================================

    (define-record-type <store>
      (%make-store raf count prim-base fields)
      store?
      (raf st-raf)
      (count st-count)
      (prim-base st-prim-base)
      (fields st-fields)) ; alist: name-symbol -> (kind vtbase vcount)

    (define (magic-ok? bv)
      (and (>= (bytevector-length bv) 8)
           (let ((m (string->utf8 store-magic-string)))
             (let loop ((i 0))
               (cond ((= i 8) #t)
                     ((= (bytevector-u8-ref bv i) (bytevector-u8-ref m i))
                      (loop (+ i 1)))
                     (else #f))))))

    (define (parse-footer bv)
      ;; returns (values count prim-base fields-alist)
      (unless (magic-ok? bv)
        (error "store-open: bad footer magic"))
      (let* ((count (read-u64-le bv 12))
             (prim-base (read-u64-le bv 20))
             (fcount (read-u32-le bv 28)))
        (let loop ((i 0) (o 32) (acc '()))
          (if (= i fcount)
              (values count prim-base (reverse acc))
              (let* ((nlen (read-u32-le bv o))
                     (name (string->symbol
                             (utf8->string (bytevector-copy bv (+ o 4) (+ o 4 nlen)))))
                     (ko (+ o 4 nlen))
                     (kind (if (= (bytevector-u8-ref bv ko) 1) 'multi 'scalar))
                     (vtbase (read-u64-le bv (+ ko 1)))
                     (vc (read-u64-le bv (+ ko 9))))
                (loop (+ i 1) (+ ko 17)
                      (cons (cons name (list kind vtbase vc)) acc)))))))

    (define (store-open filename)
      "Syntax: (store-open filename)
Library: (scm store)
Description: Opens an existing store file for read-only random access and returns
  a store handle. Reads only the small footer into memory; record payloads and
  index postings stay on disk and are read on demand.
Example:
  (define s (store-open \"r.store\"))"
      (let* ((raf (open-random-access-file filename 'read))
             (size (random-access-file-size raf))
             (hdr (random-access-file-read raf 0 16)))
        (unless (magic-ok? hdr)
          (close-random-access-file raf)
          (error "store-open: not a store file" filename))
        (let ((footer-offset (read-u64-le hdr 8)))
          (let-values (((count prim-base fields)
                        (parse-footer
                          (random-access-file-read raf footer-offset
                                                   (- size footer-offset)))))
            (%make-store raf count prim-base fields)))))

    (define (store-close s)
      "Syntax: (store-close s)
Library: (scm store)
Description: Closes the store handle s and releases the underlying file.
Example:
  (store-close s)"
      (close-random-access-file (st-raf s)))

    (define (store-count s)
      "Syntax: (store-count s)
Library: (scm store)
Description: Returns the number of records in store s.
Example:
  (store-count s) => 1000"
      (st-count s))

    (define (store-ref s rowid)
      "Syntax: (store-ref s rowid)
Library: (scm store)
Description: Returns the payload datum of the record with the given integer key,
  reading just that record from disk. Raises an error if rowid is out of range.
Example:
  (store-ref s 0) => ((id . 7))"
      (when (or (< rowid 0) (>= rowid (st-count s)))
        (error "store-ref: rowid out of range" rowid))
      (let* ((raf (st-raf s))
             (e (random-access-file-read raf (+ (st-prim-base s) (* 12 rowid)) 12))
             (off (read-u64-le e 0))
             (len (read-u32-le e 8)))
        (utf8->datum (random-access-file-read raf off len))))

    (define (field-info s name)
      (let ((p (assq name (st-fields s))))
        (if p (cdr p) (error "store: unknown field" name))))

    ;; Binary-search a field's value table; returns postings offset or #f.
    (define (field-find-postings s fi val)
      (let ((raf (st-raf s))
            (vtbase (cadr fi))
            (vc (caddr fi)))
        (let loop ((lo 0) (hi (- vc 1)))
          (if (> lo hi)
              #f
              (let* ((mid (quotient (+ lo hi) 2))
                     (e (random-access-file-read raf (+ vtbase (* 20 mid)) 20))
                     (voff (read-u64-le e 0))
                     (vlen (read-u32-le e 8))
                     (poff (read-u64-le e 12))
                     (vstr (utf8->string (random-access-file-read raf voff vlen))))
                (cond ((string=? val vstr) poff)
                      ((string<? val vstr) (loop lo (- mid 1)))
                      (else (loop (+ mid 1) hi))))))))

    (define (read-postings raf poff)
      (let* ((cnt (read-u32-le (random-access-file-read raf poff 4) 0))
             (data (random-access-file-read raf (+ poff 4) (* 4 cnt))))
        (let loop ((i (- cnt 1)) (acc '()))
          (if (< i 0) acc (loop (- i 1) (cons (read-u32-le data (* 4 i)) acc))))))

    (define (store-field-values s name)
      "Syntax: (store-field-values s name)
Library: (scm store)
Description: Returns the sorted list of distinct values present for field name in
  store s. Useful for populating filter choices. Reads only the field's value
  table, not the records.
Example:
  (store-field-values s 'splg) => (\"A1\" \"B2\" \"C3\")"
      (let* ((fi (field-info s name))
             (raf (st-raf s))
             (vtbase (cadr fi))
             (vc (caddr fi)))
        (let loop ((i (- vc 1)) (acc '()))
          (if (< i 0)
              acc
              (let* ((e (random-access-file-read raf (+ vtbase (* 20 i)) 20))
                     (voff (read-u64-le e 0))
                     (vlen (read-u32-le e 8)))
                (loop (- i 1)
                      (cons (utf8->string (random-access-file-read raf voff vlen)) acc)))))))

    ;; --- query clauses ---
    ;; A clause is one of:
    ;;   (eq field value)        record's field has value (string)
    ;;   (in field (v ...))      record's field has any of the values
    ;;   (present field)         record has at least one value for field
    ;; Multiple clauses are combined with AND.

    (define (eq-rows s field value)
      (let ((poff (field-find-postings s (field-info s field) value)))
        (if poff (read-postings (st-raf s) poff) '())))

    (define (clause->rows s clause)
      (case (car clause)
        ((eq) (eq-rows s (cadr clause) (caddr clause)))
        ((in)
         (let loop ((vals (caddr clause)) (acc '()))
           (if (null? vals)
               acc
               (loop (cdr vals) (merge-union acc (eq-rows s (cadr clause) (car vals)))))))
        ((present)
         (let loop ((vals (store-field-values s (cadr clause))) (acc '()))
           (if (null? vals)
               acc
               (loop (cdr vals) (merge-union acc (eq-rows s (cadr clause) (car vals)))))))
        (else (error "store-query: unknown clause" clause))))

    (define (store-query s clauses)
      "Syntax: (store-query s clauses)
Library: (scm store)
Description: Returns the sorted list of matching record keys for the AND of the
  given filter clauses, or #f when clauses is empty (meaning every record, without
  materialising the full key list). Each clause is (eq field value),
  (in field (value ...)), or (present field).
Example:
  (store-query s '((eq splg \"A1\") (in quer (\"x\" \"y\"))))"
      (if (null? clauses)
          #f
          (let loop ((cs (cdr clauses)) (acc (clause->rows s (car clauses))))
            (if (null? cs)
                acc
                (loop (cdr cs) (merge-intersect acc (clause->rows s (car cs))))))))

    (define (store-count-matching s clauses)
      "Syntax: (store-count-matching s clauses)
Library: (scm store)
Description: Returns how many records match the AND of the given filter clauses
  (see store-query). With no clauses this is just the total record count.
Example:
  (store-count-matching s '((eq splg \"A1\"))) => 42"
      (let ((rows (store-query s clauses)))
        (if rows (length rows) (st-count s))))

    (define (list-slice lst offset limit)
      (let loop ((lst lst) (k offset))
        (cond ((or (null? lst) (<= k 0)) (take-up-to lst limit))
              (else (loop (cdr lst) (- k 1))))))

    (define (take-up-to lst n)
      (if (or (null? lst) (<= n 0))
          '()
          (cons (car lst) (take-up-to (cdr lst) (- n 1)))))

    (define (store-page s clauses offset limit)
      "Syntax: (store-page s clauses offset limit)
Library: (scm store)
Description: Returns the list of matching record keys for the AND of clauses (see
  store-query), in ascending key order, skipping offset matches and returning at
  most limit of them. With no clauses the page is generated directly without
  materialising all keys.
Example:
  (store-page s '() 0 20)"
      (let ((rows (store-query s clauses)))
        (if rows
            (list-slice rows offset limit)
            (let ((n (st-count s)))
              (let loop ((k (max 0 offset)) (taken 0) (acc '()))
                (if (or (>= k n) (>= taken limit))
                    (reverse acc)
                    (loop (+ k 1) (+ taken 1) (cons k acc))))))))

    (define (store-page-records s clauses offset limit)
      "Syntax: (store-page-records s clauses offset limit)
Library: (scm store)
Description: Like store-page, but returns a list of (rowid . payload) pairs with
  each matching record's payload read from disk. Only the page's payloads are
  loaded.
Example:
  (store-page-records s '((eq splg \"A1\")) 0 20)"
      (map (lambda (rowid) (cons rowid (store-ref s rowid)))
           (store-page s clauses offset limit)))))
