(import (scheme base)
        (scm html builder)
        (scm html parser)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-html-parser")

(define (body-of s) (sxml-children (car (sxml-find (html->sxml s) 'body))))

(test-group "document structure"
  (test-equal '(html (head) (body)) (html->sxml ""))
  (test-equal '(html (head) (body "x")) (html->sxml "x"))
  (test-equal '(html (head (title "T")) (body (p "a")))
              (html->sxml "<title>T</title><p>a"))
  (test-equal '(html (@ (lang "de"))
                     (head (meta (@ (charset "utf-8"))) (title "T"))
                     (body (@ (class "b")) "\n" (h1 "H") "\n\n\n"))
              (html->sxml
               "<!DOCTYPE html>\n<html lang=de>\n<head>\n<meta charset=utf-8>\n<title>T</title>\n</head>\n<body class=b>\n<h1>H</h1>\n</body>\n</html>\n"))
  ;; white space between the head elements is dropped, in the body kept
  (test-equal '(html (head (title "T")) (body (p "a") "\n" (p "b") "\n"))
              (html->sxml "<title>T</title>\n<p>a</p>\n<p>b</p>\n"))
  ;; head elements after the content stay in the body
  (test-equal '(html (head) (body (p "a") (style "p{}")))
              (html->sxml "<p>a</p><style>p{}</style>"))
  ;; content after </body> and </html> still goes into the body
  (test-equal '(html (head) (body (p "a") (p "b")))
              (html->sxml "<body><p>a</p></body></html><p>b</p>")))

(test-group "implied end tags"
  (test-equal '((p "a") (p "b") (div "c"))
              (html-fragment->sxml "<p>a<p>b<div>c</div>"))
  (test-equal '((ul (li "a") (li "b" (ul (li "c"))) (li "d")))
              (html-fragment->sxml "<ul><li>a<li>b<ul><li>c</ul><li>d</ul>"))
  (test-equal '((dl (dt "t") (dd "d") (dt "u")))
              (html-fragment->sxml "<dl><dt>t<dd>d<dt>u</dl>"))
  (test-equal '((table (tr (td "a") (td "b")) (tr (td "c"))))
              (html-fragment->sxml "<table><tr><td>a<td>b<tr><td>c</table>"))
  (test-equal '((select (option "a") (option "b")))
              (html-fragment->sxml "<select><option>a<option>b</select>"))
  ;; an open <p> is closed by a block, its inline elements with it
  (test-equal '((p "x " (font "y")) (h2 "z"))
              (html-fragment->sxml "<p>x <font>y<h2>z</h2>"))
  (test-equal '((h1 "a") (h2 "b")) (html-fragment->sxml "<h1>a<h2>b</h2>"))
  (test-equal '((a (@ (href "1")) "x") (a (@ (href "2")) "y"))
              (html-fragment->sxml "<a href=1>x<a href=2>y</a>"))
  ;; a <p> inside a table cell stays there
  (test-equal '((table (tr (td (p "a")) (td "b"))))
              (html-fragment->sxml "<table><tr><td><p>a<td>b</table>")))

(test-group "stray and void tags"
  (test-equal '((p "a" (br) "b" (br) "c"))
              (html-fragment->sxml "<p>a<br>b</br>c</p>"))
  (test-equal '((p "a") "b")
              (html-fragment->sxml "<p>a</p></p></div></span>b"))
  (test-equal '((img (@ (src "x.png") (alt "")))
                (hr)
                (input (@ (disabled ""))))
              (html-fragment->sxml
               "<img src=x.png alt=\"\"><hr/><input disabled>"))
  (test-equal '((img (@ (src "y")))) (html-fragment->sxml "<image src=y>"))
  ;; a / before > does not close an HTML element ...
  (test-equal '((div (p "x"))) (html-fragment->sxml "<div/><p>x"))
  ;; ... but it does in SVG
  (test-equal '((svg (@ (width "1")) (rect (@ (x "0"))) (circle)) (p "x"))
              (html-fragment->sxml
               "<svg width=1><rect x=\"0\"/><circle/></svg><p>x"))
  ;; an end tag does not close elements outside a table cell
  (test-equal '((div (table (tr (td "a"))) "b"))
              (html-fragment->sxml
               "<div><table><tr><td>a</div></table>b</div>")))

(test-group "attributes"
  (test-equal '((a (@ (href "/a?b=1&c=2")
                      (title "x \"y\"")
                      (data-x "'z'")
                      (hidden ""))
                   "t"))
              (html-fragment->sxml
               "<A HREF='/a?b=1&amp;c=2' title=\"x &quot;y&quot;\" data-x=\"'z'\" hidden>t</a>"))
  ;; the first of repeated attributes counts
  (test-equal '((p (@ (class "a"))))
              (html-fragment->sxml "<p class=a class=b></p>"))
  ;; legacy references in attribute values
  (test-equal '((a (@ (href "?x=1&copy=2&y=©"))))
              (html-fragment->sxml "<a href=\"?x=1&copy=2&y=&copy\"></a>")))

(test-group "text"
  (test-equal '("a & b < c ä — ©2024")
              (html-fragment->sxml
               "a &amp; b &lt; c &auml; &mdash; &copy2024"))
  (test-equal '("a < b" (p "c")) (html-fragment->sxml "a < b<p>c"))
  ;; comments, doctypes and processing instructions are dropped
  (test-equal '((p "ab"))
              (html-fragment->sxml
               "<p>a<!-- c -->b<!doctype html><?php x ?></p>"))
  (test-equal '((p "x")) (html-fragment->sxml "<p>x<!-- unterminated"))
  ;; CR LF becomes LF
  (test-equal '((p "a\nb\nc")) (html-fragment->sxml "<p>a\r\nb\rc</p>"))
  ;; the newline right after <pre> is dropped
  (test-equal '((pre "  x\n  y"))
              (html-fragment->sxml "<pre>\n  x\n  y</pre>"))
  (test-equal '((math "x<y>"))
              (html-fragment->sxml "<math>x<![CDATA[<y>]]></math>")))

(test-group "text elements"
  (test-equal '((script "if (a < b && c) { x = \"</p>\"; }") (p "x"))
              (html-fragment->sxml
               "<script>if (a < b && c) { x = \"</p>\"; }</script><p>x"))
  (test-equal '((style "a > b { }"))
              (html-fragment->sxml "<style>a > b { }</STYLE>"))
  (test-equal '((textarea "<b>&</b>"))
              (html-fragment->sxml "<textarea><b>&amp;</b></textarea>"))
  (test-equal '(html (head (title "a & <b>")) (body))
              (html->sxml "<title>a &amp; <b></title>"))
  ;; </scriptx> does not end a script
  (test-equal '((script "a</scriptx>b"))
              (html-fragment->sxml "<script>a</scriptx>b</script>"))
  ;; unterminated text element runs to the end
  (test-equal '((script "x()")) (html-fragment->sxml "<script>x()")))

(test-group "fragments"
  (test-equal '() (html-fragment->sxml ""))
  (test-equal '("Hello " (b "world"))
              (html-fragment->sxml
               "<html><body>Hello <b>world</b></body></html>"))
  ;; a parsed fragment renders back with (scm html builder)
  (test-equal "<p class=\"x\">a &amp; b<br>c</p><ul><li>1</li><li>2</li></ul>"
              (html->string (html-fragment->sxml
                             "<p class=x>a &amp; b<br>c<ul><li>1<li>2</ul>"))))

(define doc
  (html->sxml
   "<title>T</title><div id=main><p class=lead>Hello <a href=/x>you</a>.</p><script>s()</script><p>Bye <a href=/y>now</a></p></div>"))

(test-group "tree helpers"
  (test-equal 'html (sxml-tag doc))
  (test-equal #f (sxml-tag "text"))
  (test-equal '((id "main")) (sxml-attributes (car (sxml-find doc 'div))))
  (test-equal '() (sxml-attributes (car (sxml-find doc 'title))))
  (test-equal "main" (sxml-attribute (car (sxml-find doc 'div)) 'id))
  (test-equal "main" (sxml-attribute (car (sxml-find doc "div")) "id"))
  (test-equal #f (sxml-attribute (car (sxml-find doc 'div)) 'class))
  (test-equal '("Hello " (a (@ (href "/x")) "you") ".")
              (sxml-children (car (sxml-find doc 'p))))
  (test-equal '("T") (sxml-children (car (sxml-find doc 'title))))
  (test-equal '() (sxml-children "x"))
  (test-equal '("/x" "/y")
              (map (lambda (a) (sxml-attribute a 'href)) (sxml-find doc 'a)))
  (test-equal '(p)
              (map sxml-tag
                   (sxml-find doc (lambda (e) (sxml-attribute e 'class)))))
  (test-equal "Hello you.Bye now" (sxml-text (car (sxml-find doc 'div))))
  (test-equal "ab" (sxml-text '("a" (b "b"))))
  (test-equal 2 (length (sxml-find (body-of "<p>a</p><p>b</p>") 'p))))

(test-group "robustness"
  ;; any input parses
  (for-each (lambda (s) (test-assert (pair? (html->sxml s))))
            '("<" "<<>>" "</" "</>" "<a" "<a href" "<a href=\"x" "<a b='" "&"
              "&#" "&#x" "<p <b>" "<!" "<!-" "<![CDATA[x" "<?" "</p x>"
              "<table><td>x" "<li>a" "<td>x</td>" "</html></html><html>"))
  (test-equal '((p "a") "<") (html-fragment->sxml "<p>a</p>&lt"))
  (test-equal '("<" (b "x")) (html-fragment->sxml "<<b>x</b>")))

(test-end "scm-html-parser")
