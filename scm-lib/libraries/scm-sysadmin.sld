(define-library (scm sysadmin)
  (import (scm fs)
          (scm fs-find)
          (scm text)
          (scm archive)
          (scm net-remote)
          (scm system)
          (scm datetime)
          (scm log)
          (scm duration)
          (scm glob)
          (scm crypto)
          (scm uri)
          (scm json)
          (scm csv))
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
          mktemp mktempdir
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
          du
          df
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
          tar-create
          tar-extract
          tar-list
          bzip2
          bunzip2
          gzip
          gunzip
          xz
          unxz
          open-output-zip-file
          open-input-zip-file
          close-output-zip
          close-input-zip
          zip-add-binary-entry
          zip-add-stored-entry
          zip-add-text-entry
          zip-entry-names
          zip-read-entry-bytevector
          zip-files-equal?
          gzip-compress
          gzip-decompress
          zlib-compress
          zlib-decompress
          deflate-compress
          deflate-decompress
          ;; (scm net-remote)
          curl
          rsync
          scp
          ssh
          wget
          ;; (scm system)
          current-pid
          env-list
          get-environment-variable
          get-bytes
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
          run?
          run-parallel
          run-program
          run-program/capture
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
          today
          now
          time
          timestamp
          timestamp->string
          format-iso8601
          parse-iso8601
          parse-rfc822
          parse-pubdate
          ;; (scm log)
          log-info
          log-warn
          log-error
          log-access
          log-port
          ;; (scm duration)
          parse-duration
          format-duration
          ;; (scm glob)
          glob
          glob-match?
          ;; (scm crypto)
          sha1-hash
          md5-hash
          sha256-hash
          base64-encode
          base64-decode
          bytevector->hex
          hex->bytevector
          ;; (scm uri)
          percent-encode
          percent-decode
          ;; (scm json)
          open-json-file
          open-json-string
          json-next-object
          json-attribute
          close-json
          ;; (scm csv)
          csv-line->fields))
