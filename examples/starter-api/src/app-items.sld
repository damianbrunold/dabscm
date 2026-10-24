;; (app items) — the sample REST resource, a plain Scheme data file.
;;
;; items.scm holds a list of (id name count) entries. Writes go through a
;; temp file + rename (a reader never sees a partial file) and are
;; serialized with a mutex, since the HTTP server is threaded. A flat file
;; is fine for a starter; swap this module for a database when you outgrow
;; it (see starter-admin).

(define-library (app items)
  (import (scheme base)
          (scheme file)
          (scheme read)
          (scheme write)
          (scm fs)
          (srfi 18))
  (export load-items find-item item->json add-item! delete-item!)
  (begin

    (define (item-id it) (car it))
    (define (item-name it) (cadr it))
    (define (item-count it) (caddr it))

    (define (load-items path)
      "Syntax: (load-items path)
Library: (app items)
Description: The list of (id name count) entries, or '() if the file does
  not exist yet."
      (if (file-exists? path)
          (let ((d (call-with-input-file path read)))
            (if (eof-object? d) '() d))
          '()))

    (define (find-item path id)
      (let loop ((items (load-items path)))
        (cond ((null? items) #f)
              ((= (item-id (car items)) id) (car items))
              (else (loop (cdr items))))))

    (define (item->json it)
      "Syntax: (item->json it)
Library: (app items)
Description: The item as a JSON object alist for (scm json simple)."
      (list (cons "id" (item-id it))
            (cons "name" (item-name it))
            (cons "count" (item-count it))))

    (define write-lock (make-mutex))

    ;; Calls (proc items) under the lock and stores the list it returns as
    ;; its first value; the second value is the call's result.
    (define (update-items! path proc)
      (dynamic-wind
        (lambda () (mutex-lock! write-lock))
        (lambda ()
          (let-values (((items result) (proc (load-items path))))
            (let ((dir (directory-name path))
                  (tmp (string-append path ".tmp")))
              (unless (directory-exists? dir) (make-directory dir))
              (call-with-output-file tmp
                (lambda (p) (write items p) (newline p)))
              (move-file tmp path))
            result))
        (lambda () (mutex-unlock! write-lock))))

    (define (add-item! path name count)
      "Syntax: (add-item! path name count)
Library: (app items)
Description: Appends a new item with the next free id and returns it."
      (update-items! path
        (lambda (items)
          (let* ((next (+ 1 (let loop ((xs items) (m 0))
                              (if (null? xs) m (loop (cdr xs) (max m (item-id (car xs))))))))
                 (it (list next name count)))
            (values (append items (list it)) it)))))

    (define (delete-item! path id)
      "Syntax: (delete-item! path id)
Library: (app items)
Description: Removes the item with id. #t if there was one, else #f."
      (update-items! path
        (lambda (items)
          (let ((kept (let loop ((xs items))
                        (cond ((null? xs) '())
                              ((= (item-id (car xs)) id) (loop (cdr xs)))
                              (else (cons (car xs) (loop (cdr xs))))))))
            (values kept (< (length kept) (length items)))))))))
