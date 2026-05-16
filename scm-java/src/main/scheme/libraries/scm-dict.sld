(define-library (scm dict)
  (export dict-clear
          dict-contains
          dict-entries
          dict-get
          dict-keys
          dict-put
          dict-size
          dict-values
          make-dict)
  (begin
    (define make-dict (%primitive "make-dict"))
    (define dict-get (%primitive "dict-get"))
    (define dict-put (%primitive "dict-put"))
    (define dict-contains (%primitive "dict-contains"))
    (define dict-clear (%primitive "dict-clear"))
    (define dict-size (%primitive "dict-size"))
    (define dict-keys (%primitive "dict-keys"))
    (define dict-values (%primitive "dict-values"))
    (define dict-entries (%primitive "dict-entries"))))
