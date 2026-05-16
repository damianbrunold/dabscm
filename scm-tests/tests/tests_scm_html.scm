(import (scheme base) (scm html) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-html")

(test-group "html-escape"
  (test-equal "" (html-escape ""))
  (test-equal "plain" (html-escape "plain"))
  (test-equal "a &lt; b" (html-escape "a < b"))
  (test-equal "a &gt; b" (html-escape "a > b"))
  (test-equal "a &amp; b" (html-escape "a & b"))
  (test-equal "&quot;quoted&quot;" (html-escape "\"quoted\""))
  (test-equal "O&#39;Brien" (html-escape "O'Brien"))
  (test-equal "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;"
              (html-escape "<script>alert(\"x\")</script>")))

(test-group "html-attr-escape"
  ;; alias of html-escape — covers both quote characters so single- and
  ;; double-quoted attributes are safe
  (test-equal "&quot;a&quot;" (html-attr-escape "\"a\""))
  (test-equal "&#39;a&#39;" (html-attr-escape "'a'")))

(test-group "strip-html-tags"
  (test-equal "" (strip-html-tags ""))
  (test-equal "plain" (strip-html-tags "plain"))
  (test-equal "hello world" (strip-html-tags "<p>hello</p> <p>world</p>"))
  (test-equal "hello world"
              (strip-html-tags "<p>hello   <b>world</b></p>"))
  ;; leading whitespace is dropped; trailing internal whitespace becomes
  ;; one space — strip-html-tags is for inline-text contexts so a dangling
  ;; trailing space is harmless
  (test-equal "x " (strip-html-tags "  x  "))
  ;; runs of whitespace collapse to a single space
  (test-equal "a b" (strip-html-tags "a\n\tb")))

(test-end "scm-html")
