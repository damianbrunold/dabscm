;; Tests for (scm text layout). Widths: every character is half the
;; font size wide (a monospaced stand-in), ascent 0.8 and descent 0.2 of
;; the size.

(import (scheme base)
        (scm test)
        (scm text layout))

(test-runner-factory scm-test-runner)
(test-begin "scm text layout")

(define (run text size . data)
  (make-text-run text (lambda (s) (/ (* size (string-length s)) 2)) size (* 4/5 size) (* 1/5 size)
                 (if (pair? data) (car data) #f)))

(define (texts lines) (map (lambda (l) (map item-text (line-items l))) lines))
(define (xs lines) (map (lambda (l) (map item-x (line-items l))) lines))

(test-group "breaking"
  ;; 10 px per char at size 20, width 100 = 10 chars
  (let ((lines (layout-paragraph (list (run "aaa bbb ccc ddd" 20)) 100)))
    (test-equal '(("aaa bbb") ("ccc ddd")) (texts lines))
    (test-equal 70 (line-width (car lines))))
  (test-equal '(("aaa") () ("bbb"))
    (texts (layout-paragraph (list (run "aaa\n\nbbb" 20)) 100)))
  (test-equal '(())
    (texts (layout-paragraph (list (run "" 20)) 100)))
  ;; a word wider than the line is broken
  (test-equal '(("aaaaaaaaaa") ("aaaaa"))
    (texts (layout-paragraph (list (run "aaaaaaaaaaaaaaa" 20)) 100)))
  ;; leading spaces stay (as the first item's offset), spaces at a soft
  ;; break hang
  (let ((lines (layout-paragraph (list (run "  aa bbbb   cc" 20)) 100)))
    (test-equal '(("aa bbbb") ("cc")) (texts lines))
    (test-equal '((20) (0)) (xs lines))))

(test-group "runs"
  (let* ((lines (layout-paragraph (list (run "fe" 20 'plain) (run "tt " 20 'bold) (run "xx" 20 'plain)) 100))
         (items (line-items (car lines))))
    (test-equal '("fe" "tt " "xx") (map item-text items))
    (test-equal '(0 20 50) (map item-x items))
    (test-equal '(plain bold plain) (map (lambda (i) (text-run-data (item-run i))) items))))

(test-group "alignment"
  (test-equal '((15)) (xs (layout-paragraph (list (run "abcde" 20)) 80 '((align . center)))))
  (test-equal '((30)) (xs (layout-paragraph (list (run "abcde" 20)) 80 '((align . right)))))
  ;; justify: the first line's gaps share the free space, the last is not stretched
  (let ((lines (layout-paragraph (list (run "aa bb cc dd ee" 20)) 100 '((align . justify)))))
    (test-equal '(("aa" "bb" "cc") ("dd ee")) (texts lines))
    (test-equal '((0 40 80) (0)) (xs lines))))

(test-group "line heights"
  (let ((l (car (layout-paragraph (list (run "a" 20)) 100))))
    (test-equal 24 (line-height l))             ; 1.2 x 20
    (test-equal 18 (line-baseline l)))           ; 2 px half-leading + 16 ascent
  ;; a larger run makes the line taller
  (let ((l (car (layout-paragraph (list (run "a" 20) (run "B" 40)) 400))))
    (test-equal 48 (line-height l)))
  ;; the strut keeps a line of small text as tall as the paragraph font
  (let ((l (car (layout-paragraph (list (run "a" 10)) 100 `((strut . ,(run "" 20)))))))
    (test-equal 24 (line-height l)))
  (test-equal 72 (layout-height (layout-paragraph (list (run "a\nb\nc" 20)) 100)))
  (test-equal 2
    (line-height (car (layout-paragraph (list (run "a" 1)) 100 '((line-height . 2)))))))

(test-end "scm text layout")
