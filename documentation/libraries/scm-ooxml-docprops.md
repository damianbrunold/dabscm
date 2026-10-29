# `(scm ooxml docprops)`

Document properties (docProps) for XLSX/DOCX

## Exports

### `docprops-content-types`

```
Syntax: (docprops-content-types props)
Library: (scm ooxml docprops)
Description: Returns the [Content_Types].xml <Override> elements for the
docProps parts (empty string when nothing is set).
Example:
  (docprops-content-types '()) => ""
```

### `docprops-parts`

```
Syntax: (docprops-parts props)
Library: (scm ooxml docprops)
Description: Returns a list of (part-name . xml-string) for the docProps parts
to add to the package; '() when nothing is set.
Example:
  (map car (docprops-parts '((category . "Intern"))))
    => ("docProps/core.xml" "docProps/app.xml")
```

### `docprops-present?`

```
Syntax: (docprops-present? props)
Library: (scm ooxml docprops)
Description: Returns #t when props (an alist, or #f) carries at least one
core or custom property, i.e. when docProps parts are written.
Example:
  (docprops-present? '()) => #f
```

### `docprops-relationships`

```
Syntax: (docprops-relationships props)
Library: (scm ooxml docprops)
Description: Returns the <Relationship> elements for the package _rels/.rels
pointing at the docProps parts (empty string when nothing is set).
Example:
  (docprops-relationships '()) => ""
```

### `docprops-valid?`

```
Syntax: (docprops-valid? props)
Library: (scm ooxml docprops)
Description: Returns #t when props is a properties alist accepted by
workbook-set-properties! / document-set-properties!: keys title, subject,
creator, keywords, description, category map to strings; custom maps to an
alist of (name . value) strings.
Example:
  (docprops-valid? '((category . "Intern"))) => #t
```

