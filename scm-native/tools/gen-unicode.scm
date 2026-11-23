;; Generate runtime/unicode.zig from the Unicode Character Database.
;;
;; Usage: scm scm-native/tools/gen-unicode.scm [ucd-dir]   (default /usr/share/unicode)
;;
;; Reads UnicodeData.txt (general categories, simple case mappings, decimal
;; digit values), DerivedCoreProperties.txt (Alphabetic, Uppercase,
;; Lowercase) and CaseFolding.txt (simple case folding: statuses C and S),
;; and writes sorted tables that runtime/chars.zig searches.

(import (scheme base)
        (scheme char)
        (scheme file)
        (scheme process-context)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm fs)
        (scm string))

(define ucd-dir (if (pair? (cdr (command-line))) (cadr (command-line)) "/usr/share/unicode"))
(define native-dir (directory-name (directory-name (normalized-path (absolute-path (car (command-line)))))))
(define out-file (join-path native-dir "runtime" "unicode.zig"))

(define (ucd name) (join-path ucd-dir name))

(define (read-lines file)
  (call-with-input-file file
    (lambda (p)
      (let loop ((acc '()))
        (let ((l (read-line p)))
          (if (eof-object? l) (reverse acc) (loop (cons l acc))))))))

(define (hex s) (string->number (string-trim-both s) 16))

(define (string-trim-both s)
  (let* ((n (string-length s))
         (a (let loop ((i 0)) (if (and (< i n) (char-whitespace? (string-ref s i))) (loop (+ i 1)) i)))
         (b (let loop ((i n)) (if (and (> i a) (char-whitespace? (string-ref s (- i 1)))) (loop (- i 1)) i))))
    (substring s a b)))

;; data lines without the comment, split at ";"
(define (fields line)
  (let* ((c (let loop ((i 0)) (cond ((= i (string-length line)) i)
                                    ((char=? (string-ref line i) #\#) i)
                                    (else (loop (+ i 1))))))
         (body (substring line 0 c)))
    (if (string=? (string-trim-both body) "")
        #f
        (map string-trim-both (string-split body ";")))))

;; "0041..005A" or "0041" as (lo . hi)
(define (code-range s)
  (let ((parts (string-split s "\\.\\.")))
    (if (= (length parts) 2)
        (cons (hex (car parts)) (hex (cadr parts)))
        (cons (hex s) (hex s)))))

;; --- general categories ---------------------------------------------------------

(define categories
  '("Lu" "Ll" "Lt" "Lm" "Lo" "Mn" "Mc" "Me" "Nd" "Nl" "No" "Pc" "Pd" "Ps" "Pe" "Pi" "Pf" "Po"
    "Sm" "Sc" "Sk" "So" "Zs" "Zl" "Zp" "Cc" "Cf" "Cs" "Co" "Cn"))

(define (category-index c)
  (let loop ((l categories) (i 0))
    (cond ((null? l) (error "unknown category" c))
          ((string=? (car l) c) i)
          (else (loop (cdr l) (+ i 1))))))

(define unicode-data
  (filter-map fields (read-lines (ucd "UnicodeData.txt"))))

(define (merge-range acc lo hi cat)
  (if (and (pair? acc)
           (= (cadr (car acc)) (- lo 1))
           (= (caddr (car acc)) cat))
      (cons (list (car (car acc)) hi cat) (cdr acc))
      (cons (list lo hi cat) acc)))

;; (lo hi cat) ranges, merged where adjacent with the same category
(define category-ranges
  (let loop ((rows unicode-data) (acc '()))
    (if (null? rows)
        (reverse acc)
        (let* ((row (car rows))
               (cp (hex (list-ref row 0)))
               (name (list-ref row 1))
               (cat (category-index (list-ref row 2))))
          (if (and (> (string-length name) 7) (string=? (substring name (- (string-length name) 7) (string-length name)) ", First>"))
              (let ((last (hex (list-ref (cadr rows) 0))))
                (loop (cddr rows) (merge-range acc cp last cat)))
              (loop (cdr rows) (merge-range acc cp cp cat)))))))

;; --- simple mappings ------------------------------------------------------------------

(define (mapping field)
  (filter-map (lambda (row)
                (let ((m (list-ref row field)))
                  (and (not (string=? m ""))
                       (cons (hex (list-ref row 0)) (hex m)))))
              unicode-data))

(define upper-map (mapping 12))
(define lower-map (mapping 13))

(define fold-map
  (list-sort (lambda (a b) (< (car a) (car b)))
             (filter-map (lambda (row)
                           (and (member (cadr row) '("C" "S"))
                                (cons (hex (car row)) (hex (caddr row)))))
                         (filter-map fields (read-lines (ucd "CaseFolding.txt"))))))

(define digit-values
  (filter-map (lambda (row)
                (and (string=? (list-ref row 2) "Nd")
                     (cons (hex (list-ref row 0)) (string->number (list-ref row 6)))))
              unicode-data))

;; --- derived properties ------------------------------------------------------------

(define derived (filter-map fields (read-lines (ucd "DerivedCoreProperties.txt"))))

(define (property-ranges name)
  (let loop ((rs (list-sort (lambda (a b) (< (car a) (car b)))
                            (filter-map (lambda (row)
                                          (and (string=? (cadr row) name) (code-range (car row))))
                                        derived)))
             (acc '()))
    (cond ((null? rs) (reverse acc))
          ((and (pair? acc) (= (cdr (car acc)) (- (car (car rs)) 1)))
           (loop (cdr rs) (cons (cons (car (car acc)) (cdr (car rs))) (cdr acc))))
          (else (loop (cdr rs) (cons (car rs) acc))))))

;; --- output ------------------------------------------------------------------------------

(define (hex-string n)
  (string-append "0x" (string-upcase (number->string n 16))))

(define (write-array p name type items item->string)
  (write-string (string-append "pub const " name " = [_]" type "{\n") p)
  (let loop ((items items) (col 0))
    (unless (null? items)
      (let ((s (string-append (item->string (car items)) ",")))
        (cond ((> (+ col (string-length s) 1) 100)
               (write-string "\n    " p)
               (write-string s p)
               (loop (cdr items) (+ 4 (string-length s))))
              ((= col 0)
               (write-string "    " p)
               (write-string s p)
               (loop (cdr items) (+ 4 (string-length s))))
              (else
               (write-string " " p)
               (write-string s p)
               (loop (cdr items) (+ col 1 (string-length s))))))))
  (write-string "\n};\n\n" p))

(call-with-output-file out-file
  (lambda (p)
    (write-string "//! Generated by tools/gen-unicode.scm from the Unicode Character Database;\n" p)
    (write-string "//! do not edit. Sorted tables, searched by runtime/chars.zig.\n\n" p)
    (write-string "pub const Category = enum(u8) {" p)
    (for-each (lambda (c) (write-string " " p) (write-string c p) (write-string "," p)) categories)
    (write-string " };\n\n" p)
    (write-string "/// general category ranges: lo, hi, category (unlisted code points are Cn)\n" p)
    (write-array p "category_lo" "u21" category-ranges (lambda (r) (hex-string (car r))))
    (write-array p "category_hi" "u21" category-ranges (lambda (r) (hex-string (cadr r))))
    (write-array p "category_of" "u8" category-ranges (lambda (r) (number->string (caddr r))))
    (for-each (lambda (m)
                (let ((name (car m)) (pairs (cdr m)))
                  (write-array p (string-append name "_from") "u21" pairs (lambda (x) (hex-string (car x))))
                  (write-array p (string-append name "_to") "u21" pairs (lambda (x) (hex-string (cdr x))))))
              (list (cons "upper" upper-map) (cons "lower" lower-map) (cons "fold" fold-map)))
    (write-array p "digit_from" "u21" digit-values (lambda (x) (hex-string (car x))))
    (write-array p "digit_value" "u8" digit-values (lambda (x) (number->string (cdr x))))
    (for-each (lambda (prop)
                (let ((rs (property-ranges (car prop))))
                  (write-array p (string-append (cdr prop) "_lo") "u21" rs (lambda (r) (hex-string (car r))))
                  (write-array p (string-append (cdr prop) "_hi") "u21" rs (lambda (r) (hex-string (cdr r))))))
              '(("Alphabetic" . "alphabetic") ("Uppercase" . "uppercase") ("Lowercase" . "lowercase")))))

(display "wrote ") (display out-file) (newline)
(display (length category-ranges)) (display " category ranges, ")
(display (length upper-map)) (display " upper, ")
(display (length lower-map)) (display " lower, ")
(display (length fold-map)) (display " fold mappings") (newline)
