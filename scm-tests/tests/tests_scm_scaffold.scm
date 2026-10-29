;; Tests for (scm scaffold): new-app copies a starter and renames every
;; spelling of its name, in paths and contents.

(import (scheme base)
        (scheme file)
        (scm test)
        (scm fs)
        (scm string)
        (scm scaffold))

(test-runner-factory scm-test-runner)
(test-begin "scm scaffold")

(define (read-all path)
  (call-with-input-file path
    (lambda (p)
      (let loop ((acc '()))
        (let ((s (read-string 65536 p)))
          (if (eof-object? s) (apply string-append (reverse acc)) (loop (cons s acc))))))))

(define (has? s x) (and (string-contains-from s x 0) #t))

(test-equal '("starter-public" "starter-login" "starter-admin" "starter-api") (starter-names))
(test-equal '("my-ledger" "my_ledger" "My Ledger" "MY_LEDGER") (app-name-variants "my-ledger"))
(test-equal '("x" "x" "X" "X") (app-name-variants "x"))

(define base (mktempdir '(prefix . "scaffold-test")))
(define dir (join-path base "my-ledger"))

(define files (new-app "starter-admin" dir))

(test-assert "README" (member "README.md" files))
(test-assert "the service is renamed" (member "deploy/systemd/my-ledger.service" files))
(test-assert "no local config" (not (member "config.scm" files)))
(test-assert "no test config" (not (member "tests/test-config.scm" files)))
(test-assert (file-exists? (join-path dir "src/app-web.sld")))
(let ((all (apply string-append (map (lambda (f) (read-all (join-path dir f))) files))))
  (test-assert "no starter-admin left" (not (has? all "starter-admin")))
  (test-assert "no starter_admin left" (not (has? all "starter_admin")))
  (test-assert "no STARTER_ADMIN left" (not (has? all "STARTER_ADMIN")))
  (test-assert "kebab" (has? all "my-ledger"))
  (test-assert "upper" (has? all "MY_LEDGER_TEST_CONFIG")))

(test-error "not empty" (new-app "starter-admin" dir))
(test-error "unknown starter" (new-app "starter-nope" (join-path base "a")))
(test-error "bad name" (new-app "starter-api" (join-path base "b") "My_App"))
(test-error "bad name: trailing dash" (new-app "starter-api" (join-path base "c") "app-"))

(test-group "explicit name"
  (let ((files (new-app "starter-public" (join-path base "web") "city-stats")))
    (test-assert (member "README.md" files))
    (test-assert (has? (read-all (join-path (join-path base "web") "README.md")) "city-stats"))))

(test-group "command"
  (test-equal 2 (new-app-command '("starter-api")))
  (test-equal 1 (new-app-command (list "starter-nope" (join-path base "d"))))
  (test-equal 0 (new-app-command (list "starter-api" (join-path base "api") "tokens"))))

(rm base 'recursive)

(test-end "scm scaffold")
