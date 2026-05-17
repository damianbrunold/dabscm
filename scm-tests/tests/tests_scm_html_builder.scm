(import (scheme base) (scm html builder) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-html-builder")

(test-group "primitives"
  (test-equal "" (html->string '()))
  (test-equal "" (html->string #f))
  (test-equal "hello" (html->string "hello"))
  (test-equal "42" (html->string 42))
  ;; strings are escaped
  (test-equal "&lt;b&gt;" (html->string "<b>"))
  (test-equal "a &amp; b" (html->string "a & b"))
  (test-equal "O&#39;Brien" (html->string "O'Brien")))

(test-group "raw"
  (test-equal "<b>x</b>" (html->string (raw "<b>x</b>")))
  (test-equal #t (raw? (raw "x")))
  (test-equal "x" (raw-value (raw "x")))
  ;; raw is one-way: strings get escaped, raw doesn't
  (test-equal "<b>x</b> &lt;b&gt;"
              (html->string `(,(raw "<b>x</b>") " " "<b>"))))

(test-group "simple elements"
  (test-equal "<p></p>" (html->string '(p)))
  (test-equal "<p>hi</p>" (html->string '(p "hi")))
  (test-equal "<div><p>a</p><p>b</p></div>"
              (html->string '(div (p "a") (p "b"))))
  ;; nested escaping
  (test-equal "<p>&lt;script&gt;</p>"
              (html->string '(p "<script>"))))

(test-group "attributes"
  (test-equal "<a href=\"/x\">link</a>"
              (html->string '(a (@ (href "/x")) "link")))
  (test-equal "<input type=\"text\" name=\"q\">"
              (html->string '(input (@ (type "text") (name "q")))))
  ;; attribute values are escaped
  (test-equal "<a title=\"&quot;quoted&quot;\">x</a>"
              (html->string '(a (@ (title "\"quoted\"")) "x")))
  ;; numeric attribute values
  (test-equal "<input maxlength=\"40\">"
              (html->string '(input (@ (maxlength 40)))))
  ;; #f attribute → omitted
  (test-equal "<a>x</a>"
              (html->string `(a (@ (class ,#f)) "x")))
  ;; #t attribute → boolean (name-only)
  (test-equal "<input type=\"checkbox\" checked>"
              (html->string `(input (@ (type "checkbox") (checked #t)))))
  ;; mixing #f and #t and a real value
  (test-equal "<a class=\"active\">x</a>"
              (html->string `(a (@ (class ,(if #t "active" #f))
                                  (rel  ,(if #f "x" #f)))
                                "x"))))

(test-group "void elements"
  (test-equal "<br>" (html->string '(br)))
  (test-equal "<hr>" (html->string '(hr)))
  (test-equal "<img src=\"/a.png\" alt=\"a\">"
              (html->string '(img (@ (src "/a.png") (alt "a")))))
  (test-equal "<meta charset=\"utf-8\">"
              (html->string '(meta (@ (charset "utf-8"))))))

(test-group "fragment lists"
  ;; A list whose car is not a symbol is treated as a sequence.
  (test-equal "<p>a</p><p>b</p>"
              (html->string '((p "a") (p "b"))))
  ;; Splicing pattern via map:
  (test-equal "<ul><li>1</li><li>2</li><li>3</li></ul>"
              (html->string
                `(ul ,@(map (lambda (n) `(li ,(number->string n)))
                            '(1 2 3))))))

(test-group "html5"
  (test-equal
    "<!doctype html>\n<html><head><title>hi</title></head><body><p>hello</p></body></html>"
    (html->string
      (html5 '(head (title "hi"))
             '(body (p "hello")))))
  (test-equal
    "<!doctype html>\n<html></html>"
    (html->string (html5))))

(test-group "mixed content"
  (test-equal "<p>Hello, <b>world</b>!</p>"
              (html->string '(p "Hello, " (b "world") "!")))
  ;; A trusted HTML chunk embedded in tree content.
  (test-equal "<main><h1>page</h1><b>x</b></main>"
              (html->string
                `(main (h1 "page")
                       ,(raw "<b>x</b>")))))

(test-group "xss safety"
  ;; The whole point: user values can never produce executable script.
  (let ((bad "<script>alert(1)</script>"))
    (test-equal "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>"
                (html->string `(p ,bad))))
  ;; Attribute injection attempt: quote-break.
  (let ((bad "\" onmouseover=alert(1) x=\""))
    (test-equal
      "<a title=\"&quot; onmouseover=alert(1) x=&quot;\">x</a>"
      (html->string `(a (@ (title ,bad)) "x")))))

(test-group "html->port"
  (let ((out (open-output-string)))
    (html->port out '(p "hi"))
    (test-equal "<p>hi</p>" (get-output-string out)))
  ;; Two writes share the same port
  (let ((out (open-output-string)))
    (html->port out '(p "a"))
    (html->port out '(p "b"))
    (test-equal "<p>a</p><p>b</p>" (get-output-string out))))

(test-end "scm-html-builder")
