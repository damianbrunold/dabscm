(import (scheme base) (srfi 13) (scm data) (scm data r) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-r")

(define (parse1 s) (car (r-parse s)))
(define (deparse s) (r-deparse (parse1 s)))
(define (r->forms s) (call-with-values (lambda () (r->scm s)) (lambda (forms unsupported) (cdr forms))))
(define (r->form s) (car (r->forms s)))
(define (r-unsupported s) (call-with-values (lambda () (r->scm s)) (lambda (forms unsupported) unsupported)))

(test-group "parser"
  (test-equal '(:call - (#f . (:call ^ (#f . 2) (#f . 2)))) (parse1 "-2^2"))
  (test-equal "a + b * c" (deparse "a + b * c"))
  (test-equal "(a + b) * c" (deparse "(a + b) * c"))
  (test-equal "x |> f() |> g(y = 1)" (deparse "x |> f() |> g(y = 1)"))
  (test-equal "a %in% b & !c" (deparse "a %in% b & !c"))
  (test-equal "x <- y <- 1" (deparse "x <- y <- 1"))
  ;; a binary operator at the end of a line continues the expression
  (test-equal 1 (length (r-parse "x <- a %>%\n  f()\n")))
  (test-equal 2 (length (r-parse "x <- a\n  f()\n")))
  ;; newlines inside parentheses do not end it
  (test-equal 1 (length (r-parse "f(a,\n  b = 2\n)")))
  (test-equal "if (a) b else c" (deparse "if (a) b else c"))
  (test-equal "function(x, n = 2) x^n" (deparse "function(x, n = 2) x ^ n"))
  (test-equal "y ~ x + z" (deparse "y ~ x + z"))
  (test-equal "df$col[[1]]" (deparse "df$col[[1]]"))
  (test-equal "dplyr::filter(d, a == \"x\")" (deparse "dplyr::filter(d, a == 'x')"))
  (test-equal "`my col` + 1L" (string-append (deparse "`my col` + 1L") "L"))
  (test-equal 3 (length (r-parse "a <- 1; b <- 2\n# comment\nc <- 3"))))

(test-group "r->scm: verbs"
  (test-equal '(define d (-> cases (where (> x 1) (in k ,(list "a" "b"))) (mutate (y (* x 2)))))
              (r->form "d <- cases %>% filter(x > 1, k %in% c('a', 'b')) %>% mutate(y = x * 2)"))
  (test-equal '(define s (-> d (group-by k) (summarise (n (n)) (m (mean x)))))
              (r->form "s <- d |> group_by(k) |> summarise(n = n(), m = mean(x, na.rm = TRUE), .groups = 'drop')"))
  ;; summarise(.by = ) becomes a group-by first
  (test-equal '(define s (-> d (group-by k) (summarise (n (n)))))
              (r->form "s <- d |> summarise(n = n(), .by = k)"))
  (test-equal '(define s (-> d (arrange (desc y) x) (select a (except b) (starts-with "p") (rename new old))))
              (r->form "s <- d |> arrange(desc(y), x) |> select(a, -b, starts_with('p'), new = old)"))
  (test-equal '(define j (-> a (left-join b (by (k . key) z))))
              (r->form "j <- a |> left_join(b, by = c('k' = 'key', 'z'))"))
  (test-equal '(define j (-> a (inner-join b (by (k . key)))))
              (r->form "j <- a |> inner_join(b, by = join_by(k == key))"))
  (test-equal '(define w (-> d (pivot-longer (cols a b) (names-to name) (values-to value))))
              (r->form "w <- d |> pivot_longer(c(a, b), names_to = 'name', values_to = 'value')"))
  (test-equal '(define c2 (-> d (tally k) (arrange (desc n))))
              (r->form "c2 <- d |> count(k, sort = TRUE)"))
  ;; across with explicit columns
  (test-equal '(define m (-> d (mutate (a (round a)) (b (round b)))))
              (r->form "m <- d |> mutate(across(c(a, b), round))"))
  ;; a verb called directly
  (test-equal '(define f (where d (> x 1))) (r->form "f <- filter(d, x > 1)")))

(test-group "r->scm: expressions"
  (test-equal '(define m (-> d (mutate (c (case-when ((< x 5) "low") (else "high")))
                                     (s (str a "-" b))
                                     (l (log x 10))
                                     (p (,expt x 2))
                                     (t (if (is-na x) 0 x)))))
              (r->form "m <- d |> mutate(c = case_when(x < 5 ~ 'low', TRUE ~ 'high'), s = paste(a, b, sep = '-'), l = log10(x), p = x^2, t = ifelse(is.na(x), 0, x))"))
  ;; a variable of the script is spliced in, a column stays a name
  (test-equal '(define f (-> d (where (> x ,lim))))
              (cadr (r->forms "lim <- 3\nf <- d |> filter(x > lim)")))
  (test-equal '(define d (read-csv "a.csv" 'sep #\; 'decimal #\,)) (r->form "d <- read_csv2('a.csv')"))
  (test-equal '(define d (read-csv "a.csv" 'sep #\;)) (r->form "d <- read_delim('a.csv', delim = ';')"))
  (test-equal '(define d (read-xlsx "a.xlsx" 'sheet "S")) (r->form "d <- readxl::read_excel('a.xlsx', sheet = 'S')")))

(test-group "r->scm: ggplot, tests, models"
  (test-equal '(define p (ggplot d (aes (x k) (y n) (fill g)) (geom-col (position dodge)) (labs (title "T") (y #f)) (coord-flip)))
              (r->form "p <- ggplot(d, aes(k, n, fill = g)) + geom_col(position = 'dodge') + labs(title = 'T', y = NULL) + coord_flip()"))
  (test-equal '(define p (ggplot (-> d (where (> n 0))) (aes (x k) (y n)) (geom-point)))
              (r->form "p <- d |> filter(n > 0) |> ggplot(aes(x = k, y = n)) + geom_point()"))
  (test-equal '(define m (ggplot sh (geom-sf (aes (fill v))) (geom-sf (data ,kt) (fill none)) (scale-fill-steps (palette blue) (n 5))))
              (r->form "m <- ggplot(sh) + geom_sf(aes(fill = v)) + geom_sf(data = kt, fill = NA) + scale_fill_fermenter(palette = 'Blues', n.breaks = 5)"))
  (test-equal '(define r (t-test sleep '(extra ~ group) 'var-equal #t))
              (r->form "r <- t.test(extra ~ group, data = sleep, var.equal = TRUE)"))
  (test-equal '(define r (wilcox-test x y 'paired #t 'alternative 'less))
              (r->form "r <- wilcox.test(x, y, paired = TRUE, alternative = 'less')"))
  (test-equal '(define r (chisq-test '((1 2) (3 4)))) (r->form "r <- chisq.test(matrix(c(1, 3, 2, 4), nrow = 2))"))
  (test-equal '(define f (lm d '(y ~ x + z))) (r->form "f <- lm(y ~ x + z, data = d)"))
  (test-equal '((define r (t-test x)) (htest-ref r 'p-value))
              (let ((fs (r->forms "r <- t.test(x)\nr$p.value"))) (list (car fs) (cadr (cadr (cadr fs))))))
  (test-equal '(lm-print f) (cadr (r->forms "f <- lm(y ~ x, data = d)\nsummary(f)"))))

(test-group "r->scm: unsupported"
  (test-equal '("rowwise()") (r-unsupported "d2 <- d |> rowwise()"))
  (test-assert (pair? (r-unsupported "x <- weird_function(1)")))
  ;; a statement that cannot be read at all does not stop the rest
  (test-equal 2 (length (r->forms "a <- 1\nb <- 2"))))

(test-group "r->scm: runs"
  ;; the translation is exactly this code, which gives the expected frame
  (let ((forms (r->forms "lim <- 1\nres <- d |> filter(x > lim) |> mutate(y = x * 2) |> arrange(desc(y))")))
    (test-equal '((define lim 1) (define res (-> d (where (> x ,lim)) (mutate (y (* x 2))) (arrange (desc y)))))
                forms))
  (let* ((d (tibble (x 1 2 3) (k "a" "b" "c")))
         (lim 1)
         (res (-> d (where (> x ,lim)) (mutate (y (* x 2))) (arrange (desc y)))))
    (test-equal #(6.0 4.0) (vector-map inexact (df-column res 'y)))
    (test-equal #("c" "b") (df-column res 'k))))

(test-group "scm->r"
  (test-equal "d <- cases |> filter(x > 1) |> mutate(y = x * 2)\n"
              (let ((s (scm->r-string '((define d (-> cases (where (> x 1)) (mutate (y (* x 2)))))))))
                (substring s (+ 2 (string-contains s "\n\n")) (string-length s))))
  (test-assert (string-contains (scm->r-string '((define d (read-csv "a.csv" 'sep #\; 'decimal #\,)))) "read_csv2(\"a.csv\")"))
  (test-assert (string-contains (scm->r-string '((define r (t-test sleep '(extra ~ group) 'var-equal #t))))
                                "t.test(extra ~ group, data = sleep, var.equal = TRUE)"))
  (test-assert (string-contains (scm->r-string '((define p (ggplot d (aes (x k) (y n)) (geom-col (position dodge)) (labs (title "T"))))))
                                "ggplot(d, aes(x = k, y = n)) +\n  geom_col(position = \"dodge\") +\n  labs(title = \"T\")"))
  (test-assert (string-contains (scm->r-string '((define s (-> d (where (in k ,(list "a" "b"))) (mutate (z (if (> x ,lim) "y" "n")))))))
                                "filter(k %in% c(\"a\", \"b\"))"))
  (test-assert (string-contains (scm->r-string '((define s (mutate d (z (* ,(f a) 2))))))
                                "z = !!f(a) * 2"))
  (test-assert (string-contains (scm->r-string '((define (sq x) (* x x)))) "sq <- function(x) x * x"))
  (test-assert (string-contains (scm->r-string "(define r (lm d '(y ~ x)))\n(lm-print r)") "print(summary(r))"))
  (test-assert (string-contains (scm->r-string '((let-values (((a b) (values 1 2))) a))) "TODO scheme"))
  (test-assert (string-contains (scm->r-string '((define x 1))) "x <- 1")))

(test-group "round trip"
  (for-each
   (lambda (r)
     (let* ((forms (call-with-values (lambda () (r->scm r)) (lambda (f u) f)))
            (back (scm->r-string forms)))
       (test-assert r (string-contains back r))))
   '("d <- cases |> filter(year >= 2024) |> group_by(splg) |> summarise(n = n())"
     "p <- ggplot(d, aes(x = splg, y = n)) +\n  geom_col() +\n  coord_flip()"
     "fit <- lm(y ~ x, data = d)")))

(test-group "report->rmd"
  (let ((rmd (report->rmd '(report (title "MFZO") (h2 "Points") (p "Total " (b "up")) (table ,per-splg (caption "ZH")) (figure ,p)))))
    (test-assert (string-contains rmd "title: \"MFZO\""))
    (test-assert (string-contains rmd "## Points"))
    (test-assert (string-contains rmd "Total **up**"))
    (test-assert (string-contains rmd "knitr::kable(per_splg, caption = \"ZH\")"))
    (test-assert (string-contains rmd "```{r, echo = FALSE}\np\n```"))))

(test-group "pretty"
  (test-equal "(define x 1)" (scm-pretty '(define x 1)))
  (test-equal "(-> d\n    ;; TODO (R): x\n    (where a))" (scm-pretty '(-> d (:comment "TODO (R): x") (where a))))
  (test-assert (string-contains (scm-pretty '(define a (-> data-frame-with-a-long-name (where (> some-column 1)) (mutate (other-column (* some-column 2))))))
                                "\n      (mutate")))

(test-end "scm-data-r")
