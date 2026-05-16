(define-library (scheme char)
  (import (scm core))
  (export char->integer
          char-alphabetic?
          char-ci<=?
          char-ci<?
          char-ci=?
          char-ci>=?
          char-ci>?
          char-downcase
          char-foldcase
          char-lower-case?
          char-numeric?
          char-upcase
          char-upper-case?
          char-whitespace?
          char<=?
          char<?
          char=?
          char>=?
          char>?
          char?
          digit-value
          integer->char
          string-ci<=?
          string-ci<?
          string-ci=?
          string-ci>=?
          string-ci>?
          string-downcase
          string-foldcase
          string-upcase)
  (begin
    (define apply (%primitive "apply"))
    (define string-copy (%primitive "string-copy"))
    (define substring (%primitive "substring"))
    (define string-length (%primitive "string-length"))
    (define string-set! (%primitive "string-set!"))
    (define string-ref (%primitive "string-ref"))
    (define string=? (%primitive "string=?"))
    (define string<? (%primitive "string<?"))
    (define string<=? (%primitive "string<=?"))
    (define string>? (%primitive "string>?"))
    (define string>=? (%primitive "string>=?"))

    (define digit-value (%primitive "digit-value"))

    (define char? (%primitive "char?"))
    (define char->integer (%primitive "char->integer"))
    (define integer->char (%primitive "integer->char"))
    (define char-alphabetic? (%primitive "char-alphabetic?"))
    (define char-numeric? (%primitive "char-numeric?"))
    (define char-whitespace? (%primitive "char-whitespace?"))
    (define char-upcase (%primitive "char-upcase"))
    (define char-downcase (%primitive "char-downcase"))
    (define char-upper-case? (%primitive "char-upper-case?"))
    (define char-lower-case? (%primitive "char-lower-case?"))
    (define char=? (%primitive "char=?"))
    (define char<? (%primitive "char<?"))
    (define char<=? (%primitive "char<=?"))
    (define char>? (%primitive "char>?"))
    (define char>=? (%primitive "char>=?"))
    (define (char-ci=?  . chars)
      "Syntax: (char-ci=? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if all given characters are equal when compared in a case-insensitive manner,
  that is, after applying char-downcase to each. Accepts one or more character arguments.
Example:
  (char-ci=? #\\A #\\a) => #t
  (char-ci=? #\\B #\\b #\\B) => #t"
      (apply char=?  (map char-downcase chars)))
    (define (char-ci<?  . chars)
      "Syntax: (char-ci<? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically increasing (strictly less than)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci<? #\\a #\\B) => #t
  (char-ci<? #\\A #\\b #\\C) => #t"
      (apply char<?  (map char-downcase chars)))
    (define (char-ci<=? . chars)
      "Syntax: (char-ci<=? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically non-decreasing (less than or equal)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci<=? #\\a #\\A) => #t
  (char-ci<=? #\\A #\\b #\\B) => #t"
      (apply char<=? (map char-downcase chars)))
    (define (char-ci>?  . chars)
      "Syntax: (char-ci>? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically decreasing (strictly greater than)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci>? #\\B #\\a) => #t
  (char-ci>? #\\C #\\b #\\A) => #t"
      (apply char>?  (map char-downcase chars)))
    (define (char-ci>=? . chars)
      "Syntax: (char-ci>=? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically non-increasing (greater than or equal)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci>=? #\\A #\\a) => #t
  (char-ci>=? #\\C #\\B #\\a) => #t"
      (apply char>=? (map char-downcase chars)))

    ;; String case conversion uses platform primitives for full Unicode support
    ;; (including one-to-many mappings like ß→SS).
    ;; The primitives handle the base case (full string). Optional start/end
    ;; parameters are handled by wrapping with substring.
    (define %string-downcase (%primitive "string-downcase"))
    (define (string-downcase s . rest)
      "Syntax: (string-downcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the lowercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping.
Example:
  (string-downcase \"Hello World\") => \"hello world\"
  (string-downcase \"HELLO\" 1 3)   => \"el\""
      (if (null? rest)
          (%string-downcase s)
          (let* ((start (car rest))
                 (end (if (null? (cdr rest)) (string-length s) (car (cdr rest)))))
            (%string-downcase (substring s start end)))))

    (define %string-upcase (%primitive "string-upcase"))
    (define (string-upcase s . rest)
      "Syntax: (string-upcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the uppercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping (e.g. ß → SS).
Example:
  (string-upcase \"hello world\") => \"HELLO WORLD\"
  (string-upcase \"ßa\") => \"SSA\""
      (if (null? rest)
          (%string-upcase s)
          (let* ((start (car rest))
                 (end (if (null? (cdr rest)) (string-length s) (car (cdr rest)))))
            (%string-upcase (substring s start end)))))

    (define string-foldcase (%primitive "string-foldcase"))
    (define char-foldcase   (%primitive "char-foldcase"))

    (define (string-ci=?  . strs)
      "Syntax: (string-ci=? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if all given strings are equal when compared in a case-insensitive manner,
  that is, after applying string-downcase to each.
Example:
  (string-ci=? \"Hello\" \"hello\") => #t
  (string-ci=? \"ABC\" \"abc\" \"Abc\") => #t"
      (apply string=?  (map string-downcase strs)))
    (define (string-ci<?  . strs)
      "Syntax: (string-ci<? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in strictly ascending lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci<? \"apple\" \"Banana\") => #t
  (string-ci<? \"a\" \"B\" \"c\") => #t"
      (apply string<?  (map string-downcase strs)))
    (define (string-ci<=? . strs)
      "Syntax: (string-ci<=? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in non-decreasing lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci<=? \"abc\" \"ABC\") => #t
  (string-ci<=? \"Apple\" \"apple\" \"Banana\") => #t"
      (apply string<=? (map string-downcase strs)))
    (define (string-ci>?  . strs)
      "Syntax: (string-ci>? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in strictly descending lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci>? \"Banana\" \"apple\") => #t
  (string-ci>? \"c\" \"B\" \"a\") => #t"
      (apply string>?  (map string-downcase strs)))
    (define (string-ci>=? . strs)
      "Syntax: (string-ci>=? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in non-increasing lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci>=? \"ABC\" \"abc\") => #t
  (string-ci>=? \"Banana\" \"apple\" \"Apple\") => #t"
      (apply string>=? (map string-downcase strs)))))
