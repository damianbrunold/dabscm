(define-library (scm sysadmin)
  (import (scm fs)
          (scm fs-find)
          (scm text)
          (scm archive)
          (scm net-remote)
          (scm system))
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
          find
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
          env-list
          get-environment-variable
          get-bytes
          getopt
          process-alive?
          process-kill
          process-pid
          process-wait
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
          watch))
