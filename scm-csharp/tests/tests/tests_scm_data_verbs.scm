(import (scheme base) (scm data core) (scm data frame) (scm data verbs) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-verbs")

(define pts (tibble (year 2024 2024 2024 2025 2025 2025)
                    (model 'v1 'v2 'v1 'v1 'v2 'v2)
                    (splg 'BEW8 'BEW8 'GYN2 'BEW8 'BEW8 'GYN2)
                    (points 10.0 12.0 5.0 11.0 15.0 na)))

(define (col df c) (vector->list (df-column df c)))
(define (list-head* xs k start) (let loop ((xs (list-tail xs start)) (k k) (acc '()))
                                  (if (= k 0) (reverse acc) (loop (cdr xs) (- k 1) (cons (car xs) acc)))))
(define (na->x xs) (map (lambda (x) (if (na? x) 'na x)) xs))

(test-group "where, mutate, transmute"
  (let ((limit 10))
    (test-equal '(12.0 11.0 15.0) (col (where pts (> points ,limit)) 'points))
    (test-equal '(12.0 15.0) (col (where pts (> points ,limit) (= model 'v2)) 'points)))
  ;; grouped where: the best row per splg, rows stay in their order
  (test-equal '(5.0 15.0) (col (-> pts (group-by splg) (where (= points (max points)))) 'points))
  (let ((m (mutate pts (p2 (* points 2)) (p3 (+ p2 1)))))
    (test-equal '(20.0 24.0 10.0 22.0 30.0 na) (na->x (col m 'p2)))
    (test-equal 21.0 (df-ref m 0 'p3)))
  ;; grouped mutate: share within the group
  (let ((s (col (-> pts (group-by year model) (mutate (s (/ points (sum points))))) 's)))
    (test-approximate (/ 10.0 15) (car s) 1e-9)
    (test-equal 1.0 (cadr s)))
  (test-equal '(year model total) (df-names (-> pts (group-by year model) (transmute (total (sum points)))))))


(test-group "summarise, tally"
  (let ((s (-> pts (group-by splg year) (summarise (total (sum points)) (n (n)) (avg (/ total n))))))
    (test-equal '(splg year total n avg) (df-names s))
    (test-equal '(BEW8 BEW8 GYN2 GYN2) (col s 'splg))
    (test-equal '(22.0 26.0 5.0 0) (col s 'total))
    (test-equal '(11.0 13.0 5.0 0.0) (col s 'avg))
    (test-equal '() (df-groups s)))
  (test-equal '(53.0) (col (summarise pts (total (sum points))) 'total))
  (let ((t (tally pts splg)))
    (test-equal '(BEW8 GYN2) (col t 'splg))
    (test-equal '(4 2) (col t 'n)))
  (test-equal '(6) (col (tally pts) 'n))
  (test-equal '(4 4 2 4 4 2) (col (add-count pts splg) 'n)))

(test-group "select, rename, relocate, pull"
  (test-equal '(splg points) (df-names (select pts splg points)))
  (test-equal '(year model points) (df-names (select pts (except splg))))
  (test-equal '(splg) (df-names (select pts (starts-with "sp"))))
  (test-equal '(model splg) (df-names (select pts (matches "^.*l.*$") (except points year))))
  (test-equal '(lg) (df-names (select pts (rename lg splg))))
  ;; grouping columns are kept
  (test-equal '(splg points) (df-names (select (group-by pts splg) points)))
  (test-equal '(year model lg points) (df-names (rename pts (lg splg))))
  (test-equal '(points year model splg) (df-names (relocate pts points)))
  (test-equal '(2024 2024 2024 2025 2025 2025) (pull pts year)))

(test-group "arrange, distinct, slicing"
  (test-equal '(15.0 12.0 11.0 10.0 5.0 na) (na->x (col (arrange pts (desc points)) 'points)))
  (test-equal '(GYN2 GYN2 BEW8 BEW8 BEW8 BEW8) (col (arrange pts (desc splg) year) 'splg))
  (test-equal '(5.0 10.0) (col (head (arrange pts points) 2) 'points))
  (test-equal '((BEW8 2024) (GYN2 2024) (BEW8 2025) (GYN2 2025))
              (df->rows (distinct pts splg year)))
  (test-equal 2 (df-nrow (head pts 2)))
  (test-equal '(15.0 na) (na->x (col (tail pts 2) 'points)))
  (test-equal '(5.0 11.0) (col (slice pts 2 4) 'points))
  (test-equal 3 (df-nrow (sample-n pts 3 42)))
  (test-equal (df->rows (sample-n pts 3 7)) (df->rows (sample-n pts 3 7))))

(define limits (tibble (splg 'BEW8 'URO1) (mfz 50 10)))

(test-group "joins"
  (let ((j (left-join pts limits)))
    (test-equal '(year model splg points mfz) (df-names j))
    (test-equal '(50 50 na 50 50 na) (na->x (col j 'mfz))))
  (test-equal 4 (df-nrow (inner-join pts limits (by splg))))
  (let ((f (full-join (distinct pts splg) limits)))
    (test-equal '(BEW8 GYN2 URO1) (col f 'splg))
    (test-equal '(50 na 10) (na->x (col f 'mfz))))
  (test-equal '(BEW8 BEW8 BEW8 BEW8) (col (semi-join pts limits) 'splg))
  (test-equal '(GYN2 GYN2) (col (anti-join pts limits) 'splg))
  (let ((j (left-join (tibble (k 1 2) (v "a" "b")) (tibble (key 1) (v "x")) (by (k . key)))))
    (test-equal '(k v.x v.y) (df-names j))
    (test-equal '("x" na) (na->x (col j 'v.y))))
  ;; 1 and 1.0 match
  (test-equal 1 (df-nrow (inner-join (tibble (k 1)) (tibble (k 1.0) (w 2))))))

(test-group "bind"
  (let ((b (bind-rows (tibble (a 1) (b "x")) (tibble (a 2) (c #t)))))
    (test-equal '(a b c) (df-names b))
    (test-equal '("x" na) (na->x (col b 'b))))
  (let ((b (df-bind-rows (list (tibble (a 1)) (tibble (a 2) )) 'src '(x y))))
    (test-equal '(src a) (df-names b))
    (test-equal '(x y) (col b 'src)))
  (test-equal '(a b) (df-names (bind-cols (tibble (a 1)) (tibble (b 2))))))

(test-group "pivot"
  (let ((w (-> pts (pivot-wider (names-from year model) (values-from points)))))
    (test-equal '(splg 2024_v1 2024_v2 2025_v1 2025_v2) (df-names w))
    (test-equal '(10.0 5.0) (col w '2024_v1))
    (test-equal '(15.0 na) (na->x (col w '2025_v2)))
    (let ((l (pivot-longer w (cols 2024_v1 2024_v2) (names-to run) (values-to p))))
      (test-equal '(splg 2025_v1 2025_v2 run p) (df-names l))
      (test-equal '(2024_v1 2024_v2 2024_v1 2024_v2) (col l 'run))))
  ;; ids are year + splg: 2024 has only v1, 2025 only v2 -> filled
  (test-equal '(5.0 0) (col (-> (where pts (= splg 'GYN2))
                                (pivot-wider (names-from model) (values-from points) (values-fill 0))
                                (select v2 v1))
                           'v1)))

(test-group "unnest, separate"
  (let* ((c (tibble (id 1 2 3) (ops '(("g1" BEW8 1.0) ("g2" BEW8 0.5)) '() '(("g1" GYN2 1.0)))))
         (u (unnest-longer c ops (into gln splg pts))))
    (test-equal '(id gln splg pts) (df-names u))
    (test-equal '(1 1 3) (col u 'id))
    (test-equal '("g1" "g2" "g1") (col u 'gln))
    (test-equal '(1 1 3) (col (unnest-longer (tibble (id 1 3) (x '(a b) '(c))) x) 'id)))
  (let ((s (separate (tibble (ft "A:3:1" "B:2")) ft (into art stat sub) (sep ":"))))
    (test-equal '("A" "B") (col s 'art))
    (test-equal '("1" na) (na->x (col s 'sub)))))

(test-group "missing values"
  (test-equal 5 (df-nrow (drop-na pts points)))
  (test-equal '(10.0 12.0 5.0 11.0 15.0 0) (col (replace-na pts (points 0)) 'points))
  (let ((f (tibble (k "a" na na "b" na))))
    (test-equal '("a" "a" "a" "b" "b") (col (fill-down f k) 'k))
    (test-equal '("a" "b" "b" "b" na) (na->x (col (fill-up f k) 'k)))))

(test-group "groups and helpers"
  (test-equal '((BEW8) (GYN2)) (map car (df-group-keys (group-by pts splg))))
  (test-equal 2 (length (df-split (group-by pts splg))))
  (test-equal '() (df-groups (ungroup (group-by pts splg))))
  (test-equal '(10.0 12.0) (list-head* (df-map-rows pts (lambda (r) (cdr (assq 'points r)))) 2 0))
  (test-equal '(20.0 24.0 10.0 22.0 30.0 na) (na->x (vector->list (eval-column pts '(* 2 points))))))

(test-end "scm-data-verbs")
