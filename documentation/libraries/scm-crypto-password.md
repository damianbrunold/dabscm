# `(scm crypto password)`

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


## Exports

### `password-hash`

```
Syntax: (password-hash plain)
Library: (scm crypto password)
Description: Hashes the password string plain with PBKDF2-HMAC-SHA256, a
  fresh 16-byte random salt and (password-pbkdf2-iterations) iterations
  (default 600000). Returns the self-describing string
  pbkdf2$<iterations>$<salt-base64>$<hash-base64>; store it as is and
  check it with password-verify.
Example:
  (password-hash "correct horse") => "pbkdf2$600000$3HBY...$j+N/..."
```

### `password-needs-rehash?`

```
Syntax: (password-needs-rehash? stored)
Library: (scm crypto password)
Description: Returns #t unless stored is a password-hash string with at
  least (password-pbkdf2-iterations) iterations. After a successful
  password-verify, store (password-hash plain) when this is #t: that
  upgrades Werkzeug hashes and hashes made with a lower cost.
Example:
  (password-needs-rehash? (password-hash "pw")) => #f
  (password-needs-rehash? "pbkdf2$200000$c2FsdA==$aGFzaA==") => #t
```

### `password-pbkdf2-iterations`

*(no documentation)*

### `password-verify`

```
Syntax: (password-verify plain stored)
Library: (scm crypto password)
Description: Returns #t if the password string plain matches stored, else
  #f. stored may be a hash from password-hash or a Werkzeug
  pbkdf2:sha256:<iterations>$... or scrypt:<n>:<r>:<p>$... hash. The
  comparison is constant-time, and a malformed stored value yields #f
  rather than an error. Pass #f as stored for an unknown user: the call
  then does the work of a real check and returns #f, so response times
  do not reveal which usernames exist.
Example:
  (password-verify "correct horse" (password-hash "correct horse")) => #t
  (password-verify "guess" #f) => #f
```

