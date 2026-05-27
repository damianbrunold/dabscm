# `(srfi 13)`

SRFI-13 — String library: predicate-based string operations

## Exports

### `check-substring-spec`

```
Syntax: (check-substring-spec proc s start end)
Library: (srfi 13)
Description: Signals an error if start/end are not valid substring bounds for s.
Example:
  (check-substring-spec 'test "hello" 0 5) => unspecified (no error)
```

### `kmp-step`

```
Syntax: (kmp-step pattern rv c i c= p-start)
Library: (srfi 13)
Description: Advances the KMP state machine by one character.
Example:
  (let ((rv (make-kmp-restart-vector "abc")))
    (kmp-step "abc" rv #\a 0 char=? 0)) => 1
```

### `let-string-start+end`

*(no documentation)*

### `list->string`

```
Syntax: (list->string list)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string formed from the characters in
  list. It is an error if any element of list is not a character.
Example:
  (list->string '(#\a #\b #\c)) => "abc"
  (list->string '())              => ""
```

### `make-kmp-restart-vector`

```
Syntax: (make-kmp-restart-vector pattern [c= [start [end]]])
Library: (srfi 13)
Description: Builds the KMP restart vector for pattern[start..end).
Example:
  (make-kmp-restart-vector "abcabc") => #(-1 0 0 -1 0 0)
```

### `make-string`

```
Syntax: (make-string k) (make-string k char)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated mutable string of k characters. If char is given, all characters are initialized to char; otherwise they are spaces.
Example:
  (make-string 3 #\x) => "xxx"
  (make-string 3) => "   "
```

### `reverse-list->string`

```
Syntax: (reverse-list->string lst)
Library: (srfi 13)
Description: Converts a list of characters to a string after reversing it.
Example:
  (reverse-list->string '(#\o #\l #\l #\e #\h)) => "hello"
```

### `string`

```
Syntax: (string char ...)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string composed of the given characters.
Example:
  (string #\a #\b #\c) => "abc"
  (string) => ""
```

### `string->list`

```
Syntax: (string->list string)
       (string->list string start)
       (string->list string start end)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated list of the characters of string
  between start and end. start defaults to 0 and end defaults to the length
  of string.
Example:
  (string->list "abc")     => (#\a #\b #\c)
  (string->list "abc" 1)   => (#\b #\c)
  (string->list "abc" 1 2) => (#\b)
```

### `string-any`

```
Syntax: (string-any criterion s [start [end]])
Library: (srfi 13)
Description: Returns the first truthy value returned by criterion applied to
characters in s[start..end), or #f if it returns #f for all characters.
Example:
  (string-any char-upper-case? "hEllo") => #t
  (string-any char-upper-case? "hello") => #f
```

### `string-append`

```
Syntax: (string-append string ...)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.
Example:
  (string-append "foo" "bar") => "foobar"
  (string-append "a" "b" "c") => "abc"
```

### `string-append/shared`

```
Syntax: (string-append string ...)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.
Example:
  (string-append "foo" "bar") => "foobar"
  (string-append "a" "b" "c") => "abc"
```

### `string-ci<`

```
Syntax: (string-ci< s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string<.
Example:
  (string-ci< "abc" "ABD") => 2
```

### `string-ci<=`

```
Syntax: (string-ci<= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string<=.
Example:
  (string-ci<= "ABC" "abc") => 3
```

### `string-ci<>`

```
Syntax: (string-ci<> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string<>.
Example:
  (string-ci<> "abc" "ABC") => #f
```

### `string-ci=`

```
Syntax: (string-ci= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string=.
Example:
  (string-ci= "ABC" "abc") => 3
```

### `string-ci>`

```
Syntax: (string-ci> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string>.
Example:
  (string-ci> "ABD" "abc") => 2
```

### `string-ci>=`

```
Syntax: (string-ci>= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string>=.
Example:
  (string-ci>= "ABC" "abc") => 3
```

### `string-compare`

```
Syntax: (string-compare s1 s2 proc< proc= proc> [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Compares s1 and s2 lexicographically. Calls the appropriate proc with the mismatch index.
Example:
  (string-compare "abc" "abd" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater)) => less
```

### `string-compare-ci`

```
Syntax: (string-compare-ci s1 s2 proc< proc= proc> [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-compare.
Example:
  (string-compare-ci "ABC" "abc" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater)) => equal
```

### `string-concatenate`

```
Syntax: (string-concatenate lst)
Library: (srfi 13)
Description: Concatenates a list of strings into a single string.
Example:
  (string-concatenate '("foo" "bar" "baz")) => "foobarbaz"
```

### `string-concatenate-reverse`

```
Syntax: (string-concatenate-reverse lst [final [end]])
Library: (srfi 13)
Description: Reverses lst then concatenates, optionally prepending (substring final 0 end).
Example:
  (string-concatenate-reverse '("baz" "bar" "foo")) => "foobarbaz"
```

### `string-concatenate-reverse/shared`

```
Syntax: (string-concatenate-reverse lst [final [end]])
Library: (srfi 13)
Description: Reverses lst then concatenates, optionally prepending (substring final 0 end).
Example:
  (string-concatenate-reverse '("baz" "bar" "foo")) => "foobarbaz"
```

### `string-concatenate/shared`

```
Syntax: (string-concatenate lst)
Library: (srfi 13)
Description: Concatenates a list of strings into a single string.
Example:
  (string-concatenate '("foo" "bar" "baz")) => "foobarbaz"
```

### `string-contains`

```
Syntax: (string-contains s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the index of the first occurrence of s2[start2..end2) in s1[start1..end1), or #f if not found.
Example:
  (string-contains "hello world" "world") => 6
  (string-contains "hello" "xyz") => #f
  (string-contains "abcabc" "b" 2) => 4
```

### `string-contains-ci`

```
Syntax: (string-contains-ci s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string-contains. Uses KMP algorithm.
Example:
  (string-contains-ci "Hello World" "world") => 6
```

### `string-copy`

```
Syntax: (string-copy string)
       (string-copy string start)
       (string-copy string start end)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated copy of the part of the given string
  between start and end. start defaults to 0 and end defaults to the length
  of the string.
Example:
  (string-copy "abc")     => "abc"
  (string-copy "abc" 1)   => "bc"
  (string-copy "abc" 1 2) => "b"
```

### `string-copy!`

```
Syntax: (string-copy! to at from)
       (string-copy! to at from start)
       (string-copy! to at from start end)
Library: (scheme base) (srfi 13)
Description: Copies the characters of string from between start and end to
  string to, starting at at. The order in which characters are copied is
  unspecified, except that if the source and destination overlap, copying
  takes place as if the source is first copied into a temporary string and
  then into the destination. start defaults to 0 and end defaults to the
  length of from.
Example:
  (let ((s (string-copy "hello")))
    (string-copy! s 1 "xyz" 0 2)
    s) => "hxylo"
```

### `string-count`

```
Syntax: (string-count s criterion [start [end]])
Library: (srfi 13)
Description: Counts the number of characters in s[start..end) matching criterion.
Example:
  (string-count "hello world" char-alphabetic?) => 10
```

### `string-delete`

```
Syntax: (string-delete criterion s [start [end]])
Library: (srfi 13)
Description: Returns s[start..end) with characters matching criterion removed.
Example:
  (string-delete char-whitespace? "hello world") => "helloworld"
```

### `string-downcase`

```
Syntax: (string-downcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the lowercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping.
Example:
  (string-downcase "Hello World") => "hello world"
  (string-downcase "HELLO" 1 3)   => "el"
```

### `string-downcase!`

```
Syntax: (string-downcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the lowercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping.
Example:
  (string-downcase "Hello World") => "hello world"
  (string-downcase "HELLO" 1 3)   => "el"
```

### `string-drop`

```
Syntax: (string-drop s n)
Library: (srfi 13)
Description: Returns s with the first n characters removed.
Example:
  (string-drop "hello" 2) => "llo"
```

### `string-drop-right`

```
Syntax: (string-drop-right s n)
Library: (srfi 13)
Description: Returns s with the last n characters removed.
Example:
  (string-drop-right "hello" 2) => "hel"
```

### `string-every`

```
Syntax: (string-every criterion s [start [end]])
Library: (srfi 13)
Description: Returns #t if criterion is satisfied by every character in
s[start..end), or #f as soon as it fails.
Example:
  (string-every char-alphabetic? "hello") => #t
  (string-every char-alphabetic? "hello1") => #f
```

### `string-fill!`

```
Syntax: (string-fill! string char)
       (string-fill! string char start)
       (string-fill! string char start end)
Library: (scheme base) (srfi 13)
Description: Stores char in every element of the given string between start
  and end. start defaults to 0 and end defaults to the length of the string.
Example:
  (let ((s (make-string 3 #\a)))
    (string-fill! s #\x)
    s) => "xxx"
  (let ((s (string-copy "hello")))
    (string-fill! s #\x 1 3)
    s) => "hxxlo"
```

### `string-filter`

```
Syntax: (string-filter criterion s [start [end]])
Library: (srfi 13)
Description: Returns a string of characters from s[start..end) that match criterion.
Example:
  (string-filter char-alphabetic? "h3ll0 w0rld") => "hllwrld"
```

### `string-fold`

```
Syntax: (string-fold kons knil s [start [end]])
Library: (srfi 13)
Description: Left-to-right fold over the characters of s[start..end). kons receives (char acc).
Example:
  (string-fold cons '() "hello") => (#\o #\l #\l #\e #\h)
```

### `string-fold-right`

```
Syntax: (string-fold-right kons knil s [start [end]])
Library: (srfi 13)
Description: Right-to-left fold over the characters of s[start..end). kons receives (char acc).
Example:
  (string-fold-right cons '() "hello") => (#\h #\e #\l #\l #\o)
```

### `string-for-each`

```
Syntax: (string-for-each proc string1 string2 ...)
       (string-for-each proc string [start [end]])
Library: (scheme base) (srfi 13)
Description: When given multiple strings, applies proc element-wise to the
  characters of the strings in order for side effects (R7RS).
  When given optional integer start/end indices, applies proc to each
  character of string[start..end) in order (SRFI-13).
Example:
  (string-for-each display "abc") ; displays abc
```

### `string-for-each-index`

```
Syntax: (string-for-each-index proc s [start [end]])
Library: (srfi 13)
Description: Applies proc to each valid index of s[start..end) in order, for side effects.
Example:
  (string-for-each-index display "hello") ; displays 0 1 2 3 4
```

### `string-hash`

```
Syntax: (string-hash s [bound [start [end]]])
Library: (srfi 13)
Description: Returns a hash of s[start..end) as a non-negative integer less than bound.
Example:
  (string-hash "hello") => some integer
  (string-hash "hello" 100) => some integer < 100
```

### `string-hash-ci`

```
Syntax: (string-hash-ci s [bound [start [end]]])
Library: (srfi 13)
Description: Case-insensitive string hash.
Example:
  (= (string-hash-ci "Hello") (string-hash-ci "hello")) => #t
```

### `string-index`

```
Syntax: (string-index s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the first character in s[start..end) matching criterion.
Example:
  (string-index "hello" #\l) => 2
  (string-index "hello" char-upper-case?) => #f
```

### `string-index-right`

```
Syntax: (string-index-right s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the last character in s[start..end) matching criterion.
Example:
  (string-index-right "hello" #\l) => 3
```

### `string-join`

```
Syntax: (string-join strs delim grammar?)
Library: (srfi 13)
Description: Concatenates a list of strings strs with delim as the separator. The optional grammar argument may be 'infix (default), 'prefix, or 'suffix.
Example:
  (string-join '("a" "b" "c") "-") => "a-b-c"
  (string-join '("x" "y") "," 'suffix) => "x,y,"
```

### `string-kmp-partial-search`

```
Syntax: (string-kmp-partial-search pattern rv text i [c= [p-start [start [end]]]])
Library: (srfi 13)
Description: Searches text for pattern using KMP with partial match state.
Example:
  (let* ((pat "abc") (rv (make-kmp-restart-vector pat)))
    (string-kmp-partial-search pat rv "xyzabc" 0)) => -6
```

### `string-length`

```
Syntax: (string-length s)
Library: (scheme base) (srfi 13)
Description: Returns the number of characters in the string s.
Example:
  (string-length "hello") => 5
  (string-length "") => 0
```

### `string-map`

```
Syntax: (string-map proc string1 string2 ...)
       (string-map proc string [start [end]])
Library: (scheme base) (srfi 13)
Description: When given multiple strings, applies proc element-wise to the
  characters of the strings and returns a string of the results. If multiple
  strings are given, they must all have the same length (R7RS).
  When given optional integer start/end indices, maps proc over the characters
  of string[start..end) and returns a new string (SRFI-13).
Example:
  (string-map char-upcase "hello")       => "HELLO"
  (string-map char-upcase "hello" 1 3)   => "EL"
  (string-map (lambda (c) c) "xyz")      => "xyz"
```

### `string-map!`

```
Syntax: (string-map! proc s [start [end]])
Library: (srfi 13)
Description: Applies proc to each character of s[start..end) and stores the result back.
Example:
  (let ((s (string-copy "hello"))) (string-map! char-upcase s) s) => "HELLO"
```

### `string-null?`

```
Syntax: (string-null? s)
Library: (srfi 13)
Description: Returns #t if s is the empty string (length 0), #f otherwise.
Example:
  (string-null? "") => #t
  (string-null? "hi") => #f
```

### `string-pad`

```
Syntax: (string-pad s k [char [start [end]]])
Library: (srfi 13)
Description: Left-pads s[start..end) to width k using char (default: space).
Example:
  (string-pad "42" 5) => "   42"
  (string-pad "hello" 3) => "llo"
```

### `string-pad-right`

```
Syntax: (string-pad-right s k [char [start [end]]])
Library: (srfi 13)
Description: Right-pads s[start..end) to width k using char (default: space).
Example:
  (string-pad-right "42" 5) => "42   "
  (string-pad-right "hello" 3) => "hel"
```

### `string-parse-final-start+end`

```
Syntax: (string-parse-final-start+end proc s rest)
Library: (srfi 13)
Description: Like string-parse-start+end but signals an error if extra args remain.
Example:
  (string-parse-final-start+end 'my-proc "hello" '(1 4)) => 1 and 4
```

### `string-parse-start+end`

```
Syntax: (string-parse-start+end proc s rest)
Library: (srfi 13)
Description: Validates and extracts start and end indices from the rest argument list.
Returns three values: the remaining args, start, and end.
Example:
  (string-parse-start+end 'my-proc "hello" '(1 4 extra)) => (extra) 1 4
```

### `string-prefix-ci?`

```
Syntax: (string-prefix-ci? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-prefix?.
Example:
  (string-prefix-ci? "HEL" "hello") => #t
```

### `string-prefix-length`

```
Syntax: (string-prefix-length s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the length of the longest common prefix of s1 and s2.
Example:
  (string-prefix-length "abcdef" "abcxyz") => 3
```

### `string-prefix-length-ci`

```
Syntax: (string-prefix-length-ci s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-prefix-length.
Example:
  (string-prefix-length-ci "ABCdef" "abcxyz") => 3
```

### `string-prefix?`

```
Syntax: (string-prefix? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Returns #t if s1 is a prefix of s2.
Example:
  (string-prefix? "hel" "hello") => #t
  (string-prefix? "world" "hello") => #f
```

### `string-ref`

```
Syntax: (string-ref s k)
Library: (scheme base) (srfi 13)
Description: Returns the character at index k in the string s. It is an error if k is out of range.
Example:
  (string-ref "hello" 0) => #\h
  (string-ref "hello" 4) => #\o
```

### `string-replace`

```
Syntax: (string-replace s1 s2 start1 end1 [start2 [end2]])
Library: (srfi 13)
Description: Returns a string built from s1 with s1[start1,end1) replaced by s2[start2,end2).
Example:
  (string-replace "abcdef" "XY" 2 4) => "abXYef"
```

### `string-reverse`

```
Syntax: (string-reverse s [start [end]])
Library: (srfi 13)
Description: Returns a new string that is the reverse of s[start..end).
Example:
  (string-reverse "hello") => "olleh"
```

### `string-reverse!`

```
Syntax: (string-reverse s [start [end]])
Library: (srfi 13)
Description: Returns a new string that is the reverse of s[start..end).
Example:
  (string-reverse "hello") => "olleh"
```

### `string-set!`

```
Syntax: (string-set! s k char)
Library: (scheme base) (srfi 13)
Description: Stores char in position k of the string s, mutating the string in place. It is an error if k is out of range.
Example:
  (let ((s (string-copy "hello")))
    (string-set! s 0 #\H)
    s) => "Hello"
```

### `string-skip`

```
Syntax: (string-skip s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the first character in s[start..end) NOT matching criterion.
Example:
  (string-skip "  hello" char-whitespace?) => 2
```

### `string-skip-right`

```
Syntax: (string-skip-right s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the last character in s[start..end) NOT matching criterion.
Example:
  (string-skip-right "hello  " char-whitespace?) => 4
```

### `string-suffix-ci?`

```
Syntax: (string-suffix-ci? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-suffix?.
Example:
  (string-suffix-ci? "LLO" "hello") => #t
```

### `string-suffix-length`

```
Syntax: (string-suffix-length s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the length of the longest common suffix of s1 and s2.
Example:
  (string-suffix-length "xyzdef" "abcdef") => 3
```

### `string-suffix-length-ci`

```
Syntax: (string-suffix-length-ci s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-suffix-length.
Example:
  (string-suffix-length-ci "xyzDEF" "abcdef") => 3
```

### `string-suffix?`

```
Syntax: (string-suffix? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Returns #t if s1 is a suffix of s2.
Example:
  (string-suffix? "llo" "hello") => #t
  (string-suffix? "hel" "hello") => #f
```

### `string-tabulate`

```
Syntax: (string-tabulate f n)
Library: (srfi 13)
Description: Builds a string of length n by applying f to each index 0, 1, ..., n-1 in order.
Example:
  (string-tabulate (lambda (i) (integer->char (+ i 65))) 5) => "ABCDE"
```

### `string-take`

```
Syntax: (string-take s n)
Library: (srfi 13)
Description: Returns the first n characters of s.
Example:
  (string-take "hello" 3) => "hel"
```

### `string-take-right`

```
Syntax: (string-take-right s n)
Library: (srfi 13)
Description: Returns the last n characters of s.
Example:
  (string-take-right "hello" 3) => "llo"
```

### `string-titlecase`

```
Syntax: (string-titlecase s [start [end]])
Library: (srfi 13)
Description: Returns a titlecased copy of s[start..end): the first alphabetic character of each
word is uppercased and the rest are lowercased.
Example:
  (string-titlecase "hello world") => "Hello World"
```

### `string-titlecase!`

```
Syntax: (string-titlecase s [start [end]])
Library: (srfi 13)
Description: Returns a titlecased copy of s[start..end): the first alphabetic character of each
word is uppercased and the rest are lowercased.
Example:
  (string-titlecase "hello world") => "Hello World"
```

### `string-tokenize`

```
Syntax: (string-tokenize s [token-set [start [end]]])
Library: (srfi 13)
Description: Splits s into a list of token strings, where a token is a maximal
non-empty contiguous sequence of chars in token-set (default: char-set:graphic).
Example:
  (string-tokenize "hello world") => ("hello" "world")
```

### `string-trim`

```
Syntax: (string-trim s [criterion [start [end]]])
Library: (srfi 13)
Description: Trims characters matching criterion from the left of s. Default: whitespace.
Example:
  (string-trim "  hello  ") => "hello  "
```

### `string-trim-both`

```
Syntax: (string-trim-both s [criterion [start [end]]])
Library: (srfi 13)
Description: Trims characters matching criterion from both sides of s. Default: whitespace.
Example:
  (string-trim-both "  hello  ") => "hello"
```

### `string-trim-right`

```
Syntax: (string-trim-right s [criterion [start [end]]])
Library: (srfi 13)
Description: Trims characters matching criterion from the right of s. Default: whitespace.
Example:
  (string-trim-right "  hello  ") => "  hello"
```

### `string-unfold`

```
Syntax: (string-unfold p f g seed [base [make-final]])
Library: (srfi 13)
Description: Builds a string by unfolding seed left-to-right. p is the termination predicate;
f maps seed to a character; g maps seed to the next seed. Optional base string is prepended;
make-final is called on the final seed to produce a suffix string.
Example:
  (string-unfold null? car cdr '(#\h #\e #\l #\l #\o)) => "hello"
```

### `string-unfold-right`

```
Syntax: (string-unfold-right p f g seed [base [make-final]])
Library: (srfi 13)
Description: Builds a string by unfolding seed right-to-left. p is the termination predicate;
f maps seed to a character; g maps seed to the next seed. Optional base string is appended;
make-final is called on the final seed to produce a prefix string.
Example:
  (string-unfold-right null? car cdr '(#\o #\l #\l #\e #\h)) => "hello"
```

### `string-upcase`

```
Syntax: (string-upcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the uppercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping (e.g. ß → SS).
Example:
  (string-upcase "hello world") => "HELLO WORLD"
  (string-upcase "ßa") => "SSA"
```

### `string-upcase!`

```
Syntax: (string-upcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the uppercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping (e.g. ß → SS).
Example:
  (string-upcase "hello world") => "HELLO WORLD"
  (string-upcase "ßa") => "SSA"
```

### `string-xcopy!`

```
Syntax: (string-xcopy! target tstart s sfrom [sto [start [end]]])
Library: (srfi 13)
Description: Copies a cyclically repeated substring of s into target starting at tstart.
Example:
  (let ((t (string-copy "......"))) (string-xcopy! t 0 "abc" 0 6) t) => "abcabc"
```

### `string<`

```
Syntax: (string< s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 < s2, #f otherwise.
Example:
  (string< "abc" "abd") => 2
  (string< "abd" "abc") => #f
```

### `string<=`

```
Syntax: (string<= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 <= s2, #f otherwise.
Example:
  (string<= "abc" "abc") => 3
  (string<= "abc" "abd") => 2
```

### `string<>`

```
Syntax: (string<> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 and s2 are not equal, #f otherwise.
Example:
  (string<> "abc" "def") => 0
  (string<> "abc" "abc") => #f
```

### `string=`

```
Syntax: (string= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 and s2 are equal, #f otherwise.
Example:
  (string= "abc" "abc") => 3
  (string= "abc" "abd") => #f
```

### `string>`

```
Syntax: (string> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 > s2, #f otherwise.
Example:
  (string> "abd" "abc") => 2
  (string> "abc" "abd") => #f
```

### `string>=`

```
Syntax: (string>= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 >= s2, #f otherwise.
Example:
  (string>= "abc" "abc") => 3
  (string>= "abd" "abc") => 2
```

### `string?`

```
Syntax: (string? obj)
Library: (scheme base) (srfi 13)
Description: Returns #t if obj is a string, otherwise returns #f.
Example:
  (string? "hello") => #t
  (string? 42) => #f
```

### `substring-spec-ok?`

```
Syntax: (substring-spec-ok? s start end)
Library: (srfi 13)
Description: Returns #t if start and end are valid substring indices for s.
Example:
  (substring-spec-ok? "hello" 0 5) => #t
  (substring-spec-ok? "hello" 3 2) => #f
```

### `substring/shared`

```
Syntax: (substring/shared s start [end])
Library: (srfi 13)
Description: Returns a substring of s from start to end.
Example:
  (substring/shared "hello" 1 4) => "ell"
  (substring/shared "hello" 2) => "llo"
```

### `xsubstring`

```
Syntax: (xsubstring s from [to [start [end]]])
Library: (srfi 13)
Description: Returns a substring of the virtual infinite string formed by repeating s cyclically.
Example:
  (xsubstring "hello" 2 7) => "llohe"
  (xsubstring "abc" 0 9) => "abcabcabc"
```

