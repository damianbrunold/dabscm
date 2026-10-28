(import (scheme base)
        (scheme inexact)
        (scm test)
        (scm raster))

(test-runner-factory scm-test-runner)

(test-begin "scm raster")

(define white (rgba 255 255 255))
(define black (rgba 0 0 0))
(define red (rgba 255 0 0))

(define (pixel c x y) (canvas-ref c x y))
(define (red? c x y) (equal? '(255 0 0 255) (pixel c x y)))
(define (white? c x y) (equal? '(255 255 255 255) (pixel c x y)))

;; how much of the canvas is not white, in pixels (fractional coverage
;; counted by its darkness on a red or black fill)
(define (ink c)
  (let ((w (canvas-width c)) (h (canvas-height c)))
    (let loop ((x 0) (y 0) (sum 0.0))
      (cond ((= y h) sum)
            ((= x w) (loop 0 (+ y 1) sum))
            (else (loop (+ x 1) y
                        (+ sum (/ (- 255 (cadr (pixel c x y))) 255.0))))))))

(test-group "canvas"
  (let ((c (make-canvas 3 2)))
    (test-equal 3 (canvas-width c))
    (test-equal 2 (canvas-height c))
    (test-equal 24 (bytevector-length (canvas-pixels c)))
    (test-equal '(0 0 0 0) (pixel c 2 1)))
  (test-equal '(10 20 30 255) (pixel (make-canvas 1 1 (rgba 10 20 30)) 0 0))
  (test-equal '(0 0 0 128) (pixel (make-canvas 1 1 (rgba 0 0 0 0.5)) 0 0)))

(test-group "transforms"
  (test-equal '(6.0 . 2.0) (transform-apply (transform-translate 5 1) 1 1))
  (test-equal '(6.0 . 8.0) (transform-apply (transform-scale 2) 3 4))
  (test-equal '(2.0 . 3.0) (transform-apply (transform-scale 2 3) 1 1))
  ;; n first, then m
  (test-equal '(12.0 . 0.0)
              (transform-apply (transform-multiply (transform-translate 10 0) (transform-scale 2))
                               1 0))
  (let ((p (transform-apply (transform-rotate 90) 1 0)))
    (test-assert (< (abs (car p)) 1e-9))
    (test-assert (< (abs (- (cdr p) 1)) 1e-9))))

(test-group "fill: pixel-aligned rectangle"
  (let ((c (make-canvas 10 10 white)))
    (canvas-fill-path! c (path-rect 2 2 4 3) red)
    (test-assert (red? c 2 2))
    (test-assert (red? c 5 4))
    (test-assert (white? c 6 4))
    (test-assert (white? c 5 5))
    (test-assert (white? c 1 2))
    ;; exactly 12 pixels covered
    (test-approximate 12.0 (let loop ((x 0) (y 0) (n 0))
                             (cond ((= y 10) n)
                                   ((= x 10) (loop 0 (+ y 1) n))
                                   (else (loop (+ x 1) y (if (red? c x y) (+ n 1) n)))))
                      0.001)))

(test-group "fill: anti-aliasing"
  ;; a rectangle covering half of each pixel in a column
  (let ((c (make-canvas 4 4 white)))
    (canvas-fill-path! c (path-rect 1.5 0 1 4) black)
    (let ((p (pixel c 1 1)))
      (test-assert (< 120 (car p) 135)))          ; half black
    (test-approximate 4.0 (ink c) 0.05))
  ;; the area of a circle, within a few percent
  (let ((c (make-canvas 40 40 white)))
    (canvas-fill-path! c (path-circle 20 20 15) black)
    (test-approximate (* 3.14159265 15 15) (ink c) 8.0)))

(test-group "fill rules"
  ;; two nested squares wound the same way: one shape with non-zero,
  ;; a hole with even-odd
  (let ((rings (append (path-rect 0 0 10 10) (path-rect 3 3 4 4))))
    (let ((c (make-canvas 10 10 white)))
      (canvas-fill-path! c rings red)
      (test-assert (red? c 5 5)))
    (let ((c (make-canvas 10 10 white)))
      (canvas-fill-path! c rings red '((fill-rule . evenodd)))
      (test-assert (white? c 5 5))
      (test-assert (red? c 1 1)))))

(test-group "fill: opacity, transform, paint procedures"
  (let ((c (make-canvas 4 4 white)))
    (canvas-fill-path! c (path-rect 0 0 4 4) (rgba 0 0 0 0.5))
    (test-equal '(128 128 128 255) (pixel c 0 0)))
  (let ((c (make-canvas 4 4 white)))
    (canvas-fill-path! c (path-rect 0 0 4 4) black '((opacity . 0.5)))
    (test-equal '(128 128 128 255) (pixel c 0 0)))
  ;; source over a transparent canvas keeps the colour, sets the alpha
  (let ((c (make-canvas 2 2)))
    (canvas-fill-path! c (path-rect 0 0 2 2) (rgba 200 100 0 0.5))
    (test-equal '(200 100 0 128) (pixel c 0 0)))
  (let ((c (make-canvas 10 10 white)))
    (canvas-fill-path! c (path-rect 0 0 2 2) red
                       (list (cons 'transform (transform-multiply (transform-translate 4 4)
                                                                  (transform-scale 2)))))
    (test-assert (red? c 4 4))
    (test-assert (red? c 7 7))
    (test-assert (white? c 8 8)))
  (let ((c (make-canvas 4 1 white)))
    (canvas-fill-path! c (path-rect 0 0 4 1)
                       (lambda (x y) (if (< x 2) red black)))
    (test-assert (red? c 1 0))
    (test-equal '(0 0 0 255) (pixel c 2 0))))

(test-group "curves"
  ;; a quadratic arch and its chord: the area between is 2/3 * base *
  ;; height; the flattened curve lies inside it, so a little less
  (let ((c (make-canvas 40 30 white)))
    (canvas-fill-path! c '((M 0 25) (Q 20 -15 40 25) (Z)) black)
    (test-approximate (* 2/3 40 20) (ink c) 12.0))
  (let ((c (make-canvas 40 40 white)))
    (canvas-fill-path! c '((M 5 35) (C 5 5 35 5 35 35) (Z)) black)
    (test-assert (> (ink c) 400))))

(test-group "strokes"
  ;; a horizontal line two pixels wide, on pixel boundaries
  (let ((c (make-canvas 10 6 white)))
    (canvas-stroke-path! c '((M 1 3) (L 9 3)) red '((width . 2)))
    (test-assert (red? c 1 2))
    (test-assert (red? c 8 3))
    (test-assert (white? c 9 3))                 ; butt cap
    (test-assert (white? c 4 1)))
  (let ((c (make-canvas 12 6 white)))
    (canvas-stroke-path! c '((M 2 3) (L 9 3)) red '((width . 2) (cap . square)))
    (test-assert (red? c 1 3))
    (test-assert (red? c 9 3)))
  ;; overlapping pieces of one stroke do not darken each other
  (let ((c (make-canvas 20 20 white)))
    (canvas-stroke-path! c '((M 2 10) (L 18 10) (L 2 11)) (rgba 0 0 0 0.5) '((width . 4)))
    (test-equal '(128 128 128 255) (pixel c 10 10)))
  ;; joins: a right angle with a miter fills the corner, a bevel cuts it
  (let ((corner (lambda (join)
                  (let ((c (make-canvas 20 20 white)))
                    (canvas-stroke-path! c '((M 4 16) (L 4 4) (L 16 4)) black
                                         (list '(width . 4) (cons 'join join)))
                    (pixel c 2 2)))))
    (test-equal '(0 0 0 255) (corner 'miter))
    (test-assert (> (car (corner 'bevel)) 100))
    (test-assert (> (car (corner 'round)) 30)))
  ;; a closed rectangle's outline
  (let ((c (make-canvas 20 20 white)))
    (canvas-stroke-path! c (path-rect 4 4 12 12) red '((width . 2)))
    (test-assert (red? c 4 10))
    (test-assert (red? c 3 3))                   ; the closing corner is joined
    (test-assert (white? c 10 10))))

(test-group "dashes"
  (let ((c (make-canvas 20 4 white)))
    (canvas-stroke-path! c '((M 0 2) (L 20 2)) red '((width . 2) (dash . (4 2))))
    (test-assert (red? c 1 2))
    (test-assert (white? c 4 2))
    (test-assert (white? c 5 2))
    (test-assert (red? c 6 2))
    (test-assert (white? c 10 2))))

(test-group "png"
  (let ((png (canvas->png (make-canvas 3 3 red))))
    (test-equal #x89 (bytevector-u8-ref png 0))
    (test-equal (char->integer #\P) (bytevector-u8-ref png 1))))

(test-end "scm raster")
