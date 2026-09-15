# Conditions signalled by gatekeepR

All errors raised by gatekeepR inherit from `gatekeepr_error` and carry
one specific class, so that code can react to a particular failure with
[`tryCatch()`](https://rdrr.io/r/base/conditions.html) or
[`rlang::try_fetch()`](https://rlang.r-lib.org/reference/try_fetch.html).
Warnings inherit from `gatekeepr_warning`.

|  |  |
|----|----|
| Class | When |
| `gatekeepr_error_config` | invalid panel, hierarchy, policy or configuration |
| `gatekeepr_error_structure` | required markers or features missing from the cell table |
| `gatekeepr_error_input` | an argument has the wrong type or value |
| `gatekeepr_error_ledger` | an invalid ledger row or target |
| `gatekeepr_error_confirm` | a destructive operation without `confirm = TRUE` |
| `gatekeepr_error_locked` | an attempt to modify a locked snapshot |
| `gatekeepr_error_lockfile` | a review working directory is held by another session |
| `gatekeepr_error_verify` | export verification failed |
| `gatekeepr_error_dependency` | a suggested package needed for this step is missing |
| `gatekeepr_error_state` | an object is not in the state a step needs |
| `gatekeepr_warning_uncallable` | markers not callable on an image (with list) |
| `gatekeepr_warning_disabled_rules` | rules disabled on an image (with list) |
