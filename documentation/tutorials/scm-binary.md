---
title: "(scm bytevector) and (scm random access): binary data"
part: libraries
order: 1046
libraries: (scm bytevector) (scm random access)
summary: Multi-byte integers and floats in bytevectors with either byte order; writing and reading a WAV sound file header; telling UTF-8 from Latin-1 text; files read and written at any position; a file of fixed-size records updated in place; growing and truncating files.
---
# (scm bytevector) and (scm random access): binary data

R7RS bytevectors hold bytes. Binary file formats store larger values in
them: 16- and 32-bit integers and floating-point numbers, in one byte
order or the other. `(scm bytevector)` reads and writes those, and
`(scm random access)` reads and writes files at any position, without
reading them from the start.

```scheme
(import (scheme base) (scheme file) (scheme inexact) (scheme write) (scm fs) (scm bytevector) (scm random access))

(define dir (mktempdir '(prefix . "binary")))
(define (at name) (join-path dir name))
```

## Numbers in bytes

A number of several bytes can be stored lowest byte first (*little
endian*, as x86 and ARM processors and most file formats do) or highest
byte first (*big endian*, "network byte order"):

```scheme
(define bv (make-bytevector 8 0))
(bytevector-u16-set! bv 0 513 'little)
(bytevector-u16-set! bv 2 513 'big)
bv                                          ;; => #u8(1 2 2 1 0 0 0 0)
(bytevector-u16-ref bv 0 'little)           ;; => 513
(bytevector-u16-ref bv 0 'big)              ;; => 258
```

Reading with the wrong byte order gives a wrong value, not an error, so
check the format's specification. The procedures follow R6RS:

| procedure | value |
|---|---|
| `bytevector-u16-ref` / `-s16-ref` | unsigned / signed 16-bit integer |
| `bytevector-u32-ref` / `-s32-ref` | unsigned / signed 32-bit integer |
| `bytevector-ieee-single-ref` | 32-bit float |
| `bytevector-ieee-double-ref` | 64-bit float |

each with a `-set!`. The index is a byte position and need not be
aligned:

```scheme
(bytevector-s16-set! bv 0 -2 'little)
(bytevector-copy bv 0 2)                    ;; => #u8(254 255)
(bytevector-u16-ref bv 0 'little)           ;; => 65534
(bytevector-ieee-double-set! bv 0 3.5 'big)
(bytevector-ieee-double-ref bv 0 'big)      ;; => 3.5
```

## Example: a WAV file

A WAV sound file starts with a 44-byte header of tags and little-endian
numbers, followed by the samples. One second of a 440 Hz tone, 8000
samples of 16 bits:

```scheme
(define rate 8000)

(define (wav-bytes samples)                 ; samples: a vector of integers -32768..32767
  (let* ((n (vector-length samples))
         (data-size (* 2 n))
         (bv (make-bytevector (+ 44 data-size) 0)))
    (define (tag! pos s) (bytevector-copy! bv pos (string->utf8 s)))
    (tag! 0 "RIFF") (bytevector-u32-set! bv 4 (+ 36 data-size) 'little)
    (tag! 8 "WAVE")
    (tag! 12 "fmt ") (bytevector-u32-set! bv 16 16 'little)
    (bytevector-u16-set! bv 20 1 'little)                 ; PCM
    (bytevector-u16-set! bv 22 1 'little)                 ; mono
    (bytevector-u32-set! bv 24 rate 'little)              ; samples per second
    (bytevector-u32-set! bv 28 (* 2 rate) 'little)        ; bytes per second
    (bytevector-u16-set! bv 32 2 'little)                 ; bytes per sample
    (bytevector-u16-set! bv 34 16 'little)                ; bits per sample
    (tag! 36 "data") (bytevector-u32-set! bv 40 data-size 'little)
    (do ((i 0 (+ i 1))) ((= i n) bv)
      (bytevector-s16-set! bv (+ 44 (* 2 i)) (vector-ref samples i) 'little))))

(define tone
  (let ((v (make-vector rate)))
    (do ((i 0 (+ i 1))) ((= i rate) v)
      (vector-set! v i (exact (round (* 8000 (sin (/ (* 2 3.141592653589793 440 i) rate)))))))))

(call-with-port (open-binary-output-file (at "tone.wav"))
  (lambda (p) (write-bytevector (wav-bytes tone) p)))
(file-size (at "tone.wav"))                 ;; => 16044
```

Reading the header back:

```scheme
(define header (call-with-port (open-binary-input-file (at "tone.wav"))
                 (lambda (p) (read-bytevector 44 p))))
(utf8->string (bytevector-copy header 8 12))  ;; => "WAVE"
(list (bytevector-u16-ref header 22 'little)  ; channels
      (bytevector-u32-ref header 24 'little)  ; sample rate
      (bytevector-u16-ref header 34 'little)) ; bits
;; => (1 8000 16)
```

## Text in bytes

Files from older systems are often in Latin-1 (ISO-8859-1) rather than
UTF-8. `utf8-valid?` tells them apart, and `latin1->string` decodes the
older ones:

```scheme
(define utf8-bytes (string->utf8 "Grüezi"))
(define latin1-bytes (string->latin1 "Grüezi"))
utf8-bytes                                  ;; => #u8(71 114 195 188 101 122 105)
latin1-bytes                                ;; => #u8(71 114 252 101 122 105)

(define (decode bv) (if (utf8-valid? bv) (utf8->string bv) (latin1->string bv)))
(decode utf8-bytes)                         ;; => "Grüezi"
(decode latin1-bytes)                       ;; => "Grüezi"
(string->latin1 "5 €" 63)                   ;; => #u8(53 32 63)
```

The euro sign does not exist in Latin-1; the optional second argument is
the byte written instead (63 is `?`), otherwise it is an error.

## Files at any position

A port reads a file from the beginning. `(scm random access)` reads and
writes at any byte offset, as databases do. A file of fixed-size records
can then be updated in place: here a stock file with 16 bytes per tea,
a 12-byte name and a 32-bit stock in grams:

```scheme
(define record-size 16)

(define (encode name grams)
  (let ((bv (make-bytevector record-size 32)))           ; padded with spaces
    (bytevector-copy! bv 0 (string->utf8 name))
    (bytevector-u32-set! bv 12 grams 'little)
    bv))

(define (decode-record bv)
  (list (string-trim-spaces (utf8->string (bytevector-copy bv 0 12)))
        (bytevector-u32-ref bv 12 'little)))

(define (string-trim-spaces s)
  (let loop ((e (string-length s)))
    (if (and (> e 0) (char=? (string-ref s (- e 1)) #\space)) (loop (- e 1)) (substring s 0 e))))

(call-with-random-access-file (at "stock.dat") 'write
  (lambda (f)
    (for-each (lambda (i tea)
                (random-access-file-write! f (* i record-size) (encode (car tea) (cadr tea))))
              '(0 1 2)
              '(("Sencha" 12500) ("Assam" 4000) ("Matcha" 800)))))
(file-size (at "stock.dat"))                ;; => 48
```

Selling 250 g of Assam reads and rewrites only record 1:

```scheme
(define (record f i) (decode-record (random-access-file-read f (* i record-size) record-size)))

(call-with-random-access-file (at "stock.dat") 'update
  (lambda (f)
    (let ((assam (record f 1)))
      (random-access-file-write! f (* 1 record-size) (encode (car assam) (- (cadr assam) 250)))
      (random-access-file-flush f)
      (map (lambda (i) (record f i)) '(0 1 2)))))
;; => (("Sencha" 12500) ("Assam" 3750) ("Matcha" 800))
```

- The modes are `read`, `write` (creates or empties the file) and
  `update` (keeps it, creating it if needed).
- `random-access-file-flush` makes sure the data reached the disk,
  before telling a user that something was saved.
- `random-access-file-size` and `random-access-file-truncate!` read and
  set the length, for example to drop the last record:

```scheme
(call-with-random-access-file (at "stock.dat") 'update
  (lambda (f)
    (random-access-file-truncate! f (* 2 record-size))
    (random-access-file-size f)))
;; => 32
(rm dir 'recursive)
```

`(scm store)` is built on this: a key-value store on disk with
transactions ([its tutorial](scm-store.md)).

## Where next

- [Files](techniques-03-files.md#binary-files) for binary ports,
  [archives](scm-archive.md) for compressed data, [images](scm-images.md)
  for PNG and JPEG.
- Reference: `(scm bytevector)`, `(scm random access)`.
