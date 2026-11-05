(define-library (scm sysadmin)
  (import (scm archive)
          (scm crypto)
          (scm csv)
          (scm datetime)
          (scm duration)
          (scm fs)
          (scm fs-find)
          (scm glob)
          (scm json)
          (scm log)
          (scm net-remote)
          (scm system)
          (scm text)
          (scm uri))
  (export ;; (scm fs)
   absolute-path
   base-name
   cd
   chmod
   chown
   copy-directory
   copy-file
   cp
   current-directory
   delete-directory
   delete-file
   directory-directories
   directory-exists?
   directory-files
   directory-name
   file-exists?
   file-modification-date
   file-modification-timestamp
   file-size
   join-path
   ln
   make-directory
   mktemp
   mktempdir
   move-directory
   move-file
   mv
   normalized-path
   path-sep
   readlink
   rm
   special-folder-application-data
   special-folder-documents
   special-folder-temp
   special-folder-user-home
   stat
   touch
   which
   ;; (scm fs-find)
   df
   du
   find-file
   tree
   xargs
   ;; (scm text)
   awk
   cat
   cut
   diff
   grep
   head
   hexdump
   sed
   sort-lines
   tail
   tee
   tr
   uniq
   wc
   ;; (scm archive)
   bunzip2
   bzip2
   close-input-zip
   close-output-zip
   deflate-compress
   deflate-decompress
   gunzip
   gzip
   gzip-compress
   gzip-decompress
   open-input-zip-file
   open-output-zip-file
   tar-create
   tar-extract
   tar-list
   unxz
   xz
   zip-add-binary-entry
   zip-add-stored-entry
   zip-add-text-entry
   zip-entry-names
   zip-files-equal?
   zip-read-entry-bytevector
   zlib-compress
   zlib-decompress
   ;; (scm net-remote)
   curl
   rsync
   scp
   ssh
   wget
   ;; (scm system)
   current-pid
   env-list
   get-bytes
   get-environment-variable
   getopt
   kill
   parent-pid
   pgrep
   pkill
   process-alive?
   process-kill
   process-pid
   process-wait
   ps
   ps-info
   run
   run!
   run-parallel
   run-program
   run-program/capture
   run?
   sh
   sh-lines
   shell-quote
   sleep
   start-program
   sys-machine-name
   sys-num-cpu-cores
   sys-os-version
   sys-platform
   sys-scm-technology
   sys-scm-version
   sys-user-name
   uuidgen
   watch
   ;; (scm datetime)
   format-iso8601
   now
   parse-iso8601
   parse-pubdate
   parse-rfc822
   time
   timestamp
   timestamp->string
   today
   ;; (scm log)
   log-access
   log-error
   log-info
   log-port
   log-warn
   ;; (scm duration)
   format-duration
   parse-duration
   ;; (scm glob)
   glob
   glob-match?
   ;; (scm crypto)
   base64-decode
   base64-encode
   bytevector->hex
   hex->bytevector
   md5-hash
   sha1-hash
   sha256-hash
   ;; (scm uri)
   percent-decode
   percent-encode
   ;; (scm json)
   close-json
   json-attribute
   json-next-object
   open-json-file
   open-json-string
   ;; (scm csv)
   csv-line->fields))
