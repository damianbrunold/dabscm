## Overview

`(scm crypto password)` stores and checks user passwords. New hashes use
PBKDF2-HMAC-SHA256 with a random salt and 600 000 iterations, written as the
self-describing string `pbkdf2$<iterations>$<salt>$<hash>`. Verification also
accepts Werkzeug (Flask) `pbkdf2:sha256:…` and `scrypt:…` hashes, so imported
users keep their passwords.

`password-pbkdf2-iterations` is a parameter holding the cost for new hashes
(default 600000). Tests can lower it with `parameterize`; raising it later
makes `password-needs-rehash?` flag the older hashes.

## Common uses

A login handler that also hides which usernames exist and upgrades old
hashes:

```scheme
(import (scm crypto password))

(define (login username password)
  (let ((user (find-user username)))          ; #f if unknown
    (and (password-verify password (and user (user-hash user)))
         (begin
           (when (password-needs-rehash? (user-hash user))
             (save-hash! user (password-hash password)))
           user))))
```

`password-verify` with `#f` as the stored value does the work of a real
check and returns `#f`, so a login for an unknown user takes as long as one
with a wrong password.
