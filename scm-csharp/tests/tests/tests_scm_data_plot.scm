(import (scheme base) (scheme file) (srfi 1) (srfi 13) (scm html builder) (scm fs)
        (scm json simple) (scm geo) (scm geo topojson)
        (scm data core) (scm data format) (scm data frame) (scm data verbs) (scm data io) (scm data plot) (scm test))

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

;; --- maps ---------------------------------------------------------------

;; two unit squares side by side, the left one with a hole, and a point
(define geojson-text
  "{\"type\":\"FeatureCollection\",\"features\":[
    {\"type\":\"Feature\",\"properties\":{\"name\":\"A\",\"v\":10},
     \"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[4,4],[6,4],[6,6],[4,6],[4,4]]]}},
    {\"type\":\"Feature\",\"properties\":{\"name\":\"B\",\"v\":30},
     \"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[10,0],[20,0],[20,10],[10,10],[10,0]]]}},
    {\"type\":\"Feature\",\"properties\":{\"name\":\"C\",\"v\":null},
     \"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[20,0],[30,0],[30,10],[20,10],[20,0]]]}}]}")

;; the same two squares as a quantized topology sharing the middle edge
(define topojson-text
  "{\"type\":\"Topology\",\"transform\":{\"scale\":[1,1],\"translate\":[0,0]},
    \"objects\":{\"sq\":{\"type\":\"GeometryCollection\",\"geometries\":[
       {\"type\":\"Polygon\",\"arcs\":[[0,1]],\"properties\":{\"name\":\"A\"}},
       {\"type\":\"Polygon\",\"arcs\":[[2,-1]],\"id\":\"B\"}]}},
    \"arcs\":[[[10,0],[0,10]],[[10,10],[-10,0],[0,-10],[10,0]],[[10,0],[10,0],[0,10],[-10,0]]]}")

(define (svg-count svg s) (let loop ((i 0) (n 0)) (let ((j (string-contains svg s i))) (if j (loop (+ j 1) (+ n 1)) n))))

(test-group "geometry io"
  (let* ((dir (mktempdir))
         (gj (join-path dir "a.geojson"))
         (tj (join-path dir "b.topojson")))
    (call-with-output-file gj (lambda (o) (write-string geojson-text o)))
    (call-with-output-file tj (lambda (o) (write-string topojson-text o)))
    (let ((d (read-sf gj)))
      (test-equal '(name v geometry) (df-names d))
      (test-equal 3 (df-nrow d))
      (test-assert (na? (df-ref d 2 'v)))
      (test-equal 2 (length (geometry-parts (df-ref d 0 'geometry))))
      (test-equal "<polygon 2 rings 10 pt>" (fmt-value (df-ref d 0 'geometry)))
      ;; round trip
      (write-geojson d (join-path dir "c.geojson"))
      (test-equal '("A" "B" "C") (vector->list (df-column (read-sf (join-path dir "c.geojson")) 'name))))
    (let ((d (read-sf tj)))
      (test-equal 2 (df-nrow d))
      (test-equal "A" (df-ref d 0 'name))
      (test-equal "B" (df-ref d 1 'id)))
    ;; arcs stitched: the second square runs 10,0 -> 20,0 -> 20,10 -> 10,10 -> 10,0
    (let ((fs (topojson->features (json-read (open-input-string topojson-text)))))
      (test-equal '(sq) (map string->symbol (topojson-layers (json-read (open-input-string topojson-text)))))
      (test-equal #(10.0 0.0 20.0 0.0 20.0 10.0 10.0 10.0 10.0 0.0)
                  (car (geometry-parts (feature-geometry (cadr fs))))))))

(test-group "maps"
  (let* ((d (features->df (geojson->features (json-read (open-input-string geojson-text)))))
         (svg (html->string (plot->svg (ggplot d (aes (fill v) (label name))
                                               (geom-sf) (geom-sf-text)
                                               (scale-fill-steps (n 2) (breaks equal))
                                               (labs (title "Map")))))))
    (test-equal 3 (svg-count svg " viz-mr"))           ; three regions
    (test-assert (string-contains svg "fill-rule:evenodd"))  ; holes
    (test-assert (string-contains svg "viz-na"))        ; the region without a value
    (test-assert (string-contains svg "No data"))
    (test-assert (string-contains svg ">10 – 20<"))      ; equal classes
    (test-assert (string-contains svg ">20 – 30<"))
    (test-equal 3 (svg-count svg "viz-halo\""))         ; labels
    ;; north up: the squares' tops (y = 10) are above their bottoms
    (test-assert (string-contains svg "viz-rblue")))
  ;; categorical fill, an outline layer with data of its own, lon/lat
  (let* ((d (features->df (geojson->features (json-read (open-input-string geojson-text)))))
         (svg (html->string (plot->svg (ggplot d (aes (fill name))
                                               (geom-sf)
                                               (geom-sf (data ,(df-take d #(0))) (fill none)))))))
    (test-assert (string-contains svg "viz-s3 viz-mr"))
    (test-equal 1 (svg-count svg "\"viz-mo\"")))
  (test-assert (bytevector? (plot->pdf (ggplot (features->df (geojson->features (json-read (open-input-string geojson-text))))
                                               (aes (fill v)) (geom-sf))))))

(test-end "scm-data-plot")
