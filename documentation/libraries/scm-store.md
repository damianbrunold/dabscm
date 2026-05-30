# `(scm store)`

## Exports

### `store-close`

```
Syntax: (store-close s)
Library: (scm store)
Description: Closes the store handle s and releases the underlying file.
Example:
  (store-close s)
```

### `store-count`

```
Syntax: (store-count s)
Library: (scm store)
Description: Returns the number of records in store s.
Example:
  (store-count s) => 1000
```

### `store-count-matching`

```
Syntax: (store-count-matching s clauses)
Library: (scm store)
Description: Returns how many records match the AND of the given filter clauses
  (see store-query). With no clauses this is just the total record count.
Example:
  (store-count-matching s '((eq splg "A1"))) => 42
```

### `store-field-values`

```
Syntax: (store-field-values s name)
Library: (scm store)
Description: Returns the sorted list of distinct values present for field name in
  store s. Useful for populating filter choices. Reads only the field's value
  table, not the records.
Example:
  (store-field-values s 'splg) => ("A1" "B2" "C3")
```

### `store-open`

```
Syntax: (store-open filename)
Library: (scm store)
Description: Opens an existing store file for read-only random access and returns
  a store handle. Reads only the small footer into memory; record payloads and
  index postings stay on disk and are read on demand.
Example:
  (define s (store-open "r.store"))
```

### `store-page`

```
Syntax: (store-page s clauses offset limit)
Library: (scm store)
Description: Returns the list of matching record keys for the AND of clauses (see
  store-query), in ascending key order, skipping offset matches and returning at
  most limit of them. With no clauses the page is generated directly without
  materialising all keys.
Example:
  (store-page s '() 0 20)
```

### `store-page-records`

```
Syntax: (store-page-records s clauses offset limit)
Library: (scm store)
Description: Like store-page, but returns a list of (rowid . payload) pairs with
  each matching record's payload read from disk. Only the page's payloads are
  loaded.
Example:
  (store-page-records s '((eq splg "A1")) 0 20)
```

### `store-query`

```
Syntax: (store-query s clauses)
Library: (scm store)
Description: Returns the sorted list of matching record keys for the AND of the
  given filter clauses, or #f when clauses is empty (meaning every record, without
  materialising the full key list). Each clause is (eq field value),
  (in field (value ...)), or (present field).
Example:
  (store-query s '((eq splg "A1") (in quer ("x" "y"))))
```

### `store-ref`

```
Syntax: (store-ref s rowid)
Library: (scm store)
Description: Returns the payload datum of the record with the given integer key,
  reading just that record from disk. Raises an error if rowid is out of range.
Example:
  (store-ref s 0) => ((id . 7))
```

### `store-writer-add!`

```
Syntax: (store-writer-add! w payload fields)
Library: (scm store)
Description: Appends one record to store writer w and returns its integer key.
  payload is any Scheme datum (serialised with write). fields is an alist mapping
  field-name symbols to index values: for a scalar field a string (or #f to skip),
  for a multi field a list of strings.
Example:
  (store-writer-add! w '((id . 7)) '((splg . "A1") (quer . ("x" "y"))))
```

### `store-writer-close`

```
Syntax: (store-writer-close w)
Library: (scm store)
Description: Finalises store writer w: writes the primary key index and all field
  indexes, appends the footer, flushes, and closes the file. The store is only
  readable after the writer is closed.
Example:
  (store-writer-close w)
```

### `store-writer-open`

```
Syntax: (store-writer-open filename scalar-names multi-names)
Library: (scm store)
Description: Creates (truncating) a store file and returns a writer. scalar-names
  and multi-names are lists of field-name symbols: scalar fields hold one value
  per record (equality/distinct queries); multi fields hold a set of values per
  record (membership queries). Add records with store-writer-add! and finish with
  store-writer-close.
Example:
  (define w (store-writer-open "r.store" '(splg) '(quer)))
```

### `store?`

*(no documentation)*

