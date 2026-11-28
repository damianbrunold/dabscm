---
title: "(scm data stats) and (scm data format): describing data"
part: libraries
order: 1035
libraries: (scm data stats) (scm data format)
summary: Mean, median, quantiles, spread, weighted means, ranks and z-scores, correlation and a straight-line fit; frequency tables, crosstabs and histogram bins as data frames; summary statistics per group; formatting numbers, percentages and changes for reports, with Swiss or other separators.
---
# (scm data stats) and (scm data format): describing data

- `(scm data stats)` computes descriptive statistics on lists and
  vectors, and frequency tables as data frames.
- `(scm data format)` writes numbers the way reports show them.

Hypothesis tests and linear models are in the [next
chapter](scm-data-tests.md).

```scheme
(import (scheme base) (scheme write) (scm data))

;; brewing times in minutes that ten customers chose for the same tea
(define brew '(3.0 3.5 2.5 4.0 3.0 5.5 3.0 2.0 4.5 3.0))
```

## Centre and spread

```scheme
(mean brew)                                 ;; => 3.4
(median brew)                               ;; => 3.0
(quantile brew 0.25)                        ;; => 3.0
(quantile brew '(0.1 0.9))                  ;; => (2.45 4.6)
(value-range brew)                          ;; => (2.0 5.5)
(iqr brew)                                  ;; => 0.875
(define (round3 x) (/ (round (* 1000 x)) 1000))
(round3 (sd brew))                          ;; => 1.022
(round3 (var brew))                         ;; => 1.044
```

- The mean is pulled up by the one customer who brews 5.5 minutes; the
  median is not, which is why reports on skewed data (incomes, waiting
  times) give the median.
- `quantile` computes as R does by default (type 7), so results match
  an R analysis of the same data.
- `sd` and `var` divide by n − 1, the sample estimates.

All of them accept lists or vectors (a data frame column) and skip `na`:

```scheme
(mean (vector 1 2 na 3))                    ;; => 2.0
(sum (list 10 na 5))                        ;; => 15
```

A weighted mean, for example the average price per kilogram over what
was sold:

```scheme
(weighted-mean '(48 22 160) '(2.5 5 0.5))  ;; => 38.75
```

## Ranks, standard scores, change

```scheme
(ranks '(30 10 20 10))                      ;; => (4 1.5 3 1.5)
(zscore '(1 2 3))                           ;; => (-1.0 0.0 1.0)
(cumsum '(1 2 3))                           ;; => (1 3 6)
(pct-change 80 100)                         ;; => 0.25
```

Ties share the average rank, as in R. `zscore` says how many standard
deviations each value is from the mean, which puts measurements of
different sizes on one scale.

## Two variables

```scheme
(define temperature '(70 75 80 85 90 95))    ; water temperature in °C
(define bitterness '(2 3 3 5 6 8))            ; tasters' score

(round3 (cor temperature bitterness))       ;; => 0.97
(round3 (cor temperature bitterness 'spearman)) ;; => 0.986
(map (lambda (p) (cons (car p) (round3 (cdr p)))) (lm-simple temperature bitterness))
;; => ((intercept . -14.829) (slope . 0.234) (r2 . 0.942) (n . 6))
```

Pearson's correlation measures a straight-line relationship, Spearman's
any steadily rising one (it correlates the ranks). `lm-simple` fits a
straight line: each degree adds about 0.23 points of bitterness. For
several predictors, confidence intervals and p-values, use `lm` from
[the tests chapter](scm-data-tests.md).

## Frequency tables and crosstabs

These return data frames, ready for `df-print`, a report table or a
chart:

```scheme
(define orders '("Sencha" "Assam" "Sencha" "Matcha" "Sencha" "Assam"))

(df-print (freq orders 'by-count))
;; prints: # A data frame: 3 × 3
;; prints:   value       n   share
;; prints:   <chr>   <int>   <dbl>
;; prints: 1 Sencha      3     0.5
;; prints: 2 Assam       2  0.3333
;; prints: 3 Matcha      1  0.1667

(df-print (crosstab '("Zurich" "Bern" "Zurich" "Basel") '("Sencha" "Assam" "Assam" "Sencha")))
;; prints: # A data frame: 3 × 3
;; prints:   row     Assam  Sencha
;; prints:   <chr>   <int>   <int>
;; prints: 1 Basel       0       1
;; prints: 2 Bern        1       0
;; prints: 3 Zurich      1       1
```

Without `'by-count`, `freq` sorts by value. `histogram-bins` counts
values in equal-width bins:

```scheme
(df-print (histogram-bins brew 4))
;; prints: # A data frame: 4 × 3
;; prints:    from     to      n
;; prints:   <dbl>  <dbl>  <int>
;; prints: 1     2  2.875      2
;; prints: 2 2.875   3.75      5
;; prints: 3  3.75  4.625      2
;; prints: 4 4.625    5.5      1
```

## Statistics per group

The same functions work inside the verbs, per group:

```scheme
(define tastings
  (tibble (tea "Sencha" "Sencha" "Sencha" "Assam" "Assam" "Assam" "Assam")
          (score 7 8 6 5 9 6 7)))

(df-print (-> tastings
              (group-by tea)
              (summarise (n (n)) (mean (mean score)) (median (median score)) (sd (sd score)))))
;; prints: # A data frame: 2 × 5
;; prints:   tea         n   mean  median      sd
;; prints:   <chr>   <int>  <dbl>   <dbl>   <dbl>
;; prints: 1 Assam       4   6.75     6.5  1.7078
;; prints: 2 Sencha      3      7       7       1
```

`df-print` rounds what it shows to a few digits; the frame keeps the
full values.

## Formatting for reports

Tables and texts in reports need numbers formatted: thousands
separators, a fixed number of decimals, percentages. Rounding is half
away from zero, on the number as written:

```scheme
(fmt-num 24973.25 1)                        ;; => "24'973.3"
(fmt-num 2.675 2)                           ;; => "2.68"
(fmt-int 1234567)                           ;; => "1'234'567"
(fmt-pct 0.2345)                            ;; => "23.5 %"
(fmt-pct 0.2345 0)                          ;; => "23 %"
(fmt-pct-change 20316 24973)                ;; => "+23 %"
(fmt-pct-change 100 96)                     ;; => "-4 %"
(fmt-si 2500000)                            ;; => "2.5M"
(fmt-num na 1)                              ;; => "NA"
(fmt-date (ymd->day 2025 3 7))              ;; => "2025-03-07"
```

(2.675 is stored as a binary number slightly below 2.675; a plain
rounding of that value would give 2.67, which nobody reading "2.675"
expects.)

The separators come from the parameter `data-locale`, Swiss by default;
`na-string` sets the text for missing values:

```scheme
(parameterize ((data-locale '((thousands . ",") (decimal . ".")))) (fmt-num 1234.5 1)) ;; => "1,234.5"
(parameterize ((data-locale '((thousands . ".") (decimal . ",")))) (fmt-num 1234.5 1)) ;; => "1.234,5"
(parameterize ((na-string "–")) (fmt-num na))                                         ;; => "–"
```

Formatting is the last step: compute with numbers, format when writing
the report, so that sums and sorting still work on the values.

## Where next

- [Hypothesis tests and linear models](scm-data-tests.md),
  [charts](scm-data-plot.md), [reports](scm-data-report.md).
- Reference: `(scm data stats)`, `(scm data format)`.
