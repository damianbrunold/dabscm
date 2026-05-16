(define-library (scm compression)
  (import (scm core))
  (export deflate-compress
          deflate-decompress
          zlib-compress
          zlib-decompress
          gzip-compress
          gzip-decompress)
  (begin
    (define deflate-compress   (%primitive "deflate-compress"))
    (define deflate-decompress (%primitive "deflate-decompress"))
    (define zlib-compress      (%primitive "zlib-compress"))
    (define zlib-decompress    (%primitive "zlib-decompress"))
    (define gzip-compress      (%primitive "gzip-compress"))
    (define gzip-decompress    (%primitive "gzip-decompress"))))
