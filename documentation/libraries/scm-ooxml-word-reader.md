# `(scm ooxml word-reader)`

## Exports

### `document-headings`

```
Syntax: (document-headings doc)
Library: (scm ooxml word-reader)
Description: Returns only the heading paragraph records (those with a heading
  level), in document order.
Example:
  (map paragraph-text (document-headings doc)) => ("Chapter 1" "Section 1.1")
```

### `document-paragraphs`

```
Syntax: (document-paragraphs doc)
Library: (scm ooxml word-reader)
Description: Returns the document's paragraphs in document order, as a list of
  paragraph records. Use paragraph-text, paragraph-style, paragraph-heading-level
  and paragraph-in-table? to inspect each record. Paragraphs inside tables are
  included. Empty paragraphs (no text and not a heading) are omitted.
Example:
  (map paragraph-text (document-paragraphs doc)) => ("Title" "Body text")
```

### `document-text`

```
Syntax: (document-text doc)
Library: (scm ooxml word-reader)
Description: Returns the whole document body as a single string, with paragraph
  texts joined by newlines.
Example:
  (document-text doc) => "Title\nBody text"
```

### `paragraph-heading-level`

```
Syntax: (paragraph-heading-level p)
Library: (scm ooxml word-reader)
Description: Returns the heading level (1..n) of a heading paragraph, or #f if
  the paragraph is not a heading. The level is determined from the paragraph's
  style: a Heading<n> style id, or the style's built-in 
```

### `paragraph-in-table?`

```
Syntax: (paragraph-in-table? p)
Library: (scm ooxml word-reader)
Description: Returns #t if the paragraph was extracted from a table cell.
Example:
  (paragraph-in-table? p) => #f
```

### `paragraph-style`

```
Syntax: (paragraph-style p)
Library: (scm ooxml word-reader)
Description: Returns the paragraph's style name (e.g. "Heading1", "Normal"),
  or #f if the paragraph has no explicit style.
Example:
  (paragraph-style p) => "Heading1"
```

### `paragraph-text`

```
Syntax: (paragraph-text p)
Library: (scm ooxml word-reader)
Description: Returns the text of a paragraph record (all runs concatenated).
Example:
  (paragraph-text p) => "Hello world"
```

### `read-document`

```
Syntax: (read-document path)
Library: (scm ooxml word-reader)
Description: Reads the text content of the DOCX document at path and returns a
  document object. Use document-paragraphs, document-text and document-headings
  to access the content. Run formatting, images, headers/footers and fields are
  not read.
Example:
  (let ((doc (read-document "letter.docx")))
    (document-text doc)) => "Dear Sir\nThank you ..."
```

### `read-document-from-bytevector`

```
Syntax: (read-document-from-bytevector bv)
Library: (scm ooxml word-reader)
Description: Like read-document, but reads from an in-memory bytevector holding
  the bytes of a DOCX file. The bytes are written to a temporary file (the
  underlying zip reader is file-based) which is removed before returning.
Example:
  (read-document-from-bytevector (document-save-to-bytevector doc))
```

