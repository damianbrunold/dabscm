(import (scheme base) (srfi 1) (srfi 13) (scm html builder)
        (scm data core) (scm data frame) (scm data verbs) (scm data plot) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-plot")

(define pts (tibble (splg 'BEW8 'GYN2 'BEW8 'GYN2)
                    (model 'v1 'v1 'v2 'v2)
                    (points 6441 1728 8694 1994)))

(define (svg p) (html->string (plot->svg p)))
(define (count-of s sub)
  (let loop ((i 0) (n 0))
    (let ((j (string-contains s sub i)))
      (if j (loop (+ j 1) (+ n 1)) n))))

(test-group "bars"
  (let ((s (svg (ggplot pts (aes (x splg) (y points) (fill model))
                  (geom-col (position dodge) (labels #t))
                  (labs (title "MFZO points") (y "Points"))))))
    (test-assert (string-prefix? "<svg" s))
    (test-assert (string-contains s "MFZO points"))
    ;; four bars in two colours (+ one legend swatch each), with tooltips
    (test-equal 3 (count-of s "class=\"viz-s1\""))
    (test-equal 3 (count-of s "class=\"viz-s2\""))
    (test-assert (string-contains s "<title>BEW8, v2: 8&#39;694</title>"))
    ;; value labels in full, legend with both keys
    (test-assert (string-contains s ">6&#39;441<"))
    (test-assert (string-contains s ">v1<"))
    (test-assert (string-contains s ">v2<"))
    ;; data below 10,000: full axis numbers
    (test-assert (string-contains s ">8&#39;000<")))
  ;; one series: no legend
  (let ((s (svg (ggplot (where pts (= model 'v1)) (aes (x splg) (y points) (fill model)) (geom-col)))))
    (test-assert (not (string-contains s ">v1<"))))
  ;; stacked: the axis reaches the stack total and switches to compact labels
  (let ((s (svg (ggplot pts (aes (x splg) (y points) (fill model)) (geom-col)))))
    (test-assert (string-contains s ">15k<")))
  ;; fill: percent axis
  (test-assert (string-contains (svg (ggplot pts (aes (x splg) (y points) (fill model)) (geom-col (position fill))))
                                "100 %"))
  ;; geom-bar counts rows
  (test-assert (string-contains (svg (ggplot pts (aes (x splg)) (geom-bar))) "<title>BEW8: 2</title>")))

(test-group "other geoms"
  (let* ((ts (tibble (year 2019 2020 2021 2019 2020 2021) (k 'a 'a 'a 'b 'b 'b) (n 1 2 3 3 2 1)))
         (s (svg (ggplot ts (aes (x year) (y n) (color k)) (geom-line) (geom-point)))))
    ;; one line per series (+ legend key), dots with a surface ring
    (test-equal 2 (count-of s "class=\"viz-l1\""))
    (test-equal 2 (count-of s "class=\"viz-l2\""))
    (test-equal 8 (count-of s "viz-ring\""))
    ;; years without thousands separator
    (test-assert (string-contains s ">2020<")))
  (test-assert (string-contains (svg (ggplot pts (aes (x splg) (y points)) (geom-boxplot))) "median"))
  (test-assert (string-contains (svg (histogram (tibble (x 1 2 2 3 7)) 'x 3)) "viz-s1"))
  (test-assert (string-contains (svg (ggplot pts (aes (x splg) (y points)) (geom-col) (geom-hline (yintercept 5000))))
                                "viz-ref"))
  (test-assert (string-contains (svg (ggplot pts (aes (x splg) (y points) (label model)) (geom-text))) ">v2<"))
  (let ((s (svg (ggplot pts (aes (x model) (y points)) (geom-col) (facet-wrap splg)))))
    (test-assert (string-contains s ">BEW8<"))
    (test-assert (string-contains s ">GYN2<"))))

(test-group "layout and output"
  (let ((s (svg (ggplot pts (aes (x splg) (y points)) (geom-col) (theme (width 500) (height 300))))))
    (test-assert (string-contains s "width=\"500\""))
    (test-assert (string-contains s "viewBox=\"0 0 500 300\"")))
  ;; long labels on a vertical bar chart are rotated
  (test-assert (string-contains (svg (ggplot (tibble (x "a very long category name" "another long category name, too")
                                                     (y 1 2))
                                       (aes (x x) (y y)) (geom-col) (theme (width 300))))
                                "rotate(-40"))
  (test-assert (string-prefix? "<?xml" (plot->svg-string (bar-chart pts 'splg 'points 'model))))
  (let ((png (plot->png (line-chart pts 'splg 'points 'model) 1)))
    (test-assert (bytevector? png))
    (test-equal 137 (bytevector-u8-ref png 0)))
  (test-assert (string-contains (plot-css) "prefers-color-scheme: dark"))
  (test-error (svg (ggplot pts (aes (x splg) (y points)))))
  (test-error (svg (ggplot (tibble (x 1 2 3 4 5 6 7 8 9) (y 1 2 3 4 5 6 7 8 9) (f 'a 'b 'c 'd 'e 'f 'g 'h 'i))
                     (aes (x x) (y y) (fill f)) (geom-col)))))

(test-end "scm-data-plot")
