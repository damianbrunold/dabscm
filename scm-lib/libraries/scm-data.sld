(define-library (scm data)
  (import (scheme base)
          (scheme process-context)
          (scheme time)
          (scheme write)
          (srfi 13)
          (scm data core)
          (scm data expr)
          (scm data format)
          (scm data frame)
          (scm data io)
          (scm data plot)
          (scm data report)
          (scm data stats)
          (scm data tests)
          (scm data verbs))
  (export script-args
          with-timing
          ;; (scm data core)
          column-type
          day->string
          day->ymd
          day-from-number
          day-month
          day-number
          day-weekday
          day-year
          day?
          infer-column
          na
          na?
          parse-cell
          string->day
          value-type
          ymd->day
          ;; (scm data format)
          data-locale
          fmt-date
          fmt-int
          fmt-num
          fmt-pct
          fmt-pct-change
          fmt-si
          fmt-value
          na-string
          ;; (scm data frame)
          alists->df
          data-frame?
          df->alists
          df->rows
          df->string
          df-column
          df-column-type
          df-columns
          df-drop-columns
          df-glimpse
          df-groups
          df-has-column?
          df-head-string
          df-names
          df-ncol
          df-nrow
          df-print
          df-ref
          df-rename-columns
          df-row
          df-select-columns
          df-set-groups
          df-take
          df-types
          df-with-column
          df-with-columns
          empty-df
          make-df
          rows->df
          tibble
          ;; (scm data expr)
          all-rows
          compile-expr
          define-df-function
          df-function-names
          expr-uses-aggregate?
          value<?
          value=?
          ;; (scm data stats)
          cor
          cov
          crosstab
          cumsum
          freq
          histogram-bins
          iqr
          lm-simple
          mean
          median
          pct-change
          quantile
          ranks
          sd
          sum
          value-range
          var
          weighted-mean
          zscore
          ;; (scm data tests)
          binom-test
          chisq-test
          cor-test
          dF
          dbeta
          dbinom
          dchisq
          dnorm
          dpois
          dt
          fisher-test
          htest->string
          htest-alternative
          htest-conf-int
          htest-conf-level
          htest-data-name
          htest-estimate
          htest-extra
          htest-method
          htest-null-value
          htest-p-value
          htest-parameter
          htest-print
          htest-ref
          htest-statistic
          htest?
          kruskal-test
          ks-test
          lbeta
          lchoose
          lgamma
          lm
          lm->string
          lm-coefficients
          lm-fitted
          lm-print
          lm-residuals
          lm-summary
          lm?
          oneway-test
          p-adjust
          pbeta
          pbeta-regularized
          pbinom
          pchisq
          pf
          pgamma-regularized
          pnorm
          ppois
          predict
          prop-test
          pt
          qbeta
          qbinom
          qchisq
          qf
          qnorm
          qt
          shapiro-test
          t-test
          tidy
          wilcox-test
          ;; (scm data verbs)
          ->
          add-count
          anti-join
          arrange
          bind-cols
          bind-rows
          df-add-count
          df-arrange
          df-bind-cols
          df-bind-rows
          df-count
          df-distinct
          df-drop-na
          df-fill
          df-filter
          df-group-by
          df-group-keys
          df-head
          df-join
          df-map-rows
          df-mutate
          df-pivot-longer
          df-pivot-wider
          df-pull
          df-relocate
          df-rename
          df-replace-na
          df-sample-n
          df-select
          df-separate
          df-slice
          df-split
          df-summarise
          df-tail
          df-transmute
          df-ungroup
          df-unnest-longer
          distinct
          drop-na
          eval-column
          fill-down
          fill-up
          full-join
          group-by
          head
          inner-join
          left-join
          mutate
          pivot-longer
          pivot-wider
          pull
          relocate
          rename
          replace-na
          sample-n
          select
          semi-join
          separate
          slice
          summarise
          summarize
          tail
          tally
          transmute
          ungroup
          unnest-longer
          where
          ;; (scm data io)
          csv-for-each
          df->csv-string
          df->features
          features->df
          query-result->df
          read-csv
          read-csv-string
          read-json-records
          read-jsonl
          read-sexp-lines
          read-sf
          read-xlsx
          strings->df
          write-csv
          write-geojson
          write-json-records
          write-jsonl
          write-sexp-lines
          write-xlsx
          ;; (scm data plot)
          bar-chart
          ggplot
          histogram
          line-chart
          make-plot
          plot->pdf
          plot->png
          plot->svg
          plot->svg-string
          plot-add
          plot-css
          plot?
          save-plot
          scatter-plot
          ;; (scm data report)
          make-report
          report
          report->html
          report->markdown
          report->pdf
          write-report)
  (begin

    ;; ================================================================
    ;; (scm data) — the data-analysis toolkit in one import: frames,
    ;; expressions, verbs, statistics, hypothesis tests, formatting, IO,
    ;; plots and maps, reports (see the individual (scm data …)
    ;; libraries), plus two helpers for analysis scripts: script-args and
    ;; with-timing. (scm data r), imported on its own, translates code
    ;; between R and (scm data).
    ;; ================================================================

    ;; type of a spec entry: (key . default) infers it, (key type default) names it
    (define (entry-type e)
      (if (and (pair? (cdr e))
               (symbol? (cadr e))
               (pair? (cddr e))
               (null? (cdddr e))
               (memq (cadr e)
                     '(string int number bool symbol list-int list-number
                       list-string list-symbol)))
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
      (if (and (pair? (cdr e))
               (symbol? (cadr e))
               (pair? (cddr e))
               (null? (cdddr e))
               (memq (cadr e)
                     '(string int number bool symbol list-int list-number
                       list-string list-symbol)))
          (caddr e)
          (cdr e)))

    (define (parse-arg value type key)
      (define (fail what)
        (error (string-append "argument "
                              (symbol->string key)
                              "="
                              value
                              ": expected "
                              what)))
      (case type
        ((bool)
         (cond ((member value '("yes" "true" "1" "y")) #t)
               ((member value '("no" "false" "0" "n")) #f)
               (else (fail "yes or no"))))
        ((int)
         (let ((n (string->number value)))
           (if (exact-integer? n) n (fail "an integer"))))
        ((number) (or (string->number value) (fail "a number")))
        ((symbol) (string->symbol value))
        ((list-int list-number list-string list-symbol)
         (let
             ((elem (cdr (assq type
                               '((list-int . int)
                                 (list-number . number)
                                 (list-string . string)
                                 (list-symbol . symbol))))))
           (map (lambda (part) (parse-arg part elem key))
                (remove (lambda (s) (string=? s ""))
                        (map string-trim-both
                             (string-tokenize* value #\,))))))
        (else value)))

    (define (string-tokenize* s sep)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s))
               (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) sep)
               (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    (define (remove pred l)
      (let loop ((l l) (acc '()))
        (cond ((null? l) (reverse acc))
              ((pred (car l)) (loop (cdr l) acc))
              (else (loop (cdr l) (cons (car l) acc))))))

    (define (show-default d)
      (cond ((boolean? d) (if d "yes" "no"))
            ((null? d) "")
            ((pair? d)
             (let loop ((d d) (acc ""))
               (if (null? d)
                   acc
                   (loop (cdr d)
                         (string-append acc
                                        (if (string=? acc "") "" ",")
                                        (fmt-value (car d)))))))
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
             (given (if (and (pair? opts) (pair? (cdr opts)))
                        (cadr opts)
                        (cdr (command-line))))
             (print-usage (lambda ()
                            (when usage
                              (display usage)
                              (newline))
                            (display "Arguments (key=value):")
                            (newline)
                            (for-each (lambda (p)
                                        (display
                                         (string-append
                                          "  "
                                          (symbol->string (car p))
                                          "="
                                          (show-default (entry-default p))))
                                        (newline))
                                      spec))))
        (let loop ((args given)
                   (acc (map (lambda (e) (cons (car e) (entry-default e)))
                             spec)))
          (if (null? args)
              acc
              (let* ((a (car args))
                     (i (string-index a #\=)))
                (cond ((member a '("help" "--help" "-h"))
                       (print-usage)
                       (exit 0))
                      ((not i)
                       (display (string-append "unknown argument: " a))
                       (newline)
                       (print-usage)
                       (exit 2))
                      (else (let* ((key (string->symbol (substring a 0 i)))
                                   (value
                                    (substring a (+ i 1) (string-length a)))
                                   (p (assq key spec)))
                              (unless p
                                (display
                                 (string-append "unknown argument: "
                                                (symbol->string key)))
                                (newline)
                                (print-usage)
                                (exit 2))
                              (loop (cdr args)
                                    (map
                                     (lambda (q)
                                       (if
                                        (eq? (car q) key)
                                        (cons
                                         key
                                         (parse-arg value (entry-type p) key))
                                        q))
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
