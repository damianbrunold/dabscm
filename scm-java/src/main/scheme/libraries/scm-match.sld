;; This code is written by Alex Shinn and placed in the
;; Public Domain.  All warranties are disclaimed.

(define-library (scm match)
  (import (scheme base) (scheme cxr))
  (export match match-lambda match-lambda* match-let match-letrec match-let*)
  (begin

(define-syntax match-syntax-error
  (syntax-rules ()
    ((_) (syntax-error "invalid match-syntax-error usage"))))

(define-syntax match
  (syntax-rules ()
    ((match)
     (match-syntax-error "missing match expression"))
    ((match atom)
     (match-syntax-error "no match clauses"))
    ((match (app ...) (pat . body) ...)
     (let ((v (app ...)))
       (match-next v ((app ...) (set! (app ...))) (pat . body) ...)))
    ((match #(vec ...) (pat . body) ...)
     (let ((v #(vec ...)))
       (match-next v (v (set! v)) (pat . body) ...)))
    ((match atom (pat . body) ...)
     (let ((v atom))
       (match-next v (atom (set! atom)) (pat . body) ...)))
    ))

(define-syntax match-next
  (syntax-rules (=>)
    ;; no more clauses, the match failed
    ((match-next v g+s)
     (error 'match "no matching pattern"))
    ;; named failure continuation
    ((match-next v g+s (pat (=> failure) . body) . rest)
     (let ((failure (lambda () (match-next v g+s . rest))))
       ;; match-one analyzes the pattern for us
       (match-one v pat g+s (match-drop-ids (begin . body)) (failure) ())))
    ;; anonymous failure continuation, give it a dummy name
    ((match-next v g+s (pat . body) . rest)
     (match-next v g+s (pat (=> failure) . body) . rest))))

(define-syntax match-one
  (syntax-rules ()
    ;; If it's a list of two or more values, check to see if the
    ;; second one is an ellipsis and handle accordingly, otherwise go
    ;; to MATCH-TWO.
    ((match-one v (p q . r) g+s sk fk i)
     (match-check-ellipsis
      q
      (match-extract-vars p (match-gen-ellipsis v p r  g+s sk fk i) i ())
      (match-two v (p q . r) g+s sk fk i)))
    ;; Go directly to MATCH-TWO.
    ((match-one . x)
     (match-two . x))))

(define-syntax match-two
  (syntax-rules (_ ___ **1 =.. *.. *** quote quasiquote ? $ struct @ object = and or not set! get!)
    ((match-two v () g+s (sk ...) fk i)
     (if (null? v) (sk ... i) fk))
    ((match-two v (quote p) g+s (sk ...) fk i)
     (if (equal? v 'p) (sk ... i) fk))
    ((match-two v (quasiquote p) . x)
     (match-quasiquote v p . x))
    ((match-two v (and) g+s (sk ...) fk i) (sk ... i))
    ((match-two v (and p q ...) g+s sk fk i)
     (match-one v p g+s (match-one v (and q ...) g+s sk fk) fk i))
    ((match-two v (or) g+s sk fk i) fk)
    ((match-two v (or p) . x)
     (match-one v p . x))
    ((match-two v (or p ...) g+s sk fk i)
     (match-extract-vars (or p ...) (match-gen-or v (p ...) g+s sk fk i) i ()))
    ((match-two v (not p) g+s (sk ...) fk i)
     (let ((fk2 (lambda () (sk ... i))))
       (match-one v p g+s (match-drop-ids fk) (fk2) i)))
    ((match-two v (get! getter) (g s) (sk ...) fk i)
     (let ((getter (lambda () g))) (sk ... i)))
    ((match-two v (set! setter) (g (s ...)) (sk ...) fk i)
     (let ((setter (lambda (x) (s ... x)))) (sk ... i)))
    ((match-two v (? pred . p) g+s sk fk i)
     (if (pred v) (match-one v (and . p) g+s sk fk i) fk))
    ((match-two v (= proc p) . x)
     (let ((w (proc v))) (match-one w p . x)))
    ((match-two v (p ___ . r) g+s sk fk i)
     (match-extract-vars p (match-gen-ellipsis v p r g+s sk fk i) i ()))
    ((match-two v (p) g+s sk fk i)
     (if (and (pair? v) (null? (cdr v)))
         (let ((w (car v)))
           (match-one w p ((car v) (set-car! v)) sk fk i))
         fk))
    ((match-two v (p *** q) g+s sk fk i)
     (match-extract-vars p (match-gen-search v p q g+s sk fk i) i ()))
    ((match-two v (p *** . q) g+s sk fk i)
     (match-syntax-error "invalid use of ***" (p *** . q)))
    ((match-two v (p **1) g+s sk fk i)
     (if (pair? v)
         (match-one v (p ___) g+s sk fk i)
         fk))
    ((match-two v (p =.. n . r) g+s sk fk i)
     (match-extract-vars
      p
      (match-gen-ellipsis/range n n v p r g+s sk fk i) i ()))
    ((match-two v (p *.. n m . r) g+s sk fk i)
     (match-extract-vars
      p
      (match-gen-ellipsis/range n m v p r g+s sk fk i) i ()))
    ((match-two v ($ rec p ...) g+s sk fk i)
     (if (is-a? v rec)
         (match-record-refs v rec 0 (p ...) g+s sk fk i)
         fk))
    ((match-two v (struct rec p ...) g+s sk fk i)
     (if (is-a? v rec)
         (match-record-refs v rec 0 (p ...) g+s sk fk i)
         fk))
    ((match-two v (@ rec p ...) g+s sk fk i)
     (if (is-a? v rec)
         (match-record-named-refs v rec (p ...) g+s sk fk i)
         fk))
    ((match-two v (object rec p ...) g+s sk fk i)
     (if (is-a? v rec)
         (match-record-named-refs v rec (p ...) g+s sk fk i)
         fk))
    ((match-two v (p . q) g+s sk fk i)
     (if (pair? v)
         (let ((w (car v)) (x (cdr v)))
           (match-one w p ((car v) (set-car! v))
                      (match-one x q ((cdr v) (set-cdr! v)) sk fk)
                      fk
                      i))
         fk))
    ((match-two v #(p ...) g+s . x)
     (match-vector v 0 () (p ...) . x))
    ((match-two v _ g+s (sk ...) fk i) (sk ... i))
    ;; Not a pair or vector or special literal, test to see if it's a
    ;; new symbol, in which case we just bind it, or if it's an
    ;; already bound symbol or some other literal, in which case we
    ;; compare it with EQUAL?.
    ((match-two v x g+s (sk ...) fk (id ...))
     ;; This extra match-check-identifier is optional in general, but
     ;; can serve as a fast path, and is needed to distinguish
     ;; keywords in Chicken.
     (match-check-identifier
      x
      (let-syntax
          ((new-sym?
            (syntax-rules (id ...)
              ((new-sym? x sk2 fk2) sk2)
              ((new-sym? y sk2 fk2) fk2))))
        (new-sym? random-sym-to-match
                  (let ((x v)) (sk ... (id ... x)))
                  (if (equal? v x) (sk ... (id ...)) fk)))
      (if (equal? v x) (sk ... (id ...)) fk)))
    ))

(define-syntax match-quasiquote
  (syntax-rules (unquote unquote-splicing quasiquote or)
    ((_ v (unquote p) g+s sk fk i)
     (match-one v p g+s sk fk i))
    ((_ v ((unquote-splicing p) . rest) g+s sk fk i)
     ;; TODO: it is an error to have another unquote-splicing in rest,
     ;; check this and signal explicitly
     (match-extract-vars
      p
      (match-gen-ellipsis/qq v p rest g+s sk fk i) i ()))
    ((_ v (quasiquote p) g+s sk fk i . depth)
     (match-quasiquote v p g+s sk fk i #f . depth))
    ((_ v (unquote p) g+s sk fk i x . depth)
     (match-quasiquote v p g+s sk fk i . depth))
    ((_ v (unquote-splicing p) g+s sk fk i x . depth)
     (match-quasiquote v p g+s sk fk i . depth))
    ((_ v (p . q) g+s sk fk i . depth)
     (if (pair? v)
       (let ((w (car v)) (x (cdr v)))
         (match-quasiquote
          w p g+s
          (match-quasiquote-step x q g+s sk fk depth)
          fk i . depth))
       fk))
    ((_ v #(elt ...) g+s sk fk i . depth)
     (if (vector? v)
       (let ((ls (vector->list v)))
         (match-quasiquote ls (elt ...) g+s sk fk i . depth))
       fk))
    ((_ v x g+s sk fk i . depth)
     (match-one v 'x g+s sk fk i))))

(define-syntax match-quasiquote-step
  (syntax-rules ()
    ((match-quasiquote-step x q g+s sk fk depth i)
     (match-quasiquote x q g+s sk fk i . depth))))

(define-syntax match-drop-ids
  (syntax-rules ()
    ((_ expr ids ...) expr)))

(define-syntax match-tuck-ids
  (syntax-rules ()
    ((_ (letish args (expr ...)) ids ...)
     (letish args (expr ... ids ...)))))

(define-syntax match-drop-first-arg
  (syntax-rules ()
    ((_ arg expr) expr)))

(define-syntax match-gen-or
  (syntax-rules ()
    ((_ v p g+s (sk ...) fk (i ...) ((id id-ls) ...))
     (let ((sk2 (lambda (id ...) (sk ... (i ... id ...))))
           (id (if #f #f)) ...)
       (match-gen-or-step v p g+s (match-drop-ids (sk2 id ...)) fk (i ...))))))

(define-syntax match-gen-or-step
  (syntax-rules ()
    ((_ v () g+s sk fk . x)
     ;; no OR clauses, call the failure continuation
     fk)
    ((_ v (p) . x)
     ;; last (or only) OR clause, just expand normally
     (match-one v p . x))
    ((_ v (p . q) g+s sk fk i)
     ;; match one and try the remaining on failure
     (let ((fk2 (lambda () (match-gen-or-step v q g+s sk fk i))))
       (match-one v p g+s sk (fk2) i)))
    ))

(define-syntax match-gen-ellipsis
  (syntax-rules ()
    ;; TODO: restore fast path when p is not already bound
    ((_ v p () g+s (sk ...) fk i ((id id-ls) ...))
     (match-check-identifier p
       ;; simplest case equivalent to (p ...), just match the list
       (let ((w v))
         (if (list? w)
             (match-one w p g+s (sk ...) fk i)
             fk))
       ;; simple case, match all elements of the list
       (let loop ((ls v) (id-ls '()) ...)
         (cond
           ((null? ls)
            (let ((id (reverse id-ls)) ...) (sk ... i)))
           ((pair? ls)
            (let ((w (car ls)))
              (match-one w p ((car ls) (set-car! ls))
                         (match-drop-ids (loop (cdr ls) (cons id id-ls) ...))
                         fk i)))
           (else
            fk)))))
    ((_ v p r g+s sk fk (i ...) ((id id-ls) ...))
     (match-verify-no-ellipsis
      r
      (match-bound-identifier-memv
       p
       (i ...)
       ;; p is bound, match the list up to the known length, then
       ;; match the trailing patterns
       (let loop ((ls v) (expect p))
         (cond
          ((null? expect)
           (match-one ls r (#f #f) sk fk (i ...)))
          ((pair? ls)
           (let ((w (car ls))
                 (e (car expect)))
             (if (equal? (car ls) (car expect))
                 (match-drop-ids (loop (cdr ls) (cdr expect)))
                 fk)))
          (else
           fk)))
       ;; general case, trailing patterns to match, keep track of
       ;; the remaining list length so we don't need any backtracking
       (let* ((tail-len (length 'r))
              (ls v)
              (len (and (list? ls) (length ls))))
         (if (or (not len) (< len tail-len))
             fk
             (let loop ((ls ls) (n len) (id-ls '()) ...)
               (cond
                ((= n tail-len)
                 (let ((id (reverse id-ls)) ...)
                   (match-one ls r (#f #f) sk fk (i ... id ...))))
                ((pair? ls)
                 (let ((w (car ls)))
                   (match-one w p ((car ls) (set-car! ls))
                              (match-drop-ids
                               (loop (cdr ls) (- n 1) (cons id id-ls) ...))
                              fk
                              (i ...))))
                (else
                 fk)))
           )))))))

(define-syntax match-gen-ellipsis/qq
  (syntax-rules ()
    ((_ v p r g+s (sk ...) fk (i ...) ((id id-ls) ...))
     (match-verify-no-ellipsis
      r
      (let* ((tail-len (length 'r))
             (ls v)
             (len (and (list? ls) (length ls))))
        (if (or (not len) (< len tail-len))
            fk
            (let loop ((ls ls) (n len) (id-ls '()) ...)
              (cond
               ((= n tail-len)
                (let ((id (reverse id-ls)) ...)
                  (match-quasiquote ls r g+s (sk ...) fk (i ... id ...))))
               ((pair? ls)
                (let ((w (car ls)))
                  (match-one w p ((car ls) (set-car! ls))
                             (match-drop-ids
                              (loop (cdr ls) (- n 1) (cons id id-ls) ...))
                             fk
                             (i ...))))
               (else
                fk)))))))))

(define-syntax match-gen-ellipsis/range
  (syntax-rules ()
    ((_ %lo %hi v p r g+s (sk ...) fk (i ...) ((id id-ls) ...))
     ;; general case, trailing patterns to match, keep track of the
     ;; remaining list length so we don't need any backtracking
     (match-verify-no-ellipsis
      r
      (let* ((lo %lo)
             (hi %hi)
             (tail-len (length 'r))
             (ls v)
             (len (and (list? ls) (- (length ls) tail-len))))
        (if (and len (<= lo len hi))
            (let loop ((ls ls) (j 0) (id-ls '()) ...)
              (cond
                ((= j len)
                 (let ((id (reverse id-ls)) ...)
                   (match-one ls r (#f #f) (sk ...) fk (i ... id ...))))
                ((pair? ls)
                 (let ((w (car ls)))
                   (match-one w p ((car ls) (set-car! ls))
                              (match-drop-ids
                               (loop (cdr ls) (+ j 1) (cons id id-ls) ...))
                              fk
                              (i ...))))
                (else
                 fk)))
            fk))))))

(define-syntax match-verify-no-ellipsis
  (syntax-rules ()
    ((_ (x . y) sk)
     (match-check-ellipsis
      x
      (match-syntax-error
       "multiple ellipsis patterns not allowed at same level")
      (match-verify-no-ellipsis y sk)))
    ((_ () sk)
     sk)
    ((_ x sk)
     (match-syntax-error "dotted tail not allowed after ellipsis" x))))

(define-syntax match-gen-search
  (syntax-rules ()
    ((match-gen-search v p q g+s sk fk i ((id id-ls) ...))
     (letrec ((try (lambda (w fail id-ls ...)
                     (match-one w q g+s
                                (match-tuck-ids
                                 (let ((id (reverse id-ls)) ...)
                                   sk))
                                (next w fail id-ls ...) i)))
              (next (lambda (w fail id-ls ...)
                      (if (not (pair? w))
                          (fail)
                          (let ((u (car w)))
                            (match-one
                             u p ((car w) (set-car! w))
                             (match-drop-ids
                              ;; accumulate the head variables from
                              ;; the p pattern, and loop over the tail
                              (let ((id-ls (cons id id-ls)) ...)
                                (let lp ((ls (cdr w)))
                                  (if (pair? ls)
                                      (try (car ls)
                                           (lambda () (lp (cdr ls)))
                                           id-ls ...)
                                      (fail)))))
                             (fail) i))))))
       ;; the initial id-ls binding here is a dummy to get the right
       ;; number of '()s
       (let ((id-ls '()) ...)
         (try v (lambda () fk) id-ls ...))))))

(define-syntax match-vector
  (syntax-rules (___)
    ((_ v n pats (p q) . x)
     (match-check-ellipsis q
                          (match-gen-vector-ellipsis v n pats p . x)
                          (match-vector-two v n pats (p q) . x)))
    ((_ v n pats (p ___) sk fk i)
     (match-gen-vector-ellipsis v n pats p sk fk i))
    ((_ . x)
     (match-vector-two . x))))

(define-syntax match-vector-two
  (syntax-rules ()
    ((_ v n ((pat index) ...) () sk fk i)
     (if (vector? v)
         (let ((len (vector-length v)))
           (if (= len n)
               (match-vector-step v ((pat index) ...) sk fk i)
               fk))
         fk))
    ((_ v n (pats ...) (p . q) . x)
     (match-vector v (+ n 1) (pats ... (p n)) q . x))))

(define-syntax match-vector-step
  (syntax-rules ()
    ((_ v () (sk ...) fk i) (sk ... i))
    ((_ v ((pat index) . rest) sk fk i)
     (let ((w (vector-ref v index)))
       (match-one w pat ((vector-ref v index) (vector-set! v index))
                  (match-vector-step v rest sk fk)
                  fk i)))))

(define-syntax match-gen-vector-ellipsis
  (syntax-rules ()
    ((_ v n ((pat index) ...) p sk fk i)
     (if (vector? v)
       (let ((len (vector-length v)))
         (if (>= len n)
           (match-vector-step v ((pat index) ...)
                              (match-vector-tail v p n len sk fk)
                              fk i)
           fk))
       fk))))

(define-syntax match-vector-tail
  (syntax-rules ()
    ((_ v p n len sk fk i)
     (match-extract-vars p (match-vector-tail-two v p n len sk fk i) i ()))))

(define-syntax match-vector-tail-two
  (syntax-rules ()
    ((_ v p n len (sk ...) fk i ((id id-ls) ...))
     (let loop ((j n) (id-ls '()) ...)
       (if (>= j len)
         (let ((id (reverse id-ls)) ...) (sk ... i))
         (let ((w (vector-ref v j)))
           (match-one w p ((vector-ref v j) (vector-set! v j))
                      (match-drop-ids (loop (+ j 1) (cons id id-ls) ...))
                      fk i)))))))

(define-syntax match-record-refs
  (syntax-rules ()
    ((_ v rec n (p . q) g+s sk fk i)
     (let ((w (slot-ref rec v n)))
       (match-one w p ((slot-ref rec v n) (slot-set! rec v n))
                  (match-record-refs v rec (+ n 1) q g+s sk fk) fk i)))
    ((_ v rec n () g+s (sk ...) fk i)
     (sk ... i))))

(define-syntax match-record-named-refs
  (syntax-rules ()
    ((_ v rec ((f p) . q) g+s sk fk i)
     (let ((w (slot-ref rec v 'f)))
       (match-one w p ((slot-ref rec v 'f) (slot-set! rec v 'f))
                  (match-record-named-refs v rec q g+s sk fk) fk i)))
    ((_ v rec () g+s (sk ...) fk i)
     (sk ... i))))

(define-syntax match-extract-vars
  (syntax-rules (_ ___ **1 =.. *.. *** ? $ struct @ object = quote quasiquote and or not get! set!)
    ((match-extract-vars (? pred . p) . x)
     (match-extract-vars p . x))
    ((match-extract-vars ($ rec . p) . x)
     (match-extract-vars p . x))
    ((match-extract-vars (struct rec . p) . x)
     (match-extract-vars p . x))
    ((match-extract-vars (@ rec (f p) ...) . x)
     (match-extract-vars (p ...) . x))
    ((match-extract-vars (object rec (f p) ...) . x)
     (match-extract-vars (p ...) . x))
    ((match-extract-vars (= proc p) . x)
     (match-extract-vars p . x))
    ((match-extract-vars (quote x) (k ...) i v)
     (k ... v))
    ((match-extract-vars (quasiquote x) k i v)
     (match-extract-quasiquote-vars x k i v (#t)))
    ((match-extract-vars (and . p) . x)
     (match-extract-vars p . x))
    ((match-extract-vars (or . p) . x)
     (match-extract-vars p . x))
    ((match-extract-vars (not . p) . x)
     (match-extract-vars p . x))
    ;; A non-keyword pair, expand the CAR with a continuation to
    ;; expand the CDR.
    ((match-extract-vars (p q . r) k i v)
     (match-check-ellipsis
      q
      (match-extract-vars (p . r) k i v)
      (match-extract-vars p (match-extract-vars-step (q . r) k i v) i ())))
    ((match-extract-vars (p . q) k i v)
     (match-extract-vars p (match-extract-vars-step q k i v) i ()))
    ((match-extract-vars #(p ...) . x)
     (match-extract-vars (p ...) . x))
    ((match-extract-vars _ (k ...) i v)    (k ... v))
    ((match-extract-vars ___ (k ...) i v)  (k ... v))
    ((match-extract-vars *** (k ...) i v)  (k ... v))
    ((match-extract-vars **1 (k ...) i v)  (k ... v))
    ((match-extract-vars =.. (k ...) i v)  (k ... v))
    ((match-extract-vars *.. (k ...) i v)  (k ... v))
    ;; This is the main part, the only place where we might add a new
    ;; var if it's an unbound symbol.
    ((match-extract-vars p (k ...) (i ...) v)
     (let-syntax
         ((new-sym?
           (syntax-rules (i ...)
             ((new-sym? p sk fk) sk)
             ((new-sym? any sk fk) fk))))
       (new-sym? random-sym-to-match
                 (k ... ((p p-ls) . v))
                 (k ... v))))
    ))

(define-syntax match-extract-vars-step
  (syntax-rules ()
    ((_ p k i v ((v2 v2-ls) ...))
     (match-extract-vars p k (v2 ... . i) ((v2 v2-ls) ... . v)))
    ))

(define-syntax match-extract-quasiquote-vars
  (syntax-rules (quasiquote unquote unquote-splicing)
    ((match-extract-quasiquote-vars (quasiquote x) k i v d)
     (match-extract-quasiquote-vars x k i v (#t . d)))
    ((match-extract-quasiquote-vars (unquote-splicing x) k i v d)
     (match-extract-quasiquote-vars (unquote x) k i v d))
    ((match-extract-quasiquote-vars (unquote x) k i v (#t))
     (match-extract-vars x k i v))
    ((match-extract-quasiquote-vars (unquote x) k i v (#t . d))
     (match-extract-quasiquote-vars x k i v d))
    ((match-extract-quasiquote-vars (x . y) k i v d)
     (match-extract-quasiquote-vars
      x
      (match-extract-quasiquote-vars-step y k i v d) i () d))
    ((match-extract-quasiquote-vars #(x ...) k i v d)
     (match-extract-quasiquote-vars (x ...) k i v d))
    ((match-extract-quasiquote-vars x (k ...) i v d)
     (k ... v))
    ))

(define-syntax match-extract-quasiquote-vars-step
  (syntax-rules ()
    ((_ x k i v d ((v2 v2-ls) ...))
     (match-extract-quasiquote-vars x k (v2 ... . i) ((v2 v2-ls) ... . v) d))
    ))


(define-syntax match-lambda
  (syntax-rules ()
    ((_ (pattern . body) ...) (lambda (expr) (match expr (pattern . body) ...)))))

(define-syntax match-lambda*
  (syntax-rules ()
    ((_ (pattern . body) ...) (lambda expr (match expr (pattern . body) ...)))))

(define-syntax match-let
  (syntax-rules ()
    ((_ ((var value) ...) . body)
     (match-let/aux () () ((var value) ...) . body))
    ((_ loop ((var init) ...) . body)
     (match-named-let loop () ((var init) ...) . body))))

(define-syntax match-let/aux
  (syntax-rules ()
    ((_ ((var expr) ...) () () . body)
     (let ((var expr) ...) . body))
    ((_ ((var expr) ...) ((pat tmp) ...) () . body)
     (let ((var expr) ...)
       (match-let* ((pat tmp) ...)
         . body)))
    ((_ (v ...) (p ...) (((a . b) expr) . rest) . body)
     (match-let/aux (v ... (tmp expr)) (p ... ((a . b) tmp)) rest . body))
    ((_ (v ...) (p ...) ((#(a ...) expr) . rest) . body)
     (match-let/aux (v ... (tmp expr)) (p ... (#(a ...) tmp)) rest . body))
    ((_ (v ...) (p ...) ((a expr) . rest) . body)
     (match-let/aux (v ... (a expr)) (p ...) rest . body))))

(define-syntax match-named-let
  (syntax-rules ()
    ((_ loop ((pat expr var) ...) () . body)
     (let loop ((var expr) ...)
       (match-let ((pat var) ...)
         . body)))
    ((_ loop (v ...) ((pat expr) . rest) . body)
     (match-named-let loop (v ... (pat expr tmp)) rest . body))))

(define-syntax match-let*
  (syntax-rules ()
    ((_ () . body)
     (let () . body))
    ((_ ((pat expr) . rest) . body)
     (match expr (pat (match-let* rest . body))))))

(define-syntax match-letrec
  (syntax-rules ()
    ((_ ((pat val) ...) . body)
     (match-letrec-one (pat ...) (((pat val) ...) . body) ()))))

(define-syntax match-letrec-one
  (syntax-rules ()
    ((_ (pat . rest) expr ((id tmp) ...))
     (match-extract-vars
      pat (match-letrec-one rest expr) (id ...) ((id tmp) ...)))
    ((_ () expr ((id tmp) ...))
     (match-letrec-two expr () ((id tmp) ...)))))

(define-syntax match-letrec-two
  (syntax-rules ()
    ((_ (() . body) ((var2 val2) ...) ((id tmp) ...))
     ;; We know the ids, their tmp names, and the renamed patterns
     ;; with the tmp names - expand to the classic letrec pattern of
     ;; let+set!.  That is, we bind the original identifiers written
     ;; in the source with let, run match on their renamed versions,
     ;; then set! the originals to the matched values.
     (let ((id (if #f #f)) ...)
       (match-let ((var2 val2) ...)
          (set! id tmp) ...
          . body)))
    ((_ (((var val) . rest) . body) ((var2 val2) ...) ids)
     (match-rewrite
      var
      ids
      (match-letrec-two-step (rest . body) ((var2 val2) ...) ids val)))))

(define-syntax match-letrec-two-step
  (syntax-rules ()
    ((_ next (rewrites ...) ids val var)
     (match-letrec-two next (rewrites ... (var val)) ids))))

(define-syntax match-rewrite
  (syntax-rules (quote)
    ((match-rewrite (quote x) ids (k ...))
     (k ... (quote x)))
    ((match-rewrite (p . q) ids k)
     (match-rewrite p ids (match-rewrite2 q ids (match-cons k))))
    ((match-rewrite () ids (k ...))
     (k ... ()))
    ((match-rewrite p () (k ...))
     (k ... p))
    ((match-rewrite p ((id tmp) . rest) (k ...))
     (match-bound-identifier=? p id (k ... tmp) (match-rewrite p rest (k ...))))
    ))

(define-syntax match-rewrite2
  (syntax-rules ()
    ((match-rewrite2 q ids (k ...) p)
     (match-rewrite q ids (k ... p)))))

(define-syntax match-cons
  (syntax-rules ()
    ((match-cons (k ...) p q)
     (k ... (p . q)))))

(define-syntax match-check-ellipsis
  (syntax-rules ()
    ;; these two aren't necessary but provide fast-case failures
    ((match-check-ellipsis (a . b) success-k failure-k) failure-k)
    ((match-check-ellipsis #(a ...) success-k failure-k) failure-k)
    ;; matching an atom
    ((match-check-ellipsis id success-k failure-k)
     (let-syntax ((ellipsis? (syntax-rules ()
                               ;; iff `id' is `...' here then this will
                               ;; match a list of any length
                               ((ellipsis? (foo id) sk fk) sk)
                               ((ellipsis? other sk fk) fk))))
       ;; this list of three elements will only match the (foo id) list
       ;; above if `id' is `...'
       (ellipsis? (a b c) success-k failure-k)))))

(define-syntax match-check-identifier
  (syntax-rules ()
    ;; fast-case failures, lists and vectors are not identifiers
    ((_ (x . y) success-k failure-k) failure-k)
    ((_ #(x ...) success-k failure-k) failure-k)
    ;; x is an atom
    ((_ x success-k failure-k)
     (let-syntax
         ((sym?
           (syntax-rules ()
             ;; if the symbol `abracadabra' matches x, then x is a
             ;; symbol
             ((sym? x sk fk) sk)
             ;; otherwise x is a non-symbol datum
             ((sym? y sk fk) fk))))
       (sym? abracadabra success-k failure-k)))))

;; This check is inlined in some cases above, but included here for
;; the convenience of match-rewrite.
(define-syntax match-bound-identifier=?
  (syntax-rules ()
    ((match-bound-identifier=? a b sk fk)
     (let-syntax ((b (syntax-rules ())))
       (let-syntax ((eq (syntax-rules (b)
                          ((eq b) sk)
                          ((eq _) fk))))
         (eq a))))))

;; Variant of above for a list of ids.
(define-syntax match-bound-identifier-memv
  (syntax-rules ()
    ((match-bound-identifier-memv a (id ...) sk fk)
     (match-check-identifier
      a
      (let-syntax
          ((memv?
            (syntax-rules (id ...)
              ((memv? a sk2 fk2) fk2)
              ((memv? anything-else sk2 fk2) sk2))))
        (memv? random-sym-to-match sk fk))
      fk))))
))
