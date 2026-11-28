---
title: (scm xml) and (scm feed): XML and news feeds
part: libraries
order: 1016
libraries: (scm xml) (scm feed)
summary: The pull reader's nodes, reading attributes and text, a reusable loop, building a tree from a stream, namespaces, large files, safety; parsing Atom and RSS feeds.
---
# (scm xml) and (scm feed): XML and news feeds

`(scm xml)` is a *pull reader*: the program asks for one node after the
other and decides what to keep. It needs little memory however large the
file is. `(scm feed)` is built on it and reads Atom and RSS feeds.

```scheme
(import (scheme base) (scheme cxr) (scheme write) (srfi 1)
        (scm xml) (scm feed))
```

## Nodes

`xml-read` moves to the next node and returns `#f` at the end. Each node
has a type and, for elements, a name:

```scheme
(define (nodes text)
  (let ((r (open-xml-string text)))
    (let loop ((acc '()))
      (if (xml-read r)
          (loop (cons (list (xml-node-type r) (xml-name r)) acc))
          (begin (close-xml r) (reverse acc))))))

(nodes "<?xml version=\"1.0\"?><order id=\"7\"><item>tea &amp; cake</item><gift/><!-- note --></order>")
;; => ((element "order") (element "item") (text "") (end-element "item") (element "gift") (end-element "gift") (comment "") (end-element "order"))
```

- `element` and `end-element`; an empty element like `<gift/>` gives both;
- `text`: a run of character data, with `&amp;` and CDATA sections already
  merged in;
- `comment` and `pi` (processing instructions).

The XML declaration and white space outside the root element give no nodes.

## Attributes and text

On an element, `xml-attribute` reads an attribute (`#f` if it is missing)
and `xml-value` reads the element's text:

```scheme
(define r (open-xml-string "<item sku=\"T-1\" qty=\"2\">Green tea</item>"))
(xml-read r)
(xml-attribute r "sku")                     ;; => "T-1"
(xml-attribute r 'qty)                      ;; => "2"
(xml-attribute r "price")                   ;; => #f
(xml-value r)                               ;; => "Green tea"
(xml-node-type r)                           ;; => end-element
(close-xml r)
```

`xml-value` leaves the reader on the element's end, so the loop goes on
with the next sibling. It expects text only: an element with child elements
is an error.

## The basic loop

`xml-read-to` skips to the next element with a name. Most extraction code
is this loop:

```scheme
(define catalog "<catalog>
  <book isbn=\"978-0441013593\"><title>Dune</title><year>1965</year></book>
  <book isbn=\"978-0441569595\"><title>Neuromancer</title><year>1984</year></book>
  <book isbn=\"978-0553283686\"><title>Hyperion</title><year>1989</year></book>
</catalog>")

(define (collect text element proc)
  (let ((r (open-xml-string text)))
    (let loop ((acc '()))
      (if (xml-read-to r element)
          (loop (cons (proc r) acc))
          (begin (close-xml r) (reverse acc))))))

(collect catalog "title" xml-value)         ;; => ("Dune" "Neuromancer" "Hyperion")
(collect catalog "book" (lambda (r) (xml-attribute r "isbn")))
;; => ("978-0441013593" "978-0441569595" "978-0553283686")
```

## Records from a stream

To build one record per `book` from its children, read until the book
ends. A small state machine keeps track of where the reader is:

```scheme
(define (read-books text)
  (let ((r (open-xml-string text)))
    (let loop ((books '()) (current #f))
      (if (not (xml-read r))
          (begin (close-xml r) (reverse books))
          (case (xml-node-type r)
            ((element)
             (cond ((equal? (xml-name r) "book")
                    (loop books `((isbn . ,(xml-attribute r "isbn")))))
                   ((and current (member (xml-name r) '("title" "year")))
                    (let* ((key (string->symbol (xml-name r)))
                           (text (xml-value r)))
                      (loop books (cons (cons key (if (eq? key 'year) (string->number text) text))
                                        current))))
                   (else (loop books current))))
            ((end-element)
             (if (equal? (xml-name r) "book")
                 (loop (cons (reverse current) books) #f)
                 (loop books current)))
            (else (loop books current)))))))

(define books (read-books catalog))
(car books)
;; => ((isbn . "978-0441013593") (title . "Dune") (year . 1965))
(map (lambda (b) (cdr (assq 'title b)))
     (filter (lambda (b) (> (cdr (assq 'year b)) 1980)) books))
;; => ("Neuromancer" "Hyperion")
```

Only one book is in memory at a time, so the same code handles a catalogue
of millions: read from `open-xml-file` instead of a string, and process
each record as it is completed instead of collecting them.

## A whole tree

For small documents a tree is handier. This builds SXML, the
`(tag (@ (attr "value") ...) child ...)` form that `(scm html builder)`
writes and `(scm html parser)` reads. The attributes have to be read
while the reader is on the element; this version reads `id` and `class`
and leaves text out:

```scheme
(define (xml->tree text)
  (let ((r (open-xml-string text)))
    (define (element)
      (let* ((name (string->symbol (xml-name r)))
             (attrs (filter-map (lambda (a)
                                  (let ((v (xml-attribute r a)))
                                    (and v (list (string->symbol a) v))))
                                '("id" "class"))))
        (let loop ((kids '()))
          (xml-read r)
          (case (xml-node-type r)
            ((end-element) (append (list name)
                                   (if (null? attrs) '() (list (cons '@ attrs)))
                                   (reverse kids)))
            ((element) (loop (cons (element) kids)))
            (else (loop kids))))))
    (let ((tree (and (xml-read r) (element))))
      (close-xml r)
      tree)))

(xml->tree "<menu id=\"m\"><entry class=\"hot\"/><entry/></menu>")
;; => (menu (@ (id "m")) (entry (@ (class "hot"))) (entry))
```

## Namespaces

`xml-name` gives the qualified name with its prefix; `xml-read-to` and
`xml-attribute` accept the qualified or the local name:

```scheme
(define sitemap "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"
                         xmlns:img=\"http://www.google.com/schemas/sitemap-image/1.1\">
  <url><loc>https://example.org/</loc><img:image><img:loc>https://example.org/a.png</img:loc></img:image></url>
  <url><loc>https://example.org/about</loc></url>
</urlset>")

(collect sitemap "loc" xml-value)
;; => ("https://example.org/" "https://example.org/a.png" "https://example.org/about")
(collect sitemap "img:loc" xml-value)       ;; => ("https://example.org/a.png")
```

The local name `loc` also matches `img:loc`; the qualified name picks only
the images.

## Safety

XML from outside can attack the reader: entity definitions that expand to
gigabytes, or external entities that read local files. `(scm xml)` does
not process DTDs and never loads external entities; a document that relies
on them is refused:

```scheme
(define (try-read text)
  (guard (e (#t 'refused))
    (collect text "r" xml-value)))

(try-read "<!DOCTYPE r [<!ENTITY x SYSTEM \"file:///etc/passwd\">]><r>&x;</r>") ;; => refused
(try-read "<r>a &lt; b</r>")                ;; => ("a < b")
```

Malformed documents raise an error at the point where the problem is
found, so wrap reads of untrusted data in a `guard`.

## News feeds with (scm feed)

`parse-feed-string`, `parse-feed-file` and `parse-feed-bytevector` read
Atom and RSS 2.0 alike and return the feed title and a list of entries,
each an alist with the keys `title`, `link`, `guid`, `summary` and
`published`:

```scheme
(define rss "<?xml version=\"1.0\"?>
<rss version=\"2.0\"><channel>
  <title>dabscm news</title>
  <item><title>2.29 released</title><link>https://example.org/229</link>
        <guid>n229</guid><pubDate>Thu, 27 Nov 2025 10:00:00 GMT</pubDate>
        <description>Tutorials for every library.</description></item>
  <item><title>2.28 released</title><link>https://example.org/228</link>
        <guid>n228</guid><pubDate>Mon, 10 Nov 2025 09:00:00 GMT</pubDate></item>
</channel></rss>")

(define feed (parse-feed-string rss))
(car feed)                                  ;; => "dabscm news"
(map (lambda (e) (cdr (assoc "title" e))) (cdr feed))
;; => ("2.29 released" "2.28 released")
(cdr (assoc "published" (cadr feed)))       ;; => "Thu, 27 Nov 2025 10:00:00 GMT"
(cdr (assoc "summary" (caddr feed)))        ;; => ""
```

Missing fields are empty strings. `parse-pubdate` from `(scm datetime)`
turns the dates of both formats into epoch seconds, for sorting and
filtering (see the [feed example there](scm-datetime.md)).

## Where next

- [`(scm html)`](scm-html.md) for HTML, which is not XML;
  [structured data](techniques-08-structured-data.md).
- Reference: `(scm xml)`, `(scm feed)`.
