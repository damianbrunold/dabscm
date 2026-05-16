# `(scm json)`

JSON file reading

## Exports

### `close-json`

```
Syntax: (close-json reader)
Library: (scm core)
Description: Closes the given JSON reader, releasing any underlying resources.
Example:
  (let ((r (open-json-file "data.json")))
    (close-json r))
```

### `json-attribute`

```
Syntax: (json-attribute object name) (json-attribute object name default)
Library: (scm core)
Description: Returns the value of the named attribute from a JSON object. Returns default (or #f) if the attribute does not exist.
Example:
  (let ((obj (json-next-object reader)))
    (json-attribute obj 'name "unknown"))
```

### `json-next-object`

```
Syntax: (json-next-object reader)
Library: (scm core)
Description: Reads and returns the next JSON object from the given JSON reader, or #f if there are no more objects.
Example:
  (let ((r (open-json-file "data.json")))
    (json-next-object r))
```

### `open-json-file`

```
Syntax: (open-json-file filename)
Library: (scm core)
Description: Opens the named JSON file and returns a JSON reader object. An optional list-id symbol may be specified to identify list nodes.
Example:
  (define r (open-json-file "data.json"))
  (json-next-object r) => next parsed JSON object
```

### `open-json-string`

```
Syntax: (open-json-string s)
Library: (scm json)
Description: Returns a JSON reader object that parses the JSON contained in the string s. An optional list-id symbol or string may be specified to identify list nodes.
Example:
  (define r (open-json-string "{\"a\": 1}"))
  (json-next-object r) => parsed object
```

