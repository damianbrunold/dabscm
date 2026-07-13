(import (scheme base) (scm markdown) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-markdown")

(test-group "parse-markdown: headings"
  (test-equal '((heading 1 "Title")) (parse-markdown "# Title"))
  (test-equal '((heading 3 "Sub")) (parse-markdown "### Sub"))
  ;; trailing closing #'s are stripped
  (test-equal '((heading 2 "Mid")) (parse-markdown "## Mid ##"))
  ;; no space after # is not a heading
  (test-equal '((paragraph "#notitle")) (parse-markdown "#notitle")))

(test-group "parse-markdown: paragraphs and soft breaks"
  (test-equal '((paragraph "one two")) (parse-markdown "one\ntwo"))
  (test-equal '((paragraph "a") (paragraph "b")) (parse-markdown "a\n\nb")))

(test-group "parse-markdown: hard line breaks"
  ;; a trailing backslash forces a line break within a paragraph
  (test-equal '((paragraph "a" (break) "b")) (parse-markdown "a\\\nb"))
  ;; two or more trailing spaces do the same
  (test-equal '((paragraph "a" (break) "b")) (parse-markdown "a  \nb"))
  ;; several breaks in a row (e.g. the lines of a prayer)
  (test-equal '((paragraph "l1" (break) "l2" (break) "l3"))
              (parse-markdown "l1\\\nl2\\\nl3"))
  ;; a soft break (no marker) still joins with a space
  (test-equal '((paragraph "a b")) (parse-markdown "a\nb"))
  ;; a trailing marker on the final line has no line to break and is ignored
  (test-equal '((paragraph "a")) (parse-markdown "a  ")))

(test-group "parse-markdown: inline strong/emph"
  (test-equal '((paragraph "Hello " (strong "world")))
              (parse-markdown "Hello **world**"))
  (test-equal '((paragraph (emph "x"))) (parse-markdown "*x*"))
  (test-equal '((paragraph (strong "x"))) (parse-markdown "__x__"))
  (test-equal '((paragraph (emph "x"))) (parse-markdown "_x_"))
  ;; intraword underscores are literal
  (test-equal '((paragraph "foo_bar_baz")) (parse-markdown "foo_bar_baz"))
  ;; nested emphasis inside strong
  (test-equal '((paragraph (strong "a " (emph "b"))))
              (parse-markdown "**a _b_**")))

(test-group "parse-markdown: code spans"
  (test-equal '((paragraph "use " (code "(scm toml)") " here"))
              (parse-markdown "use `(scm toml)` here"))
  ;; double-backtick span can contain a backtick
  (test-equal '((paragraph (code "a ` b")))
              (parse-markdown "``a ` b``")))

(test-group "parse-markdown: links and escapes"
  (test-equal '((paragraph "see " (link ("docs") "http://x/y")))
              (parse-markdown "see [docs](http://x/y)"))
  (test-equal '((paragraph "a * not emph"))
              (parse-markdown "a \\* not emph")))

(test-group "parse-markdown: thematic breaks"
  (test-equal '((thematic-break)) (parse-markdown "---"))
  (test-equal '((thematic-break)) (parse-markdown "***"))
  (test-equal '((thematic-break)) (parse-markdown "- - -")))

(test-group "parse-markdown: lists"
  (test-equal '((bullet-list (item "one") (item "two")))
              (parse-markdown "- one\n- two"))
  ;; *, + and - are all accepted bullet markers
  (test-equal '((bullet-list (item "a") (item "b")))
              (parse-markdown "* a\n+ b"))
  (test-equal '((ordered-list 1 (item "a") (item "b")))
              (parse-markdown "1. a\n2. b"))
  (test-equal '((ordered-list 3 (item "x")))
              (parse-markdown "3. x")))

(test-group "parse-markdown: nested lists"
  ;; a deeper-indented bullet starts a sub-list under the item above it
  (test-equal '((bullet-list
                  (item "a" (bullet-list (item "b") (item "c")))
                  (item "d")))
              (parse-markdown "- a\n  - b\n  - c\n- d"))
  ;; an ordered sub-list nested under a bullet item
  (test-equal '((bullet-list
                  (item "a" (ordered-list 1 (item "x") (item "y")))))
              (parse-markdown "- a\n  1. x\n  2. y"))
  ;; three levels deep
  (test-equal '((bullet-list
                  (item "a" (bullet-list (item "b" (bullet-list (item "c")))))))
              (parse-markdown "- a\n  - b\n    - c")))

(test-group "parse-markdown: fenced code"
  (test-equal '((code-block "scheme" "(+ 1 2)"))
              (parse-markdown "```scheme\n(+ 1 2)\n```"))
  (test-equal '((code-block #f "plain"))
              (parse-markdown "```\nplain\n```"))
  ;; markdown-looking content inside a fence is literal
  (test-equal '((code-block #f "# not a heading"))
              (parse-markdown "```\n# not a heading\n```")))

(test-group "parse-markdown: blockquotes"
  (test-equal '((blockquote (paragraph "quoted more")))
              (parse-markdown "> quoted\n> more"))
  (test-equal '((blockquote (heading 1 "Q")))
              (parse-markdown "> # Q")))

(test-group "markdown->html: blocks"
  (test-equal "<h1>Title</h1>" (markdown->html "# Title"))
  (test-equal "<p>plain</p>" (markdown->html "plain"))
  (test-equal "<hr>" (markdown->html "---"))
  (test-equal "<pre><code class=\"language-scheme\">(+ 1 2)</code></pre>"
              (markdown->html "```scheme\n(+ 1 2)\n```"))
  (test-equal "<ul>\n<li>a</li>\n<li>b</li>\n</ul>"
              (markdown->html "- a\n- b"))
  (test-equal "<ol start=\"2\">\n<li>x</li>\n</ol>"
              (markdown->html "2. x"))
  ;; a nested sub-list is rendered inside its parent <li>
  (test-equal
    "<ul>\n<li>a\n<ul>\n<li>b</li>\n<li>c</li>\n</ul>\n</li>\n<li>d</li>\n</ul>"
    (markdown->html "- a\n  - b\n  - c\n- d")))

(test-group "markdown->html: unsafe links dropped"
  ;; javascript:/data: schemes are stripped; only the text survives
  (test-equal "<p>t</p>" (markdown->html "[t](javascript:x)"))
  (test-equal "<p>t</p>" (markdown->html "[t](data:text/html,x)"))
  ;; safe schemes and relative URLs are kept
  (test-equal "<p><a href=\"/a\">t</a></p>" (markdown->html "[t](/a)"))
  (test-equal "<p><a href=\"mailto:a@b\">t</a></p>"
              (markdown->html "[t](mailto:a@b)")))

(test-group "markdown->html: hard line breaks"
  ;; both hard-break spellings render as <br> inside a proportional <p>
  (test-equal "<p>a<br>b</p>" (markdown->html "a\\\nb"))
  (test-equal "<p>a<br>b</p>" (markdown->html "a  \nb"))
  ;; a plain soft break stays a space
  (test-equal "<p>a b</p>" (markdown->html "a\nb")))

(test-group "markdown->html: inline"
  (test-equal "<p>a <strong>b</strong> c</p>" (markdown->html "a **b** c"))
  (test-equal "<p>a <em>b</em></p>" (markdown->html "a *b*"))
  (test-equal "<p><code>x</code></p>" (markdown->html "`x`"))
  (test-equal "<p><a href=\"http://x\">t</a></p>" (markdown->html "[t](http://x)")))

(test-group "markdown->html: escaping"
  ;; angle brackets and ampersands in text are escaped
  (test-equal "<p>a &lt;b&gt; &amp; c</p>" (markdown->html "a <b> & c"))
  ;; code content is escaped too
  (test-equal "<p><code>&lt;x&gt;</code></p>" (markdown->html "`<x>`")))

(test-end "scm-markdown")
