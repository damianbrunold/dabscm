(define-library (scheme cxr)
  (export caaaar
          caaadr
          caaar
          caadar
          caaddr
          caadr
          cadaar
          cadadr
          cadar
          caddar
          cadddr
          caddr
          cdaaar
          cdaadr
          cdaar
          cdadar
          cdaddr
          cdadr
          cddaar
          cddadr
          cddar
          cdddar
          cddddr
          cdddr)
  (begin
    (define caaar (%primitive "caaar"))
    (define caadr (%primitive "caadr"))
    (define cadar (%primitive "cadar"))
    (define caddr (%primitive "caddr"))
    (define cdaar (%primitive "cdaar"))
    (define cdadr (%primitive "cdadr"))
    (define cddar (%primitive "cddar"))
    (define cdddr (%primitive "cdddr"))
    (define caaaar (%primitive "caaaar"))
    (define caaadr (%primitive "caaadr"))
    (define caadar (%primitive "caadar"))
    (define caaddr (%primitive "caaddr"))
    (define cadaar (%primitive "cadaar"))
    (define cadadr (%primitive "cadadr"))
    (define caddar (%primitive "caddar"))
    (define cadddr (%primitive "cadddr"))
    (define cdaaar (%primitive "cdaaar"))
    (define cdaadr (%primitive "cdaadr"))
    (define cdadar (%primitive "cdadar"))
    (define cdaddr (%primitive "cdaddr"))
    (define cddaar (%primitive "cddaar"))
    (define cddadr (%primitive "cddadr"))
    (define cdddar (%primitive "cdddar"))
    (define cddddr (%primitive "cddddr"))))
