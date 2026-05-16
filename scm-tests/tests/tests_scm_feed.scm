(import (scheme base) (scm feed) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-feed")

(define (entry-field e k) (cdr (assoc k e)))

(define rss-fixture
  (string-append
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    "<rss version=\"2.0\">\n"
    "  <channel>\n"
    "    <title>Demo Feed</title>\n"
    "    <link>https://example.com/</link>\n"
    "    <description>Demo</description>\n"
    "    <item>\n"
    "      <title>First post</title>\n"
    "      <link>https://example.com/1</link>\n"
    "      <guid isPermaLink=\"false\">post-1</guid>\n"
    "      <pubDate>Thu, 16 May 2024 12:34:56 +0200</pubDate>\n"
    "      <description>Hello &amp; goodbye</description>\n"
    "    </item>\n"
    "    <item>\n"
    "      <title>Second post</title>\n"
    "      <link>https://example.com/2</link>\n"
    "      <guid>post-2</guid>\n"
    "      <pubDate>Fri, 17 May 2024 08:00:00 GMT</pubDate>\n"
    "      <description>Second body</description>\n"
    "    </item>\n"
    "  </channel>\n"
    "</rss>\n"))

(define atom-fixture
  (string-append
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    "<feed xmlns=\"http://www.w3.org/2005/Atom\">\n"
    "  <title>Demo Atom</title>\n"
    "  <link href=\"https://example.com/atom/\"/>\n"
    "  <id>urn:atom:demo</id>\n"
    "  <updated>2024-05-16T12:34:56Z</updated>\n"
    "  <entry>\n"
    "    <title>Atom one</title>\n"
    "    <link href=\"https://example.com/a/1\"/>\n"
    "    <id>urn:atom:demo:1</id>\n"
    "    <published>2024-05-16T12:34:56Z</published>\n"
    "    <summary>Atom summary one</summary>\n"
    "  </entry>\n"
    "  <entry>\n"
    "    <title>Atom two</title>\n"
    "    <link href=\"https://example.com/a/2\"/>\n"
    "    <id>urn:atom:demo:2</id>\n"
    "    <updated>2024-05-17T08:00:00+02:00</updated>\n"
    "    <content type=\"html\">&lt;p&gt;Body 2&lt;/p&gt;</content>\n"
    "  </entry>\n"
    "</feed>\n"))

(test-group "local-name"
  (test-equal "title" (local-name "title"))
  (test-equal "title" (local-name "atom:Title"))
  (test-equal "entry" (local-name "ns:ENTRY")))

(test-group "qname-field"
  (test-equal "title" (qname-field "title"))
  (test-equal "title" (qname-field "atom:title"))
  (test-equal #f (qname-field "media:content"))
  (test-equal #f (qname-field "unknown")))

(test-group "RSS via parse-feed-string"
  (let* ((parsed (parse-feed-string rss-fixture))
         (title  (car parsed))
         (es     (cdr parsed)))
    (test-equal "Demo Feed" title)
    (test-eqv 2 (length es))
    (let ((e1 (car es)))
      (test-equal "First post"            (entry-field e1 "title"))
      (test-equal "https://example.com/1" (entry-field e1 "link"))
      (test-equal "post-1"                (entry-field e1 "guid"))
      (test-equal "Hello & goodbye"       (entry-field e1 "summary"))
      (test-equal "Thu, 16 May 2024 12:34:56 +0200"
                  (entry-field e1 "published")))
    (let ((e2 (cadr es)))
      (test-equal "Second post" (entry-field e2 "title"))
      (test-equal "post-2"      (entry-field e2 "guid")))))

(test-group "Atom via parse-feed-string"
  (let* ((parsed (parse-feed-string atom-fixture))
         (title  (car parsed))
         (es     (cdr parsed)))
    (test-equal "Demo Atom" title)
    (test-eqv 2 (length es))
    (let ((e1 (car es)))
      (test-equal "Atom one"               (entry-field e1 "title"))
      (test-equal "https://example.com/a/1" (entry-field e1 "link"))
      (test-equal "urn:atom:demo:1"        (entry-field e1 "guid"))
      (test-equal "Atom summary one"       (entry-field e1 "summary"))
      (test-equal "2024-05-16T12:34:56Z"   (entry-field e1 "published")))
    (let ((e2 (cadr es)))
      (test-equal "Atom two"               (entry-field e2 "title"))
      ;; updated falls through to summary as content fallback chain
      (test-equal "<p>Body 2</p>"          (entry-field e2 "summary")))))

(test-group "parse-feed-bytevector"
  (let* ((parsed (parse-feed-bytevector (string->utf8 rss-fixture)))
         (title  (car parsed)))
    (test-equal "Demo Feed" title)
    (test-eqv 2 (length (cdr parsed)))))

(test-end "scm-feed")
