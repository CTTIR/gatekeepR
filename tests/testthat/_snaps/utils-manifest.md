# changed, missing, unlisted and unsafe entries are reported

    Code
      .gk_verify_manifest(dir, class = "verify", allow_extra = FALSE)
    Condition
      Error:
      ! Integrity check failed for '<review-dir>'.
      x file_hashes_match: changed: a.txt
      x no_unlisted_files: unlisted: .DS_Store

