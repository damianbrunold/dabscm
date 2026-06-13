;; (app store) — the data layer, two plain Scheme data files.
;;
;;   data/users.scm  : list of (username hash created), managed by the CLI.
;;   data/items.scm  : list of (id name count), the sample REST resource.
;;
;; Writes go through a temp file + rename (a reader never sees a partial
;; file) and are serialized with a mutex, since the HTTP server is threaded.
;; A flat file is fine for a starter; swap this module for a database when
;; you outgrow it.

(define-library (app store)
  (import (scheme base)
          (scheme read)
          (scheme char)
          (scheme file)
          (scheme write)
          (scm fs)
          (srfi 1)
          (srfi 13)
          (srfi 18))
  (export load-users save-users! find-user user-hash upsert-user valid-username?
          load-items find-item item->alist add-item! delete-item!)
  (begin

    (define write-lock (make-mutex))
    (define (with-write-lock thunk)
      (dynamic-wind
        (lambda () (mutex-lock! write-lock))
        thunk
        (lambda () (mutex-unlock! write-lock))))

    (define (read-datum path)
      (if (file-exists? path)
          (let ((d (call-with-input-file path read)))
            (if (eof-object? d) '() d))
          '()))

    (define (write-datum! path datum)
      (let ((tmp (string-append path ".tmp")))
        (call-with-output-file tmp
          (lambda (p) (write datum p) (newline p)))
        (move-file tmp path)))

    ;; --- users --------------------------------------------------------

    (define (load-users path) (read-datum path))
    (define (user-name u) (car u))
    (define (user-hash u) (cadr u))

    (define (find-user users name)
      (cond ((null? users) #f)
            ((string=? (user-name (car users)) name) (car users))
            (else (find-user (cdr users) name))))

    (define (upsert-user users name hash created)
      (cond
        ((null? users) (list (list name hash created)))
        ((string=? (user-name (car users)) name)
         (cons (list name hash (list-ref (car users) 2)) (cdr users)))
        (else (cons (car users) (upsert-user (cdr users) name hash created)))))

    (define (save-users! path users) (write-datum! path users))

    (define (valid-username? s)
      (and (string? s)
           (<= 1 (string-length s) 64)
           (string-every
            (lambda (c)
              (or (char-alphabetic? c) (char-numeric? c)
                  (memv c '(#\. #\_ #\-))))
            s)))

    ;; --- items --------------------------------------------------------

    (define (item-id it) (car it))
    (define (item-name it) (cadr it))
    (define (item-count it) (caddr it))

    (define (load-items path) (read-datum path))

    (define (find-item items id)
      (find (lambda (it) (= (item-id it) id)) items))

    (define (item->alist it)
      "Syntax: (item->alist it)
Library: (app store)
Description: Converts an item to a JSON-object alist for (scm json simple)."
      (list (cons "id" (item-id it))
            (cons "name" (item-name it))
            (cons "count" (item-count it))))

    (define (next-id items)
      (+ 1 (fold (lambda (it m) (max m (item-id it))) 0 items)))

    (define (add-item! path name count)
      "Syntax: (add-item! path name count)
Library: (app store)
Description: Appends a new item (assigning the next id) and returns it."
      (with-write-lock
        (lambda ()
          (let* ((items (load-items path))
                 (it (list (next-id items) name count)))
            (write-datum! path (append items (list it)))
            it))))

    (define (delete-item! path id)
      "Syntax: (delete-item! path id)
Library: (app store)
Description: Removes the item with the given id. Returns #t if one was
  removed, #f if no such item existed."
      (with-write-lock
        (lambda ()
          (let* ((items (load-items path))
                 (kept (filter (lambda (it) (not (= (item-id it) id))) items)))
            (cond ((= (length kept) (length items)) #f)
                  (else (write-datum! path kept) #t))))))))
