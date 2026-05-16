# `(scm net http client)`

HTTP client — GET, POST, and other request methods

## Exports

### `http-delete`

```
Syntax: (http-delete url)
Library: (scm net http client)
Description: Performs an HTTP DELETE request and returns an http-response.
Example:
  (http-delete "http://example.com/item/1")
```

### `http-get`

```
Syntax: (http-get url) (http-get url headers)
Library: (scm net http client)
Description: Performs an HTTP GET request and returns an http-response object.
Example:
  (http-response-status (http-get "http://example.com/")) => 200
```

### `http-get-json`

```
Syntax: (http-get-json url)
Library: (scm net http client)
Description: Performs an HTTP GET request with Accept: application/json header.
  Returns an http-response.
Example:
  (http-get-json "http://example.com/api/items")
```

### `http-post`

```
Syntax: (http-post url body) (http-post url body headers)
Library: (scm net http client)
Description: Performs an HTTP POST request with the given body string and returns an http-response object.
Example:
  (http-post "http://example.com/api" "{}")
```

### `http-post-json`

```
Syntax: (http-post-json url body)
Library: (scm net http client)
Description: Performs an HTTP POST with Content-Type: application/json. body should
  be a JSON string. Returns an http-response.
Example:
  (http-post-json "http://example.com/api" "{\"x\":1}")
```

### `http-put`

```
Syntax: (http-put url body)
Library: (scm net http client)
Description: Performs an HTTP PUT request with the given body and returns an http-response.
Example:
  (http-put "http://example.com/item/1" "updated")
```

### `http-send`

```
Syntax: (http-send request)
Library: (scm net http client)
Description: Sends an HTTP request object and returns an http-response object.
Example:
  (http-send (make-http-request "DELETE" "http://example.com/x" '() #f))
```

