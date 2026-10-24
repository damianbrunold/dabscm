(import (scheme base) (scm crypto) (scm crypto password) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-crypto-password")

;; Cheap iterations keep the suite fast; the format is the same.
(password-pbkdf2-iterations 1000)

(test-group "password-hash / password-verify"
  (let ((h (password-hash "correct horse")))
    (test-assert "native prefix" (string=? "pbkdf2$1000$" (substring h 0 12)))
    (test-assert "correct" (password-verify "correct horse" h))
    (test-assert "wrong" (not (password-verify "Correct horse" h)))
    (test-assert "empty" (not (password-verify "" h)))
    ;; fresh salt each time
    (test-assert "salted" (not (string=? h (password-hash "correct horse")))))
  (test-assert "unicode" (password-verify "Zürich ✓" (password-hash "Zürich ✓"))))

(test-group "existing native hashes still verify"
  ;; A starter-era hash (200000 iterations), built here with known parts.
  (let* ((salt (string->utf8 "0123456789abcdef"))
         (dk (pbkdf2-sha256 (string->utf8 "secret") salt 2000 32))
         (h (string-append "pbkdf2$2000$" (base64-encode salt) "$" (base64-encode dk))))
    (test-assert (password-verify "secret" h))
    (test-assert (not (password-verify "Secret" h)))))

(test-group "Werkzeug hashes"
  ;; Fixtures from Werkzeug 3.1 generate_password_hash.
  (let ((scrypt-h "scrypt:32768:8:1$Mxy0MVyNc2hydnsv$e93478ea1860cadf42afa47e90627b933fb9f12d7ed2458fc00906414fdb48669b583090989beff2d3cbd732bfac656254c41f5deac74d997336e92506f20a12")
        (pbkdf2-h (let ((salt "abc123saltvalue0"))
                    (string-append "pbkdf2:sha256:1000$" salt "$"
                                   (bytevector->hex
                                    (pbkdf2-sha256 (string->utf8 "hunter2")
                                                   (string->utf8 salt) 1000 32))))))
    (test-assert "scrypt correct" (password-verify "hunter2" scrypt-h))
    (test-assert "scrypt wrong" (not (password-verify "hunter" scrypt-h)))
    (test-assert "pbkdf2 correct" (password-verify "hunter2" pbkdf2-h))
    (test-assert "pbkdf2 wrong" (not (password-verify "x" pbkdf2-h)))
    ;; Werkzeug pbkdf2 without an iteration count is not accepted
    (test-assert (not (password-verify "hunter2" "pbkdf2:sha256$salt$00")))))

(test-group "malformed or missing stored values"
  (test-equal #f (password-verify "x" #f))
  (test-equal #f (password-verify "x" ""))
  (test-equal #f (password-verify "x" "bcrypt$x$y"))
  (test-equal #f (password-verify "x" "pbkdf2$abc$c2FsdA==$aGFzaA=="))
  (test-equal #f (password-verify "x" "pbkdf2$1000$!!!$aGFzaA=="))
  (test-equal #f (password-verify "x" "pbkdf2$1000$c2FsdA==$"))
  (test-equal #f (password-verify "x" "scrypt:1:2$s$zz"))
  (test-equal #f (password-verify #f (password-hash "x"))))

(test-group "password-needs-rehash?"
  (test-equal #f (password-needs-rehash? (password-hash "pw")))
  (test-equal #t (password-needs-rehash? "pbkdf2$500$c2FsdA==$aGFzaA=="))
  (test-equal #f (password-needs-rehash? "pbkdf2$5000$c2FsdA==$aGFzaA=="))
  (test-equal #t (password-needs-rehash? "pbkdf2:sha256:600000$s$00"))
  (test-equal #t (password-needs-rehash? "garbage"))
  (test-equal #t (password-needs-rehash? #f))
  (parameterize ((password-pbkdf2-iterations 600000))
    (test-equal #t (password-needs-rehash? "pbkdf2$1000$c2FsdA==$aGFzaA=="))))

(test-end "scm-crypto-password")
