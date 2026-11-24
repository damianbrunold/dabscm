;; Differential tests: random cases from a seed, each run on the JVM, on C#
;; and natively (compiled by scmc), the results compared.
;;
;; Usage: scm scm-native/difftest.scm [--seed n] [--time secs] [--cases n] [gen ...]
;;   gen: numbers, reader, strings (default: all)
;;   --seed: the first round's seed (default: from the clock); round k uses
;;     seed + k, so a reported round can be run again alone with --rounds 1
;;   --time: stop starting rounds after this many seconds (default 300)
;;   --rounds: at most this many rounds
;;   --cases: cases per generator and round (default 400)
;;   --csharp path: the C# scm (default: scm-csharp/repl/bin/Release/net10.0/scm)
;;
;; Each case is an expression; a program evaluates every case in a guard and
;; prints its values (as write writes them) or its error message. A value
;; against an error, or different values, is a divergence; errors with
;; different messages are minor and listed separately. An implementation
;; that dies (a crash, a timeout) is reported for the case it died at, and
;; the rest of its cases run again without it. Report:
;; build/difftest/report-<seed>.txt.

(import (scheme base)
        (scheme char)
        (scheme file)
        (scheme process-context)
        (scheme time)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm fs)
        (scm module)
        (scm system))

(define native-dir (directory-name (normalized-path (absolute-path (car (command-line))))))
(define base-dir (directory-name native-dir))
(module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))

(import (scm native driver))

(define build-dir (join-path native-dir "build" "difftest"))
(define seed #f)
(define time-limit 300)
(define max-rounds #f)
(define cases-per-gen 400)
(define csharp (join-path base-dir "scm-csharp" "repl" "bin" "Release" "net10.0" "scm"))
(define generators-wanted '())

(let parse ((args (cdr (command-line))))
  (cond ((null? args) #t)
        ((and (member (car args) '("--seed" "--time" "--rounds" "--cases" "--csharp")) (pair? (cdr args)))
         (let ((v (cadr args)))
           (cond ((string=? (car args) "--seed") (set! seed (string->number v)))
                 ((string=? (car args) "--time") (set! time-limit (string->number v)))
                 ((string=? (car args) "--rounds") (set! max-rounds (string->number v)))
                 ((string=? (car args) "--cases") (set! cases-per-gen (string->number v)))
                 (else (set! csharp v))))
         (parse (cddr args)))
        (else (set! generators-wanted (append generators-wanted (list (car args))))
              (parse (cdr args)))))

(unless seed (set! seed (modulo (exact (floor (current-second))) 1000000)))

;; --- a deterministic random generator (the same cases for a seed) ---------

(define rng-state 1)
(define (rng-seed! s) (set! rng-state (+ 1 (* 2654435761 (+ s 1)))) (rand 2) (rand 2))
(define (rand n)
  ;; 64-bit LCG (Knuth's MMIX constants), the high bits
  (set! rng-state (modulo (+ (* rng-state 6364136223846793005) 1442695040888963407)
                          18446744073709551616))
  (modulo (quotient rng-state 4294967296) n))
(define (pick l) (list-ref l (rand (length l))))
(define (chance n) (= 0 (rand n)))

(define (digits n) ; n random decimal digits, the first not 0
  (let loop ((i 0) (acc (list (integer->char (+ 49 (rand 9))))))
    (if (= i (- n 1))
        (list->string (reverse acc))
        (loop (+ i 1) (cons (integer->char (+ 48 (rand 10))) acc)))))

;; --- generators: each returns a list of expressions (source text) ---------

(define number-literals
  '("0" "1" "-1" "7" "-12" "255" "4611686018427387903" "4611686018427387904"
    "-4611686018427387905" "9223372036854775807" "9223372036854775808"
    "123456789012345678901234567890" "-98765432109876543210" "1/3" "-7/2" "22/7"
    "1/123456789012345678901" "0.0" "-0.0" "1.5" "-2.25" "0.1" "1e300" "1e-300"
    "4.9e-324" "1.7976931348623157e308" "+inf.0" "-inf.0" "+nan.0" "3.0" "1e21"
    "1e-7" "123456.789" "1+2i" "-1.5+0.5i" "+i" "1/2-3/4i" "2.0-0.0i" "0.5+inf.0i"))

(define (random-number)
  (case (rand 7)
    ((0 1) (pick number-literals))
    ((2) (string-append (if (chance 2) "-" "") (number->string (rand 1000))))
    ((3) (string-append (if (chance 2) "-" "") (digits (+ 15 (rand 30)))))
    ((4) (string-append (if (chance 2) "-" "") (number->string (+ 1 (rand 1000))) "/"
                        (number->string (+ 1 (rand 1000)))))
    ((5) (string-append (if (chance 2) "-" "") (digits (+ 1 (rand 4))) "." (digits (+ 1 (rand 8)))
                        (if (chance 2) (string-append "e" (number->string (- (rand 600) 300))) "")))
    (else (string-append "(make-rectangular " (random-small-number) " " (random-small-number) ")"))))

(define (random-small-number)
  (pick '("0" "1" "-2" "1/2" "0.0" "-0.0" "1.5" "-3.25" "1e10" "+inf.0")))

(define unary-ops
  '("-" "abs" "exact" "inexact" "sqrt" "exact-integer-sqrt" "floor" "ceiling" "round" "truncate"
    "numerator" "denominator" "exp" "log" "sin" "cos" "atan" "square" "number->string"
    "magnitude" "angle" "real-part" "imag-part" "exact-integer?" "integer?" "rational?"
    "real?" "nan?" "infinite?" "finite?" "zero?" "positive?" "negative?" "odd?" "even?"
    "exact?" "(lambda (x) (string->number (number->string x)))"
    "(lambda (x) (eqv? x (string->number (number->string x))))"
    "(lambda (x) (exact (floor x)))" "(lambda (x) (round (* x 1000)))"))

(define binary-ops
  '("+" "-" "*" "/" "quotient" "remainder" "modulo" "floor/" "truncate/" "floor-quotient"
    "floor-remainder" "gcd" "lcm" "min" "max" "=" "<" ">" "<=" ">=" "eqv?" "equal?" "atan"
    "make-rectangular" "make-polar" "log"))

(define (gen-numbers n)
  (list-tabulate
   n
   (lambda (i)
     (case (rand 5)
       ((0 1) (string-append "(" (pick unary-ops) " " (random-number) ")"))
       ((2 3) (string-append "(" (pick binary-ops) " " (random-number) " " (random-number) ")"))
       (else
        (case (rand 3)
          ((0) (string-append "(number->string " (random-number) " " (pick '("2" "8" "16")) ")"))
          ((1) (string-append "(expt " (random-number) " " (pick '("0" "1" "2" "3" "-1" "-2" "1/2" "0.5" "-0.5" "2.0" "0.0")) ")"))
          (else (string-append "(exact-integer-sqrt " (digits (+ 1 (rand 40))) ")"))))))))

;; texts for read: pieces of number, symbol and other syntax
(define reader-pieces
  '("0" "1" "9" "12" "+" "-" "." "e" "E" "/" "i" "#" "x" "b" "o" "d" "a" "@" "|" "\\" "\""
    ";" "(" ")" " " "n" "f" "t" "'" "`" "," ",@" "#\\" "inf.0" "nan.0" "#e" "#i" "#x" "#b"
    "#u8(" "#;" "#|" "|#" "#(" "#t" "#f" "#true" "\n" "1.5" "1/2" "e3" "s" "l" "x41;" "\\x"
    "space" "#!fold-case" "λ" "é" "..."))

(define (scheme-string-literal s)
  ;; ASCII text with \x escapes: the program's reader sees the same string
  ;; on every implementation
  (let ((out (open-output-string)))
    (write-char #\" out)
    (string-for-each
     (lambda (c)
       (let ((k (char->integer c)))
         (cond ((or (char=? c #\") (char=? c #\\) (< k 32) (> k 126))
                (write-string (string-append "\\x" (number->string k 16) ";") out))
               (else (write-char c out)))))
     s)
    (write-char #\" out)
    (get-output-string out)))

(define (gen-reader n)
  (list-tabulate
   n
   (lambda (i)
     (let loop ((k (+ 1 (rand 6))) (acc ""))
       (if (= k 0)
           (string-append "(read-all " (scheme-string-literal acc) ")")
           (loop (- k 1) (string-append acc (pick reader-pieces))))))))

(define string-chars
  ;; no characters above #xFFFF: the JVM and C# hold UTF-16 (documented)
  (append (string->list "aZ09 -_.!?")
          (map integer->char '(#xE9 #xDF #xFF #xC0 #x3A3 #x3C3 #x3C2 #x130 #x131 #xFB01 #x149
                               #x41F #x4E2D #x301 #x2163 #x660 #x1E9E #x3B0 #x10A0 #xA0 #x2028))))

(define (random-string)
  (let ((n (rand 6)))
    (scheme-string-literal (list->string (list-tabulate n (lambda (i) (pick string-chars)))))))

(define (random-char)
  (string-append "#\\x" (number->string (char->integer (pick string-chars)) 16)))

(define string-unary
  '("string-upcase" "string-downcase" "string-foldcase" "string-length" "string->list"
    "string->utf8" "(lambda (s) (utf8->string (string->utf8 s)))" "string->symbol"
    "(lambda (s) (symbol->string (string->symbol s)))" "string-copy" "string->vector"
    "(lambda (s) (string-map char-upcase s))" "(lambda (s) (string-map char-foldcase s))"
    "(lambda (s) (string->number s))" "(lambda (s) (list->string (reverse (string->list s))))"))

(define string-binary
  '("string=?" "string<?" "string>?" "string-ci=?" "string-ci<?" "string-append" "equal?"))

(define char-unary
  '("char-upcase" "char-downcase" "char-foldcase" "char-alphabetic?" "char-numeric?"
    "char-whitespace?" "char-upper-case?" "char-lower-case?" "digit-value" "char->integer"
    "(lambda (c) (string c))" "(lambda (c) (string-upcase (string c)))"))

(define (gen-strings n)
  (list-tabulate
   n
   (lambda (i)
     (case (rand 5)
       ((0 1) (string-append "(" (pick string-unary) " " (random-string) ")"))
       ((2) (string-append "(" (pick string-binary) " " (random-string) " " (random-string) ")"))
       ((3) (string-append "(" (pick char-unary) " " (random-char) ")"))
       (else (string-append "(substring " (random-string) " " (number->string (rand 4)) " "
                            (number->string (rand 6)) ")"))))))

(define generators
  (list (cons "numbers" gen-numbers) (cons "reader" gen-reader) (cons "strings" gen-strings)))

;; --- programs and runs ------------------------------------------------------

(define prelude "(import (scheme base) (scheme char) (scheme complex) (scheme inexact) (scheme read) (scheme write))
(define (written v) (let ((p (open-output-string))) (write v p) (get-output-string p)))
(define (read-all s)
  (let ((p (open-input-string s)))
    (let loop ((acc '()))
      (let ((d (read p)))
        (if (eof-object? d) (reverse acc) (loop (cons d acc)))))))
(define (show i thunk)
  (let ((r (guard (e (#t (list 'error (if (error-object? e) (error-object-message e) (written e)))))
             (cons 'ok (map written (call-with-values thunk list))))))
    (display i) (display \" \") (write r) (newline)))
")

;; the program of cases ((index . text) ...)
(define (write-program file cases)
  (call-with-output-file file
    (lambda (p)
      (write-string prelude p)
      (for-each (lambda (c)
                  (write-string (string-append "(show " (number->string (car c)) " (lambda () "
                                               (cdr c) "))\n")
                                p))
                cases))))

(define (with-timeout secs cmd)
  (if (eq? (sys-platform) 'windows) cmd (append (list "timeout" (number->string secs)) cmd)))

;; Run cases on an implementation: an alist index -> result text. Where it
;; dies, the case is recorded as (crash ...) and the later ones run again.
(define (run-impl impl cases tag)
  (let loop ((cases cases) (acc '()) (part 0))
    (if (null? cases)
        acc
        (let* ((prog (join-path build-dir (string-append tag "-" impl "-" (number->string part) ".scm")))
               (_ (write-program prog cases))
               (r (guard (e (#t (list 99 "" (if (error-object? e) (error-object-message e) "failed"))))
                    (run-impl-program impl prog)))
               (lines (parse-output (cadr r)))
               (acc (append lines acc))
               (missing (filter (lambda (c) (not (assv (car c) lines))) cases)))
          (if (null? missing)
              acc
              (let ((dead (car missing)))
                (loop (cdr missing)
                      (cons (cons (car dead)
                                  (string-append "(crash " (number->string (car r)) " "
                                                 (first-line (caddr r)) ")"))
                            acc)
                      (+ part 1))))))))

(define (first-line s)
  (let loop ((i 0))
    (cond ((= i (string-length s)) (if (> i 120) (substring s 0 120) s))
          ((or (char=? (string-ref s i) #\newline) (= i 120)) (substring s 0 i))
          (else (loop (+ i 1))))))

(define (run-impl-program impl prog)
  (cond ((string=? impl "jvm") (run-program/capture (with-timeout 300 (list "scm" prog))))
        ((string=? impl "csharp") (run-program/capture (with-timeout 300 (list csharp prog))))
        (else
         (let ((exe (string-append prog ".exe")))
           (compile-program prog exe native-dir '())
           (run-program/capture (with-timeout 300 (list exe)))))))

;; "17 (ok \"3\")" lines -> ((17 . "(ok \"3\")") ...)
(define (parse-output out)
  (filter-map
   (lambda (line)
     (let ((sp (let loop ((i 0)) (cond ((= i (string-length line)) #f)
                                        ((char=? (string-ref line i) #\space) i)
                                        (else (loop (+ i 1)))))))
       (and sp (let ((n (string->number (substring line 0 sp))))
                 (and n (cons n (substring line (+ sp 1) (string-length line))))))))
   (string-split out "\n")))

(define (string-split s sep)
  (let loop ((i 0) (start 0) (acc '()))
    (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
          ((string=? (substring s i (+ i 1)) sep) (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else (loop (+ i 1) start acc)))))

;; --- comparison ---------------------------------------------------------------

(define (prefix? p s) (and (>= (string-length s) (string-length p)) (string=? p (substring s 0 (string-length p)))))
(define (error-result? r) (prefix? "(error " r))

;; 'same, 'minor (errors with different messages) or 'major
(define (compare-results rs)
  (cond ((every (lambda (r) (string=? r (car rs))) rs) 'same)
        ((every error-result? rs) 'minor)
        (else 'major)))

(define impls '("jvm" "csharp" "native"))
(define divergences '()) ; (kind gen case-text (impl . result) ...)

(define (round! k)
  (rng-seed! (+ seed k))
  (for-each
   (lambda (g)
     (when (or (null? generators-wanted) (member (car g) generators-wanted))
       (let* ((texts ((cdr g) cases-per-gen))
              (cases (map cons (iota (length texts)) texts))
              (tag (string-append (car g) "-" (number->string (+ seed k))))
              (results (map (lambda (impl) (cons impl (run-impl impl cases tag))) impls))
              (major 0) (minor 0))
         (for-each
          (lambda (c)
            (let* ((rs (map (lambda (impl)
                              (cond ((assv (car c) (cdr (assoc impl results))) => cdr)
                                    (else "(missing)")))
                            impls))
                   (kind (compare-results rs)))
              (unless (eq? kind 'same)
                (if (eq? kind 'major) (set! major (+ major 1)) (set! minor (+ minor 1)))
                (set! divergences (cons (list kind (car g) (+ seed k) (cdr c) rs) divergences)))))
          cases)
         (display (string-append "seed " (number->string (+ seed k)) " " (car g) ": "
                                 (number->string (length cases)) " cases, "
                                 (number->string major) " divergences, "
                                 (number->string minor) " minor"))
         (newline))))
   generators))

;; divergences grouped by the operation (the case's first word) and the
;; pattern of results: a few examples each
(define (case-key d)
  (let* ((text (list-ref d 3))
         (op (let loop ((i 1)) (if (or (= i (string-length text)) (memv (string-ref text i) '(#\space #\))))
                                   (substring text 0 i) (loop (+ i 1))))))
    (string-append (symbol->string (car d)) " " (cadr d) " " op " "
                   (let ((rs (list-ref d 4)))
                     (apply string-append (map (lambda (r) (if (error-result? r) "E" "v")) rs))))))

(define (write-report file)
  (let ((groups '()))
    (for-each (lambda (d)
                (let* ((k (case-key d)) (g (assoc k groups)))
                  (if g (set-cdr! g (cons d (cdr g))) (set! groups (cons (list k d) groups)))))
              (reverse divergences))
    (call-with-output-file file
      (lambda (p)
        (for-each
         (lambda (g)
           (write-string (string-append "== " (car g) " (" (number->string (length (cdr g))) ")\n") p)
           (for-each (lambda (d)
                       (write-string (string-append "  [seed " (number->string (list-ref d 2)) "] "
                                                    (list-ref d 3) "\n") p)
                       (for-each (lambda (impl r) (write-string (string-append "    " impl ": " r "\n") p))
                                 impls (list-ref d 4)))
                     (let ((l (reverse (cdr g)))) (if (> (length l) 3) (take l 3) l))))
         (list-sort (lambda (a b) (string<? (car a) (car b))) groups))))
    (length groups)))

(define (make-directories dir)
  (unless (directory-exists? dir)
    (make-directories (directory-name dir))
    (make-directory dir)))

(make-directories build-dir)
(define start (current-second))
(let loop ((k 0))
  (when (and (< (- (current-second) start) time-limit) (or (not max-rounds) (< k max-rounds)))
    (round! k)
    (loop (+ k 1))))
(let* ((report (join-path build-dir (string-append "report-" (number->string seed) ".txt")))
       (n (write-report report)))
  (display (string-append (number->string (length divergences)) " divergent cases in "
                          (number->string n) " groups: " report))
  (newline))
