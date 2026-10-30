(define-library (scm data)
  (import (scheme base)
          (scheme process-context)
          (scheme time)
          (scheme write)
          (srfi 13)
          (scm data core)
          (scm data format)
          (scm data frame)
          (scm data expr)
          (scm data stats)
          (scm data verbs)
          (scm data io)
          (scm data plot)
          (scm data report))
  (export script-args
          with-timing
          ;; (scm data core)
          na na? day? ymd->day day->ymd day-number day-from-number day-year
          day-month day-weekday string->day day->string value-type column-type
          parse-cell infer-column
          ;; (scm data format)
          data-locale na-string fmt-num fmt-int fmt-pct fmt-pct-change fmt-si
          fmt-date fmt-value
          ;; (scm data frame)
          data-frame? make-df rows->df alists->df tibble empty-df df-nrow
          df-ncol df-names df-has-column? df-column df-columns df-ref df-row
          df->rows df->alists df-types df-column-type df-groups df-set-groups
          df-with-column df-with-columns df-drop-columns df-select-columns
          df-rename-columns df-take df-print df-head-string df->string
          df-glimpse
          ;; (scm data expr)
          compile-expr expr-uses-aggregate? define-df-function
          df-function-names value<? value=? all-rows
          ;; (scm data stats)
          sum mean weighted-mean median quantile var sd iqr value-range cumsum
          ranks zscore cov cor pct-change freq crosstab histogram-bins
          lm-simple
          ;; (scm data verbs)
          -> where mutate transmute summarise summarize select rename arrange
          distinct group-by tally add-count pull relocate left-join inner-join
          full-join semi-join anti-join pivot-longer pivot-wider unnest-longer
          separate drop-na replace-na fill-down fill-up ungroup head tail
          slice sample-n bind-rows bind-cols df-filter df-mutate df-transmute
          df-summarise df-select df-rename df-arrange df-distinct df-group-by
          df-ungroup df-count df-add-count df-pull df-relocate df-head df-tail
          df-slice df-sample-n df-join df-bind-rows df-bind-cols
          df-pivot-longer df-pivot-wider df-unnest-longer df-separate
          df-drop-na df-replace-na df-fill df-group-keys df-split df-map-rows
          eval-column
          ;; (scm data io)
          read-csv read-csv-string csv-for-each write-csv df->csv-string
          read-xlsx write-xlsx read-json-records write-json-records read-jsonl
          write-jsonl read-sexp-lines write-sexp-lines strings->df
          query-result->df
          ;; (scm data plot)
          ggplot make-plot plot? plot-add plot->svg plot->svg-string plot->png
          save-plot plot-css bar-chart line-chart scatter-plot histogram
          ;; (scm data report)
          report make-report report->html report->markdown write-report)
  (begin

    ;; ================================================================
    ;; (scm data) — the data-analysis toolkit in one import: frames,
    ;; expressions, verbs, statistics, formatting, IO, plots and reports
    ;; (see the individual (scm data …) libraries), plus two helpers for
    ;; analysis scripts: script-args and with-timing.
    ;; ================================================================

    ;; type of a spec entry: (key . default) infers it, (key type default) names it
    (define (entry-type e)
      (if (and (pair? (cdr e)) (symbol? (cadr e)) (pair? (cddr e)) (null? (cdddr e))
               (memq (cadr e) '(string int number bool symbol list-int list-number list-string list-symbol)))
          (cadr e)
          (let ((d (cdr e)))
            (cond ((boolean? d) 'bool)
                  ((exact-integer? d) 'int)
                  ((real? d) 'number)
                  ((symbol? d) 'symbol)
                  ((and (pair? d) (exact-integer? (car d))) 'list-int)
                  ((and (pair? d) (real? (car d))) 'list-number)
                  ((and (pair? d) (symbol? (car d))) 'list-symbol)
                  ((pair? d) 'list-string)
                  (else 'string)))))

    (define (entry-default e)
      (if (and (pair? (cdr e)) (symbol? (cadr e)) (pair? (cddr e)) (null? (cdddr e))
               (memq (cadr e) '(string int number bool symbol list-int list-number list-string list-symbol)))
          (caddr e)
          (cdr e)))

    (define (parse-arg value type key)
      (define (fail what)
        (error (string-append "argument " (symbol->string key) "=" value ": expected " what)))
      (case type
        ((bool) (cond ((member value '("yes" "true" "1" "y")) #t)
                      ((member value '("no" "false" "0" "n")) #f)
                      (else (fail "yes or no"))))
        ((int) (let ((n (string->number value))) (if (exact-integer? n) n (fail "an integer"))))
        ((number) (or (string->number value) (fail "a number")))
        ((symbol) (string->symbol value))
        ((list-int list-number list-string list-symbol)
         (let ((elem (cdr (assq type '((list-int . int) (list-number . number)
                                       (list-string . string) (list-symbol . symbol))))))
           (map (lambda (part) (parse-arg part elem key))
                (remove (lambda (s) (string=? s "")) (map string-trim-both (string-tokenize* value #\,))))))
        (else value)))

    (define (string-tokenize* s sep)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) sep) (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    (define (remove pred l) (let loop ((l l) (acc '())) (cond ((null? l) (reverse acc)) ((pred (car l)) (loop (cdr l) acc)) (else (loop (cdr l) (cons (car l) acc))))))

    (define (show-default d)
      (cond ((boolean? d) (if d "yes" "no"))
            ((null? d) "")
            ((pair? d) (let loop ((d d) (acc "")) (if (null? d) acc (loop (cdr d) (string-append acc (if (string=? acc "") "" ",") (fmt-value (car d)))))))
            ((not d) "")
            (else (fmt-value d))))

    (define (script-args spec . opts)
      "Syntax: (script-args spec [usage [args]])
Library: (scm data)
Description: Parses the script's key=value arguments. spec lists the
  arguments as (key . default), the type taken from the default: #t/#f
  yes/no, integers, numbers, symbols, comma lists (typed like the
  default's first element), strings otherwise; or as (key type default)
  with type string, int, number, bool, symbol, list-int, list-number,
  list-string or list-symbol, e.g. (out string #f) for an optional
  string. Returns the alist ((key . value) …) of all arguments.
  Unknown keys and help/--help print the usage (with the optional usage
  text) and exit. args defaults to the command line after the script.
Example:
  ;; scm report.scm years=2024,2025 out=rep
  (define args (script-args '((years . (2024 2025)) (out . \"report\") (regroup . #f))))
  (cdr (assq 'years args)) => (2024 2025)"
      (let* ((usage (and (pair? opts) (car opts)))
             (given (if (and (pair? opts) (pair? (cdr opts))) (cadr opts) (cdr (command-line))))
             (print-usage
             (lambda ()
               (when usage (display usage) (newline))
               (display "Arguments (key=value):") (newline)
               (for-each (lambda (p)
                           (display (string-append "  " (symbol->string (car p)) "=" (show-default (entry-default p))))
                           (newline))
                         spec))))
        (let loop ((args given) (acc (map (lambda (e) (cons (car e) (entry-default e))) spec)))
          (if (null? args)
              acc
              (let* ((a (car args)) (i (string-index a #\=)))
                (cond
                 ((member a '("help" "--help" "-h")) (print-usage) (exit 0))
                 ((not i) (display (string-append "unknown argument: " a)) (newline) (print-usage) (exit 2))
                 (else
                  (let* ((key (string->symbol (substring a 0 i)))
                         (value (substring a (+ i 1) (string-length a)))
                         (p (assq key spec)))
                    (unless p
                      (display (string-append "unknown argument: " (symbol->string key))) (newline)
                      (print-usage) (exit 2))
                    (loop (cdr args)
                          (map (lambda (q) (if (eq? (car q) key) (cons key (parse-arg value (entry-type p) key)) q))
                               acc))))))))))

    (define (with-timing label thunk)
      "Syntax: (with-timing label thunk)
Library: (scm data)
Description: Calls thunk, prints label and the elapsed seconds to the
  current output port, and returns thunk's result.
Example:
  (define cases (with-timing \"read\" (lambda () (read-csv \"cases.csv\"))))"
      (let* ((t0 (current-jiffy))
             (r (thunk))
             (secs (/ (- (current-jiffy) t0) (jiffies-per-second))))
        (display (string-append label ": " (fmt-num (inexact secs) 1) " s"))
        (newline)
        r))))
