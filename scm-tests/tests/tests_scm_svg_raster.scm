(import (scheme base)
        (scm test)
        (scm html builder)
        (scm raster)
        (scm svg raster))

(test-runner-factory scm-test-runner)

(test-begin "scm svg raster")

(define (px svg x y . options)
  (canvas-ref (apply svg->canvas svg options) x y))

(define (svg body . size)
  (let ((w (if (pair? size) (car size) 20)) (h (if (pair? size) (cadr size) 20)))
    (string-append "<svg xmlns='http://www.w3.org/2000/svg' width='" (number->string w)
                   "' height='" (number->string h) "'>" body "</svg>")))

(define white '((background . #(255 255 255 1.0))))

(test-group "parsing"
  (test-equal '(svg (@ (width "10")) (rect (@)))
              (svg-text->sxml "<svg width='10'><rect/></svg>"))
  (test-equal '(svg (@) (text (@ (x "1")) "a & b"))
              (svg-text->sxml "<?xml version='1.0'?><!-- c --><svg><text x=\"1\">a &amp; b</text></svg>"))
  (test-equal '(svg (@) (style (@) ".a{}"))
              (svg-text->sxml "<svg><style><![CDATA[.a{}]]></style></svg>")))

(test-group "size"
  (let ((c (svg->canvas (svg "" 30 10))))
    (test-equal 30 (canvas-width c))
    (test-equal 10 (canvas-height c)))
  (let ((c (svg->canvas (svg "" 30 10) '((scale . 2)))))
    (test-equal 60 (canvas-width c))
    (test-equal 20 (canvas-height c)))
  ;; without width and height, the viewBox gives the size
  (let ((c (svg->canvas "<svg viewBox='0 0 40 25'></svg>")))
    (test-equal 40 (canvas-width c))
    (test-equal 25 (canvas-height c)))
  ;; transparent unless a background is given
  (test-equal '(0 0 0 0) (px (svg "") 5 5))
  (test-equal '(255 255 255 255) (px (svg "") 5 5 white)))

(test-group "shapes"
  (test-equal '(255 0 0 255) (px (svg "<rect x='5' y='5' width='10' height='10' fill='red'/>") 10 10))
  (test-equal '(0 0 0 255) (px (svg "<rect width='10' height='10'/>") 5 5))     ; fill black
  (test-equal '(0 0 0 0) (px (svg "<rect width='10' height='10' fill='none'/>") 5 5))
  (test-equal '(0 0 255 255) (px (svg "<circle cx='10' cy='10' r='5' fill='#00f'/>") 10 10))
  (test-equal '(0 0 0 0) (px (svg "<circle cx='10' cy='10' r='5' fill='#00f'/>") 2 2))
  (test-equal '(0 128 0 255) (px (svg "<ellipse cx='10' cy='10' rx='8' ry='3' fill='green'/>") 3 10))
  (test-equal '(255 0 0 255)
              (px (svg "<polygon points='0,0 20,0 20,20' fill='red'/>") 15 5))
  (test-equal '(0 0 0 0)
              (px (svg "<polygon points='0,0 20,0 20,20' fill='red'/>") 5 15))
  ;; a line has no fill; its stroke shows
  (test-equal '(0 0 0 255)
              (px (svg "<line x1='0' y1='10' x2='20' y2='10' stroke='black' stroke-width='4'/>") 10 9)))

(test-group "paths"
  (let ((p (lambda (d x y) (px (svg (string-append "<path fill='red' d='" d "'/>")) x y))))
    (test-equal '(255 0 0 255) (p "M2 2 H18 V18 H2 Z" 10 10))
    (test-equal '(255 0 0 255) (p "m2 2 h16 v16 h-16 z" 10 10))
    (test-equal '(255 0 0 255) (p "M2,2L18,2,18,18,2,18z" 10 10))
    ;; numbers packed without separators
    (test-equal '(255 0 0 255) (p "M2-0.5e1l16.0.0V18H2z" 10 10))
    ;; arcs: two half circles make a circle (flags packed too)
    (test-equal '(255 0 0 255) (p "M2 10a8 8 0 1018 0a8 8 0 10-16 0z" 10 10))
    (test-equal '(0 0 0 0) (p "M2 10a8 8 0 1018 0a8 8 0 10-16 0z" 3 3))
    ;; curves, smooth curves
    (test-equal '(255 0 0 255) (p "M2 18 C2 2 18 2 18 18 Z" 10 14))
    (test-equal '(255 0 0 255) (p "M2 18 Q10 0 18 18 Z" 10 14))
    (test-equal '(255 0 0 255) (p "M2 18 Q6 0 10 18 T18 18 Z" 6 14))
    ;; even-odd leaves the inner square empty
    (test-equal '(0 0 0 0)
                (px (svg "<path fill='red' fill-rule='evenodd' d='M0 0H20V20H0Z M5 5H15V15H5Z'/>") 10 10))))

(test-group "colours"
  (let ((c (lambda (fill) (px (svg (string-append "<rect width='20' height='20' fill='" fill "'/>")) 5 5))))
    (test-equal '(18 52 86 255) (c "#123456"))
    (test-equal '(17 34 51 255) (c "#123"))
    (test-equal '(10 20 30 255) (c "rgb(10, 20, 30)"))
    (test-equal '(10 20 30 128) (c "rgba(10,20,30,.5)"))
    (test-equal '(255 255 255 255) (c "white"))
    (test-equal '(0 0 0 0) (c "transparent"))))

(test-group "style sheets"
  (let ((doc (lambda (body)
               (svg (string-append
                     "<style>.cv{font-size:11px} .cv .a{fill:red} .a{fill:blue} #x{fill:green}"
                     " @media (prefers-color-scheme:dark){.cv .a{fill:yellow}}"
                     " :root .cv .a{fill:purple} rect.b{fill:#00f}</style>"
                     "<g class='cv'>" body "</g>")))))
    ;; the descendant rule beats the plain class: more specific
    (test-equal '(255 0 0 255) (px (doc "<rect class='a' width='20' height='20'/>") 5 5))
    ;; an id beats both
    (test-equal '(0 128 0 255) (px (doc "<rect id='x' class='a' width='20' height='20'/>") 5 5))
    ;; a style sheet beats a presentation attribute
    (test-equal '(255 0 0 255) (px (doc "<rect class='a' fill='black' width='20' height='20'/>") 5 5))
    ;; the style attribute beats the sheet
    (test-equal '(0 0 0 255)
                (px (doc "<rect class='a' style='fill: black' width='20' height='20'/>") 5 5))
    ;; type and class together
    (test-equal '(0 0 255 255) (px (doc "<rect class='b' width='20' height='20'/>") 5 5))
    ;; fill is inherited from the group
    (test-equal '(255 0 0 255)
                (px (doc "<g class='a'><rect width='20' height='20'/></g>") 5 5))))

(test-group "opacity"
  (test-equal '(128 128 128 255)
              (px (svg "<rect width='20' height='20' fill='black' fill-opacity='0.5'/>") 5 5 white))
  (test-equal '(128 128 128 255)
              (px (svg "<g opacity='0.5'><rect width='20' height='20'/></g>") 5 5 white))
  (test-equal '(255 255 255 255)
              (px (svg "<rect width='20' height='20' style='fill:#000;fill-opacity:0'/>") 5 5 white))
  (test-equal '(255 255 255 255)
              (px (svg "<rect width='20' height='20' display='none'/>") 5 5 white))
  (test-equal '(255 255 255 255)
              (px (svg "<rect width='20' height='20' visibility='hidden'/>") 5 5 white)))

(test-group "strokes"
  (let ((doc (svg "<rect x='4' y='4' width='12' height='12' fill='none' stroke='red' stroke-width='2'/>")))
    (test-equal '(255 0 0 255) (px doc 4 10))
    (test-equal '(0 0 0 0) (px doc 10 10)))
  ;; dashes
  (let ((doc (svg "<line x1='0' y1='10' x2='20' y2='10' stroke='red' stroke-width='2' stroke-dasharray='4 2'/>")))
    (test-equal '(255 0 0 255) (px doc 1 10))
    (test-equal '(0 0 0 0) (px doc 5 10)))
  ;; paint-order: the stroke goes under the fill
  (let ((doc (lambda (order)
               (svg (string-append "<rect x='5' y='5' width='10' height='10' fill='blue' stroke='red'"
                                   " stroke-width='4' paint-order='" order "'/>")))))
    (test-equal '(255 0 0 255) (px (doc "normal") 6 6))
    (test-equal '(0 0 255 255) (px (doc "stroke") 6 6))))

(test-group "transforms and viewBox"
  (test-equal '(255 0 0 255)
              (px (svg "<g transform='translate(10 10)'><rect width='5' height='5' fill='red'/></g>") 12 12))
  (test-equal '(0 0 0 0)
              (px (svg "<g transform='translate(10 10)'><rect width='5' height='5' fill='red'/></g>") 2 2))
  (test-equal '(255 0 0 255)
              (px (svg "<rect width='5' height='5' fill='red' transform='scale(3)'/>") 13 13))
  (test-equal '(255 0 0 255)
              ;; around (10, 10), a quarter turn back takes (10, 14) to (14, 10)
              (px (svg "<rect x='8' y='12' width='4' height='4' fill='red' transform='rotate(-90 10 10)'/>") 14 10))
  (test-equal '(0 0 0 0)
              (px (svg "<rect x='8' y='12' width='4' height='4' fill='red' transform='rotate(-90 10 10)'/>") 10 14))
  ;; the viewBox maps 0..10 onto 0..20
  (test-equal '(255 0 0 255)
              (px "<svg width='20' height='20' viewBox='0 0 10 10'><rect x='5' y='5' width='5' height='5' fill='red'/></svg>"
                  15 15)))

(test-group "patterns"
  (let ((doc (svg (string-append
                   "<defs><pattern id='p' patternUnits='userSpaceOnUse' width='4' height='4'>"
                   "<rect width='2' height='4' fill='red'/></pattern></defs>"
                   "<rect width='20' height='20' fill='url(#p)'/>"))))
    (test-equal '(255 0 0 255) (px doc 1 1))
    (test-equal '(0 0 0 0) (px doc 3 1))
    (test-equal '(255 0 0 255) (px doc 5 9))))

(test-group "text"
  (let* ((doc (lambda (anchor)
                (svg (string-append "<text x='50' y='15' font-size='14' text-anchor='" anchor
                                    "' fill='black'>MMM</text>")
                     100 20)))
         ;; the leftmost dark column
         (left (lambda (c)
                 (let loop ((x 0) (y 0))
                   (cond ((= x 100) #f)
                         ((= y 20) (loop (+ x 1) 0))
                         ((> (cadddr (canvas-ref c x y)) 128) x)
                         (else (loop x (+ y 1))))))))
    (let ((s (left (svg->canvas (doc "start"))))
          (m (left (svg->canvas (doc "middle"))))
          (e (left (svg->canvas (doc "end")))))
      (test-assert (<= 50 s 52))
      (test-assert (< e m s))
      (test-assert (< 15 (- s e) 45)))))

(test-group "sxml from (scm html builder)"
  (let ((tree `(svg (@ (width 20) (height 20) (class "cv"))
                    (style ,(raw ".cv .k{fill:#ff0000}"))
                    ,(list `(rect (@ (class "k") (width 20) (height 20))))
                    #f "")))
    (test-equal '(255 0 0 255) (canvas-ref (svg->canvas tree) 5 5))
    (test-equal #x89 (bytevector-u8-ref (svg->png tree) 0))))

(test-end "scm svg raster")
