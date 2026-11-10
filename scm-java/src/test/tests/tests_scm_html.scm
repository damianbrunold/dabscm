(import (scheme base)
        (scm html)
        (scm test))

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
  (test-equal "hello world" (strip-html-tags "<p>hello   <b>world</b></p>"))
  ;; leading whitespace is dropped; trailing internal whitespace becomes
  ;; one space — strip-html-tags is for inline-text contexts so a dangling
  ;; trailing space is harmless
  (test-equal "x " (strip-html-tags "  x  "))
  ;; runs of whitespace collapse to a single space
  (test-equal "a b" (strip-html-tags "a\n\tb")))

(test-group "html-unescape"
  (test-equal "" (html-unescape ""))
  (test-equal "plain" (html-unescape "plain"))
  (test-equal "a & b < c > d \" '"
              (html-unescape "a &amp; b &lt; c &gt; d &quot; &apos;"))
  (test-equal "äÖß" (html-unescape "&auml;&Ouml;&szlig;"))
  (test-equal "→ ∉ ≂̸" (html-unescape "&rarr; &notin; &NotEqualTilde;"))
  ;; numeric references, decimal and hexadecimal, with or without ;
  (test-equal "ää ä" (html-unescape "&#228;&#xE4; &#XE4"))
  ;; 128-159 as Windows-1252; 0, surrogates, too large as U+FFFD
  (test-equal "€—" (html-unescape "&#128;&#x97;"))
  (test-equal (string (integer->char #xFFFD)
                      (integer->char #xFFFD)
                      (integer->char #xFFFD))
              (html-unescape "&#0;&#xD800;&#x110000;"))
  ;; legacy names work without ;, the longest one that fits
  (test-equal "© 2024" (html-unescape "&copy 2024"))
  (test-equal "¬it;" (html-unescape "&notit;"))
  ;; unknown names and lone ampersands stay
  (test-equal "&foo; & &# &x" (html-unescape "&foo; & &# &x"))
  (test-equal "AT&T" (html-unescape "AT&T"))
  ;; in attribute values a legacy name followed by = or a letter stays
  (test-equal "?a=1&copy=2&" (html-unescape "?a=1&copy=2&amp" #t))
  (test-equal "?a=1&b=2" (html-unescape "?a=1&amp;b=2" #t))
  (test-equal "© x" (html-unescape "&copy x" #t))
  ;; html-escape and html-unescape are inverse
  (test-equal "<a href=\"x\">O'Brien & co</a>"
              (html-unescape (html-escape "<a href=\"x\">O'Brien & co</a>"))))

(test-end "scm-html")
